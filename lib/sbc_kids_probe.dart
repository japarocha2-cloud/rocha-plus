// CI-only entry point. Its diagnostic APK is never uploaded for distribution.
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'src/live/channel_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: Scaffold(body: Center(
    child: Text('SBC Kids playback diagnostic')))));
  try {
    final channels = await ChannelRepository().loadBrazilPublicDirectory();
    final channel = channels.singleWhere((c) => c.name == 'SBC Kids');
    final controller = VideoPlayerController.networkUrl(Uri.parse(channel.url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false));
    final startup = Stopwatch()..start();
    // Match the existing production player's initialization limit exactly.
    await controller.initialize().timeout(const Duration(seconds: 8));
    startup.stop();
    await controller.play();
    runApp(MaterialApp(home: Scaffold(body: Center(child: AspectRatio(
      aspectRatio: controller.value.aspectRatio,
      child: VideoPlayer(controller))))));
    for (var tick = 0; tick < 45; tick++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      final value = controller.value;
      if (value.hasError) throw StateError(value.errorDescription ?? 'Playback error');
      if (value.position >= const Duration(seconds: 10) &&
          value.isPlaying && !value.isBuffering && value.size.width > 0) {
        // ignore: avoid_print
        print('ROCHA_SBC_KIDS_PROBE_OK startup_ms=${startup.elapsedMilliseconds} '
          'position_ms=${value.position.inMilliseconds} size=${value.size}');
        return;
      }
    }
    throw StateError('No ten seconds of advancing native playback');
  } catch (error, stack) {
    // ignore: avoid_print
    print('ROCHA_SBC_KIDS_PROBE_FAILURE $error\n$stack');
  }
}
