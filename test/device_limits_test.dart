import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/auth/device_limits.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/screens/player_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

const channel = Channel(name: 'Canal', url: 'https://example.test/live.m3u8');
const streamId = '00000000-0000-4000-8000-000000000001';

/// Scripted server: each route answers from a queue, defaulting to success.
class FakeServer {
  final calls = <String>[];
  final bodies = <Map<String, Object?>>[];
  final scripted = <String, List<DeviceResponse>>{};
  void script(String route, List<DeviceResponse> responses) => scripted[route] = [...responses];
  Future<DeviceResponse> post(String route, Map<String, Object?> body) async {
    calls.add(route);
    bodies.add(body);
    final queue = scripted[route];
    if (queue != null && queue.isNotEmpty) return queue.removeAt(0);
    return switch (route) {
      'streams/start' => const DeviceResponse(200, {'streamId': streamId, 'leaseSeconds': 90}),
      _ => const DeviceResponse(200),
    };
  }
  StreamLease lease() => StreamLease(post: post, deviceId: () async => 'install-0000000000000001');
}

class TestController extends VideoPlayerController {
  TestController() : super.asset('fixture.mp4');
  int disposals = 0;
  @override
  Future<void> initialize() async {
    value = const VideoPlayerValue(duration: Duration.zero, size: Size(1920, 1080), isInitialized: true);
  }
  @override
  Future<void> play() async { value = value.copyWith(isPlaying: true); }
  @override
  Future<void> pause() async { value = value.copyWith(isPlaying: false); }
  @override
  Future<void> dispose() async { disposals++; await super.dispose(); }
}

