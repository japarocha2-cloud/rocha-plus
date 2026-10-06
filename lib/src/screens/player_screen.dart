import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:video_player/video_player.dart';
import '../cast/cast_hls_proxy.dart';
import 'cast_control_screen.dart';
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
    if (!mounted) {
      await GoogleCastDiscoveryManager.instance.stopDiscovery();
      return;
    }
    try {
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
    } finally {
      await GoogleCastDiscoveryManager.instance.stopDiscovery();
    }
  }

  String _castContentType(Uri uri) {
    final path = uri.path.toLowerCase();
    if (path.endsWith('.m3u8') || path.endsWith('.m3u')) {
      return 'application/x-mpegURL';
    }
    if (path.endsWith('.mpd')) return 'application/dash+xml';
    if (path.endsWith('.webm')) return 'video/webm';
    if (path.endsWith('.mp4') || path.endsWith('.m4v')) return 'video/mp4';
    // URLs without an extension in the Rocha+ live catalogue are normally HLS.
    return 'application/x-mpegURL';
  }

  Future<void> _loadAndConfirmCast(Uri uri) async {
    final media = GoogleCastMediaInformation(
      contentId: uri.toString(),
      contentUrl: uri,
      contentType: _castContentType(uri),
      streamType: CastMediaStreamType.live,
      metadata: GoogleCastMovieMediaMetadata(title: widget.channel.name),
    );

    await GoogleCastRemoteMediaClient.instance.loadMedia(
      media,
      autoPlay: true,
      playPosition: Duration.zero,
      playbackRate: 1.0,
    );
    await GoogleCastRemoteMediaClient.instance.play();

    for (var i = 0; i < 16; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final status = GoogleCastRemoteMediaClient.instance.mediaStatus;
      final state = status?.playerState;
      if (state == CastMediaPlayerState.playing) {
        return;
      }
      if (state == CastMediaPlayerState.idle && status?.idleReason != null) {
        throw StateError('Receiver entrou em idle: ${status?.idleReason}');
      }
    }

    throw TimeoutException(
      'A TV abriu a sessão, mas não confirmou reprodução real do canal.',
    );
  }

  Future<void> _waitForCastSession() async {
    if (GoogleCastSessionManager.instance.connectionState ==
        GoogleCastConnectState.connected) {
      return;
    }

    await GoogleCastSessionManager.instance.currentSessionStream
        .firstWhere(
          (session) =>
              session?.connectionState == GoogleCastConnectState.connected,
        )
        .timeout(
          const Duration(seconds: 8),
          onTimeout: () => throw TimeoutException(
            'A TV foi encontrada, mas a sessão Cast não ficou conectada.',
          ),
        );
  }

  Future<void> _startCasting(GoogleCastDevice device) async {
    try {
      final uri = Uri.parse(widget.channel.url);
      final started =
          await GoogleCastSessionManager.instance.startSessionWithDevice(device);
      if (!started) {
        throw StateError('O Google Cast recusou o início da sessão.');
      }
      await _waitForCastSession();

      Object? directError;
      try {
        await _loadAndConfirmCast(uri);
      } catch (error) {
        directError = error;
        final isHls = _castContentType(uri) == 'application/x-mpegURL';
        if (!isHls || !device.isOnLocalNetwork) rethrow;

        final relayUri = await CastHlsProxy.instance.relay(uri);
        await _loadAndConfirmCast(relayUri);
      }

      debugPrint('Rocha+ Cast confirmado. Falha direta anterior: $directError');
      await _controller?.pause();

      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CastControlScreen(
              channel: widget.channel,
              deviceName: device.friendlyName,
            ),
          ),
        );
        if (GoogleCastSessionManager.instance.connectionState !=
            GoogleCastConnectState.connected) {
          await CastHlsProxy.instance.stop();
          await _controller?.play();
        }
      }
    } catch (error) {
      try {
        if (GoogleCastSessionManager.instance.connectionState !=
            GoogleCastConnectState.disconnected) {
          await GoogleCastSessionManager.instance.endSessionAndStopCasting();
        }
      } catch (_) {
        // A falha original de transmissão é mais importante que a limpeza.
      }
      await CastHlsProxy.instance.stop();
      await _controller?.play();
      debugPrint('Rocha+ Cast error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A TV foi encontrada, mas não confirmou a reprodução deste canal.',
            ),
          ),
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

    if (_fullscreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: _failed
              ? _FailureState(onRetry: _initialize)
              : _loading ||
                      controller == null ||
                      !controller.value.isInitialized
                  ? const CircularProgressIndicator(
                      color: RochaColors.playGreen,
                    )
                  : SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
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
                            fullscreen: true,
                            onShowControls: _showControls,
                            onTogglePlayback: _togglePlayback,
                            onToggleFullscreen: _toggleFullscreen,
                          ),
                        ),
                      ),
                    ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final tv = constraints.maxWidth >= 900;
        return Scaffold(
          backgroundColor: RochaColors.background,
          appBar: AppBar(
            titleSpacing: tv ? 24 : 4,
            leading: IconButton(
              autofocus: tv,
              tooltip: 'Voltar',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
            ),
            title: Text(
              widget.channel.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: tv ? 24 : 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0x33D91527),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFD91527)),
                ),
                child: const Center(
                  child: Text(
                    'AO VIVO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Transmitir para TV',
                onPressed: _openCastPicker,
                icon: const Icon(
                  Icons.cast,
                  color: RochaColors.playGreen,
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: _PlayerBody(
            tv: tv,
            channel: widget.channel,
            controller: controller,
            loading: _loading,
            failed: _failed,
            controlsVisible: _controlsVisible,
            onRetry: _initialize,
            onCast: _openCastPicker,
            onShowControls: _showControls,
            onTogglePlayback: _togglePlayback,
            onToggleFullscreen: _toggleFullscreen,
          ),
        );
      },
    );
  }
}

