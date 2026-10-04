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
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _failed = false;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final attempt = ++_attempt;
    final old = _controller;
    _controller = null;
    await old?.dispose();

    if (mounted) setState(() { _loading = true; _failed = false; });

    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.channel.url));
    _controller = controller;
    try {
      await controller.initialize().timeout(const Duration(seconds: 15));
      if (!mounted || attempt != _attempt) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onPlayerChanged);
      await controller.play();
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      await controller.dispose();
      if (_controller == controller) _controller = null;
      if (mounted && attempt == _attempt) {
        setState(() { _loading = false; _failed = true; });
      }
    }
  }

  void _onPlayerChanged() {
    final controller = _controller;
    if (controller != null && controller.value.hasError && mounted && !_failed) {
      setState(() { _loading = false; _failed = true; });
    }
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() {
      controller.value.isPlaying ? controller.pause() : controller.play();
    });
  }

  @override
  void dispose() {
    _attempt++;
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onPlayerChanged);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text(widget.channel.name)),
      body: Center(
        child: _failed
            ? _FailureState(onRetry: _initialize)
            : _loading || controller == null || !controller.value.isInitialized
                ? const CircularProgressIndicator(color: RochaColors.ruby)
                : AspectRatio(
                    aspectRatio: controller.value.aspectRatio > 0
                        ? controller.value.aspectRatio
                        : 16 / 9,
                    child: Stack(alignment: Alignment.center, children: [
                      VideoPlayer(controller),
                      IconButton.filled(
                        autofocus: true,
                        tooltip: controller.value.isPlaying ? 'Pausar' : 'Reproduzir',
                        iconSize: 42,
                        onPressed: _togglePlayback,
                        icon: Icon(controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
                      ),
                    ]),
                  ),
      ),
    );
  }
}

class _FailureState extends StatelessWidget {
  final VoidCallback onRetry;
  const _FailureState({required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.signal_wifi_connected_no_internet_4, size: 48, color: RochaColors.ruby),
            const SizedBox(height: 16),
            const Text('Este sinal está indisponível no momento.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              autofocus: true,
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
}
