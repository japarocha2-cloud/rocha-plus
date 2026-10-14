import 'dart:async';
import 'package:flutter/material.dart';
import 'home_screen.dart';

class VisualTrialTestScreen extends StatefulWidget {
  const VisualTrialTestScreen({super.key});

  @override
  State<VisualTrialTestScreen> createState() => _VisualTrialTestScreenState();
}

class _VisualTrialTestScreenState extends State<VisualTrialTestScreen>
    with TickerProviderStateMixin {
  late final AnimationController _stars;
  late final AnimationController _boy;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _stars = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _boy = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _stars.dispose();
    _boy.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    setState(() => _closing = true);
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => HomeScreen(
          previewOnly: true,
          onSignOut: () async {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071426),
      body: SafeArea(
        child: Center(
          child: AnimatedScale(
            scale: _closing ? 0.82 : 1,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeInBack,
            child: AnimatedOpacity(
              opacity: _closing ? 0 : 1,
              duration: const Duration(milliseconds: 360),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 390),
                margin: const EdgeInsets.all(22),
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF10233E),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white24),
                  boxShadow: const [
                    BoxShadow(blurRadius: 30, color: Colors.black45),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _stars,
                      builder: (_, child) => Opacity(
                        opacity: 0.45 + (_stars.value * 0.45),
                        child: child,
                      ),
                      child: const Text(
                        '✦  ✧  ✦',
                        style: TextStyle(
                          color: Color(0xFFFFD45C),
                          fontSize: 24,
                          letterSpacing: 8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedBuilder(
                      animation: _boy,
                      child: Image.asset(
                        'branding/trial-welcome-boy.webp',
                        height: 190,
                        fit: BoxFit.contain,
                      ),
                      builder: (_, child) => Transform.translate(
                        offset: Offset(0, -3 * _boy.value),
                        child: child,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Bem-vindo ao Rocha+!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Você ganhou 7 dias para conhecer o Rocha+.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFD9E6F7),
                        fontSize: 16,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _closing ? null : _continue,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          backgroundColor: const Color(0xFFFFC928),
                          foregroundColor: const Color(0xFF071426),
                        ),
                        child: const Text(
                          'Continuar',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
