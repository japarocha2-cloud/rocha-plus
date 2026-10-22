import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/cast/cast_connection_observer.dart';

void main() {
  test('native cancellation failure is consumed after disposal', () async {
    var disconnects = 0;
    final states = StreamController<bool>(onCancel: () async {
      throw StateError('native cancel failed');
    });
    addTearDown(states.close);
    final observer = CastConnectionObserver(
      states.stream,
      onDisconnected: () => disconnects++,
    );
    observer.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(states.hasListener, isFalse);
    expect(disconnects, 0);
  });
  test('failure reading native current state invalidates the observation', () {
    final states = StreamController<bool>();
    addTearDown(states.close);
    var disconnects = 0;
    final observer = CastConnectionObserver(
      states.stream,
      isDisconnected: () => throw StateError('native service unavailable'),
      onDisconnected: () => disconnects++,
    );
    addTearDown(observer.dispose);
    expect(disconnects, 1);
    expect(states.hasListener, isFalse);
  });
  test('terminal disconnect is delivered immediately and cancels listening', () {
    var cancellations = 0;
    var disconnects = 0;
    final states = StreamController<bool>.broadcast(
      sync: true,
      onCancel: () => cancellations++,
    );
    addTearDown(states.close);
    final observer = CastConnectionObserver(
      states.stream,
      onDisconnected: () => disconnects++,
    );
    addTearDown(observer.dispose);
    states.add(true);
    expect(disconnects, 0);
    states.add(false);
    expect(disconnects, 1);
    expect(cancellations, 1);
    states.add(false);
    expect(disconnects, 1);
  });

  test('initial state catches disconnect lost before subscription', () {
    final states = StreamController<bool>();
    addTearDown(states.close);
    var disconnects = 0;
    final observer = CastConnectionObserver(
      states.stream,
      isDisconnected: () => true,
      onDisconnected: () => disconnects++,
    );
    addTearDown(observer.dispose);
    expect(disconnects, 1);
    expect(states.hasListener, isFalse);
  });

  test('stream failure invalidates connection and is consumed', () async {
    final states = StreamController<bool>();
    addTearDown(states.close);
    var disconnects = 0;
    final observer = CastConnectionObserver(
      states.stream,
      onDisconnected: () => disconnects++,
    );
    addTearDown(observer.dispose);
    states.addError(StateError('native session service failed'));
    await Future<void>.delayed(Duration.zero);
    expect(disconnects, 1);
    expect(states.hasListener, isFalse);
  });

  test('stream completion invalidates an unobservable connection', () async {
    final states = StreamController<bool>();
    var disconnects = 0;
    final observer = CastConnectionObserver(
      states.stream,
      onDisconnected: () => disconnects++,
    );
    addTearDown(observer.dispose);
    await states.close();
    expect(disconnects, 1);
  });

  test('dispose suppresses queued terminal events and is idempotent', () async {
    final states = StreamController<bool>();
    addTearDown(states.close);
    var disconnects = 0;
    final observer = CastConnectionObserver(
      states.stream,
      onDisconnected: () => disconnects++,
    );
    states.add(false);
    observer.dispose();
    observer.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(disconnects, 0);
    expect(states.hasListener, isFalse);
  });
}
