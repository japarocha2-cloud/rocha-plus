import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rocha_plus/src/auth/auth_controller.dart';
import 'package:rocha_plus/src/auth/auth_repository.dart';
import 'package:rocha_plus/src/lab/functional_lab_app.dart';
import 'package:rocha_plus/src/lab/approved_catalog_repository.dart';
import 'package:rocha_plus/src/lab/lab_entitlement.dart';
import 'package:rocha_plus/src/lab/lab_access_gate.dart';
import 'package:rocha_plus/src/screens/login_screen.dart';

class FixtureAuth extends AuthRepository {
  final changes = StreamController<AuthAccount?>.broadcast();
  @override
  Future<void> initialize() async {}
  @override
  Stream<AuthAccount?> get accountChanges async* {
    yield null;
    yield* changes.stream;
  }

  @override
  bool supports(LoginProvider provider) => provider == LoginProvider.google;
  @override
  Future<void> signIn(LoginProvider provider) async {
    changes.add(const AuthAccount(uid: 'fixture'));
  }

  @override
  Future<void> signOut() async {
    changes.add(null);
  }
}

Map<String, dynamic> grant({String uid = 'fixture', int ttl = 60000}) => {
      'uid': uid,
      'readOnly': true,
      'allowed': true,
      'reason': 'trial',
      'validForMs': ttl,
    };

Map<String, dynamic> approved(String name, {String engine = 'exoPlayer'}) {
  Map<String, Object?> phase(int seconds) => {
        'engine': engine,
        'elapsedSeconds': seconds,
        'progressSeconds': seconds,
        'startupMilliseconds': 500,
        'bufferingMilliseconds': 0,
        'stalls': 0,
        'videoTrackDetected': true,
        'error': null,
      };
  return {
    'name': name,
    'url': 'https://fixture.invalid/$name',
    'group': 'Filmes',
    'status': 'automatic_audiovisual_pass',
    'eligible': true,
    'blocked': false,
    'result': {
      'channelUrl': 'https://fixture.invalid/$name',
      'preferred': engine,
      engine == 'exoPlayer' ? 'exo' : 'vlc': phase(60),
      'confirmation': phase(180),
      'measuredEvidence': {
        engine == 'exoPlayer' ? 'exo' : 'vlc': {
          'changingPixelsObserved': true,
          'audioOutputObserved': true
        },
        'confirmation': {
          'changingPixelsObserved': true,
          'audioOutputObserved': true
        },
      }
    }
  };
}

