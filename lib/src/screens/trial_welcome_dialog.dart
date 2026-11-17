import 'package:flutter/material.dart';

import '../theme/rocha_theme.dart';

/// Owner-approved "Você ganhou 7 dias grátis!" welcome (owner mockup 2026-11-16).
///
/// Shown once per account after the server confirms an active trial. It only
/// informs: closing it never grants or changes access.
class TrialWelcomeDialog extends StatelessWidget {
  static const artAsset = 'branding/trial_welcome_art.jpg';
  static const startKey = ValueKey('trial-welcome-start');
  static const closeKey = ValueKey('trial-welcome-close');

  const TrialWelcomeDialog({super.key});

  /// Route for the caller's (protected) navigator; not the root navigator.
  static DialogRoute<void> route(BuildContext context) => DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.72),
        builder: (_) => const TrialWelcomeDialog(),
      );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Scale typography with the dialog width so small phones keep the layout.
    final width = (size.width - 40).clamp(260.0, 440.0);
    final scale = (width / 400).clamp(0.78, 1.1);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: 'Você ganhou 7 dias grátis',
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: width, maxHeight: size.height - 48),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF07060F),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: RochaColors.gold, width: 2),
              boxShadow: [
                BoxShadow(
                    color: RochaColors.gold.withValues(alpha: 0.45),
                    blurRadius: 24,
                    spreadRadius: 1)
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Stack(children: [
                SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    AspectRatio(
                      aspectRatio: 580 / 453,
                      child: Image.asset(artAsset,
                          fit: BoxFit.cover,
                          semanticLabel:
                              'Personagem Rocha+ fazendo coração com as mãos'),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, 4, 20, 18 * scale),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('Você ganhou',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 34 * scale,
                                fontWeight: FontWeight.w800,
                                height: 1.05)),
                        Text('7 dias grátis!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: RochaColors.gold,
                                fontSize: 40 * scale,
                                fontWeight: FontWeight.w900,
                                height: 1.1)),
                        SizedBox(height: 4 * scale),
                        Text('Bem-vindo ao Rocha+',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22 * scale,
                                fontWeight: FontWeight.w800)),
                        Container(
                            height: 2,
                            width: 140 * scale,
                            margin: EdgeInsets.symmetric(vertical: 8 * scale),
                            color: RochaColors.gold),
                        Text(
                            'Aproveite os canais e recursos durante seu período de teste.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: const Color(0xFFF2F2F4),
                                fontSize: 17 * scale,
                                height: 1.25)),
                        SizedBox(height: 8 * scale),
                        Text(
                            'Depois dos 7 dias, escolha um plano para continuar assistindo.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: const Color(0xFFD9D4E6),
                                fontSize: 13.5 * scale)),
                        SizedBox(height: 12 * scale),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                              vertical: 9 * scale, horizontal: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: RochaColors.gold, width: 1.5),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Mensal R\$ 7,90  •  Anual R\$ 86,90',
                                style: TextStyle(
                                    color: RochaColors.gold,
                                    fontSize: 18 * scale,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ),
                        SizedBox(height: 14 * scale),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: startKey,
                            style: FilledButton.styleFrom(
                              // #0B7A28 keeps white text above WCAG AA (about 5.5:1).
                              backgroundColor: const Color(0xFF0B7A28),
                              foregroundColor: Colors.white,
                              minimumSize: Size.fromHeight(56 * scale),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              textStyle: TextStyle(
                                  fontSize: 20 * scale,
                                  fontWeight: FontWeight.w800),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.play_arrow_rounded,
                                size: 30 * scale),
                            label: const Text('Começar a assistir'),
                          ),
                        ),
                        SizedBox(height: 10 * scale),
                        Text('Este aviso aparece uma única vez por conta.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: const Color(0xFFD9D4E6),
                                fontSize: 13 * scale)),
                      ]),
                    ),
                  ]),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: IconButton(
                    key: closeKey,
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.45)),
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 28),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
