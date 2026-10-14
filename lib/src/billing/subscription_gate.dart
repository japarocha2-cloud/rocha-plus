import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import '../cast/cast_hls_proxy.dart';
import '../screens/home_screen.dart';
import '../screens/subscription_screen.dart';
import 'billing_controller.dart';
import 'billing_repository.dart';

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
  late final BillingController controller;
  GlobalKey<NavigatorState> navigationKey = GlobalKey<NavigatorState>();
  bool previouslyAllowed = false;
  bool noticePending = false;
  bool noticeChecked = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = BillingController(widget.repository ?? HttpBillingRepository.forAccount(widget.uid));
    controller.addListener(checkAccess);
    unawaited(controller.initialize());
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
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(showWelcomeNotice()));
    }
  }
  Future<void> showWelcomeNotice() async {
    try {
      if (!mounted) return;
      final show = await controller.repository.claimTrialWelcomeNotice();
      if (!mounted) return;
      noticeChecked = true;
      if (!show || !controller.allowed || controller.access?.state != 'trial') return;
      await showDialog<void>(context: context, barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Você ganhou 7 dias grátis!'),
          content: const Text('Bem-vindo ao Rocha+! Aproveite os canais e recursos durante seu período de teste. '
            'Depois, escolha um plano para continuar: R\$ 4,90 por mês ou R\$ 55,00 por ano.'),
          actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Começar a assistir'))],
        ));
    } catch (_) {
      // A notice failure never grants playback access; retry on next status refresh.
    } finally {
      noticePending = false;
    }
  }
  Widget subscription(BuildContext context) => AnimatedBuilder(animation: controller,
    builder: (_, __) => SubscriptionScreen(checkout: controller.checkout,
      statusMessage: controller.message, onRefresh: controller.refresh,
      onSignOut: widget.onSignOut, busy: controller.checking || controller.openingCheckout));
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(controller.refresh());
  }
  @override
  void dispose() {
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
          animation: controller, builder: (context, _) => controller.allowed
            ? HomeScreen(accountId: widget.uid, onSignOut: widget.onSignOut,
                subscriptionBuilder: subscription)
            : subscription(context))),
      ),
    ));
}
