import 'package:flutter/material.dart';

import '../live/channel.dart';
import 'adaptive_player_screen.dart';

/// A real, user-opened preview; no autoplay on focus or simulated frames.
class ChannelPreviewScreen extends StatefulWidget {
  final Channel channel;
  final List<Channel> channels;
  const ChannelPreviewScreen({
    super.key,
    required this.channel,
    required this.channels,
  });
  @override
  State<ChannelPreviewScreen> createState() => _ChannelPreviewScreenState();
}

class _ChannelPreviewScreenState extends State<ChannelPreviewScreen> {
  late Channel selected = widget.channel;
  bool casting = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Prévia do canal')),
    body: Column(
      children: [
        Expanded(
          child: AdaptivePlayerScreen(
            channel: widget.channel,
            channels: widget.channels,
            onCastingChanged: (value) {
              if (value == casting) return;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => casting = value);
              });
            },
            onChannelChanged: (channel) {
              if (channel.url == selected.url) return;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => selected = channel);
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            autofocus: true,
            icon: const Icon(Icons.fullscreen),
            label: const Text('Assistir em tela cheia'),
            onPressed: casting
                ? null
                : () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdaptivePlayerScreen(
                        channel: selected,
                        channels: widget.channels,
                        initiallyFullscreen: true,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    ),
  );
}
