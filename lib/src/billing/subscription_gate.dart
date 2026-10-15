import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import '../cast/cast_hls_proxy.dart';
import '../screens/home_screen.dart';
import '../screens/subscription_screen.dart';
import 'billing_controller.dart';
import 'billing_repository.dart';
import 'trial_welcome_dialog.dart';
import 'spark_billing_repository.dart';

class SubscriptionGate extends StatefulWidget {
  final String uid;
  final Future<void> Function() onSignOut;
  final BillingRepository? repository;
  const SubscriptionGate({super.key, required this.uid,
    required this.onSignOut, this.repository});
  @override
  State<SubscriptionGate> createState() => _SubscriptionGateState();
}
class _SubscriptionGateState extends State<SubscriptionGate> with WidgetsBindingObserver {
  late BillingController controller;
  GlobalKey<NavigatorState> navigationKey = GlobalKey<NavigatorState>();
  bool previouslyAllowed = false;
  bool noticeChecked = false;
  bool noticePending = false;
  bool welcomeRequired = false;
  bool accepting = false;
  bool acceptancePending = false;
  String? welcomeError;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initializeAccount();
  }
  void initializeAccount() {
    controller = BillingController(widget.repository ?? (SparkBillingRepository.enabled
      ? SparkBillingRepository.forAccount(widget.uid)
      : HttpBillingRepository.forAccount(widget.uid)));
    controller.addListener(checkAccess);
    unawaited(controller.initialize());
  }
  @override
  void didUpdateWidget(covariant SubscriptionGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid == widget.uid && oldWidget.repository == widget.repository) return;
    generation++;
    welcomeError = null;
    controller.removeListener(checkAccess);
    controller.dispose();
    unawaited(stopCast());
    navigationKey = GlobalKey<NavigatorState>();
    previouslyAllowed = noticeChecked = noticePending = welcomeRequired = accepting = acceptancePending = false;
    initializeAccount();
  }
  Future<void> stopCast() async {
    try { await GoogleCastSessionManager.instance.endSessionAndStopCasting(); } catch (_) {}
    await CastHlsProxy.instance.close();
  }
  void checkAccess() {
    final allowed = controller.allowed;
    if (previouslyAllowed && !allowed) unawaited(stopCast());
    if (previouslyAllowed != allowed) navigationKey = GlobalKey<NavigatorState>();
    previouslyAllowed = allowed;
    if (allowed && !controller.checking && controller.error == null &&
        controller.access?.state == 'trial' && !noticeChecked && !noticePending) {
      noticePending = true;
      unawaited(resolveWelcome(generation, controller, widget.uid));
    }
  }
  bool isCurrent(int ticket, BillingController source) =>
      mounted && ticket == generation && identical(source, controller);

  Future<bool> syncAcceptance(SharedPreferences prefs, BillingRepository repository,
      String pendingKey) async {
    if (prefs.getBool(pendingKey) != true) return true;
    try {
      await repository.claimTrialWelcomeNotice();
      await prefs.remove(pendingKey);
      return true;
    } catch (_) {
      return false;
    }
  }
  Future<void> resolveWelcome(int ticket, BillingController source, String uid) async {
    final acceptedKey = 'trial-welcome-accepted:$uid';
    final pendingKey = 'trial-welcome-pending:$uid';
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!isCurrent(ticket, source)) return;
      final serverAccepted = source.access?.trialWelcomeNoticeAccepted == true;
      final accepted = serverAccepted || prefs.getBool(acceptedKey) == true;
      if (serverAccepted) {
        await prefs.setBool(acceptedKey, true);
        await prefs.remove(pendingKey);
      } else if (accepted) {
        // A local receipt never replaces the per-account server acknowledgement.
        await prefs.setBool(pendingKey, true);
        final synced = await syncAcceptance(prefs, source.repository, pendingKey);
        if (!isCurrent(ticket, source)) return;
        if (!synced) {
          setState(() {
            noticeChecked = true;
            acceptancePending = true;
            welcomeError = 'Não foi possível confirmar a aceitação. Tente novamente.';
          });
          return;
        }
      }
      if (!isCurrent(ticket, source)) return;
      setState(() {
        noticeChecked = true;
        welcomeRequired = !accepted;
      });
    } catch (_) {
      if (isCurrent(ticket, source)) setState(() => welcomeError = 'Não foi possível carregar seu aviso de teste.');
    } finally {
      if (isCurrent(ticket, source)) noticePending = false;
    }
  }
  Future<void> acceptWelcome() async {
    if (accepting) return;
    final ticket = generation;
    final source = controller;
    final uid = widget.uid;
    setState(() {
      accepting = true;
      acceptancePending = true;
      welcomeError = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!isCurrent(ticket, source)) return;
      await prefs.setBool('trial-welcome-pending:$uid', true);
      await prefs.setBool('trial-welcome-accepted:$uid', true);
      final synced = await syncAcceptance(prefs, source.repository, 'trial-welcome-pending:$uid');
      if (!isCurrent(ticket, source)) return;
      setState(() {
        if (synced) {
          welcomeRequired = false;
          acceptancePending = false;
        } else {
          welcomeError = 'Não foi possível confirmar a aceitação. Tente novamente.';
        }
      });
    } catch (_) {
      if (isCurrent(ticket, source)) setState(() => welcomeError = 'Não foi possível salvar a aceitação.');
    } finally {
      if (isCurrent(ticket, source)) setState(() => accepting = false);
    }
  }
  Widget subscription(BuildContext context) => AnimatedBuilder(animation: controller,
    builder: (_, __) => SubscriptionScreen(checkout: controller.checkout,
      statusMessage: controller.message, onRefresh: controller.refresh,
      onSignOut: widget.onSignOut, busy: controller.checking || controller.openingCheckout));

  Widget accessScreen(BuildContext context) {
    // No grant is not an expired grant: never show checkout while resolving
    // authentication, server time, trial creation or a failed status request.
    if (controller.access == null) {
      return Scaffold(key: const ValueKey('access-verification'),
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (controller.error == null) const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(controller.error ?? 'Confirmando seu acesso…', textAlign: TextAlign.center),
          if (controller.error != null) ...[
            TextButton(onPressed: controller.refresh, child: const Text('Tentar novamente')),
            TextButton(onPressed: widget.onSignOut, child: const Text('Sair da conta')),
          ],
        ])));
    }
    if (!controller.allowed) return subscription(context);
    if (controller.access?.state == 'trial') {
      if (acceptancePending) {
        return Scaffold(key: const ValueKey('access-verification'),
          body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (welcomeError == null) const CircularProgressIndicator(),
            Text(welcomeError ?? 'Confirmando sua aceitação…', textAlign: TextAlign.center),
            if (welcomeError != null)
              TextButton(onPressed: accepting ? null : acceptWelcome,
                child: const Text('Tentar novamente')),
            TextButton(onPressed: widget.onSignOut, child: const Text('Sair da conta')),
          ])));
      }
      if (!noticeChecked) {
        return Scaffold(key: const ValueKey('access-verification'),
          body: Center(child: welcomeError == null ? const CircularProgressIndicator()
            : TextButton(onPressed: () {
                setState(() => welcomeError = null);
                checkAccess();
              }, child: const Text('Tentar novamente'))));
      }
      if (welcomeRequired) {
        // Keep the approved artwork, but contain the notice inside this account's
        // gate. It cannot outlive sign-out or expose Home before acceptance.
        return Scaffold(body: TrialWelcomeDialog(onAccepted: () => unawaited(acceptWelcome())));
      }
    }
    return HomeScreen(accountId: widget.uid, onSignOut: widget.onSignOut,
      subscriptionBuilder: subscription);
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(controller.refresh());
  }
  @override
  void dispose() {
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(checkAccess);
    controller.dispose();
    unawaited(stopCast());
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: controller,
    builder: (_, __) => NavigatorPopHandler<Object?>(
      onPopWithResult: (_) {
        final navigator = navigationKey.currentState;
        if (navigator != null) unawaited(navigator.maybePop());
      },
      child: Navigator(key: navigationKey,
        onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => AnimatedBuilder(
          animation: controller, builder: (context, _) => accessScreen(context))),
      ),
    ));
}
