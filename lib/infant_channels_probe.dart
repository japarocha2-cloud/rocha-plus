// CI-only diagnostic entry point; its APK is never distributed.
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'src/live/channel.dart';
import 'src/live/channel_repository.dart';

const _waiting = MaterialApp(home: Scaffold(body: Center(
  child: Text('Infant channel playback diagnostic'))));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(_waiting);
  try {
    final channels = await ChannelRepository().loadBrazilPublicDirectory();
    final failures = <String>[];
    for (final name in ['SBC Kids', 'Kuriakos Kids', '3ABN Kids']) {
      try {
        await _probe(channels.singleWhere((c) => c.name == name));
      } catch (error) {
        failures.add(name);
        // ignore: avoid_print
        print('ROCHA_INFANT_CHANNEL_FAILURE name=$name error=$error');
      }
    }
    if (failures.isNotEmpty) throw StateError('Failed channels: $failures');
    // ignore: avoid_print
    print('ROCHA_INFANT_PROBE_OK channels=3');
  } catch (error, stack) {
    // ignore: avoid_print
    print('ROCHA_INFANT_PROBE_FAILURE $error\n$stack');
  }
}

Future<void> _probe(Channel channel) async {
  final controller = VideoPlayerController.networkUrl(Uri.parse(channel.url),
    videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false));
  try {
    final startup = Stopwatch()..start();
    // Match the unchanged runtime player's eight-second initialization limit.
    await controller.initialize().timeout(const Duration(seconds: 8));
    startup.stop();
    await controller.play();
    runApp(MaterialApp(home: Scaffold(body: Center(child: AspectRatio(
      aspectRatio: controller.value.aspectRatio,
      child: VideoPlayer(controller))))));
    Duration? previous;
    var advancedMs = 0;
    var playingTicks = 0;
    for (var tick = 0; tick < 45; tick++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      final value = controller.value;
      if (value.hasError) throw StateError(value.errorDescription ?? 'Playback error');
      if (value.isPlaying && !value.isBuffering) {
        playingTicks++;
        if (previous != null) {
          final delta = (value.position - previous).inMilliseconds;
          // Ignore initial live-window offsets and later HLS timeline jumps.
          if (delta > 0 && delta < 5000) advancedMs += delta.clamp(0, 2000).toInt();
        }
      }
      previous = value.position;
      if (advancedMs >= 10000 && playingTicks >= 10 && value.size.width > 0) {
        // ignore: avoid_print
        print('ROCHA_INFANT_CHANNEL_OK name=${channel.name} '
          'startup_ms=${startup.elapsedMilliseconds} advanced_ms=$advancedMs '
          'size=${value.size.width}x${value.size.height}');
        return;
      }
    }
    throw StateError('No ten seconds of advancing native playback');
  } finally {
    runApp(_waiting);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await controller.dispose();
  }
}
