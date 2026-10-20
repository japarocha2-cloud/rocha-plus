import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

import '../live/channel.dart';
import '../live/player_lab_results.dart';
import 'player_screen.dart';

/// Reads the laboratory decision once per opening, avoiding mid-stream flips.
/// Unknown channels continue to use the frozen ExoPlayer behavior.
class AdaptivePlayerScreen extends StatelessWidget {
  final Channel channel;
  const AdaptivePlayerScreen({super.key, required this.channel});

  @override
  Widget build(BuildContext context) => FutureBuilder<LabEngine?>(
    future: PlayerLabResults().preferred(channel),
    builder: (context, snapshot) {
      if (!snapshot.hasData && snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return snapshot.data == LabEngine.libVlc
          ? _VlcPlaybackScreen(channel: channel)
          : PlayerScreen(channel: channel);
    },
  );
}

class _VlcPlaybackScreen extends StatefulWidget {
  final Channel channel;
  const _VlcPlaybackScreen({required this.channel});
  @override
  State<_VlcPlaybackScreen> createState() => _VlcPlaybackScreenState();
}

class _VlcPlaybackScreenState extends State<_VlcPlaybackScreen> {
  late final VlcPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VlcPlayerController.network(widget.channel.url,
      hwAcc: HwAcc.auto, autoPlay: true, options: VlcPlayerOptions());
    _controller.addListener(_updated);
  }

  void _updated() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    _controller.removeListener(_updated);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.value;
    final error = value.errorDescription != VlcPlayerValue.noError;
    return Scaffold(backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.channel.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(error ? 'Sinal indisponível' : 'LibVLC • player selecionado no laboratório',
            style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ])),
      body: Center(child: error
        ? Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('O sinal falhou neste reprodutor.'),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => PlayerScreen(channel: widget.channel))),
            child: const Text('Tentar no ExoPlayer')),
        ])
        : AspectRatio(aspectRatio: 16 / 9,
          child: Stack(children: [
            Positioned.fill(child: VlcPlayer(controller: _controller,
              aspectRatio: 16 / 9,
              placeholder: const Center(child: CircularProgressIndicator()))),
            Positioned(right: 8, bottom: 8,
              child: IconButton.filledTonal(
                icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
                tooltip: value.isPlaying ? 'Pausar' : 'Reproduzir',
                onPressed: () => value.isPlaying ? _controller.pause() : _controller.play())),
          ]))),
    );
  }
}
