import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
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
  bool _controlsVisible = false;
  bool _fullscreen = false;
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

  Future<void> _openCastPicker() async {
    await GoogleCastDiscoveryManager.instance.startDiscovery();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: RochaColors.surface,
      builder: (sheetContext) => SafeArea(
        child: StreamBuilder<List<GoogleCastDevice>>(
          stream: GoogleCastDiscoveryManager.instance.devicesStream,
          builder: (context, snapshot) {
            final devices = snapshot.data ?? const <GoogleCastDevice>[];
            if (devices.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: RochaColors.ruby),
                    SizedBox(height: 18),
                    Text('Procurando TVs e Chromecasts na mesma rede Wi-Fi...'),
                  ],
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (_, index) {
                final device = devices[index];
                return ListTile(
                  leading: const Icon(Icons.cast, color: RochaColors.gold),
                  title: Text(device.friendlyName),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _startCasting(device);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _startCasting(GoogleCastDevice device) async {
    try {
      await GoogleCastSessionManager.instance.startSessionWithDevice(device);
      final media = GoogleCastMediaInformation(
        contentId: widget.channel.url,
        contentUrl: Uri.parse(widget.channel.url),
        contentType: 'application/x-mpegURL',
        streamType: CastMediaStreamType.live,
        metadata: GoogleCastMovieMediaMetadata(title: widget.channel.name),
      );
      await GoogleCastRemoteMediaClient.instance.loadMedia(media);
      await _controller?.pause();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Canal enviado para a TV.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível iniciar o espelhamento.')),
        );
      }
    }
  }

  void _showControls() {
    setState(() => _controlsVisible = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _controller?.value.isPlaying == true) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  Future<void> _toggleFullscreen() async {
    final enterFullscreen = !_fullscreen;
    if (mounted) setState(() => _fullscreen = enterFullscreen);

    if (enterFullscreen) {
      // Lock the player to landscape and remove Android system chrome.
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _fullscreen
          ? null
          : AppBar(
              backgroundColor: Colors.black,
              title: Text(widget.channel.name),
              actions: [
                IconButton(
                  tooltip: 'Transmitir para TV',
                  onPressed: _openCastPicker,
                  icon: const Icon(Icons.cast),
                ),
              ],
            ),
      body: Center(
        child: _failed
            ? _FailureState(onRetry: _initialize)
            : _loading || controller == null || !controller.value.isInitialized
                ? const CircularProgressIndicator(color: RochaColors.ruby)
                : _fullscreen
                    ? SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: controller.value.size.width > 0
                                ? controller.value.size.width
                                : 1920,
                            height: controller.value.size.height > 0
                                ? controller.value.size.height
                                : 1080,
                            child: _VideoSurface(
                              controller: controller,
                              controlsVisible: _controlsVisible,
                              fullscreen: _fullscreen,
                              onShowControls: _showControls,
                              onTogglePlayback: _togglePlayback,
                              onToggleFullscreen: _toggleFullscreen,
                            ),
                          ),
                        ),
                      )
                    : AspectRatio(
                        aspectRatio: controller.value.aspectRatio > 0
                            ? controller.value.aspectRatio
                            : 16 / 9,
                        child: _VideoSurface(
                          controller: controller,
                          controlsVisible: _controlsVisible,
                          fullscreen: _fullscreen,
                          onShowControls: _showControls,
                          onTogglePlayback: _togglePlayback,
                          onToggleFullscreen: _toggleFullscreen,
                        ),
                      ),
      )
    );
  }
}

class _VideoSurface extends StatelessWidget {
  final VideoPlayerController controller;
  final bool controlsVisible;
  final bool fullscreen;
  final VoidCallback onShowControls;
  final VoidCallback onTogglePlayback;
  final VoidCallback onToggleFullscreen;

  const _VideoSurface({
    required this.controller,
    required this.controlsVisible,
    required this.fullscreen,
    required this.onShowControls,
    required this.onTogglePlayback,
    required this.onToggleFullscreen,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onShowControls,
        onDoubleTap: onToggleFullscreen,
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            VideoPlayer(controller),
            Center(
              child: AnimatedOpacity(
                opacity: controlsVisible ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: !controlsVisible,
                  child: IconButton.filled(
                    autofocus: true,
                    tooltip: controller.value.isPlaying ? 'Pausar' : 'Reproduzir',
                    iconSize: 42,
                    onPressed: () {
                      onTogglePlayback();
                      onShowControls();
                    },
                    icon: Icon(controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: AnimatedOpacity(
                opacity: controlsVisible ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: !controlsVisible,
                  child: IconButton.filledTonal(
                    tooltip: fullscreen ? 'Sair da tela cheia' : 'Tela cheia',
                    onPressed: onToggleFullscreen,
                    icon: Icon(fullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
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
