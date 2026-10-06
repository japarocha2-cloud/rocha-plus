import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'login_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  VideoPlayerController? _controller;
  Timer? _safetyTimer;
  bool _finishing = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _startIntro();
  }

  Future<void> _startIntro() async {
    final controller = VideoPlayerController.asset('assets/rocha_intro_v2.mp4');
    _controller = controller;
    controller.addListener(_onVideoStateChanged);

    try {
      await controller.initialize().timeout(const Duration(seconds: 4));
      if (!mounted) return;
      await controller.setLooping(false);
      await controller.setVolume(1);
      setState(() {});
      await controller.play();

      final duration = controller.value.duration;
      _safetyTimer = Timer(
        duration > Duration.zero
            ? duration + const Duration(milliseconds: 450)
            : const Duration(seconds: 6),
        _finish,
      );
    } catch (error) {
      debugPrint('Rocha+ intro error: $error');
      if (!mounted) return;
      setState(() => _failed = true);
      _safetyTimer = Timer(const Duration(milliseconds: 1400), _finish);
    }
  }

  void _onVideoStateChanged() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _finishing) {
      return;
    }
    final duration = controller.value.duration;
    if (duration > Duration.zero &&
        controller.value.position >= duration - const Duration(milliseconds: 120)) {
      _finish();
    }
  }

  void _finish() {
    if (!mounted || _finishing) return;
    _finishing = true;
    _safetyTimer?.cancel();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, animation, __) => const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onVideoStateChanged);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: SizedBox.expand(
          child: _failed
              ? const Center(child: RochaLogo(fontSize: 54))
              : controller == null || !controller.value.isInitialized
                  ? const ColoredBox(color: Colors.black)
                  : FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: controller.value.size.width,
                        height: controller.value.size.height,
                        child: VideoPlayer(controller),
                      ),
                    ),
        ),
      ),
    );
  }
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
          TextSpan(text: 'Rocha', style: TextStyle(color: Color(0xFFD6D6D8))),
          TextSpan(text: '+', style: TextStyle(color: Color(0xFFF4D7A4))),
        ],
      ),
    );
  }
}
