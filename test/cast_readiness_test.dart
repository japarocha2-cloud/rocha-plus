import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/cast/cast_readiness.dart';

void main() {
  test('awaits native initialization rather than reporting early readiness', () async {
    final native = Completer<bool>();
    var completed = false;
    CastReadiness.initialize(() => native.future);
    CastReadiness.ready.then((_) => completed = true);
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    native.complete(true);
    expect(await CastReadiness.ready, isTrue);
  });
  test('missing native Cast service leaves browsing available', () async {
    CastReadiness.initialize(() async { throw StateError('service missing'); });
    expect(await CastReadiness.ready, isFalse);
  });
}
