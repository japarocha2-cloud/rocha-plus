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
