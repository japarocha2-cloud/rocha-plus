import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/rocha_theme.dart';
import '../sports/caze_tv_source.dart';

/// Official YouTube embed only; no signal extraction or retransmission.
class CazeTvScreen extends StatefulWidget {
  const CazeTvScreen({super.key});

  static const usesOfficialYouTubeEmbed = true;
  static const extractsMediaStream = false;
  static bool isValidVideoId(String value) => CazeTvSource.isValidVideoId(value);

  @override
  State<CazeTvScreen> createState() => _CazeTvScreenState();
}

class _CazeTvScreenState extends State<CazeTvScreen> {
  WebViewController? _web;
  bool _loading = true;
  bool _error = false;

  Future<void> _loadVideo() async {
    final url = CazeTvSource.embedUri;
    final web = _web;
    if (url == null || web == null) return;
    try {
      await web.loadRequest(url, headers: const {
        'Referer': CazeTvSource.appHttpReferer,
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  @override
  void initState() {
    super.initState();
    if (CazeTvSource.embedUri == null) return;
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() { _loading = true; _error = false; });
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame == true && mounted) {
            setState(() { _loading = false; _error = true; });
          }
        },
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri == null || uri.scheme != 'https') {
            return NavigationDecision.prevent;
          }
          final host = uri.host.toLowerCase();
          if (host == 'youtube.com' || host.endsWith('.youtube.com') ||
              host == 'youtube-nocookie.com' ||
              host.endsWith('.youtube-nocookie.com') ||
              host == 'googlevideo.com' || host.endsWith('.googlevideo.com')) {
            return NavigationDecision.navigate;
          }
          return NavigationDecision.prevent;
        },
      ));
    unawaited(_loadVideo());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('CazéTV • Oficial')),
    body: SafeArea(child: SingleChildScrollView(child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('CazéTV', style: TextStyle(
              fontSize: 26, fontWeight: FontWeight.w900, color: RochaColors.gold)),
            const SizedBox(height: 12),
            if (_web == null)
              const Text('Nenhuma transmissão oficial incorporável está configurada nesta versão. '
                'A programação ao vivo depende da disponibilidade e das permissões da CazéTV.',
                textAlign: TextAlign.center)
            else ...[
              if (_loading && !_error)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: CircularProgressIndicator(),
                ),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: WebViewWidget(controller: _web!),
              ),
              if (_error) Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(children: [
                  const Text('Não foi possível carregar o player oficial. '
                    'O vídeo pode não permitir incorporação.'),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() { _loading = true; _error = false; });
                      unawaited(_loadVideo());
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            const Text('Reprodução pelo player oficial do YouTube. '
              'Sem retransmissão, extração de sinal ou ocultação de controles.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
      ),
    ))),
  );
}
