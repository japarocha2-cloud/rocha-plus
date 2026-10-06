import 'dart:async';

import 'package:flutter/material.dart';
import 'login_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  Timer? _finishTimer;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _fade = CurvedAnimation(
      parent: _animation,
      curve: const Interval(0, .72, curve: Curves.easeOut),
    );
    _scale = Tween<double>(begin: .92, end: 1).animate(
      CurvedAnimation(parent: _animation, curve: Curves.easeOutCubic),
    );
    _animation.forward();
    _finishTimer = Timer(const Duration(milliseconds: 2200), _finish);
  }

  void _finish() {
    if (!mounted || _finishing) return;
    _finishing = true;
    _finishTimer?.cancel();
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
    _finishTimer?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260, maxHeight: 260),
                child: Image.asset(
                  'branding/rocha_plus_icon.webp',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => const RochaLogo(fontSize: 54),
                ),
              ),
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