void main() {
  test('layout heuristic: phone-sized screens are phones, large screens are TVs', () {
    expect(deviceKindFor(360), DeviceKind.phone);
    expect(deviceKindFor(430), DeviceKind.phone); // large phone
    expect(deviceKindFor(540), DeviceKind.tv); // 1080p Android TV (960x540)
    expect(deviceKindFor(800), DeviceKind.tv); // tablet counts as TV
  });

  test('feature is off by default and builds no production client', () {
    expect(deviceLimitsEnabled, isFalse);
    expect(StreamLease.production(), isNull);
  });

  test('server refusals map to plan messages; unreachable fails closed', () {
    expect(deviceLimitMessage(const DeviceResponse(409, {'error': 'Phone limit reached'})),
        contains('1 celular'));
    expect(deviceLimitMessage(const DeviceResponse(409, {'error': 'TV limit reached'})),
        contains('2 TVs'));
    expect(deviceLimitMessage(const DeviceResponse(409, {'error': 'Concurrent stream limit reached'})),
        contains('2 aparelhos'));
    expect(deviceLimitMessage(DeviceResponse.unreachable), contains('Confira a conexão'));
    expect(deviceLimitMessage(const DeviceResponse(500, {'error': 'stack trace here'})),
        isNot(contains('stack')));
  });

  test('install ID is random, valid and stable across calls', () async {
    SharedPreferences.setMockInitialValues({});
    final first = await StreamLease.installId();
    expect(first, matches(RegExp(r'^[A-Za-z0-9_-]{16,128}$')));
    expect(await StreamLease.installId(), first);
  });

  test('start registers the device with its kind, then starts a stream', () async {
    final server = FakeServer();
    final lease = server.lease();
    expect((await lease.start(DeviceKind.tv)).granted, isTrue);
    expect(server.calls, ['devices/register', 'streams/start']);
    expect(server.bodies.first, {'deviceId': 'install-0000000000000001', 'kind': 'tv'});
    expect((await lease.start(DeviceKind.tv)).granted, isTrue);
    expect(server.calls, hasLength(2), reason: 'an active lease is reused');
    await lease.stop();
  });

  test('device and stream limits deny before any media is opened', () async {
    final phone = FakeServer()..script('devices/register',
        [const DeviceResponse(409, {'error': 'Phone limit reached'})]);
    final denied = await phone.lease().start(DeviceKind.phone);
    expect(denied.granted, isFalse);
    expect(denied.message, contains('1 celular'));
    expect(phone.calls, ['devices/register']);

    final streams = FakeServer()..script('streams/start',
        [const DeviceResponse(409, {'error': 'Concurrent stream limit reached'})]);
    expect((await streams.lease().start(DeviceKind.tv)).message, contains('2 aparelhos'));

    final offline = FakeServer()..script('devices/register', [DeviceResponse.unreachable]);
    expect((await offline.lease().start(DeviceKind.tv)).granted, isFalse);
  });

  testWidgets('heartbeat renews every third of the lease; explicit refusal ends it once', (tester) async {
    final server = FakeServer();
    final lease = server.lease();
    final lost = <String>[];
    lease.onLost = lost.add;
    await lease.start(DeviceKind.tv);
    await tester.pump(const Duration(seconds: 30));
    expect(server.calls.where((c) => c == 'streams/heartbeat'), hasLength(1));
    server.script('streams/heartbeat', [const DeviceResponse(403, {'error': 'Entitlement required'})]);
    await tester.pump(const Duration(seconds: 30));
    expect(lost, ['Acesso não liberado pelo servidor.']);
    expect(lease.active, isFalse);
    await tester.pump(const Duration(seconds: 90));
    expect(server.calls.where((c) => c == 'streams/heartbeat'), hasLength(2), reason: 'timer stopped');
  });

  testWidgets('offline heartbeats keep playing only for one lease (3 misses)', (tester) async {
    final server = FakeServer();
    final lease = server.lease();
    final lost = <String>[];
    lease.onLost = lost.add;
    await lease.start(DeviceKind.phone);
    server.script('streams/heartbeat', [DeviceResponse.unreachable, DeviceResponse.unreachable,
        const DeviceResponse(200), DeviceResponse.unreachable, DeviceResponse.unreachable]);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 30)); // miss, miss, ok, miss, miss
    }
    expect(lost, isEmpty);
    server.script('streams/heartbeat', [DeviceResponse.unreachable]);
    await tester.pump(const Duration(seconds: 30)); // third miss in a row
    expect(lost.single, contains('Confira a conexão'));
  });

  testWidgets('transient server errors count as missed heartbeats, not refusals', (tester) async {
    final server = FakeServer();
    final lease = server.lease();
    final lost = <String>[];
    lease.onLost = lost.add;
    await lease.start(DeviceKind.tv);
    server.script('streams/heartbeat', [const DeviceResponse(502), const DeviceResponse(429),
        const DeviceResponse(200)]);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 30));
    }
    expect(lost, isEmpty);
    expect(lease.active, isTrue);
    await lease.stop();
  });

  test('closing the player while the server is granting releases the slot', () async {
    final gate = Completer<void>();
    final server = FakeServer();
    final lease = StreamLease(deviceId: () async => 'install-0000000000000001',
        post: (route, body) async {
          if (route == 'streams/start') await gate.future;
          return server.post(route, body);
        });
    final pending = lease.start(DeviceKind.tv);
    await Future<void>.delayed(Duration.zero);
    await lease.stop(); // dispose while start is in flight
    gate.complete();
    final outcome = await pending;
    expect(outcome.granted, isFalse);
    expect(lease.active, isFalse);
    expect(server.calls.last, 'streams/stop');
    expect(server.bodies.last, {'streamId': streamId});
    expect((await lease.start(DeviceKind.tv)).granted, isFalse, reason: 'a stopped lease stays stopped');
  });

  testWidgets('stop releases the stream and stops heartbeats', (tester) async {
    final server = FakeServer();
    final lease = server.lease();
    await lease.start(DeviceKind.tv);
    await lease.stop();
    expect(server.calls.last, 'streams/stop');
    expect(server.bodies.last, {'streamId': streamId});
    await tester.pump(const Duration(seconds: 120));
    expect(server.calls.where((c) => c == 'streams/heartbeat'), isEmpty);
  });

  group('PlayerScreen', () {
    testWidgets('without a lease the player behaves as before', (tester) async {
      var created = 0;
      await tester.pumpWidget(MaterialApp(home: PlayerScreen(channel: channel,
          controllerFactory: (_) { created++; return TestController(); })));
      await tester.pump();
      expect(created, 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a refused lease never opens the media and offers retry', (tester) async {
      final server = FakeServer()..script('streams/start',
          [const DeviceResponse(409, {'error': 'Concurrent stream limit reached'})]);
      var created = 0;
      await tester.pumpWidget(MaterialApp(home: PlayerScreen(channel: channel,
          streamLease: server.lease(),
          controllerFactory: (_) { created++; return TestController(); })));
      await tester.pump();
      await tester.pump();
      expect(created, 0);
      expect(find.textContaining('2 aparelhos'), findsOneWidget);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pump();
      await tester.pump();
      expect(created, 1, reason: 'retry asks the server again and opens once granted');
      expect(find.textContaining('2 aparelhos'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('losing the lease disposes local playback and shows the reason', (tester) async {
      final server = FakeServer();
      final controller = TestController();
      await tester.pumpWidget(MaterialApp(home: PlayerScreen(channel: channel,
          streamLease: server.lease(), controllerFactory: (_) => controller)));
      await tester.pump();
      await tester.pump();
      expect(controller.value.isPlaying, isTrue);
      server.script('streams/heartbeat', [const DeviceResponse(409, {'error': 'Stream lease expired'})]);
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(controller.disposals, greaterThanOrEqualTo(1));
      expect(find.textContaining('encerrada pelo servidor'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('leaving the player releases the server slot', (tester) async {
      final server = FakeServer();
      await tester.pumpWidget(MaterialApp(home: PlayerScreen(channel: channel,
          streamLease: server.lease(), controllerFactory: (_) => TestController())));
      await tester.pump();
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(server.calls.last, 'streams/stop');
    });
  });
}
