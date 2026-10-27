import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rocha_plus/src/auth/subscription_access.dart';

void main() {
  test('known reasons are displayed only when consistent with server authorization', () {
    for (final reason in ['trial', 'paid', 'expired']) {
      final result = SubscriptionAccessResult.fromPayload({
        'uid': 'A', 'allowed': reason != 'expired', 'reason': reason,
        'expiresAt': '2026-11-01T12:00:00Z',
      }, 'A')!;
      expect(result.reason, reason);
      expect(result.expiresAt, DateTime.utc(2026, 11, 1, 12));
    }
    for (final payload in [
      {'uid': 'B', 'allowed': true, 'reason': 'paid'},
      {'uid': 'A', 'allowed': 'true', 'reason': 'paid'},
      {'uid': 'A', 'reason': 'trial'},
      ['paid'],
    ]) {
      expect(SubscriptionAccessResult.fromPayload(payload, 'A'), isNull);
    }
  });

  test('unknown or contradictory metadata never claims paid access or a trial', () {
    for (final reason in ['future', 'expired', null]) {
      final result = SubscriptionAccessResult.fromPayload({
        'uid': 'A', 'allowed': true, 'reason': reason,
        'expiresAt': '2026-11-01T12:00:00Z',
      }, 'A')!;
      expect(result.allowed, isTrue);
      expect(result.reason, isNull);
      expect(result.expiresAt, isNull);
      expect(result.label, 'Acesso confirmado pelo servidor');
    }
    expect(SubscriptionAccessResult.fromPayload({
      'uid': 'A', 'allowed': false, 'reason': 'paid',
    }, 'A')!.reason, isNull);
  });

  test('dates are optional and never authorize using the local clock', () {
    final past = SubscriptionAccessResult.fromPayload({
      'uid': 'A', 'allowed': true, 'reason': 'paid',
      'expiresAt': '2000-01-01T00:00:00Z',
    }, 'A')!;
    expect(past.allowed, isTrue); // Server decision, not DateTime.now().
    for (final expiry in [null, 'tomorrow', '2026-13-01T00:00:00Z',
      '2026-02-30T00:00:00Z', '2026-11-01T12:00:00', 123]) {
      final result = SubscriptionAccessResult.fromPayload({
        'uid': 'A', 'allowed': true, 'reason': 'trial', 'expiresAt': expiry,
      }, 'A')!;
      expect(result.expiresAt, isNull);
    }
  });

  test('401, malformed payload and offline responses cannot confirm access', () async {
    for (final client in [
      MockClient((_) async => http.Response('{"allowed":true}', 401)),
      MockClient((_) async => http.Response('invalid json', 200)),
      MockClient((_) async => throw StateError('offline')),
    ]) {
      addTearDown(client.close);
      expect(await SubscriptionAccess.check('A', client: client,
        endpointUri: Uri.parse('https://example.test/entitlement'),
        currentUid: () => 'A', getToken: () async => 'fixture'), isNull);
    }
  });

  test('account switch while token or response is pending discards the old account', () async {
    var uid = 'A';
    final token = Completer<String?>();
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.headers['Authorization'], 'Bearer fixture');
      uid = 'B';
      return http.Response(jsonEncode({'uid': 'A', 'allowed': true, 'reason': 'paid'}), 200);
    });
    addTearDown(client.close);
    final pending = SubscriptionAccess.check('A', client: client,
      endpointUri: Uri.parse('https://example.test/entitlement'),
      currentUid: () => uid, getToken: () => token.future);
    uid = 'B';
    token.complete('fixture');
    expect(await pending, isNull);
    expect(calls, 0);
    uid = 'A';
    expect(await SubscriptionAccess.check('A', client: client,
      endpointUri: Uri.parse('https://example.test/entitlement'),
      currentUid: () => uid, getToken: () async => 'fixture'), isNull);
    expect(calls, 1);
  });

  test('missing or invalid token never sends an HTTP request', () async {
    final client = MockClient((_) async => throw StateError('must not call HTTP'));
    addTearDown(client.close);
    for (final readToken in <Future<String?> Function()>[
      () async => null, () async => '', () async => throw StateError('invalid token'),
    ]) {
      expect(await SubscriptionAccess.check('A', client: client,
        endpointUri: Uri.parse('https://example.test/entitlement'),
        currentUid: () => 'A', getToken: readToken), isNull);
    }
  });
  test('invalid timezone offsets cannot fabricate a displayed expiration', () {
    for (final suffix in ['+24:00', '-24:00', '+03:60', '-99:99']) {
      final result = SubscriptionAccessResult.fromPayload({
        'uid': 'A', 'allowed': true, 'reason': 'paid',
        'expiresAt': '2026-11-01T12:00:00' + suffix,
      }, 'A')!;
      expect(result.allowed, isTrue);
      expect(result.expiresAt, isNull);
    }
    expect(SubscriptionAccessResult.fromPayload({
      'uid': 'A', 'allowed': true, 'reason': 'paid',
      'expiresAt': '2026-11-01T12:00:00-03:00',
    }, 'A')!.expiresAt, DateTime.utc(2026, 11, 1, 15));
  });
}
