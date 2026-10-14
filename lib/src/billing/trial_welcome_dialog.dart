import 'package:flutter/material.dart';
import '../theme/rocha_theme.dart';

class TrialWelcomeDialog extends StatelessWidget {
  const TrialWelcomeDialog({super.key});

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
              Align(alignment: Alignment.topRight,
                child: IconButton(tooltip: 'Fechar aviso',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: RochaColors.silver))),
              Image.asset('branding/rocha-wordmark-antennas.webp', height: 42,
                excludeFromSemantics: true),
              const SizedBox(height: 12),
              Image.asset('branding/trial-welcome-boy.webp', height: 190,
                semanticLabel: 'Menino sorrindo e fazendo um coração com as mãos',
                errorBuilder: (_, __, ___) => const SizedBox(height: 190,
                  child: Icon(Icons.favorite, size: 72, color: RochaColors.gold))),
              const SizedBox(height: 12),
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
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Começar a assistir', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
              const SizedBox(height: 18),
              const Text('Este aviso aparece uma única vez por conta.', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white60)),
            ])),
        ),
      ),
    ),
  );
}
