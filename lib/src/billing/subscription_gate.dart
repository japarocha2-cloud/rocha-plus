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
  late final BillingController controller;
  GlobalKey<NavigatorState> navigationKey = GlobalKey<NavigatorState>();
  bool previouslyAllowed = false;
  bool noticePending = false;
  bool noticeChecked = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = BillingController(widget.repository ?? (SparkBillingRepository.enabled
      ? SparkBillingRepository.forAccount(widget.uid)
      : HttpBillingRepository.forAccount(widget.uid)));
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
  String get _acceptedKey => 'trial-welcome-accepted:${widget.uid}';
  String get _pendingKey => 'trial-welcome-pending:${widget.uid}';

  Future<void> _syncAcceptance(SharedPreferences prefs) async {
    if (prefs.getBool(_pendingKey) != true) return;
    try {
      // The authenticated server binds this acknowledgement to the account.
      await controller.repository.claimTrialWelcomeNotice();
      await prefs.remove(_pendingKey);
    } catch (_) {
      // Keep the local acknowledgement and retry on the next status refresh.
    }
  }

  Future<void> showWelcomeNotice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      if (controller.access?.trialWelcomeNoticeAccepted == true) {
        await prefs.setBool(_acceptedKey, true);
        await prefs.remove(_pendingKey);
        noticeChecked = true;
        return;
      }
      if (prefs.getBool(_acceptedKey) == true) {
        await _syncAcceptance(prefs);
        noticeChecked = prefs.getBool(_pendingKey) != true;
        return;
      }
      if (!controller.allowed || controller.access?.state != 'trial') return;
      noticeChecked = true;
      final accepted = await showTrialWelcomeDialog(context);
      if (accepted == true) {
        // The dialog has already closed; storage/network never delay the click.
        await prefs.setBool(_pendingKey, true);
        await prefs.setBool(_acceptedKey, true);
        await _syncAcceptance(prefs);
        noticeChecked = prefs.getBool(_pendingKey) != true;
      } else {
        noticeChecked = false;
      }
    } catch (_) {
      noticeChecked = false;
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