void main() {
  test(
      'authenticated GET has bearer, disables redirects and closes on missing config',
      () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      expect(request.method, 'GET');
      expect(request.url.toString(), labEntitlementUrl);
      expect(request.headers['Authorization'], 'Bearer fixture-token');
      expect(request.followRedirects, false);
      return http.Response(jsonEncode(grant()), 200);
    });
    Future<LabAccess> check(String endpoint) => LabEntitlement.check('fixture',
        client: client,
        endpoint: endpoint,
        currentUid: () => 'fixture',
        getToken: () async => 'fixture-token');
    expect((await check('')).allowed, false);
    expect((await check('https://example.invalid/entitlement')).allowed, false);
    expect(requests, 0);
    expect((await check(labEntitlementUrl)).allowed, true);
    expect(requests, 1);
  });

  test(
      'denial, HTTP errors, wrong owner, legacy responses and invalid lifetimes fail closed',
      () async {
    final payloads = [
      grant(uid: 'someone-else'),
      {...grant(), 'readOnly': false},
      {...grant(), 'allowed': false},
      grant(ttl: 0),
      grant(ttl: 60001),
      {...grant(), 'allowed': 'true'},
      {...grant(), 'reason': 'local-admin'},
      {'uid': 'fixture', 'allowed': true}
    ];
    for (final payload in payloads) {
      final result = await LabEntitlement.check('fixture',
          endpoint: labEntitlementUrl,
          currentUid: () => 'fixture',
          getToken: () async => 'fixture-token',
          client:
              MockClient((_) async => http.Response(jsonEncode(payload), 200)));
      expect(result.allowed, false);
    }
    for (final code in [302, 401, 403, 404, 500, 503]) {
      final result = await LabEntitlement.check('fixture',
          endpoint: labEntitlementUrl,
          currentUid: () => 'fixture',
          getToken: () async => 'fixture-token',
          client: MockClient(
              (_) async => http.Response(jsonEncode(grant()), code)));
      expect(result.allowed, false);
    }
  });

  test('account switch during token lookup prevents any request', () async {
    var uid = 'fixture';
    final result = await LabEntitlement.check('fixture',
        endpoint: labEntitlementUrl,
        currentUid: () => uid,
        getToken: () async {
          uid = 'next';
          return 'fixture-token';
        },
        client: MockClient((_) async => throw StateError('must not send')));
    expect(result.allowed, false);
  });

  test(
      'approved snapshot preserves source order and rejects absent A/V evidence',
      () async {
    final rows = [approved('z'), approved('a', engine: 'libVlc')];
    final repo = ApprovedCatalogRepository(read: () async => jsonEncode(rows));
    final channels = await repo.loadBrazilPublicDirectory();
    expect(channels.map((c) => c.name), ['z', 'a']);
    expect(channels.last.preferredEngine, 'libVlc');
    final silent = approved('silent');
    silent['result']['measuredEvidence']['confirmation']
        ['audioOutputObserved'] = false;
    final short = approved('short');
    short['result']['confirmation']['elapsedSeconds'] = 60;
    for (final rows in [
      [],
      [silent],
      [short],
      [
        {...approved('pending'), 'status': 'pending'}
      ]
    ]) {
      final repo =
          ApprovedCatalogRepository(read: () async => jsonEncode(rows));
      await expectLater(
          repo.loadBrazilPublicDirectory(), throwsFormatException);
    }
  });

  testWidgets(
      'login -> server authorization -> catalog; logout removes private routes',
      (tester) async {
    final repository = FixtureAuth();
    final controller = AuthController(repository);
    final verification = Completer<LabAccess>();
    await tester.pumpWidget(FunctionalLabApp(
        authController: controller,
        verify: (_) => verification.future,
        homeBuilder: (_) =>
            const Scaffold(body: Text('Catalog fixture — no real streams'))));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Entrar com Apple'), findsNothing);
    expect(find.byKey(const ValueKey('apple-unavailable')), findsOneWidget);
    await tester.tap(find.text('Entrar com Google'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Catalog fixture — no real streams'), findsNothing);
    verification.complete(const LabAccess(true, Duration(seconds: 30)));
    await tester.pumpAndSettle();
    expect(find.text('Catalog fixture — no real streams'), findsOneWidget);
    final navigator = Navigator.of(
        tester.element(find.text('Catalog fixture — no real streams')));
    unawaited(navigator.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Private player fixture')))));
    await tester.pumpAndSettle();
    repository.changes.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Private player fixture'), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await repository.changes.close();
  });

  testWidgets(
      'grant expires and pending/offline authorization disposes nested player routes',
      (tester) async {
    var calls = 0;
    final offline = Completer<LabAccess>();
    await tester.pumpWidget(MaterialApp(
        home: LabAccessGate(
            uid: 'fixture',
            verify: (_) async => ++calls == 1
                ? const LabAccess(true, Duration(seconds: 2))
                : offline.future,
            homeBuilder: (_) =>
                const Scaffold(body: Text('Authorized catalog fixture')),
            onSignOut: () {})));
    await tester.pumpAndSettle();
    final navigator =
        Navigator.of(tester.element(find.text('Authorized catalog fixture')));
    unawaited(navigator.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Player fixture')))));
    await tester.pumpAndSettle();
    expect(find.text('Player fixture'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Player fixture'), findsNothing);
    offline.complete(LabAccess.denied);
    await tester.pumpAndSettle();
    expect(find.textContaining('Nenhum acesso foi concedido'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
