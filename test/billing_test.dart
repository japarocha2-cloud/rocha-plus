import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rocha_plus/src/billing/billing_repository.dart';
import 'package:rocha_plus/src/billing/billing_controller.dart';

class FakeBillingRepository implements BillingRepository {
  bool active = true;
  bool fail = false;
  Duration duration = const Duration(days: 7);
  int checkouts = 0;
  @override
  Future<BillingAccess> status() async {
    if (fail) throw const BillingFailure('Sem confirmação do servidor.');
    return BillingAccess(active: active, state: active ? 'trial' : 'expired',
      remaining: active ? duration : Duration.zero, trialRemainingDays: active ? 7 : 0);
  }
  @override
  Future<Uri> checkout(String plan) async {
    checkouts++;
    return Uri.parse('https://www.mercadopago.com.br/checkout/v1/redirect');
  }
}
void main() {
  test('backend endpoint missing or insecure never grants access', () async {
    for (final endpoint in ['', 'http://example.com']) {
      final repository = HttpBillingRepository(endpoint: endpoint,
        tokenProvider: () async => 'token', client: MockClient((_) async => throw StateError('No request')));
      await expectLater(repository.status(), throwsA(isA<BillingFailure>()));
    }
  });
  test('identity token is sent only to configured API; client does not choose UID or amount', () async {
    final repository = HttpBillingRepository(endpoint: 'https://example.com/billing',
      tokenProvider: () async => 'synthetic-token', client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer synthetic-token');
        expect(jsonDecode(request.body), {'action': 'checkout', 'plan': 'monthly'});
        return http.Response(jsonEncode({'checkoutUrl': 'https://www.mercadopago.com.br/checkout/v1/redirect'}), 200);
      }));
    expect((await repository.checkout('monthly')).host, 'www.mercadopago.com.br');
  });
  test('malformed or expired grants are rejected; duration uses server clock', () {
    expect(BillingAccess.fromJson({'active': true, 'state': 'trial', 'serverTime': 100,
      'accessUntil': 200, 'trialRemainingDays': 1}).remaining, const Duration(milliseconds: 100));
    expect(() => BillingAccess.fromJson({'active': true, 'state': 'trial',
      'serverTime': 100, 'accessUntil': 99, 'trialRemainingDays': 1}), throwsA(isA<BillingFailure>()));
  });
  test('checkout return is never proof of payment', () async {
    final repository = FakeBillingRepository()..active = false;
    final controller = BillingController(repository, openUrl: (_) async => true);
    addTearDown(controller.dispose);
    await controller.refresh();
    await controller.checkout('monthly');
    expect(controller.allowed, isFalse);
    repository.active = true;
    await controller.refresh();
    expect(controller.allowed, isTrue);
  });
  test('network failure revokes a previously granted lease', () async {
    final repository = FakeBillingRepository();
    final controller = BillingController(repository);
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(controller.allowed, isTrue);
    repository.fail = true;
    await controller.refresh();
    expect(controller.allowed, isFalse);
  });
}
