import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/rocha_theme.dart';
import 'login_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();
    _timer = Timer(const Duration(seconds: 4), _finish);
  }

  void _finish() {
    if (!mounted) return;
    _timer?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: InkWell(
        onTap: _finish,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              radius: 1.1,
              colors: [RochaColors.wine, RochaColors.background],
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: ScaleTransition(
                  scale: _scale,
                  child: const RochaLogo(fontSize: 64),
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 42,
                child: Text(
                  'O entretenimento ganhou um novo reino.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
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
