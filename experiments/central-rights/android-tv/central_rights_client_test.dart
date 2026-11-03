import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rocha_plus/src/auth/central_rights_client.dart';

void main() {
  test('shared cross-platform contract vectors', () {
    final cases = jsonDecode(File('test/fixtures/central-rights-v1.json').readAsStringSync()) as List;
    for (final c in cases) {
      expect(CentralLease.parse(c['packet'], uid: c['uid'] as String,
          device: c['device'] as String, scope: c['scope'] as String, elapsedMs: 0) != null,
          c['allowed'], reason: c['name'] as String);
    }
  });
  Map<String, dynamic> packet() => {'contractVersion': 1,
    'environment': 'central-rights-lab', 'scope': 'homologation', 'uid': 'fixture',
    'device_id': 'mobile', 'state': 'lab', 'allowed': true, 'active': true,
    'serverTime': 1000, 'accessUntil': 61000, 'grantUntil': 100000,
    'playbackAllowed': false};
  CentralLease? parse(Map<String, dynamic> p) => CentralLease.parse(p,
      uid: 'fixture', device: 'mobile', scope: 'homologation', elapsedMs: 10);
  test('LAB separate from paid and clock discounts network', () {
    expect(parse(packet())!.duration.inMilliseconds, 59990);
    expect(parse({...packet(), 'state': 'paid'}), isNull);
  });
  test('UID, device and scope mismatch deny', () {
    for (final field in ['uid', 'device_id', 'scope']) {
      expect(parse({...packet(), field: 'other'}), isNull);
    }
  });
  test('expired, oversized and untyped lease deny', () {
    expect(parse({...packet(), 'accessUntil': 1001}), isNull);
    expect(parse({...packet(), 'accessUntil': 62000}), isNull);
    expect(parse({...packet(), 'serverTime': '1000'}), isNull);
    expect(parse({...packet(), 'grantUntil': 2000}), isNull);
  });
  test('server paid and trial accepted only in commercial scope', () {
    for (final state in ['paid', 'trial']) {
      expect(CentralLease.parse({...packet(), 'scope': 'commercial', 'state': state},
          uid: 'fixture', device: 'mobile', scope: 'commercial', elapsedMs: 0), isNotNull);
    }
  });
  test('authenticated request, no client-supplied UID or duration', () async {
    final client = CentralRightsClient(endpoint: Uri.parse('https://fixture.invalid/v1/access'),
      uid: 'fixture', mobileId: 'a' * 64, currentUid: () => 'fixture',
      getIdToken: () async => 'fixture-token', httpClient: MockClient((req) async {
        expect(req.headers['Authorization'], 'Bearer fixture-token');
        final body = jsonDecode(req.body) as Map;
        expect(body.containsKey('uid'), false); expect(body.containsKey('paidUntil'), false);
        return http.Response(jsonEncode(packet()), 200);
      }));
    expect(await client.status(), isNotNull);
    expect(await client.status(playback: true), isNull);
  });
  test('network, unauthorized and missing token fail closed', () async {
    for (final status in [401, 403, 503]) {
      final client = CentralRightsClient(endpoint: Uri.parse('https://fixture.invalid/v1/access'),
        uid: 'fixture', mobileId: 'a' * 64, currentUid: () => 'fixture',
        getIdToken: () async => 'fixture-token', httpClient: MockClient((_) async => http.Response('{}', status)));
      expect(await client.status(), isNull);
    }
  });
  test('account switched while token loads rejects response', () async {
    var uid = 'fixture';
    final client = CentralRightsClient(endpoint: Uri.parse('https://fixture.invalid/v1/access'),
      uid: uid, mobileId: 'a' * 64, currentUid: () => uid,
      getIdToken: () async { uid = 'other'; return 'fixture-token'; },
      httpClient: MockClient((_) async => throw StateError('must not send')));
    expect(await client.status(), isNull);
  });
  test('HTTP endpoint rejected before sending identity', () async {
    final client = CentralRightsClient(endpoint: Uri.parse('http://fixture.invalid/v1/access'),
      uid: 'fixture', mobileId: 'a' * 64, currentUid: () => 'fixture',
      getIdToken: () async => throw StateError('must not read token'),
      httpClient: MockClient((_) async => throw StateError('must not send')));
    expect(await client.status(), isNull);
  });
  test('TV code, pending, authenticated mobile approval and session binding', () async {
    final device = 'c' * 64, token = 'd' * 64;
    var approved = false;
    final client = CentralRightsClient(endpoint: Uri.parse('https://fixture.invalid/v1/access'),
      uid: 'fixture', mobileId: 'a' * 64, currentUid: () => 'fixture',
      getIdToken: () async => 'fixture-token', httpClient: MockClient((req) async {
        final body = jsonDecode(req.body) as Map;
        switch (body['action']) {
          case 'start': return http.Response(jsonEncode({'environment': 'central-rights-lab',
            'device_code': 'b' * 64, 'device_id': device, 'user_code': 'ABCD2345'}), 200);
          case 'approve': approved = true; return http.Response('{}', 200);
          case 'poll': return http.Response(jsonEncode(approved
            ? {...packet(), 'device_id': device, 'session_token': token, 'status': 'approved'}
            : {'status': 'pending'}), approved ? 200 : 202);
          default:
            expect(req.headers['Authorization'], 'Bearer $token');
            return http.Response(jsonEncode({...packet(), 'device_id': device,
              'playbackAllowed': body['playback_active'] == true}), 200);
        }
      }));
    expect(await client.startTvPairing(), 'ABCD2345');
    expect(await client.pollTvPairing(), isNull);
    await client.approveTv('ABCD2345');
    expect(await client.pollTvPairing(), isNotNull);
    expect(client.sessionToken, token);
    expect((await client.status(tv: true, playback: true))!.playbackAllowed, true);
  });

  test('neutral TV navigation never sends stop; playback and stop are explicit', () async {
    final bodies = <Map<String, dynamic>>[];
    final client = CentralRightsClient(endpoint: Uri.parse('https://fixture.invalid/v1/access'),
      uid: 'fixture', mobileId: 'a' * 64, currentUid: () => 'fixture',
      getIdToken: () async => 'fixture-token', httpClient: MockClient((req) async {
        bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response(jsonEncode({...packet(), 'device_id': 'c' * 64,
          'playbackAllowed': true}), 200);
      }))..sessionToken = 'd' * 64..tvDevice = 'c' * 64;
    for (var i = 0; i < 3; i++) { expect(await client.status(tv: true), isNotNull); }
    expect(bodies.every((b) => b['action'] == 'status' && !b.containsKey('playback_active')), true);
    await client.status(tv: true, playback: true);
    expect(bodies.last['playback_active'], true);
    await client.stop(tv: true);
    expect(bodies.last['playback_active'], false);
    await client.request('logout', tv: true);
    expect(bodies.last, {'action': 'logout'});
  });
  test('mobile entitlement is neutral, playback and stop are separate actions', () async {
    final bodies = <Map<String, dynamic>>[];
    final client = CentralRightsClient(endpoint: Uri.parse('https://fixture.invalid/v1/access'),
      uid: 'fixture', mobileId: 'a' * 64, currentUid: () => 'fixture',
      getIdToken: () async => 'fixture-token', httpClient: MockClient((req) async {
        bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response(jsonEncode({...packet(), 'playbackAllowed': true}), 200);
      }));
    await client.status(); await client.status(playback: true); await client.stop();
    expect(bodies.map((b) => b['action']).toList(), ['entitlement', 'mobile_playback', 'mobile_stop']);
    expect(bodies.every((b) => !b.containsKey('playback_active')), true);
  });
}
