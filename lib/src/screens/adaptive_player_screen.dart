import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

import '../live/channel.dart';
import '../live/channel_repository.dart';
import '../live/channel_playback_session.dart';
import '../widgets/channel_navigation.dart';
import 'session_cast_launcher.dart';
import '../live/player_lab_results.dart';
import 'player_screen.dart';

/// Shared selection keeps remote keys, buttons and Cast on the same playlist.
class AdaptivePlayerScreen extends StatefulWidget {
  final Channel channel;
  final List<Channel> channels;
  final ValueChanged<Channel>? onChannelChanged;
  final bool initiallyFullscreen;
  const AdaptivePlayerScreen({
    super.key,
    required this.channel,
    this.channels = const [],
    this.onChannelChanged,
    this.initiallyFullscreen = false,
  });
  @override
  State<AdaptivePlayerScreen> createState() => _AdaptivePlayerScreenState();
}

class _AdaptivePlayerScreenState extends State<AdaptivePlayerScreen> {
  late final ChannelPlaybackSession session;
  LabEngine? engine;
  bool loading = true;
  int generation = 0;
  String? lastUrl;
  bool wasCasting = false;
  @override
  void initState() {
    super.initState();
    final repository = ChannelRepository();
    session = ChannelPlaybackSession(
      initial: widget.channel,
      channels: widget.channels,
      allowed: (c) =>
          !repository.isBlocked(c) && !repository.isQuarantined(c.url),
    );
    session.addListener(_changed);
    _choose();
  }

  Future<void> _choose() async {
    final version = ++generation;
    lastUrl = session.current.url;
    setState(() => loading = true);
    final preferred = switch (session.current.preferredEngine) {
      'libVlc' => LabEngine.libVlc,
      'exoPlayer' => LabEngine.exoPlayer,
      _ => await PlayerLabResults().preferred(session.current),
    };
    if (!mounted || generation != version) return;
    setState(() {
      engine = preferred;
      loading = false;
    });
  }

  void _changed() {
    if (!mounted) return;
    widget.onChannelChanged?.call(session.current);
    final choose =
        !session.casting && (wasCasting || lastUrl != session.current.url);
    wasCasting = session.casting;
    if (choose) {
      _choose();
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    session.removeListener(_changed);
    session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChannelNavigation(
    session: session,
    child: loading
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : engine == LabEngine.libVlc
        ? _VlcPlaybackScreen(
            channel: session.current,
            session: session,
            initiallyFullscreen: widget.initiallyFullscreen,
          )
        : PlayerScreen(
            channel: session.current,
            session: session,
            initiallyFullscreen: widget.initiallyFullscreen,
          ),
  );
}

class _VlcPlaybackScreen extends StatefulWidget {
  final Channel channel;
  final ChannelPlaybackSession session;
  final bool initiallyFullscreen;
  const _VlcPlaybackScreen({
    required this.channel,
    required this.session,
    this.initiallyFullscreen = false,
  });
  @override
  State<_VlcPlaybackScreen> createState() => _VlcPlaybackScreenState();
}

class _VlcPlaybackScreenState extends State<_VlcPlaybackScreen> {
  VlcPlayerController? _controller;
  late bool fullscreen = widget.initiallyFullscreen;

  @override
  void initState() {
    super.initState();
    if (!widget.session.casting) _initialize();
  }

  void _initialize() {
    final controller = VlcPlayerController.network(
      widget.channel.url,
      hwAcc: HwAcc.auto,
      autoPlay: true,
      options: VlcPlayerOptions(),
    );
    _controller = controller;
    controller.addListener(_updated);
  }

  @override
  void didUpdateWidget(covariant _VlcPlaybackScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel.url != widget.channel.url &&
        !widget.session.casting) {
      _controller?.removeListener(_updated);
      _controller?.dispose();
      _initialize();
    }
  }

  void _updated() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_updated);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const Scaffold(body: Center(child: Text('Reprodução na TV')));
    }
    final value = controller.value;
    final error = value.errorDescription != VlcPlayerValue.noError;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: fullscreen
          ? null
          : AppBar(
              backgroundColor: Colors.black,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    error ? 'Sinal indisponível' : 'Ao vivo',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              actions: [
                ChannelStepButtons(session: widget.session),
                IconButton(
                  tooltip: 'Transmitir para TV',
                  icon: const Icon(Icons.cast),
                  onPressed: () => launchSessionCast(
                    context,
                    widget.session,
                    pauseLocal: () async {
                      await _controller?.pause();
                    },
                  ),
                ),
              ],
            ),
      body: Center(
        child: widget.session.casting
            ? const Text('Reprodução na TV')
            : error
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('O sinal falhou neste reprodutor.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayerScreen(
                          channel: widget.channel,
                          session: widget.session,
                        ),
                      ),
                    ),
                    child: const Text('Tentar no ExoPlayer'),
                  ),
                ],
              )
            : AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: VlcPlayer(
                        controller: controller,
                        aspectRatio: 16 / 9,
                        placeholder: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: ChannelStepButtons(session: widget.session),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: fullscreen
                                ? 'Sair da tela cheia'
                                : 'Tela cheia',
                            icon: Icon(
                              fullscreen
                                  ? Icons.fullscreen_exit
                                  : Icons.fullscreen,
                            ),
                            onPressed: () =>
                                setState(() => fullscreen = !fullscreen),
                          ),
                          IconButton.filledTonal(
                            icon: Icon(
                              value.isPlaying ? Icons.pause : Icons.play_arrow,
                            ),
                            tooltip: value.isPlaying ? 'Pausar' : 'Reproduzir',
                            onPressed: () => value.isPlaying
                                ? controller.pause()
                                : controller.play(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
