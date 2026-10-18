import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/rocha_theme.dart';
import 'amambai_news_repository.dart';

class NewsCarouselCard extends StatefulWidget {
  final AmambaiNewsRepository? repository;
  final Future<bool> Function(Uri)? opener;
  final ImageProvider<Object> Function(Uri)? imageProvider;
  const NewsCarouselCard({super.key, this.repository, this.opener, this.imageProvider});
  @override
  State<NewsCarouselCard> createState() => _NewsCarouselCardState();
}

class _NewsCarouselCardState extends State<NewsCarouselCard> with WidgetsBindingObserver {
  late final repository = widget.repository ?? AmambaiNewsRepository.shared;
  NewsHeadline? headline;
  Timer? timer;
  bool opening = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resume();
  }
  void _resume() {
    unawaited(_refresh());
    timer?.cancel();
    timer = Timer.periodic(AmambaiNewsRepository.refreshInterval, (_) => unawaited(_refresh()));
  }
  Future<void> _refresh() async {
    final next = await repository.load();
    if (mounted) setState(() => headline = next);
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resume();
    } else {
      timer?.cancel();
    }
  }
  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  Future<void> _open() async {
    if (opening) return;
    opening = true;
    try {
      final uri = headline?.article ?? AmambaiNewsRepository.homepage;
      final opened = await (widget.opener?.call(uri) ?? launchUrl(uri, mode: LaunchMode.externalApplication));
      if (!opened && mounted) _showFailure();
    } catch (_) {
      if (mounted) _showFailure();
    } finally { opening = false; }
  }
  void _showFailure() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Não foi possível abrir o jornal. Tente novamente.')));

  @override
  Widget build(BuildContext context) {
    final article = headline;
    final date = article?.publishedAt.toLocal();
    final stamp = date == null ? 'Notícias de Amambai e região' :
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return Material(
      color: const Color(0xFF100B22),
      borderRadius: BorderRadius.circular(18), clipBehavior: Clip.antiAlias,
      child: InkWell(key: const ValueKey('amambai-news-card'), onTap: _open,
        child: DecoratedBox(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18),
            border: Border.all(color: RochaColors.gold.withValues(alpha: .75))),
          child: Stack(fit: StackFit.expand, children: [
            if (article?.image != null) Image(
              image: widget.imageProvider?.call(article!.image!) ?? NetworkImage(article!.image!.toString()),
              fit: BoxFit.cover, excludeFromSemantics: true,
              errorBuilder: (_, __, ___) => const _NewsFallback(),
            ) else const _NewsFallback(),
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0x66050409), Color(0xF5050409)]))),
            Padding(padding: const EdgeInsets.all(12), child: Align(
              alignment: Alignment.bottomLeft,
              // Use the existing finite carousel bounds, including large text.
              child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.bottomLeft,
                child: SizedBox(width: 250, child: Column(mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('AMAMBAI NOTÍCIAS • $stamp', maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: RochaColors.gold, fontSize: 10, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(article?.title ?? 'Acompanhe as notícias de Amambai',
                    maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, height: 1.12, fontWeight: FontWeight.w800)),
                  if (article != null && article.summary.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(article.summary, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Colors.white70)),
                  ],
                  const SizedBox(height: 6),
                  const Text('Ler no jornal ↗', style: TextStyle(fontSize: 11, color: RochaColors.gold)),
                ])),
              ),
            )),
          ]),
        ),
      ),
    );
  }
}
class _NewsFallback extends StatelessWidget {
  const _NewsFallback();
  @override
  Widget build(BuildContext context) => const ColoredBox(color: Color(0xFF24113D),
    child: Align(alignment: Alignment.topRight, child: Padding(
      padding: EdgeInsets.all(16), child: Icon(Icons.newspaper, size: 44, color: Colors.white24))));
}
