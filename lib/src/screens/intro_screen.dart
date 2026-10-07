import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/rocha_theme.dart';
import 'login_screen.dart';

class IntroScreen extends StatefulWidget {
  final VideoPlayerController Function()? controllerFactory;
  final VoidCallback? onFinished;
  const IntroScreen({super.key, this.controllerFactory, this.onFinished});
  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  late final VideoPlayerController _controller;
  Timer? _guard;
  bool _finished = false;
  @override
  void initState() {
    super.initState();
    _controller = widget.controllerFactory?.call() ??
      VideoPlayerController.asset('branding/intro-rocha-plus.mp4');
    _controller.addListener(_changed);
    _start();
  }
  Future<void> _start() async {
    try {
      await _controller.initialize().timeout(const Duration(seconds: 8));
      if (!mounted || _finished) return;
      await _controller.setLooping(false);
      await _controller.setVolume(1);
      if (!mounted || _finished) return;
      _guard = Timer(_controller.value.duration + const Duration(seconds: 3), _finish);
      await _controller.play();
      if (mounted && !_finished) setState(() {});
    } catch (_) {
      _finish();
    }
  }
  void _changed() {
    if (!mounted || _finished) return;
    final value = _controller.value;
    if (value.hasError ||
        (value.isInitialized && value.duration > Duration.zero &&
          value.position >= value.duration)) {
      _finish();
      return;
    }
    setState(() {});
  }
  void _finish() {
    if (!mounted || _finished) return;
    setState(() => _finished = true);
    _guard?.cancel();
    unawaited(_controller.pause().catchError((Object _) {}));
    if (widget.onFinished != null) {
      widget.onFinished!();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }
  @override
  void dispose() {
    _guard?.cancel();
    _controller.removeListener(_changed);
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(children: [
      Positioned.fill(child: _finished ? const SizedBox.shrink() : _controller.value.isInitialized ?
        IntroVideoFrame(size: _controller.value.size, child: VideoPlayer(_controller)) :
        const Center(child: CircularProgressIndicator(color: RochaColors.gold))),
      Positioned(right: 16, bottom: 16,
        child: SafeArea(child: TextButton(
          autofocus: true, onPressed: _finish, child: const Text('Pular')))),
    ]),
  );
}

/// Contains the complete source frame: no cover, crop, stretch or added zoom.
class IntroVideoFrame extends StatelessWidget {
  final Size size;
  final Widget child;
  const IntroVideoFrame({super.key, required this.size, required this.child});
  @override
  Widget build(BuildContext context) => Center(child: FittedBox(
    fit: BoxFit.contain,
    child: SizedBox(width: size.width, height: size.height, child: child)));
}

class RochaLogo extends StatelessWidget {
  final double fontSize;
  const RochaLogo({super.key, this.fontSize = 42});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900),
        children: const [
          TextSpan(
            text: 'Rocha',
            style: TextStyle(color: RochaColors.silver),
          ),
          TextSpan(
            text: '+',
            style: TextStyle(color: RochaColors.gold),
          ),
        ],
      ),
    );
  }
}