class _PlayerBody extends StatelessWidget {
  final bool tv;
  final Channel channel;
  final VideoPlayerController? controller;
  final bool loading;
  final bool failed;
  final bool controlsVisible;
  final VoidCallback onRetry;
  final VoidCallback onCast;
  final VoidCallback onShowControls;
  final VoidCallback onTogglePlayback;
  final VoidCallback onToggleFullscreen;

  const _PlayerBody({
    required this.tv,
    required this.channel,
    required this.controller,
    required this.loading,
    required this.failed,
    required this.controlsVisible,
    required this.onRetry,
    required this.onCast,
    required this.onShowControls,
    required this.onTogglePlayback,
    required this.onToggleFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final player = _PlayerFrame(
      controller: controller,
      loading: loading,
      failed: failed,
      controlsVisible: controlsVisible,
      onRetry: onRetry,
      onShowControls: onShowControls,
      onTogglePlayback: onTogglePlayback,
      onToggleFullscreen: onToggleFullscreen,
    );

    if (tv) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 20, 32, 28),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 7,
              child: Center(child: player),
            ),
            const SizedBox(width: 24),
            SizedBox(
              width: 340,
              child: _ChannelPanel(
                channel: channel,
                tv: true,
                onCast: onCast,
                onFullscreen: onToggleFullscreen,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: player,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: _ChannelPanel(
            channel: channel,
            tv: false,
            onCast: onCast,
            onFullscreen: onToggleFullscreen,
          ),
        ),
      ],
    );
  }
}

class _PlayerFrame extends StatelessWidget {
  final VideoPlayerController? controller;
  final bool loading;
  final bool failed;
  final bool controlsVisible;
  final VoidCallback onRetry;
  final VoidCallback onShowControls;
  final VoidCallback onTogglePlayback;
  final VoidCallback onToggleFullscreen;

  const _PlayerFrame({
    required this.controller,
    required this.loading,
    required this.failed,
    required this.controlsVisible,
    required this.onRetry,
    required this.onShowControls,
    required this.onTogglePlayback,
    required this.onToggleFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final ratio =
        c != null && c.value.isInitialized && c.value.aspectRatio > 0
            ? c.value.aspectRatio
            : 16 / 9;

    return AspectRatio(
      aspectRatio: ratio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: RochaColors.border),
          ),
          child: failed
              ? Center(child: _FailureState(onRetry: onRetry))
              : loading || c == null || !c.value.isInitialized
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: RochaColors.playGreen,
                      ),
                    )
                  : _VideoSurface(
                      controller: c,
                      controlsVisible: controlsVisible,
                      fullscreen: false,
                      onShowControls: onShowControls,
                      onTogglePlayback: onTogglePlayback,
                      onToggleFullscreen: onToggleFullscreen,
                    ),
        ),
      ),
    );
  }
}

class _ChannelPanel extends StatelessWidget {
  final Channel channel;
  final bool tv;
  final VoidCallback onCast;
  final VoidCallback onFullscreen;

  const _ChannelPanel({
    required this.channel,
    required this.tv,
    required this.onCast,
    required this.onFullscreen,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(tv ? 22 : 18),
        decoration: BoxDecoration(
          color: RochaColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: RochaColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2216F34A),
              blurRadius: 26,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: tv ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ChannelLogo(channel: channel, size: tv ? 76 : 62),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channel.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: tv ? 24 : 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        channel.group,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: RochaColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: tv ? 22 : 16),
            const Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 9,
                  color: RochaColors.playGreen,
                ),
                SizedBox(width: 8),
                Text(
                  'Sinal ao vivo',
                  style: TextStyle(
                    color: RochaColors.playGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            if (tv) const Spacer() else const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                autofocus: tv,
                onPressed: onCast,
                icon: const Icon(Icons.cast),
                label: const Text('Transmitir para TV'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onFullscreen,
                icon: const Icon(Icons.fullscreen),
                label: const Text('Tela cheia'),
              ),
            ),
          ],
        ),
      );
}

class _ChannelLogo extends StatelessWidget {
  final Channel channel;
  final double size;

  const _ChannelLogo({
    required this.channel,
    required this.size,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: RochaColors.surfaceRaised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: RochaColors.border),
        ),
        child: channel.logo == null || channel.logo!.isEmpty
            ? const Icon(Icons.live_tv, color: RochaColors.playGreen)
            : Image.network(
                channel.logo!,
                fit: BoxFit.contain,
                cacheWidth: 180,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.live_tv,
                  color: RochaColors.playGreen,
                ),
              ),
      );
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
