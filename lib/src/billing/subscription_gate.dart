import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import '../cast/cast_hls_proxy.dart';
import '../screens/home_screen.dart';
import '../live/favorites_repository.dart';
import '../live/channel_repository.dart';
import 'billing_controller.dart';
import 'subscription_screen.dart';

class SubscriptionGate extends StatefulWidget {
  final String uid;
  final FavoritesRepository favoritesRepository;
  final BillingController? billingController;
  final ChannelRepository? channelRepository;
  final Future<void> Function() onSignOut;
  const SubscriptionGate({super.key, required this.uid, required this.onSignOut,
    required this.favoritesRepository, this.billingController, this.channelRepository});
  @override
  State<SubscriptionGate> createState() => _SubscriptionGateState();
}
class _SubscriptionGateState extends State<SubscriptionGate> with WidgetsBindingObserver {
  late final BillingController controller;
  bool previouslyAllowed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = widget.billingController ?? BillingController(widget.uid);
    assert(controller.uid == widget.uid);
    previouslyAllowed = controller.allowed;
    controller.addListener(checkAccess);
    unawaited(controller.initialize());
  }
  Future<void> stopCast() async {
    try { await GoogleCastSessionManager.instance.endSessionAndStopCasting(); } catch (_) {}
    await CastHlsProxy.instance.close();
  }
  void checkAccess() {
    if (previouslyAllowed && !controller.allowed) unawaited(stopCast());
    previouslyAllowed = controller.allowed;
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(controller.refresh());
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(checkAccess);
    if (widget.billingController == null) controller.dispose();
    unawaited(stopCast());
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: controller,
    builder: (_, __) => Navigator(
      // Replace the complete route stack on loss of entitlement, disposing players.
      key: ValueKey(controller.allowed),
      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) =>
        controller.allowed
          ? HomeScreen(favoritesRepository: widget.favoritesRepository,
              repository: widget.channelRepository, onSignOut: widget.onSignOut, onSubscription: (context) {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) =>
                SubscriptionScreen(controller: controller)));
            })
          : SubscriptionScreen(controller: controller, onSignOut: widget.onSignOut)),
    ));
}
