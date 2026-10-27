import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vlc_player_platform_interface/flutter_vlc_player_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/screens/adaptive_player_screen.dart';

const first = Channel(name: 'Regional Um', url: 'https://example.test/one',
    preferredEngine: 'libVlc');
const second = Channel(name: 'Regional Dois', url: 'https://example.test/two',
    preferredEngine: 'libVlc');

/// Simulates view creation exactly once per mounted native surface.
class NativeView extends StatefulWidget {
  const NativeView({required this.platform, required this.onCreated});
  final TestVlcPlatform platform;
  final PlatformViewCreatedCallback onCreated;
  @override
  State<NativeView> createState() => _NativeViewState();
}

class _NativeViewState extends State<NativeView> {
  late final int id;
  @override
  void initState() {
    super.initState();
    id = ++widget.platform.nextId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onCreated(id);
    });
  }
  @override
  Widget build(BuildContext context) => SizedBox(key: ValueKey('native-vlc-' + id.toString()));
}

class TestVlcPlatform extends VlcPlayerPlatform {
  int nextId = 0;
  final created = <(int, String)>[];
  final disposed = <int>[];
  final commands = <String>[];
  final events = <int, StreamController<VlcMediaEvent>>{};

  void reset() {
    created.clear();
    disposed.clear();
    commands.clear();
  }
  @override
  Future<void> init() async {}
  @override
  Widget buildView(PlatformViewCreatedCallback onPlatformViewCreated, {
    bool virtualDisplay = true,
  }) => NativeView(platform: this, onCreated: onPlatformViewCreated);
  @override
  Future<void> create({
    required int viewId, required String uri, required DataSourceType type,
    String? package, bool? autoPlay, HwAcc? hwAcc, VlcPlayerOptions? options,
  }) async {
    created.add((viewId, uri));
    events[viewId] = StreamController<VlcMediaEvent>.broadcast(sync: true);
  }
  @override
  Stream<VlcMediaEvent> mediaEventsFor(int viewId) => events[viewId]!.stream;
  @override
  Stream<VlcRendererEvent> rendererEventsFor(int viewId) => const Stream.empty();
  @override
  Future<void> dispose(int viewId) async {
    disposed.add(viewId);
    await events.remove(viewId)?.close();
  }
  @override
  Future<void> play(int viewId) async { commands.add('play:' + viewId.toString()); }
  @override
  Future<void> pause(int viewId) async { commands.add('pause:' + viewId.toString()); }
}

void main() {
  final platform = TestVlcPlatform();
  final original = VlcPlayerPlatform.instance;
  setUpAll(() { VlcPlayerPlatform.instance = platform; });
  tearDownAll(() { VlcPlayerPlatform.instance = original; });
  setUp(() {
    platform.reset();
    SharedPreferences.setMockInitialValues({});
    ChannelRepository.resetSessionHealthForTests();
  });

  Future<void> frames(WidgetTester tester) async {
    // The plugin keeps its hidden placeholder ticker alive. Wait a bounded
    // number of frames, then assert explicit platform state instead.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> open(WidgetTester tester, {bool fullscreen = false}) async {
    await tester.pumpWidget(MaterialApp(home: AdaptivePlayerScreen(
        channel: first, channels: const [first, second],
        initiallyFullscreen: fullscreen)));
    await frames(tester);
  }
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await frames(tester);
    expect(platform.events, isEmpty);
    expect(tester.takeException(), isNull);
  }

  testWidgets('VLC initializes one native surface and remote Enter reaches playback', (tester) async {
    await open(tester);
    expect(platform.created, hasLength(1));
    final id = platform.created.single.$1;
    expect(platform.created.single.$2, first.url);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await frames(tester);
    expect(platform.commands, ['play:' + id.toString()]);
    await close(tester);
    expect(platform.disposed, [id]);
  });

  testWidgets('VLC channel change binds the new controller to a new native surface', (tester) async {
    await open(tester);
    final originalId = platform.created.single.$1;
    await tester.sendKeyEvent(LogicalKeyboardKey.channelUp);
    await frames(tester);
    expect(find.text(second.name), findsOneWidget);
    expect(platform.created, hasLength(2));
    expect(platform.created.last.$2, second.url);
    expect(platform.created.last.$1, isNot(originalId));
    expect(platform.disposed, [originalId]);
    await close(tester);
    expect(platform.disposed.toSet(), platform.created.map((entry) => entry.$1).toSet());
  });

  testWidgets('VLC Back exits fullscreen before disposing the player', (tester) async {
    await open(tester, fullscreen: true);
    expect(find.byType(AppBar), findsNothing);
    await tester.binding.handlePopRoute();
    await frames(tester);
    expect(find.byType(AdaptivePlayerScreen), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(platform.created, hasLength(1));
    expect(platform.disposed, isEmpty);
    await close(tester);
  });

  testWidgets('VLC fullscreen toggles retain the existing native surface', (tester) async {
    await open(tester);
    final id = platform.created.single.$1;
    await tester.tap(find.byTooltip('Tela cheia'));
    await frames(tester);
    await tester.tap(find.byTooltip('Sair da tela cheia'));
    await frames(tester);
    expect(platform.created, [(id, first.url)]);
    expect(platform.disposed, isEmpty);
    await close(tester);
  });

  testWidgets('VLC decoder error leaves an actionable fallback focused for the remote', (tester) async {
    await open(tester);
    final id = platform.created.single.$1;
    platform.events[id]!.add(VlcMediaEvent(mediaEventType: VlcMediaEventType.error));
    await frames(tester);
    expect(find.text('O sinal falhou neste reprodutor.'), findsOneWidget);
    expect(find.text(first.name), findsOneWidget);
    expect(Focus.of(tester.element(find.text('Tentar no ExoPlayer'))).hasFocus, isTrue);
    await close(tester);
  });

  testWidgets('repeated VLC channel changes release every replaced native player', (tester) async {
    await open(tester);
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.channelUp);
      await frames(tester);
    }
    expect(platform.created, hasLength(5));
    expect(platform.events, hasLength(1));
    await close(tester);
    expect(platform.disposed, hasLength(5));
    expect(platform.disposed.toSet(), hasLength(5));
  });
  testWidgets('initialized VLC removes its hidden loading animation', (tester) async {
    await open(tester);
    expect(platform.created, hasLength(1));
    expect(find.byType(CircularProgressIndicator, skipOffstage: false), findsNothing);
    await close(tester);
  });
}
