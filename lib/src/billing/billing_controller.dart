import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import '../app_release_policy.dart';

class BillingController extends ChangeNotifier {
  static const productId = 'rocha_plus_monthly';
  static const endpoint = String.fromEnvironment('ROCHA_BILLING_ENDPOINT');
  final String uid;
  BillingController(this.uid);
  StreamSubscription<List<PurchaseDetails>>? _purchases;
  Timer? _poll;
  Timer? _expiry;
  bool _disposed = false;
  bool busy = false;
  bool active = false;
  String state = 'NONE';
  String? error;
  String? accountId;
  int? expiresAt;
  bool autoRenewing = false;
  List<GooglePlayProductDetails> offers = [];
  bool get beta => RochaReleasePolicy.betaAccessIsFree;
  bool get allowed => beta || (active && expiresAt != null &&
      DateTime.now().millisecondsSinceEpoch < expiresAt!);
  bool get configured => Uri.tryParse(endpoint)?.scheme == 'https';
  void changed() { if (!_disposed) notifyListeners(); }
  Future<Map<String, dynamic>> request(String action, {String? token}) async {
    if (!configured || FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('Billing unavailable');
    }
    final idToken = await FirebaseAuth.instance.currentUser!.getIdToken();
    final response = await http.post(Uri.parse(endpoint),
      headers: {'Authorization': 'Bearer $idToken', 'Content-Type': 'application/json'},
      body: jsonEncode({'action': action, if (token != null) 'token': token}),
    ).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw StateError('Verification failed');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
  Future<void> initialize() async {
    if (beta) return; // No store connection or purchase flow in the authorized beta.
    if (defaultTargetPlatform != TargetPlatform.android || kIsWeb) {
      error = 'Assinaturas disponíveis no Android com Google Play.'; changed(); return;
    }
    _purchases = InAppPurchase.instance.purchaseStream.listen(
      (items) => unawaited(handle(items)), onError: (Object _) {
        active = false; error = 'Não foi possível verificar a compra.'; changed();
      });
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => unawaited(refresh()));
    await run(() async {
      accountId = (await request('account'))['accountId'] as String;
      if (!await InAppPurchase.instance.isAvailable()) throw StateError('Store unavailable');
      final response = await InAppPurchase.instance.queryProductDetails({productId});
      if (response.error != null) throw StateError('Products unavailable');
      offers = response.productDetails.whereType<GooglePlayProductDetails>().where((p) {
        final index = p.subscriptionIndex;
        final details = p.productDetails.subscriptionOfferDetails;
        if (index == null || details == null || index >= details.length) return false;
        final offer = details[index];
        final phases = offer.pricingPhases;
        return offer.basePlanId == 'monthly' && phases.isNotEmpty &&
          phases.last.billingPeriod == 'P1M' &&
          phases.last.priceCurrencyCode == 'BRL' &&
          phases.last.priceAmountMicros == 4900000 &&
          (offer.offerId == null || (offer.offerId == 'trial-7-days' &&
            phases.length == 2 && phases.first.priceAmountMicros == 0 &&
            phases.first.billingPeriod == 'P7D'));
      }).toList();
      await refresh();
      await InAppPurchase.instance.restorePurchases();
    });
  }
  bool isTrial(GooglePlayProductDetails p) {
    final index = p.subscriptionIndex;
    return index != null &&
      p.productDetails.subscriptionOfferDetails?[index].offerId == 'trial-7-days';
  }
  void apply(Map<String, dynamic> value) {
    if (_disposed) return;
    expiresAt = value['expiresAt'] as int?;
    active = value['active'] == true && expiresAt != null;
    state = value['state'] as String? ?? 'NONE';
    autoRenewing = value['autoRenewing'] == true;
    _expiry?.cancel();
    if (active) {
      final remaining = expiresAt! - DateTime.now().millisecondsSinceEpoch;
      if (remaining <= 0) { active = false; } else {
        _expiry = Timer(Duration(milliseconds: remaining), () {
          active = false; state = 'SUBSCRIPTION_STATE_EXPIRED'; changed();
        });
      }
    }
    changed();
  }
  Future<void> refresh() async {
    if (beta || _disposed) return;
    try { apply(await request('entitlement')); }
    catch (_) { active = false; error = 'Não foi possível confirmar sua assinatura. Tente novamente.'; changed(); }
  }
  Future<void> run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true; error = null; changed();
    try { await action(); }
    catch (_) { error = 'Não foi possível concluir. Tente novamente.'; }
    finally { busy = false; changed(); }
  }
  Future<void> buy(GooglePlayProductDetails offer) async {
    if (beta || accountId == null || !offers.contains(offer)) return;
    await run(() async {
      final ok = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: GooglePlayPurchaseParam(productDetails: offer,
          applicationUserName: accountId, offerToken: offer.offerToken));
      if (!ok) throw StateError('Purchase not started');
    });
  }
  Future<void> restore() async {
    if (beta) return;
    await run(() async {
      await InAppPurchase.instance.restorePurchases();
      await refresh();
    });
  }
  Future<void> handle(List<PurchaseDetails> items) async {
    for (final purchase in items) {
      if (_disposed || purchase.productID != productId) continue;
      if (purchase.status == PurchaseStatus.pending) {
        state = 'SUBSCRIPTION_STATE_PENDING'; changed(); continue;
      }
      if (purchase.status == PurchaseStatus.canceled) {
        error = 'Compra cancelada. Nenhuma nova assinatura foi confirmada.'; changed(); continue;
      }
      if (purchase.status == PurchaseStatus.error) {
        error = 'A Google Play não concluiu a compra.'; changed(); continue;
      }
      try {
        final result = await request('verify',
          token: purchase.verificationData.serverVerificationData);
        apply(result);
        // Backend acknowledges only authenticated, bound, eligible test purchases.
        if (result['active'] == true && purchase.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchase);
        }
        error = null; changed();
      } catch (_) {
        active = false; error = 'Compra ainda não validada. Use Restaurar compras.'; changed();
      }
    }
  }
  @override
  void dispose() {
    _disposed = true; _poll?.cancel(); _expiry?.cancel();
    unawaited(_purchases?.cancel()); super.dispose();
  }
}
