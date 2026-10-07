import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/screens/home_screen.dart';
import 'package:rocha_plus/src/screens/cast_control_screen.dart';
import 'package:rocha_plus/src/screens/live_tv_screen.dart';
import 'package:rocha_plus/src/theme/rocha_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ChannelRepository.resetSessionHealthForTests();
  });
  ChannelRepository repo() => ChannelRepository(client: MockClient((request) async =>
    http.Response(request.url == ChannelRepository.sportsPlaylist ? '#EXTM3U' :
        '#EXTM3U\n#EXTINF:-1 group-title="General",SBT Nacional\nhttps://example.com/sbt\n',
        200, headers: {'content-type': 'text/plain; charset=utf-8'})));
  for (final size in [const Size(320, 568), const Size(430, 932),
      const Size(960, 540), const Size(1920, 1080)]) {
    testWidgets('official Home, grid and Cast adapt at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Widget app(Widget child) => MaterialApp(theme: RochaTheme.dark, home: RepaintBoundary(key: const ValueKey('visual-capture'), child: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(1.3)), child: child)));
      await tester.pumpWidget(app(HomeScreen(repository: repo())));
      await tester.runAsync(() async {
        final context = tester.element(find.byType(HomeScreen));
        await precacheImage(const AssetImage('branding/dashboard-reference.png'), context);
        await precacheImage(const AssetImage('branding/cast-reference.png'), context);
      });
      await tester.pumpAndSettle();
      if (size.width == 430 || size.width == 1920) {
        await capture(tester, 'home-${size.width.toInt()}');
      }
      expect(find.byKey(const ValueKey('official-sidebar')),
        size.width >= 900 ? findsOneWidget : findsNothing);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('category-Infantil')), 180,
          scrollable: find.descendant(of: find.byKey(const ValueKey('home-scroll')),
            matching: find.byType(Scrollable)).first);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(app(LiveTvScreen(initialGroup: 'TV aberta', repository: repo())));
      await tester.pumpAndSettle();
      expect(find.text('SBT Nacional'), findsOneWidget);
      expect(find.byKey(const ValueKey('channel-grid')), findsOneWidget);
      expect(tester.takeException(), isNull);

      var toggles = 0;
      var disconnected = 0;
      await tester.pumpWidget(app(CastControlView(
        channel: const Channel(name: 'SBT Nacional', url: 'https://example.com/live', group: 'TV aberta'),
        deviceName: 'Sala de TV', status: 'Transmitindo agora', connected: true, playing: true,
        onBack: () {}, onToggle: () => toggles++, onDisconnect: () => disconnected++)));
      await tester.pumpAndSettle();
      if (size.width == 430 || size.width == 1920) {
        await capture(tester, 'cast-${size.width.toInt()}');
      }
      await tester.scrollUntilVisible(find.byTooltip('Pausar na TV'), 160);
      await tester.tap(find.byTooltip('Pausar na TV'));
      expect(toggles, 1);
      await tester.scrollUntilVisible(find.text('Desconectar da TV'), 100);
      await tester.tap(find.text('Desconectar da TV'));
      expect(disconnected, 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('unconfirmed Cast does not enable playback controls', (tester) async {
    var toggles = 0;
    await tester.pumpWidget(MaterialApp(home: CastControlView(
      channel: const Channel(name: 'Teste', url: 'https://example.com/live'),
      deviceName: 'Sala', status: 'Sem reprodução confirmada', connected: false, playing: false,
      onBack: () {}, onToggle: () => toggles++, onDisconnect: () {})));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byTooltip('Reproduzir na TV'), 140);
    await tester.tap(find.byTooltip('Reproduzir na TV'));
    expect(toggles, 0);
    expect(find.text('Transmitindo para'), findsNothing);
  });
  testWidgets('remote Enter activates the focused official watch button', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: HomeScreen(repository: repo())));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(LiveTvScreen), findsOneWidget);
    expect(find.text('SBT Nacional'), findsOneWidget);
  });
}

Future<void> capture(WidgetTester tester, String label) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('visual-capture')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final encoded = base64Encode(bytes!.buffer.asUint8List());
    image.dispose();
    // CI evidence is encoded so it can be inspected without a Flutter SDK on the host.
    // ignore: avoid_print
    print('ROCHA_SNAPSHOT_START ${label}');
    for (var i = 0; i < encoded.length; i += 160) {
      // ignore: avoid_print
      print(encoded.substring(i, (i + 160).clamp(0, encoded.length)));
    }
    // ignore: avoid_print
    print('ROCHA_SNAPSHOT_END ${label}');
  });
}
