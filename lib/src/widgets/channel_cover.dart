import 'package:flutter/material.dart';
import '../live/channel.dart';

/// Offline artwork identifies every channel even without a remote logo.
class ChannelCover extends StatelessWidget {
  final Channel channel;
  const ChannelCover({super.key, required this.channel});

  @override
  Widget build(BuildContext context) {
    final name = channel.name
        .replaceAll(RegExp(r'\s*\(\d+p\)|\s*\[[^\]]*\]'), '')
        .trim();
    final hue = name.runes.fold<int>(0, (sum, rune) => sum + rune) % 360;
    final accent = HSVColor.fromAHSV(1, hue.toDouble(), .55, .8).toColor();
    final artwork = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: .65), const Color(0xFF160C29)],
        ),
        border: Border.all(color: accent.withValues(alpha: .7)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(right: -18, bottom: -25,
            child: Icon(Icons.live_tv_rounded, size: 125,
              color: Colors.white.withValues(alpha: .08))),
          Center(child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(name, textAlign: TextAlign.center, maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 21, height: 1.1,
                fontWeight: FontWeight.w900, color: Colors.white)),
          )),
        ],
      ),
    );
    final logo = channel.logo;
    if (logo == null || logo.isEmpty) return artwork;
    return Image.network(logo, fit: BoxFit.contain,
      loadingBuilder: (_, child, progress) => progress == null ? child : artwork,
      errorBuilder: (_, __, ___) => artwork);
  }
}
