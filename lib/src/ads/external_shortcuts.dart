import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/rocha_theme.dart';

/// Owner-approved external shortcut banners (16/11/2026). Order is fixed.
///
/// Destinations open only when the end user selects a banner, in the external
/// browser. The literal URL is passed as-is: no query, token, UID, cookie or any
/// other Rocha+ data is appended, and nothing is loaded inside the app.
class ExternalShortcut {
  final String id;
  final String title;
  final String asset;
  final String url;
  const ExternalShortcut({required this.id, required this.title, required this.asset, required this.url});

  /// Plain HTTP destinations require an explicit, informed confirmation.
  bool get insecure => Uri.parse(url).scheme == 'http';
}

const externalShortcuts = <ExternalShortcut>[
  ExternalShortcut(
    id: 'amambai-noticias',
    title: 'AMAMBAI NOTÍCIAS',
    asset: 'branding/shortcuts/amambai_noticias.png',
    url: 'https://www.amambainoticias.com.br/',
  ),
  ExternalShortcut(
    id: 'ganhe-br',
    title: 'GANHE BR',
    asset: 'branding/shortcuts/ganhe_br.png',
    url: 'https://www.ganhebr47.com/?r=gml4729',
  ),
];

/// Approved art is 1122 x 1402 (vertical); kept exactly, never stretched.
const shortcutArtAspectRatio = 1122 / 1402;

typedef ExternalLauncher = Future<bool> Function(Uri uri);

Future<bool> _openInExternalBrowser(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Opens [shortcut] after user selection. HTTP destinations show a warning and
/// open only if the user explicitly continues. Returns whether it was opened.
Future<bool> openExternalShortcut(BuildContext context, ExternalShortcut shortcut,
    {ExternalLauncher? launcher}) async {
  final uri = Uri.parse(shortcut.url);
  if (shortcut.insecure) {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.lock_open_rounded, color: Color(0xFFFFB74D), size: 36),
        title: const Text('Site externo sem criptografia'),
        content: Text(
          'Você vai sair do Rocha+ e abrir "${uri.host}" no navegador.\n\n'
          'Este endereço usa HTTP, sem criptografia: o que você enviar nesse site '
          'pode ser visto por terceiros. Não informe senhas nem dados pessoais.\n\n'
          'O Rocha+ não envia sua conta, login ou qualquer dado seu para esse site.',
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('shortcut-insecure-continue'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Abrir mesmo assim'),
          ),
        ],
      ),
    );
    if (proceed != true) return false;
  }
  var opened = false;
  try {
    opened = await (launcher ?? _openInExternalBrowser)(uri);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
      content: Text('Não foi possível abrir o navegador. Verifique se há um navegador instalado.'),
    ));
  }
  return opened;
}

/// One approved shortcut as a large banner of the Home "Destaques" carousel.
/// The vertical art is shown whole (contain), never stretched or cropped.
class ExternalShortcutBanner extends StatefulWidget {
  final ExternalShortcut shortcut;
  final ExternalLauncher? launcher;
  const ExternalShortcutBanner({super.key, required this.shortcut, this.launcher});

  @override
  State<ExternalShortcutBanner> createState() => _ExternalShortcutBannerState();
}

class _ExternalShortcutBannerState extends State<ExternalShortcutBanner> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.shortcut;
    return Semantics(
      button: true,
      label: 'Abrir ${s.title}, site externo${s.insecure ? ' sem criptografia' : ''}',
      child: Shortcuts(
        shortcuts: const {SingleActivator(LogicalKeyboardKey.select): ActivateIntent()},
        child: Material(
          color: const Color(0xFF07060F),
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('shortcut-${s.id}'),
            onFocusChange: (value) => setState(() => focused = value),
            onTap: () => openExternalShortcut(context, s, launcher: widget.launcher),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: focused ? RochaColors.gold : const Color(0xFF4A286A),
                    width: focused ? 3 : 1),
              ),
              child: Stack(fit: StackFit.expand, children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: shortcutArtAspectRatio,
                    child: Image.asset(s.asset, fit: BoxFit.contain, filterQuality: FilterQuality.medium,
                        cacheWidth: 720, excludeFromSemantics: true),
                  ),
                ),
                if (s.insecure)
                  const Positioned(
                    right: 10, bottom: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: Color(0xCC000000), shape: BoxShape.circle),
                      child: Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.lock_open_rounded, size: 18, color: Color(0xFFFFB74D)),
                      ),
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
