import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/live/native_channel_keys.dart';

Future<void> nativeEvent(String method, dynamic value) {
  final done = Completer<void>();
  ServicesBinding.instance.channelBuffers.push(NativeChannelKeys.channel.name,
    const StandardMethodCodec().encodeMethodCall(MethodCall(method, value)),
    (_) => done.complete());
  return done.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(NativeChannelKeys.channel, (call) async {
        calls.add(call);
        return null;
      });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(NativeChannelKeys.channel, null);
  });
  test('native CH keys are enabled only while a player owns the bridge', () async {
    final steps = <int>[];
    final bridge = NativeChannelKeys(steps.add);
    expect(await bridge.activate(), isTrue);
    await nativeEvent('switch', 1);
    await nativeEvent('switch', -1);
    expect(steps, [1, -1]);
    await bridge.deactivate();
    expect(calls.map((call) => call.method), ['setEnabled', 'setEnabled']);
    expect(calls.map((call) => call.arguments), [true, false]);
  });
  test('late native events are discarded and cannot change a later player', () async {
    final first = <int>[];
    final second = <int>[];
    final old = NativeChannelKeys(first.add);
    await old.activate();
    await old.deactivate();
    await nativeEvent('switch', 1);
    final next = NativeChannelKeys(second.add);
    await next.activate();
    expect(first, isEmpty);
    expect(second, isEmpty);
    await nativeEvent('switch', -1);
    expect(second, [-1]);
    await next.deactivate();
  });
  test('disposal of a superseded player does not disable the current one', () async {
    final first = <int>[];
    final second = <int>[];
    final old = NativeChannelKeys(first.add);
    final next = NativeChannelKeys(second.add);
    await old.activate();
    await next.activate();
    await old.deactivate();
    await nativeEvent('unknown', 1);
    await nativeEvent('switch', 0);
    await nativeEvent('switch', 10);
    await nativeEvent('switch', 1);
    expect(first, isEmpty);
    expect(second, [1]);
    expect(calls.map((call) => call.arguments), [true, true]);
    await next.deactivate();
  });
  test('missing native integration leaves the Flutter keyboard fallback available', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(NativeChannelKeys.channel, (_) async => throw MissingPluginException());
    final bridge = NativeChannelKeys((_) {});
    expect(await bridge.activate(), isFalse);
    await bridge.deactivate();
  });
}
