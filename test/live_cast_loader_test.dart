import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/cast/live_cast_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(LiveCastLoader.channel, null);
  });
  test('Android live load waits for native acceptance and never sends position zero or PLAY', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(LiveCastLoader.channel, (call) async { calls.add(call); });
    final uri = Uri.parse('https://fixture.example/live.m3u8');
    await LiveCastLoader.load(GoogleCastMediaInformation(contentId: uri.toString(),
      contentUrl: uri, contentType: 'application/x-mpegURL', streamType: CastMediaStreamType.live,
      metadata: GoogleCastMovieMediaMetadata(title: 'Teste ao vivo')));
    expect(calls.length, 1);
    expect(calls.single.method, 'loadLive');
    expect(calls.single.arguments, {'url': uri.toString(), 'title': 'Teste ao vivo',
      'contentType': 'application/x-mpegURL'});
  });
  test('native load rejection stays a failure instead of confirming TV playback', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(LiveCastLoader.channel, (_) async {
        throw PlatformException(code: 'cast_disconnected');
      });
    await expectLater(LiveCastLoader.load(GoogleCastMediaInformation(
      contentId: 'https://fixture.example/live.m3u8', contentType: 'application/x-mpegURL',
      streamType: CastMediaStreamType.live)), throwsA(isA<PlatformException>()));
  });
}
