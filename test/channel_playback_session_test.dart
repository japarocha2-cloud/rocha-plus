import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/live/channel_playback_session.dart';
import 'package:rocha_plus/src/widgets/channel_navigation.dart';

const first = Channel(name: 'Primeiro', url: 'https://example.test/one');
const second = Channel(name: 'Segundo', url: 'https://example.test/two');
const blocked = Channel(name: 'Bloqueado', url: 'https://example.test/blocked');

void main() {
  test(
    'next/previous wrap, deduplicate URLs and skip blocked channels',
    () async {
      final session = ChannelPlaybackSession(
        initial: first,
        channels: [first, blocked, second, second],
        allowed: (c) => c != blocked,
      );
      addTearDown(session.dispose);
      expect(session.playlist, [first, second]);
      await session.step(1);
      expect(session.current, second);
      await session.step(1);
      expect(session.current, first);
      await session.step(-1);
      expect(session.current, second);
    },
  );
  test('Cast changes only after receiver confirmation and does not overlap commands', () async {
    final gate = Completer<String>();
    final loads = <Channel>[];
    final session = ChannelPlaybackSession(initial: first, channels: [second]);
    addTearDown(session.dispose);
    await session.startCasting((channel) async {
      loads.add(channel);
      return channel == first ? 'confirmed-one' : gate.future;
    });
    final switching = session.step(1);
    expect(session.current, first);
    expect(session.busy, isTrue);
    await session.step(1);
    expect(loads, [first, second]);
    gate.complete('confirmed-two');
    await switching;
    expect(session.current, second);
    expect(session.confirmedContentId, 'confirmed-two');
  });
  test(
    'failed Cast change retains previous selection and unlocks retry',
    () async {
      final session = ChannelPlaybackSession(
        initial: first,
        channels: [second],
      );
      addTearDown(session.dispose);
      await session.startCasting((c) async {
        if (c == second) throw StateError('receiver rejected');
        return c.url;
      });
      await expectLater(session.step(1), throwsStateError);
      expect(session.current, first);
      expect(session.confirmedContentId, first.url);
      expect(session.busy, isFalse);
      session.stopCasting();
      await session.step(1);
      expect(session.current, second);
    },
  );
  test('disconnect discards a late Cast connection confirmation', () async {
    final gate = Completer<String>();
    final session = ChannelPlaybackSession(initial: first, channels: [second]);
    addTearDown(session.dispose);
    final connecting = session.startCasting((_) => gate.future);
    session.deviceName = 'TV';
    session.stopCasting();
    expect(session.busy, isFalse);
    expect(session.deviceName, isNull);
    gate.complete('late-confirmation');
    await connecting;
    expect(session.casting, isFalse);
    expect(session.confirmedContentId, isNull);
  });
  test('disconnect discards an in-flight Cast channel change', () async {
    final gate = Completer<String>();
    final session = ChannelPlaybackSession(initial: first, channels: [second]);
    addTearDown(session.dispose);
    await session.startCasting((c) async {
      if (c == first) return c.url;
      return gate.future;
    });
    final switching = session.step(1);
    session.stopCasting();
    gate.complete(second.url);
    await switching;
    expect(session.current, first);
    expect(session.casting, isFalse);
    expect(session.confirmedContentId, isNull);
    expect(session.busy, isFalse);
    await session.step(1);
    expect(session.current, second);
  });
  test('stale completion cannot unlock a newer Cast operation', () async {
    final oldGate = Completer<String>();
    final newGate = Completer<String>();
    final session = ChannelPlaybackSession(initial: first, channels: [second]);
    addTearDown(session.dispose);
    final oldConnection = session.startCasting((_) => oldGate.future);
    session.stopCasting();
    final newConnection = session.startCasting((_) => newGate.future);
    oldGate.complete('old-receiver');
    await oldConnection;
    expect(session.busy, isTrue);
    expect(session.casting, isFalse);
    newGate.complete('new-receiver');
    await newConnection;
    expect(session.busy, isFalse);
    expect(session.casting, isTrue);
    expect(session.confirmedContentId, 'new-receiver');
  });
  test('disposed session ignores late confirmation and further commands', () async {
    final gate = Completer<String>();
    final session = ChannelPlaybackSession(initial: first, channels: [second]);
    final connecting = session.startCasting((_) => gate.future);
    session.dispose();
    gate.complete('late-receiver');
    await connecting;
    var called = false;
    await session.startCasting((_) async {
      called = true;
      return 'unexpected';
    });
    await session.step(1);
    expect(called, isFalse);
    expect(session.current, first);
    expect(session.casting, isFalse);
    expect(session.confirmedContentId, isNull);
    expect(session.canChange, isFalse);
  });
  test('dispose discards an in-flight Cast channel selection', () async {
    final gate = Completer<String>();
    final session = ChannelPlaybackSession(initial: first, channels: [second]);
    await session.startCasting((c) async {
      if (c == first) return c.url;
      return gate.future;
    });
    final switching = session.step(1);
    session.dispose();
    gate.complete(second.url);
    await switching;
    expect(session.current, first);
    expect(session.casting, isFalse);
    expect(session.confirmedContentId, isNull);
    expect(session.busy, isFalse);
  });
  testWidgets(
    'remote CH and page keys change both local and casting selections',
    (tester) async {
      final session = ChannelPlaybackSession(
        initial: first,
        channels: [second],
      );
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ChannelNavigation(
            session: session,
            child: const Scaffold(body: Text('Reprodução')),
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.channelUp);
      await tester.pump();
      expect(session.current, second);
      final loads = <String>[];
      await session.startCasting((c) async {
        loads.add(c.url);
        return c.url;
      });
      await tester.sendKeyEvent(LogicalKeyboardKey.channelDown);
      await tester.pump();
      expect(session.current, first);
      expect(loads, [second.url, first.url]);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pump();
      expect(session.current, second);
    },
  );
}
