import 'package:flutter/material.dart';

Future<bool?> showTrialWelcomeDialog(BuildContext context) =>
    showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (_, __, ___) => const TrialWelcomeDialog(),
    );

/// Displays only the alert from the approved source, without redrawing it.
class TrialWelcomeDialog extends StatelessWidget {
  final VoidCallback? onAccepted;
  const TrialWelcomeDialog({super.key, this.onAccepted});

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetAnimationDuration: Duration.zero,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 638),
        child: AspectRatio(
          aspectRatio: 638 / 1010,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 638,
              height: 1010,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(46),
                child: Stack(children: [
                  Positioned(
                    left: -114, top: -411, width: 864, height: 1536,
                    child: Image.asset('branding/trial-welcome-approved.png',
                      fit: BoxFit.fill,
                      excludeFromSemantics: true),
                  ),
                  Positioned.fill(child: Semantics(
                    label: 'Rocha+. Você ganhou 7 dias grátis! '
                      'Bem-vindo ao Rocha+. Aproveite os canais e recursos '
                      'durante seu período de teste. Depois dos 7 dias, '
                      'escolha um plano para continuar assistindo. '
                      'Mensal R\$ 4,90. Anual R\$ 55,00. '
                      'Este aviso aparece uma única vez por conta.',
                    child: const SizedBox.expand(),
                  )),
                  Positioned(
                    left: 44, top: 840, width: 548, height: 90,
                    child: Semantics(
                      button: true, label: 'Começar a assistir',
                      child: GestureDetector(
                        key: const ValueKey('trial-welcome-accept'),
                        behavior: HitTestBehavior.opaque,
                        onTap: onAccepted ?? () => Navigator.of(context).pop(true),
                        child: FocusableActionDetector(
                          autofocus: true,
                          actions: <Type, Action<Intent>>{
                            ActivateIntent: CallbackAction<ActivateIntent>(
                              onInvoke: (_) {
                                if (onAccepted != null) { onAccepted!(); }
                                else { Navigator.of(context).pop(true); }
                                return null;
                              }),
                          },
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
