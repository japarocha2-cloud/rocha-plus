import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:rocha_plus/src/screens/intro_screen.dart';

class FakeIntroController extends VideoPlayerController {
  final bool fail;
  FakeIntroController({this.fail = false}) : super.asset('test.mp4');
  @override
  Future<void> initialize() async {
    if (fail) throw StateError('decoder failed');
    value = const VideoPlayerValue(duration: Duration(seconds: 5),
      size: Size(1080, 1080), isInitialized: true);
  }
  @override
  Future<void> setLooping(bool looping) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> play() async { value = value.copyWith(isPlaying: true); }
  @override
  Future<void> pause() async { value = value.copyWith(isPlaying: false); }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('approved intro MP4 is bundled', () async {
    final data = await rootBundle.load('branding/intro-rocha-plus.mp4');
    expect(data.lengthInBytes, 4554552);
    expect(String.fromCharCodes(data.buffer.asUint8List(4, 4)), 'ftyp');
  });
  for (final size in [const Size(320, 568), const Size(430, 932),
      const Size(960, 540), const Size(1920, 1080)]) {
    testWidgets('complete square intro fits $size without cropping', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body:
        IntroVideoFrame(size: Size(1080, 1080), child:
          ColoredBox(key: ValueKey('source-frame'), color: Colors.green)))));
      final rect = tester.getRect(find.byKey(const ValueKey('source-frame')));
      expect(rect.width, closeTo(size.shortestSide, .01));
      expect(rect.height, closeTo(size.shortestSide, .01));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(size.width + .01));
      expect(rect.bottom, lessThanOrEqualTo(size.height + .01));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('video completion advances exactly once', (tester) async {
    final controller = FakeIntroController();
    var finished = 0;
    await tester.pumpWidget(MaterialApp(home: IntroScreen(
      controllerFactory: () => controller, onFinished: () => finished++)));
    await tester.pumpAndSettle();
    expect(finished, 0);
    controller.value = controller.value.copyWith(position: const Duration(seconds: 5));
    controller.value = controller.value.copyWith(position: const Duration(seconds: 6));
    await tester.pump();
    expect(finished, 1);
  });
  testWidgets('remote Enter skips the intro once', (tester) async {
    var finished = 0;
    await tester.pumpWidget(MaterialApp(home: IntroScreen(
      controllerFactory: () => FakeIntroController(), onFinished: () => finished++)));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(finished, 1);
  });
  testWidgets('decoder failure never blocks opening', (tester) async {
    var finished = 0;
    await tester.pumpWidget(MaterialApp(home: IntroScreen(
      controllerFactory: () => FakeIntroController(fail: true),
      onFinished: () => finished++)));
    await tester.pumpAndSettle();
    expect(finished, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('stalled playback has a bounded wait', (tester) async {
    var finished = 0;
    await tester.pumpWidget(MaterialApp(home: IntroScreen(
      controllerFactory: () => FakeIntroController(), onFinished: () => finished++)));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 8));
    expect(finished, 1);
  });
}