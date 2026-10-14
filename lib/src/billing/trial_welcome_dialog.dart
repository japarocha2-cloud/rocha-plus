import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/rocha_theme.dart';

class TrialWelcomeDialog extends StatefulWidget {
  const TrialWelcomeDialog({super.key});

  @override
  State<TrialWelcomeDialog> createState() => _TrialWelcomeDialogState();
}

class _TrialWelcomeDialogState extends State<TrialWelcomeDialog>
    with TickerProviderStateMixin {
  late final AnimationController _stars;
  late final AnimationController _celebration;
  late final Animation<double> _jump;
  late final Animation<double> _cardScale;
  late final Animation<double> _cardTurn;
  late final Animation<double> _cardOpacity;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _stars = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    _celebration = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );

    _jump = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: -14)
          .chain(CurveTween(curve: Curves.easeOut)), weight: 12),
      TweenSequenceItem(tween: Tween<double>(begin: -14, end: 0)
          .chain(CurveTween(curve: Curves.easeIn)), weight: 12),
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: -11)
          .chain(CurveTween(curve: Curves.easeOut)), weight: 12),
      TweenSequenceItem(tween: Tween<double>(begin: -11, end: 0)
          .chain(CurveTween(curve: Curves.easeIn)), weight: 12),
      TweenSequenceItem(tween: ConstantTween(0), weight: 52),
    ]).animate(_celebration);

    _cardScale = Tween<double>(begin: 1, end: .08).animate(
      CurvedAnimation(parent: _celebration,
        curve: const Interval(.42, 1, curve: Curves.easeInBack)),
    );
    _cardTurn = Tween<double>(begin: 0, end: .07).animate(
      CurvedAnimation(parent: _celebration,
        curve: const Interval(.42, 1, curve: Curves.easeInOut)),
    );
    _cardOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _celebration,
        curve: const Interval(.72, 1, curve: Curves.easeIn)),
    );
  }

  @override
  void dispose() {
    _stars.dispose();
    _celebration.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_closing) return;
    setState(() => _closing = true);
    await _celebration.forward();
    if (mounted) Navigator.of(context).pop(true);
  }

  Widget _star(double left, double top, double phase, double size) {
    return AnimatedBuilder(
      animation: _stars,
      builder: (_, __) {
        final t = (_stars.value + phase) % 1;
        final glow = .28 + .72 * ((math.sin(t * math.pi * 2) + 1) / 2);
        final drift = math.sin(t * math.pi * 2) * 4;
        return Positioned(
          left: left + drift,
          top: top - drift * .45,
          child: Opacity(
            opacity: glow,
            child: Icon(Icons.star_rounded, size: size,
              color: RochaColors.gold),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    child: AnimatedBuilder(
      animation: _celebration,
      builder: (_, child) => Opacity(
        opacity: _cardOpacity.value,
        child: Transform.rotate(
          angle: _cardTurn.value,
          child: Transform.scale(scale: _cardScale.value, child: child),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: RochaColors.gold, width: 1.5),
            gradient: const LinearGradient(begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [RochaColors.background, RochaColors.cosmicBlue, RochaColors.background]),
            boxShadow: [BoxShadow(color: RochaColors.gold.withValues(alpha: .18), blurRadius: 24)],
          ),
          child: SingleChildScrollView(
            child: Padding(padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Image.asset('branding/rocha-wordmark-antennas.webp', height: 42,
                  excludeFromSemantics: true),
                const SizedBox(height: 12),
                SizedBox(height: 198, child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _star(16, 20, .00, 18),
                    _star(315, 28, .18, 14),
                    _star(42, 132, .36, 12),
                    _star(300, 142, .54, 20),
                    _star(275, 78, .72, 10),
                    Center(child: AnimatedBuilder(
                      animation: _celebration,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(0, _jump.value), child: child),
                      child: Image.asset('branding/trial-welcome-boy.webp', height: 190,
                        semanticLabel: 'Menino fazendo um coração com as mãos',
                        errorBuilder: (_, __, ___) => const SizedBox(height: 190,
                          child: Icon(Icons.favorite, size: 72, color: RochaColors.gold))),
                    )),
                  ],
                )),
                const SizedBox(height: 8),
                const Text('Você ganhou 7 dias grátis!', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: RochaColors.gold)),
                const SizedBox(height: 12),
                const Text('Bem-vindo ao Rocha+', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600, color: RochaColors.silver)),
                const SizedBox(height: 16),
                const Text('Aproveite os canais e recursos durante seu período de teste.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 17, color: RochaColors.silver)),
                const SizedBox(height: 14),
                const Text('Depois dos 7 dias, escolha um plano para continuar assistindo.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                const Text('Mensal R\$ 4,90 • Anual R\$ 55,00', textAlign: TextAlign.center,
                  style: TextStyle(color: RochaColors.gold, fontWeight: FontWeight.w700, fontSize: 17)),
                const SizedBox(height: 22),
                SizedBox(width: double.infinity, child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: RochaColors.playGreen,
                    foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: _closing ? null : _continue,
                  child: const Text('Continuar', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
                const SizedBox(height: 18),
                const Text('Este aviso aparece uma única vez por conta.', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.white60)),
              ])),
          ),
        ),
      ),
    ),
  );
}
