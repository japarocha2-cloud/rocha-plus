import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../live/channel.dart';
import '../theme/rocha_theme.dart';

class PlayerScreen extends StatefulWidget {
  final Channel channel;
  const PlayerScreen({super.key, required this.channel});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final VideoPlayerController controller;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.channel.url));
    initialize();
  }

  Future<void> initialize() async {
    try {
      await controller.initialize();
      await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(backgroundColor: Colors.black, title: Text(widget.channel.name)),
    body: Center(
      child: failed
        ? const Text('Este sinal está indisponível no momento.')
        : !controller.value.isInitialized
          ? const CircularProgressIndicator(color: RochaColors.ruby)
          : AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: Stack(alignment: Alignment.center, children: [
                VideoPlayer(controller),
                IconButton.filled(
                  iconSize: 42,
                  onPressed: () => setState(() {
                    controller.value.isPlaying ? controller.pause() : controller.play();
                  }),
                  icon: Icon(controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
                ),
              ]),
            ),
    ),
  );
}
