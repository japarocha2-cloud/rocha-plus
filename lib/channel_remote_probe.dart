// CI-only: exercises the actual PlayerScreen with native Android key events.
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'src/live/channel_repository.dart';
import 'src/screens/player_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final catalog = await ChannelRepository().loadBrazilPublicDirectory();
  final lineup = ['Kuriakos Kids', '3ABN Kids', 'SBC Kids']
    .map((name) => catalog.singleWhere((c) => c.name == name)).toList();
  runApp(MaterialApp(home: PlayerScreen(channel: lineup.first, lineup: lineup,
    controllerFactory: (uri) {
      // URI parsing normalizes default :443 ports used by the official source.
      final channel = lineup.singleWhere((c) => Uri.parse(c.url) == uri);
      final controller = VideoPlayerController.networkUrl(uri,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false));
      Duration? previous;
      var advanced = 0;
      var reported = false;
      controller.addListener(() {
        final value = controller.value;
        if (!value.isInitialized || !value.isPlaying || value.isBuffering || value.hasError) return;
        if (previous != null) {
          final delta = (value.position - previous!).inMilliseconds;
          if (delta > 0 && delta < 5000) advanced += delta.clamp(0, 2000).toInt();
        }
        previous = value.position;
        if (!reported && advanced >= 3000 && value.size.width > 0) {
          reported = true;
          // ignore: avoid_print
          print('ROCHA_REMOTE_PLAYING name=${channel.name} advanced_ms=$advanced');
        }
      });
      return controller;
    },
    // ignore: avoid_print
    onChannelChanged: (channel) => print('ROCHA_REMOTE_SELECTION name=${channel.name}'),
  )));
}
