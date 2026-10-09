import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../sports/caze_tv_source.dart';
import '../theme/rocha_theme.dart';
import '../widgets/rocha_artwork.dart';

/// Official YouTube embed only. This screen does not extract or relay streams.
///
/// The premium dark/gold layout is based on the owner's approved visual example.
/// There is deliberately no simulated live indicator or fabricated match content.
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
  bool _loading = false;
  bool _error = false;

  Future<void> _loadVideo() async {
    final url = CazeTvSource.embedUri;
    final web = _web;
    if (url == null || web == null) return;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = false;
      });
    }
    try {
      await web.loadRequest(url, headers: const {
        'Referer': CazeTvSource.appHttpReferer,
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
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
          if (mounted) {
            setState(() {
              _loading = true;
              _error = false;
            });
          }
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame == true && mounted) {
            setState(() {
              _loading = false;
              _error = true;
            });
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: const Color(0xFF0A0A0D),
        title: const SizedBox(
          width: 142,
          height: 44,
          child: RochaWordmark(),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            final wide = viewport.maxWidth >= 760;
            final inset = wide ? 28.0 : 16.0;
            return SingleChildScrollView(
              key: const ValueKey('cazetv-scroll'),
              padding: EdgeInsets.fromLTRB(inset, 20, inset, 36),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _CazeHero(),
                      SizedBox(height: wide ? 24 : 18),
                      _playerPanel(),
                      const SizedBox(height: 16),
                      _watchButton(),
                      const SizedBox(height: 14),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.verified_user_outlined,
                            size: 17, color: RochaColors.gold),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Player oficial incorporado ao Rocha+',
                              style: TextStyle(
                                color: Colors.white70, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _helpPanel(),
                      const SizedBox(height: 14),
                      const Text(
                        'Sem retransmissão ou extração de sinal. '
                        'Os controles e permissões são do YouTube.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12, color: Colors.white54),
                      ),
                      SizedBox(height: wide ? 35 : 28),
                      const _CazeContentPreview(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _playerPanel() {
    final controller = _web;
    return Container(
      key: const ValueKey('cazetv-player-panel'),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF665129)),
        boxShadow: const [
          BoxShadow(color: Color(0x30000000),
            blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: controller == null
                ? const _NoOfficialVideo()
                : WebViewWidget(controller: controller),
          ),
          if (_loading && !_error)
            const Padding(
              padding: EdgeInsets.all(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: RochaColors.gold)),
                  SizedBox(width: 9),
                  Text('Carregando player oficial...',
                    style: TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
          if (_error)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Não foi possível carregar o player oficial. '
                'O vídeo pode não permitir incorporação.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70)),
            ),
        ],
      ),
    );
  }

  Widget _watchButton() {
    final available = _web != null;
    return SizedBox(
      height: 54,
      child: FilledButton.icon(
        key: const ValueKey('cazetv-watch-official'),
        onPressed: available ? () => unawaited(_loadVideo()) : null,
        style: FilledButton.styleFrom(
          foregroundColor: const Color(0xFF100D07),
          backgroundColor: RochaColors.gold,
          disabledBackgroundColor: const Color(0xFF453B2B),
          disabledForegroundColor: Colors.white60,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13)),
        ),
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text(available
            ? 'Assistir pelo player oficial'
            : 'Transmissão não configurada',
          style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _helpPanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF15171D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF35363E)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                size: 28, color: Colors.white70),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Problemas para carregar?',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                    Text('Confira a conexão e tente novamente.',
                      softWrap: true,
                      style: TextStyle(fontSize: 12, color: Colors.white60)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              key: const ValueKey('cazetv-retry'),
              onPressed: _web == null ? null : () => unawaited(_loadVideo()),
              style: OutlinedButton.styleFrom(
                foregroundColor: RochaColors.silver,
                side: const BorderSide(color: Color(0xFF77767B))),
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CazeHero extends StatelessWidget {
  const _CazeHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('cazetv-approved-hero'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            Color(0xFF272018),
            Color(0xFF111115),
            Color(0xFF09090D),
          ],
        ),
        border: Border.all(color: const Color(0xFF5A4825)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 23),
      child: Row(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF201A13),
            border: Border.all(color: RochaColors.gold, width: 2)),
          child: const Icon(Icons.sports_soccer_outlined,
            color: RochaColors.gold, size: 28),
        ),
        const SizedBox(width: 15),
        const Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CazéTV',
              key: ValueKey('cazetv-hero-title'),
              style: TextStyle(fontSize: 27,
                fontWeight: FontWeight.w900, color: Colors.white)),
            SizedBox(height: 3),
            Text('ESPORTE E ENTRETENIMENTO',
              style: TextStyle(fontSize: 11, letterSpacing: 1.1,
                color: Colors.white70)),
            SizedBox(height: 7),
            Text('Reprodução via YouTube oficial',
              style: TextStyle(fontSize: 12, color: RochaColors.gold)),
          ],
        )),
      ]),
    );
  }
}

class _NoOfficialVideo extends StatelessWidget {
  const _NoOfficialVideo();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.live_tv_outlined,
            color: RochaColors.gold, size: 32),
          SizedBox(height: 5),
          Text('Nenhuma transmissão oficial configurada',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 5),
          Text('A reprodução depende de um vídeo da CazéTV '
            'que permita incorporação.',
            style: TextStyle(fontSize: 12, color: Colors.white70),
            textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Navigation cards remain informative until the official catalog is wired.
/// No fake feeds or dead buttons are presented as playable content.
class _CazeContentPreview extends StatelessWidget {
  const _CazeContentPreview();

  @override
  Widget build(BuildContext context) {
    const categories = [
      ('Ao vivo', Icons.live_tv_outlined),
      ('Melhores momentos', Icons.sports_soccer),
      ('Programas', Icons.mic_external_on_outlined),
      ('Cortes', Icons.movie_outlined),
    ];
    return Column(
      key: const ValueKey('cazetv-content-categories'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Conteúdo da CazéTV',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        const Text('Categorias previstas. '
          'O catálogo oficial ainda não está integrado.',
          style: TextStyle(fontSize: 12, color: Colors.white60)),
        const SizedBox(height: 16),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, index) {
              final category = categories[index];
              return Container(
                width: 157,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF19191E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF393330)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(category.$2, color: RochaColors.gold),
                    Text(category.$1,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
