import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'billing_repository.dart';

class BillingController extends ChangeNotifier {
  final BillingRepository repository;
  final Future<bool> Function(Uri) openUrl;
  BillingController(this.repository, {Future<bool> Function(Uri)? openUrl})
      : openUrl = openUrl ?? ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication));
  final Stopwatch _leaseClock = Stopwatch();
  BillingAccess? _grant;
  Duration _lease = Duration.zero;
  Timer? _expiry;
  Timer? _poll;
  Future<void>? _pending;
  bool _disposed = false;
  bool checking = false;
  bool openingCheckout = false;
  String? error;
  bool get allowed => _grant?.active == true && _leaseClock.elapsed < _lease;
  BillingAccess? get access => _grant;
  String get message {
    if (error != null) return error!;
    if (checking && _grant == null) return 'Confirmando seu acesso…';
    if (_grant?.state == 'trial' && allowed) {
      return '${_grant!.trialRemainingDays} dia(s) restantes de teste grátis.';
    }
    if (_grant?.state == 'paid' && allowed) return 'Sua assinatura está ativa.';
    return 'Seu período de acesso terminou. Assine para continuar assistindo.';
  }
  Future<void> initialize() {
    _poll ??= Timer.periodic(const Duration(minutes: 1), (_) => unawaited(refresh()));
    return refresh();
  }
  Future<void> refresh() => _pending ??= _refresh().whenComplete(() => _pending = null);
  Future<void> _refresh() async {
    if (_disposed) return;
    checking = true;
    error = null;
    notifyListeners();
    try {
      final requestTime = Stopwatch()..start();
      final grant = await repository.status();
      final remaining = grant.remaining - requestTime.elapsed;
      if (_disposed) return;
      _expiry?.cancel();
      _grant = grant;
      _lease = remaining < const Duration(minutes: 5)
          ? remaining : const Duration(minutes: 5);
      _leaseClock..reset()..start();
      if (grant.active && remaining > Duration.zero) {
        _expiry = Timer(_lease, () {
          _grant = null;
          _leaseClock.stop();
          notifyListeners();
          unawaited(refresh());
        });
      }
    } catch (failure) {
      if (_disposed) return;
      _grant = null;
      _expiry?.cancel();
      error = failure is BillingFailure ? failure.message : 'Não foi possível confirmar seu acesso.';
    } finally {
      if (!_disposed) { checking = false; notifyListeners(); }
    }
  }
  Future<void> checkout(String plan) async {
    if (_disposed || openingCheckout) return;
    openingCheckout = true;
    notifyListeners();
    try {
      final uri = await repository.checkout(plan);
      if (_disposed) return;
      if (!await openUrl(uri)) throw const BillingFailure('Não foi possível abrir o Mercado Pago.');
      // Returning from checkout never grants access. Only status() can do that.
    } finally {
      if (!_disposed) { openingCheckout = false; notifyListeners(); }
    }
  }
  @override
  void dispose() {
    _disposed = true;
    _expiry?.cancel();
    _poll?.cancel();
    _leaseClock.stop();
    super.dispose();
  }
}
