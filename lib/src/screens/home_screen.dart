import 'package:flutter/material.dart';
import '../theme/rocha_theme.dart';
import 'live_tv_screen.dart';
import 'news_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const sections = [
    ('TV ao Vivo', Icons.live_tv_rounded),
    ('Esportes', Icons.sports_soccer_rounded),
    ('Notícias', Icons.newspaper_rounded),
    ('Infantil', Icons.toys_rounded),

    ('Favoritos', Icons.favorite_rounded),
  ];

  void openSection(BuildContext context, String title) {
    if (title == 'Notícias') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const NewsScreen()));
      return;
    }
    if (title == 'TV ao Vivo' || title == 'Favoritos' || title == 'Esportes' || title == 'Infantil') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveTvScreen(
            initialGroup: title == 'Favoritos'
                ? 'Favoritos'
                : (title == 'Esportes' ? 'Esportes' : (title == 'Infantil' ? 'Infantil' : 'Todos')),
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title está sendo preparado para uma próxima versão.')),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: RochaColors.background,
        body: SafeArea(
          child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: RochaColors.background.withValues(alpha: .96),
                title: const RochaBrand(compact: true),
                actions: [
                  IconButton(
                    tooltip: 'Transmitir',
                    onPressed: () => openSection(context, 'TV ao Vivo'),
                    icon: const Icon(Icons.cast_rounded, color: RochaColors.gold),
                  ),
                  const SizedBox(width: 6),
                ],
              ),
              SliverToBoxAdapter(
                child: _CosmicHero(onWatch: () => openSection(context, 'TV ao Vivo')),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 28, 20, 14),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, color: RochaColors.gold, size: 19),
                      SizedBox(width: 9),
                      Text('Explore o Rocha+',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid.builder(
                  itemCount: sections.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    mainAxisExtent: 132,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
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
            ],
          ),
          ),
        ),
      );
}

class RochaBrand extends StatelessWidget {
  final bool compact;
  const RochaBrand({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 32 : 46,
            height: compact ? 32 : 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [RochaColors.cosmicPurple, RochaColors.rock],
              ),
              border: Border.all(color: RochaColors.gold.withValues(alpha: .8)),
              boxShadow: [
                BoxShadow(
                  color: RochaColors.cosmicPurple.withValues(alpha: .45),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Icon(Icons.play_arrow_rounded,
                color: RochaColors.playGreen, size: compact ? 22 : 30),
          ),
          const SizedBox(width: 10),
          Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: compact ? 24 : 38,
                fontWeight: FontWeight.w900,
                letterSpacing: .4,
              ),
              children: const [
                TextSpan(text: 'ROCHA', style: TextStyle(color: RochaColors.silver)),
                TextSpan(text: '+', style: TextStyle(color: RochaColors.gold)),
              ],
            ),
          ),
        ],
      );
}

class _CosmicHero extends StatelessWidget {
  final VoidCallback onWatch;
  const _CosmicHero({required this.onWatch});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 600;
          final television = constraints.maxWidth >= 900;
          final contentWidth = television ? 1280.0 : double.infinity;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentWidth),
              child: Container(
            margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            constraints: BoxConstraints(minHeight: narrow ? 360 : (television ? 390 : 330)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: RochaColors.gold.withValues(alpha: .28)),
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xFF32105C),
                  RochaColors.cosmicPurple,
                  Color(0xFF0B0712),
                  RochaColors.background,
                ],
                stops: [0, .32, .7, 1],
              ),
              boxShadow: [
                BoxShadow(
                  color: RochaColors.cosmicPurple.withValues(alpha: .28),
                  blurRadius: 34,
                  spreadRadius: 2,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned(
                  right: narrow ? -55 : (television ? 90 : 40),
                  top: narrow ? 24 : (television ? 55 : 35),
                  child: const _CrownedPlanet(),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(26, narrow ? 185 : 42, 26, 30),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ROCHA+ ORIGINAL',
                          style: TextStyle(
                            color: RochaColors.gold,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.2,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          'ENTRETENIMENTO\nSEM LIMITES',
                          style: TextStyle(
                            fontSize: narrow ? 30 : (television ? 52 : 42),
                            height: .98,
                            fontWeight: FontWeight.w900,
                            color: RochaColors.silver,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'TV e transmissões públicas ou autorizadas em uma experiência feita para celular e televisão.',
                          style: TextStyle(color: Colors.white70, height: 1.35),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: onWatch,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('ASSISTIR AGORA'),
                          autofocus: !narrow,
                          style: FilledButton.styleFrom(
                            minimumSize: Size(narrow ? 0 : 190, narrow ? 48 : 56),
                            backgroundColor: RochaColors.playGreen,
                            foregroundColor: Colors.black,
                            textStyle: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
              ),
            ),
          );
        },
      );
}

class _CrownedPlanet extends StatelessWidget {
  const _CrownedPlanet();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        height: 180,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: -.22,
              child: Container(
                width: 205,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: RochaColors.gold, width: 3),
                ),
              ),
            ),
            Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-.35, -.45),
                  colors: [Color(0xFF4B4752), RochaColors.rock, Color(0xFF09090C)],
                ),
                border: Border.all(color: Colors.white24),
                boxShadow: [
                  BoxShadow(
                    color: RochaColors.cosmicPurple.withValues(alpha: .75),
                    blurRadius: 32,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: RochaColors.playGreen, size: 64),
            ),
            const Positioned(
              top: 0,
              child: Icon(Icons.workspace_premium_rounded,
                  color: RochaColors.gold, size: 54),
            ),
          ],
        ),
      );
}

class _SectionCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const _SectionCard({required this.title, required this.icon, required this.onTap});

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  bool focused = false;

  @override
  Widget build(BuildContext context) => AnimatedScale(
        scale: focused ? 1.035 : 1,
        duration: const Duration(milliseconds: 120),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF191421), RochaColors.surface],
            ),
            border: Border.all(
              color: focused
                  ? RochaColors.gold
                  : RochaColors.cosmicPurple.withValues(alpha: .5),
              width: focused ? 1.8 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            autofocus: widget.title == 'TV ao Vivo',
            focusColor: RochaColors.cosmicPurple.withValues(alpha: .35),
            onFocusChange: (value) => setState(() => focused = value),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(widget.icon, size: 32, color: RochaColors.gold),
                  const Spacer(),
                  Text(widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  const Text('Abrir',
                      style: TextStyle(color: RochaColors.gold, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      );
}
