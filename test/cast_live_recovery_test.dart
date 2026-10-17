import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/cast/cast_live_recovery.dart';

void main() {
  final source = Uri.parse('https://fixture.example/live.m3u8');
  final relay = Uri.parse('http://192.168.1.10:1234/hls?id=fixture');
  test('runtime ERROR reloads source, later failure tries relay, budget never loops', () async {
    final loads = <Uri>[];
    var ended = 0;
    final r = CastLiveRecovery(current: source, reload: (u) async { loads.add(u); },
      relay: () async => relay, canRecover: () => true, giveUp: () async { ended++; });
    expect(await r.recover(), isTrue);
    expect(await r.recover(), isTrue);
    expect(loads, [source, relay]);
    expect(await r.recover(), isFalse);
    expect(await r.recover(), isFalse);
    expect(ended, 1);
    expect(loads.length, 2);
  });
  test('duplicate receiver errors share one pending reload', () async {
    final loaded = Completer<void>();
    var calls = 0;
    final r = CastLiveRecovery(current: source, reload: (_) { calls++; return loaded.future; },
      canRecover: () => true, giveUp: () async {});
    final a = r.recover();
    final b = r.recover();
    expect(identical(a, b), isTrue);
    expect(calls, 1);
    loaded.complete();
    expect(await a, isTrue);
  });
  test('failed direct reload advances to relay in the same bounded recovery', () async {
    var calls = 0;
    final r = CastLiveRecovery(current: source,
      reload: (_) async { if (++calls == 1) throw StateError('receiver error'); },
      relay: () async => relay, canRecover: () => true, giveUp: () async { fail('Recovered relay'); });
    expect(await r.recover(), isTrue);
    expect(r.current, relay);
    expect(calls, 2);
  });
  test('account/player disposal while relay resolves prevents another remote load', () async {
    final pendingRelay = Completer<Uri>();
    var loads = 0;
    var ended = 0;
    final r = CastLiveRecovery(current: source, reload: (_) async { loads++; throw StateError('failed'); },
      relay: () => pendingRelay.future, canRecover: () => true, giveUp: () async { ended++; });
    final pending = r.recover();
    await Future<void>.delayed(Duration.zero);
    r.dispose();
    pendingRelay.complete(relay);
    expect(await pending, isFalse);
    expect(loads, 1);
    expect(ended, 0);
  });
  test('lost session or revoked access cannot initiate a reload', () async {
    final r = CastLiveRecovery(current: source, reload: (_) async { fail('Must not load'); },
      canRecover: () => false, giveUp: () async { fail('Must not touch another session'); });
    expect(await r.recover(), isFalse);
  });
  test('15 seconds of stalled media triggers recovery; short buffering does not', () {
    final w = CastStallWatchdog();
    expect(w.observe(position: const Duration(seconds: 40), now: Duration.zero, paused: false), isFalse);
    expect(w.observe(position: const Duration(seconds: 40), now: const Duration(seconds: 8), paused: false), isFalse);
    expect(w.observe(position: const Duration(seconds: 40), now: const Duration(seconds: 15), paused: false), isTrue);
    w.reset();
    expect(w.observe(position: const Duration(seconds: 60), now: const Duration(seconds: 16), paused: false), isFalse);
  });
  test('progress and deliberate pause never consume stalled playback budget', () {
    final w = CastStallWatchdog();
    for (var i = 0; i < 30; i++) {
      expect(w.observe(position: Duration(seconds: i), now: Duration(seconds: i), paused: false), isFalse);
    }
    for (var i = 30; i < 180; i++) {
      expect(w.observe(position: const Duration(seconds: 29), now: Duration(seconds: i), paused: true), isFalse);
    }
    expect(w.observe(position: const Duration(seconds: 30), now: const Duration(seconds: 180), paused: false), isFalse);
  });
}
