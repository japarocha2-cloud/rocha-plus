import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'home_screen.dart';

/// Isolated preview. Never grants trial access or opens protected streams.
class VisualTrialTestScreen extends StatefulWidget {
  const VisualTrialTestScreen({super.key});

  @override
  State<VisualTrialTestScreen> createState() => _VisualTrialTestScreenState();
}

class _VisualTrialTestScreenState extends State<VisualTrialTestScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fireflies;
  late final AnimationController _celebration;
  late final AnimationController _collect;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _fireflies = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 4300),
    )..repeat();
    _celebration = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100),
    );
    _collect = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 850),
    );
  }

  @override
  void dispose() {
    _fireflies.dispose();
    _celebration.dispose();
    _collect.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_closing) return;
    setState(() => _closing = true);
    // The boy NEVER jumps on his own. Celebrate first, collect second.
    await _celebration.forward();
    if (!mounted) return;
    await _collect.forward();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => HomeScreen(previewOnly: true, onSignOut: () async {}),
      ),
    );
  }

  Widget _firefly(int i) {
    return AnimatedBuilder(
      animation: _fireflies,
      builder: (context, _) {
        final t = _fireflies.value * math.pi * 2;
        final phase = i * 2.39996;
        final dx = math.sin(t + phase) * (7 + i * 2);
        final dy = math.cos(t * .7 + phase) * (8 + i);
        final glimmer = .25 + .75 *
            (0.5 + 0.5 * math.sin(t * (1.3 + i * .12) + phase));
        return Positioned(
          left: (i.isEven ? 9.0 : 70.0) + dx,
          top: 12 + i * 19.0 + dy,
          child: Opacity(
            opacity: glimmer.clamp(0.0, 1.0),
            child: Text(i.isEven ? '✦' : '✧',
              style: TextStyle(
                fontSize: 14 + (i % 3) * 3.0,
                color: const Color(0xFFFFD45C),
                shadows: [
                  Shadow(color: const Color(0xFFFFDA65)
                      .withValues(alpha: glimmer * .85), blurRadius: 13),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _boyImage() {
    return AnimatedBuilder(
      animation: _celebration,
      child: Image.asset('branding/trial-welcome-boy.webp',
        height: 190, fit: BoxFit.contain),
      builder: (context, child) {
        final t = _celebration.value;
        // Two joyful hops, with a soft landing, only after Continue.
        final hop = _closing
            ? math.pow(math.sin(2 * math.pi * t), 2).toDouble() *
                36 * (1 - .28 * t)
            : 0.0;
        return Transform.translate(
          offset: Offset(0, -hop),
          child: Transform.rotate(
            angle: _closing ? math.sin(4 * math.pi * t) * .065 : 0,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071426),
      body: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _collect,
            builder: (context, child) {
              final t = Curves.easeInCubic.transform(_collect.value);
              // Collection has a visible destination above the card,
              // rather than simply fading in place.
              return Transform.translate(
                offset: Offset(0, -235 * t),
                child: Transform.rotate(
                  angle: .28 * t,
                  child: Transform.scale(
                    scale: 1 - .93 * t,
                    child: Opacity(
                      opacity: (1 - .72 * t).clamp(0.0, 1.0),
                      child: child,
                    ),
                  ),
                ),
              );
            },
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
                  SizedBox(
                    height: 190,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        for (var i = 0; i < 8; i++) _firefly(i),
                        _boyImage(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Bem-vindo ao Rocha+!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 25,
                      fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  const Text('Você ganhou 7 dias para conhecer o Rocha+.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFD9E6F7),
                      fontSize: 16, height: 1.35)),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _closing ? null : _continue,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: const Color(0xFFFFC928),
                        foregroundColor: const Color(0xFF071426)),
                      child: const Text('Continuar',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
