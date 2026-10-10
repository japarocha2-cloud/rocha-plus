import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:video_player/video_player.dart';
import '../live/channel.dart';
import '../live/playback_evidence.dart';
import '../live/channel_repository.dart';
import '../theme/rocha_theme.dart';
import '../widgets/player_viewport.dart';
import '../widgets/player_controls_focus.dart';
import '../cast/cast_device_picker.dart';
import '../cast/cast_readiness.dart';
import '../cast/cast_playback_evidence.dart';
import '../cast/cast_hls_proxy.dart';
import 'cast_control_screen.dart';

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
  bool _casting = false;
  String? _castMessage;
  bool _controlsVisible = false;
  bool _fullscreen = false;
  bool? _portraitOnExit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _portraitOnExit ??= MediaQuery.sizeOf(context).width < 600;
  }
  bool _playbackConfirmed = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  int _attempt = 0;
  final _evidence = PlaybackEvidence();
  final ChannelRepository _channelRepository = ChannelRepository();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final attempt = ++_attempt;
    final old = _controller;
    _controller = null;
    old?.removeListener(_onPlayerChanged);
    await old?.dispose();
    if (!mounted || attempt != _attempt) return;

    setState(() { _loading = true; _failed = false; _playbackConfirmed = false; _isPlaying = false; _isBuffering = false; });

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.channel.url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );
    _controller = controller;
    try {
      // O player recebe diretamente o master HLS da fonte. Não fazemos
      // transcodificação nem redução de resolução no aparelho.
      await controller.initialize().timeout(const Duration(seconds: 8));
      if (!mounted || attempt != _attempt) {
        await controller.dispose();
        return;
      }
      _evidence.reset(controller.value.position);
      controller.addListener(_onPlayerChanged);
      // Dispara a reprodução imediatamente após a preparação do decoder.
      // A qualidade continua sendo a original/adaptativa oferecida pelo HLS.
      await controller.play();
      if (!mounted || attempt != _attempt) return;
      setState(() => _loading = false);
      _onPlayerChanged();
    } catch (_) {
      if (!mounted || attempt != _attempt) return;
      _channelRepository.reportPlaybackFailure(widget.channel.url);
      await controller.dispose();
      if (_controller == controller) _controller = null;
      if (mounted && attempt == _attempt) {
        setState(() { _loading = false; _failed = true; });
      }
    }
  }

  void _onPlayerChanged() {
    final controller = _controller;
    if (controller == null || !mounted || _failed) return;
    final value = controller.value;
    if (value.hasError) {
      _channelRepository.reportPlaybackFailure(widget.channel.url);
      setState(() { _loading = false; _failed = true; _playbackConfirmed = false; });
      return;
    }
    final confirmed = _evidence.observe(position: value.position,
        isPlaying: value.isPlaying, isBuffering: value.isBuffering, hasError: value.hasError);
    if (confirmed) {
      _channelRepository.reportPlaybackSuccess(widget.channel.url);
    }
    if (confirmed || _isPlaying != value.isPlaying || _isBuffering != value.isBuffering) {
      setState(() {
        if (confirmed) _playbackConfirmed = true;
        _isPlaying = value.isPlaying;
        _isBuffering = value.isBuffering;
      });
    }
  }

  Future<void> _openCastPicker() async {
    final ready = await CastReadiness.ready;
    if (!mounted) return;
    if (!ready) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Google Cast indisponível neste aparelho.'),
      ));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: RochaColors.surface,
      builder: (sheetContext) => SafeArea(
        child: CastDevicePicker(
          onSelected: (device) async {
            Navigator.pop(sheetContext);
            await _startCasting(device);
          },
        ),
      ),
    );
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
    ).timeout(const Duration(seconds: 8));
    await GoogleCastRemoteMediaClient.instance.play().timeout(const Duration(seconds: 5));

    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final status = GoogleCastRemoteMediaClient.instance.mediaStatus;
      final state = status?.playerState;
      final info = status?.mediaInformation;
      final matches = CastPlaybackEvidence.matches(uri.toString(), info?.contentId, info?.contentUrl);
      if (CastPlaybackEvidence.confirms(
          requested: uri.toString(), contentId: info?.contentId,
          contentUrl: info?.contentUrl, playing: state == CastMediaPlayerState.playing)) {
        return;
      }
      if (matches && state == CastMediaPlayerState.idle && status?.idleReason != null) {
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
    if (_casting) return;
    setState(() { _casting = true; _castMessage = 'Conectando à TV…'; });
    var sessionConnected = false;
    try {
      final started = await GoogleCastSessionManager.instance
          .startSessionWithDevice(device).timeout(const Duration(seconds: 8));
      if (!started) throw StateError('Sessão Cast recusada.');
      await _waitForCastSession();
      sessionConnected = true;
      if (mounted) setState(() => _castMessage = 'Enviando o canal para a TV…');
      await CastHlsProxy.instance.close();
      final uri = Uri.parse(widget.channel.url);
      try {
        await _loadAndConfirmCast(uri);
      } catch (_) {
        if (_castContentType(uri) != 'application/x-mpegURL' || !device.isOnLocalNetwork) rethrow;
        final relayUri = await CastHlsProxy.instance.relay(uri);
        await _loadAndConfirmCast(relayUri);
      }
      await _controller?.pause();
      if (mounted) {
        setState(() => _castMessage = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reprodução confirmada pela TV.')),
        );
        await Navigator.push(context, MaterialPageRoute(builder: (_) => CastControlScreen(
          channel: widget.channel, deviceName: device.friendlyName,
          confirmedContentId: GoogleCastRemoteMediaClient.instance.mediaStatus?.mediaInformation?.contentId)));
        if (GoogleCastSessionManager.instance.connectionState == GoogleCastConnectState.disconnected) {
          await CastHlsProxy.instance.close();
          await _controller?.play();
        }
      }
    } catch (_) {
      await CastHlsProxy.instance.close();
      try {
        await GoogleCastSessionManager.instance.endSessionAndStopCasting()
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // Preserve the original playback failure.
      }
      if (mounted) {
        setState(() => _castMessage = sessionConnected
            ? 'A TV conectou, mas não confirmou a reprodução do canal. Tente outro canal.'
            : 'Não foi possível conectar à TV. Confira se ela está ligada e na mesma rede Wi-Fi.');
      }
    } finally {
      if (mounted) setState(() => _casting = false);
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
      await SystemChrome.setPreferredOrientations(
        _portraitOnExit == true ? [DeviceOrientation.portraitUp] : DeviceOrientation.values,
      );
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
    SystemChrome.setPreferredOrientations(
      _portraitOnExit == true ? [DeviceOrientation.portraitUp] : DeviceOrientation.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return PopScope(
      canPop: !_fullscreen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _fullscreen) _toggleFullscreen();
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      bottomNavigationBar: _castMessage == null ? null : SafeArea(
        child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          Expanded(child: Text(_castMessage!)),
          if (!_casting) IconButton(tooltip: 'Fechar aviso de transmissão',
            onPressed: () => setState(() => _castMessage = null),
            icon: const Icon(Icons.close)),
        ])),
      ),
      appBar: _fullscreen
          ? null
          : AppBar(
              backgroundColor: Colors.black,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.channel.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    _failed ? 'Sinal indisponível' : _playbackConfirmed
                        ? (_isBuffering ? 'Carregando…' : _isPlaying ? 'Reproduzindo' : 'Pausado')
                        : 'Conectando…',
                    style: TextStyle(
                      fontSize: 12,
                      color: _playbackConfirmed ? RochaColors.playGreen : Colors.white54,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Transmitir para TV',
                  onPressed: _casting ? null : _openCastPicker,
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
                        child: _VideoSurface(
                          controller: controller,
                          controlsVisible: _controlsVisible,
                          fullscreen: _fullscreen,
                          onShowControls: _showControls,
                          onTogglePlayback: _togglePlayback,
                          onToggleFullscreen: _toggleFullscreen,
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
      ),
      ),
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
  Widget build(BuildContext context) => PlayerControlsFocus(
        controlsVisible: controlsVisible,
        onShowControls: onShowControls,
        child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onShowControls,
        onDoubleTap: onToggleFullscreen,
        child: PlayerViewport(
          aspectRatio: controller.value.aspectRatio,
          video: VideoPlayer(controller),
          overlays: [
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
