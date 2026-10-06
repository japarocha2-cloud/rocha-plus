import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'login_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/rocha_intro.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        _controller
          ..setLooping(false)
          ..addListener(_watchPlayback)
          ..play();
        setState(() => _ready = true);
      }).catchError((_) => _finish());
  }

  void _watchPlayback() {
    if (!_controller.value.isInitialized || _finishing) return;
    final duration = _controller.value.duration;
    final position = _controller.value.position;
    if (duration > Duration.zero &&
        position >= duration - const Duration(milliseconds: 120)) {
      _finish();
    }
  }

  void _finish() {
    if (!mounted || _finishing) return;
    _finishing = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_watchPlayback);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: SizedBox.expand(
          child: !_ready
              ? const Center(child: CircularProgressIndicator())
              : FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
        ),
      ),
    );
  }
}
