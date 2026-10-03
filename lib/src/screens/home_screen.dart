import 'package:flutter/material.dart';
import '../theme/rocha_theme.dart';
import 'live_tv_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const sections = [
    ('TV ao Vivo', Icons.live_tv),
    ('Filmes', Icons.movie_outlined),
    ('Séries', Icons.tv_outlined),
    ('Esportes', Icons.sports_soccer),
    ('Infantil', Icons.toys_outlined),
    ('Documentários', Icons.public),
    ('Regionais', Icons.location_city),
    ('Favoritos', Icons.favorite_border),
  ];

  void openSection(BuildContext context, String title) {
    if (title == 'TV ao Vivo') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveTvScreen()));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title entra na próxima etapa.')),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: RochaColors.background,
          title: const Text.rich(TextSpan(children: [
            TextSpan(text: 'Rocha', style: TextStyle(fontWeight: FontWeight.w900)),
            TextSpan(text: '+', style: TextStyle(color: RochaColors.gold, fontWeight: FontWeight.w900)),
          ])),
        ),
        SliverToBoxAdapter(child: _Hero(onWatch: () => openSection(context, 'TV ao Vivo'))),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 26, 20, 14),
          sliver: SliverToBoxAdapter(child: Text('Explore o Rocha+', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid.builder(
            itemCount: sections.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 280, mainAxisExtent: 145,
              crossAxisSpacing: 14, mainAxisSpacing: 14,
            ),
            itemBuilder: (_, index) {
              final item = sections[index];
              return _SectionCard(
                title: item.$1,
                icon: item.$2,
                onTap: () => openSection(context, item.$1),
              );
            },
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ]),
    ),
  );
}

class _Hero extends StatelessWidget {
  final VoidCallback onWatch;
  const _Hero({required this.onWatch});

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 310),
    padding: const EdgeInsets.all(28),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topRight, end: Alignment.bottomLeft,
        colors: [RochaColors.wine, RochaColors.background],
      ),
    ),
    child: Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('BEM-VINDO AO ROCHA+', style: TextStyle(color: RochaColors.gold, letterSpacing: 2)),
            const SizedBox(height: 12),
            const Text('Entretenimento sem limites', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            const Text('TV aberta e transmissões públicas ou autorizadas em uma experiência rápida e elegante.',
              style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: onWatch, icon: const Icon(Icons.play_arrow), label: const Text('Assistir agora')),
          ],
        ),
      ),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const _SectionCard({required this.title, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 38, color: RochaColors.gold),
          const Spacer(),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('Abrir', style: TextStyle(color: Colors.white54)),
        ]),
      ),
    ),
  );
}
