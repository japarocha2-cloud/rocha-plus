import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:rocha_plus/src/billing/billing_controller.dart';

Map<String, dynamic> grant(bool active) => {
  'active': active, 'state': active ? 'SUBSCRIPTION_STATE_ACTIVE' : 'SUBSCRIPTION_STATE_EXPIRED',
  'expiresAt': DateTime.now().millisecondsSinceEpoch + 60000, 'autoRenewing': true,
};
PurchaseDetails purchase(PurchaseStatus status) => PurchaseDetails(
  productID: BillingController.productId,
  verificationData: PurchaseVerificationData(localVerificationData: '',
    serverVerificationData: 'test-token-aaaaaaaa', source: 'google_play'),
  transactionDate: null, status: status,
);
void main() {
  test('late active refresh cannot override newer revocation', () async {
    final responses = <Completer<Map<String, dynamic>>>[];
    final controller = BillingController('one', beta: false,
      transport: (action, {token}) {
        final pending = Completer<Map<String, dynamic>>(); responses.add(pending);
        return pending.future;
      });
    final old = controller.refresh(), latest = controller.refresh();
    responses[1].complete(grant(false)); await latest;
    responses[0].complete(grant(true)); await old;
    expect(controller.allowed, false);
    controller.dispose();
  });
  test('late failure cannot revoke a newer verified result', () async {
    final responses = <Completer<Map<String, dynamic>>>[];
    final controller = BillingController('one', beta: false,
      transport: (action, {token}) {
        final pending = Completer<Map<String, dynamic>>(); responses.add(pending);
        return pending.future;
      });
    final old = controller.refresh(), latest = controller.refresh();
    responses[1].complete(grant(true)); await latest;
    responses[0].completeError(StateError('offline')); await old;
    expect(controller.allowed, true); expect(controller.error, isNull);
    controller.dispose();
  });
  test('pending never requests verification or grants access', () async {
    var calls = 0;
    final controller = BillingController('one', beta: false,
      transport: (action, {token}) async { calls++; return grant(true); });
    await controller.handle([purchase(PurchaseStatus.pending)]);
    expect(controller.allowed, false); expect(calls, 0);
    expect(controller.state, 'SUBSCRIPTION_STATE_PENDING');
    controller.dispose();
  });
  test('purchased and restored require server validation; failure blocks', () async {
    var fail = false;
    final calls = <String>[];
    final controller = BillingController('one', beta: false,
      transport: (action, {token}) async {
        calls.add(action); expect(token, 'test-token-aaaaaaaa');
        if (fail) throw StateError('offline');
        return grant(true);
      });
    await controller.handle([purchase(PurchaseStatus.purchased)]);
    expect(controller.allowed, true);
    await controller.handle([purchase(PurchaseStatus.restored)]);
    expect(calls, ['verify', 'verify']);
    fail = true;
    await controller.handle([purchase(PurchaseStatus.restored)]);
    expect(controller.allowed, false);
    controller.dispose();
  });
  test('disposed controller ignores late verification', () async {
    final response = Completer<Map<String, dynamic>>();
    final controller = BillingController('one', beta: false,
      transport: (action, {token}) => response.future);
    final pending = controller.refresh();
    controller.dispose(); response.complete(grant(true)); await pending;
    expect(controller.active, false);
  });
  test('beta does not verify store events', () async {
    var calls = 0;
    final controller = BillingController('one',
      transport: (action, {token}) async { calls++; return grant(true); });
    await controller.handle([purchase(PurchaseStatus.purchased)]);
    expect(calls, 0); expect(controller.allowed, true);
    controller.dispose();
  });
}
