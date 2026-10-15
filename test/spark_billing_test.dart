import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rocha_plus/src/billing/billing_repository.dart';
import 'package:rocha_plus/src/billing/spark_billing_repository.dart';

const name = 'projects/rocha-plus/databases/(default)/documents/rochaSparkAccounts/111';
const start = '2026-10-14T12:00:00Z';
Map<String, dynamic> found(String now, {bool accepted = false, String? paidUntil}) => {
  'readTime': now, 'found': {'name': name, 'updateTime': start, 'fields': {
    'trialStartedAt': {'timestampValue': start},
    'welcomeAcceptedAt': accepted ? {'timestampValue': start} : {'nullValue': null},
    if (paidUntil != null) 'paidUntil': {'timestampValue': paidUntil},
  }},
};
SparkBillingRepository repo(http.Client client) => SparkBillingRepository(
  projectId: 'rocha-plus', accountId: '111', tokenProvider: () async => 'synthetic-token', client: client);
void main() {
  test('trial uses authoritative readTime and expires exactly seven days later', () async {
    var now = '2026-10-21T11:59:59Z';
    final r = repo(MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer synthetic-token');
      expect(jsonDecode(request.body), {'documents': [name]});
      return http.Response(jsonEncode([found(now)]), 200);
    }));
    final active = await r.status();
    expect(active.active, true); expect(active.remaining, const Duration(seconds: 1));
    now = '2026-10-21T12:00:00Z';
    final expired = await r.status();
    expect(expired.active, false); expect(expired.state, 'expired');
  });
  test('first login creates only server timestamp and never client payment data', () async {
    var readCount = 0;
    final r = repo(MockClient((request) async {
      if (request.url.path.endsWith(':batchGet')) {
        readCount++;
        return http.Response(jsonEncode([readCount == 1
          ? {'missing': name, 'readTime': start} : found(start)]), 200);
      }
      final write = (jsonDecode(request.body)['writes'] as List).single as Map;
      expect(write['currentDocument'], {'exists': false});
      expect(write['updateTransforms'], [{'fieldPath': 'trialStartedAt', 'setToServerValue': 'REQUEST_TIME'}]);
      expect(write['update']['fields'], {'welcomeAcceptedAt': {'nullValue': null}});
      return http.Response('{}', 200);
    }));
    expect((await r.status()).trialRemainingDays, 7);
  });
  test('reinstall reads existing trial without writes and acceptance is account bound', () async {
    final r = repo(MockClient((request) async {
      expect(request.url.path.endsWith(':batchGet'), true);
      return http.Response(jsonEncode([found('2026-10-16T12:00:00Z', accepted: true)]), 200);
    }));
    expect((await r.status()).trialRemainingDays, 5);
    expect((await r.status()).trialWelcomeNoticeAccepted, true);
    expect(await r.claimTrialWelcomeNotice(), false);
  });
  test('acceptance uses server transform and document version without resetting trial', () async {
    final r = repo(MockClient((request) async {
      if (request.url.path.endsWith(':batchGet')) {
        return http.Response(jsonEncode([found(start)]), 200);
      }
      expect(jsonDecode(request.body), {'writes': [{
        'transform': {'document': name, 'fieldTransforms': [
          {'fieldPath': 'welcomeAcceptedAt', 'setToServerValue': 'REQUEST_TIME'}]},
        'currentDocument': {'updateTime': start},
      }]});
      return http.Response('{}', 200);
    }));
    expect(await r.claimTrialWelcomeNotice(), true);
  });
  test('opening existing checkout never grants or changes access', () async {
    final r = repo(MockClient((request) async =>
      http.Response(jsonEncode([found('2026-10-22T12:00:00Z')]), 200)));
    expect((await r.checkout('monthly')).toString(), 'https://mpago.la/2E7yjF4');
    expect((await r.status()).active, false);
    await expectLater(r.checkout('unknown'), throwsA(isA<BillingFailure>()));
  });
  test('permission denial, missing server time and another account fail closed', () async {
    for (final response in [http.Response('{}', 403),
      http.Response(jsonEncode([{'found': found(start)['found']}]), 200),
      http.Response(jsonEncode([{'readTime': start, 'missing': '$name-other'}]), 200)]) {
      await expectLater(repo(MockClient((_) async => response)).status(), throwsA(isA<BillingFailure>()));
    }
  });
  test('only an authoritative paidUntil can grant access after the trial', () async {
    final r = repo(MockClient((_) async => http.Response(jsonEncode([
      found('2026-10-22T12:00:00Z', paidUntil: '2026-11-22T12:00:00Z')]), 200)));
    expect((await r.status()).state, 'paid');
  });
  test('concurrent trial creation re-reads existing server record after conflict', () async {
    var reads = 0, writes = 0;
    final r = repo(MockClient((request) async {
      if (request.url.path.endsWith(':commit')) {
        writes++;
        return http.Response('{}', 409);
      }
      reads++;
      return http.Response(jsonEncode([reads == 1
        ? {'missing': name, 'readTime': '2026-10-16T12:00:00Z'}
        : found('2026-10-16T12:00:00Z', accepted: true)]), 200);
    }));
    final access = await r.status();
    expect(access.trialRemainingDays, 5);
    expect(access.trialWelcomeNoticeAccepted, true);
    expect(writes, 1);
  });
  test('reopening and recreating repository cannot restart expired trial', () async {
    final client = MockClient((request) async {
      expect(request.url.path.endsWith(':batchGet'), true);
      return http.Response(jsonEncode([found('2026-10-22T12:00:00Z', accepted: true)]), 200);
    });
    for (var attempt = 0; attempt < 3; attempt++) {
      final access = await repo(client).status();
      expect(access.active, false);
      expect(access.trialRemainingDays, 0);
      expect(access.trialWelcomeNoticeAccepted, true);
    }
  });
  test('account B cannot reuse the server trial response of A', () async {
    final r = SparkBillingRepository(projectId: 'rocha-plus', accountId: '222',
      tokenProvider: () async => 'synthetic-B', client: MockClient((request) async {
        expect(jsonDecode(request.body), {'documents': [name.replaceAll('/111', '/222')]});
        return http.Response(jsonEncode([found(start)]), 200);
      }));
    await expectLater(r.status(), throwsA(isA<BillingFailure>()));
  });

}
