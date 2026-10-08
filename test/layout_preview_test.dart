import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/auth/auth_controller.dart';
import 'package:rocha_plus/src/auth/auth_repository.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/screens/home_screen.dart';
import 'package:rocha_plus/src/screens/live_tv_screen.dart';
import 'package:rocha_plus/src/screens/login_screen.dart';
import 'package:rocha_plus/src/theme/rocha_theme.dart';

class _DisabledAuth implements AuthRepository {
  @override
  Future<void> initialize() async =>
      throw const LoginFailure('O login ainda não foi ativado nesta versão.');
  @override
  Stream<AuthAccount?> get accountChanges => const Stream.empty();
  @override
  bool supports(LoginProvider provider) => false;
  @override
  Future<void> signIn(LoginProvider provider) async => throw StateError('blocked');
  @override
  Future<void> signOut() async => throw StateError('blocked');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('regular login does not show layout preview by default', (tester) async {
    final auth = AuthController(_DisabledAuth());
    addTearDown(auth.dispose);
    await auth.initialize();
    await tester.pumpWidget(MaterialApp(home: LoginScreen(controller: auth)));
    expect(find.byKey(const ValueKey('layout-preview-button')), findsNothing);
    expect(find.text('Entrar com Google'), findsOneWidget);
    expect(find.text('O login ainda não foi ativado nesta versão.'), findsOneWidget);
  });

  testWidgets('explicit preview callback shows a labeled entry, not a sign-in',
      (tester) async {
    var opened = false;
    final auth = AuthController(_DisabledAuth());
    addTearDown(auth.dispose);
    await auth.initialize();
    await tester.pumpWidget(MaterialApp(home: LoginScreen(
      controller: auth, onPreviewLayout: () => opened = true,
    )));
    expect(find.byKey(const ValueKey('layout-preview-button')), findsOneWidget);
    expect(find.text('Prévia visual, sem canais, player ou espelhamento.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('layout-preview-button')));
    expect(opened, isTrue);
    expect(auth.account, isNull);
  });

  testWidgets('layout-only Home never queries channels and blocks media routes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var requests = 0;
    final repository = ChannelRepository(client: MockClient((request) async {
      requests++;
      return http.Response('UNEXPECTED REQUEST', 500);
    }));
    await tester.pumpWidget(MaterialApp(theme: RochaTheme.dark,
      home: HomeScreen(repository: repository, previewOnly: true)));
    await tester.pumpAndSettle();
    expect(requests, 0);
    expect(find.byKey(const ValueKey('home-featured-carousel')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-preview-notice')), findsOneWidget);
    expect(find.byType(LiveTvScreen), findsNothing);
    await tester.tap(find.byKey(const ValueKey('home-search')));
    await tester.pump();
    expect(find.byType(LiveTvScreen), findsNothing);
    expect(find.textContaining('Prévia do layout: canais'), findsOneWidget);
    expect(requests, 0);
    expect(tester.takeException(), isNull);
  });
}
