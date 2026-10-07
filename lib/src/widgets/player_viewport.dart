import 'package:flutter/material.dart';

class PlayerViewport extends StatelessWidget {
  final double aspectRatio;
  final Widget video;
  final List<Widget> overlays;
  const PlayerViewport({
    super.key, required this.aspectRatio, required this.video,
    required this.overlays,
  });
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Center(child: AspectRatio(
        aspectRatio: aspectRatio > 0 ? aspectRatio : 16 / 9,
        child: video,
      )),
      ...overlays,
    ],
  );
}
