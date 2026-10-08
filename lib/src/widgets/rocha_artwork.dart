import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Renders approved artwork from the supplied references without redrawing the brand.
class RochaArtwork extends StatefulWidget {
  final bool room;
  final String? assetPath;
  final Rect region;
  final BoxFit fit;
  const RochaArtwork({super.key, this.room = false, this.assetPath,
    this.region = const Rect.fromLTRB(.53, 0, .885, .40), this.fit = BoxFit.cover});
  @override
  State<RochaArtwork> createState() => _RochaArtworkState();
}

class _RochaArtworkState extends State<RochaArtwork> {
  ImageStream? _stream;
  ImageInfo? _info;
  late final ImageStreamListener _listener;
  @override
  void initState() {
    super.initState();
    _listener = ImageStreamListener((info, _) {
      if (mounted) { setState(() { _info?.dispose(); _info = info; }); }
      else { info.dispose(); }
    }, onError: (Object _, StackTrace? __) {});
  }
  @override
  void didChangeDependencies() { super.didChangeDependencies(); _resolve(); }
  @override
  void didUpdateWidget(RochaArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room != widget.room || oldWidget.assetPath != widget.assetPath) _resolve();
  }
  void _resolve() {
    final stream = AssetImage(widget.assetPath ?? (widget.room
        ? 'branding/cast-reference.png' : 'branding/dashboard-reference.png'))
        .resolve(createLocalImageConfiguration(context));
    if (_stream?.key == stream.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }
  @override
  void dispose() {
    _stream?.removeListener(_listener); _info?.dispose(); super.dispose();
  }
  @override
  Widget build(BuildContext context) => Semantics(
    image: true, label: 'Arte oficial Rocha+',
    child: _info == null ? const SizedBox.expand() :
      CustomPaint(painter: _ArtworkPainter(_info!.image, widget.region, widget.fit),
        child: const SizedBox.expand()),
  );
}

class _ArtworkPainter extends CustomPainter {
  final ui.Image image;
  final Rect region;
  final BoxFit fit;
  _ArtworkPainter(this.image, this.region, this.fit);
  @override
  void paint(Canvas canvas, Size size) {
    final source = Rect.fromLTRB(region.left * image.width, region.top * image.height,
        region.right * image.width, region.bottom * image.height);
    final fitted = applyBoxFit(fit, source.size, size);
    final input = Alignment.center.inscribe(fitted.source, source);
    final output = Alignment.center.inscribe(fitted.destination, Offset.zero & size);
    canvas.drawImageRect(image, input, output, Paint()..filterQuality = FilterQuality.high);
  }
  @override
  bool shouldRepaint(_ArtworkPainter old) =>
      old.image != image || old.region != region || old.fit != fit;
}

/// Approved wordmark with silver TV antennas on R and genuine alpha.
class RochaWordmark extends StatelessWidget {
  const RochaWordmark({super.key});
  @override
  Widget build(BuildContext context) => const RochaArtwork(
    assetPath: 'branding/rocha-wordmark-antennas.webp',
    region: Rect.fromLTRB(.03, .16, .98, .85), fit: BoxFit.contain);
}
