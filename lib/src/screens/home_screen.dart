import 'package:flutter/material.dart';

import '../live/channel.dart';
import '../live/channel_repository.dart';
import '../theme/rocha_theme.dart';
import 'live_tv_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int mobileTab = 0;
  late final Future<List<Channel>> _livePreview;

  @override
  void initState() {
    super.initState();
    _livePreview = ChannelRepository().loadBrazilPublicDirectory();
  }

  static const sections = [
    ('TV ao Vivo', Icons.live_tv_outlined),
    ('Filmes', Icons.movie_outlined),
    ('Séries', Icons.tv_outlined),
    ('Infantil', Icons.child_care_outlined),
    ('Esportes', Icons.sports_soccer),
    ('Documentários', Icons.public),
    ('Regionais', Icons.location_city_outlined),
    ('Favoritos', Icons.favorite_border),
  ];

  void openSection(String title) {
    if (title == 'TV ao Vivo' || title == 'Favoritos') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveTvScreen(
            initialGroup: title == 'Favoritos' ? 'Favoritos' : 'Todos',
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title entra na próxima etapa.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tv = constraints.maxWidth >= 900;
        return Scaffold(
          bottomNavigationBar: tv
              ? null
              : NavigationBar(
                  selectedIndex: mobileTab,
                  onDestinationSelected: (index) {
                    setState(() => mobileTab = index);
                    if (index == 1 || index == 2) {
                      openSection('TV ao Vivo');
                    }
                    if (index == 3) openSection('Favoritos');
                    if (index == 4) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'O perfil será ativado junto com o login oficial Google e Apple.',
                          ),
                        ),
                      );
                    }
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Início',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.sensors_outlined),
                      selectedIcon: Icon(Icons.sensors),
                      label: 'Ao vivo',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.live_tv_outlined),
                      selectedIcon: Icon(Icons.live_tv),
                      label: 'Canais',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.favorite_border),
                      selectedIcon: Icon(Icons.favorite),
                      label: 'Favoritos',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: 'Perfil',
                    ),
                  ],
                ),
          body: SafeArea(
            child: Column(
              children: [
                _ResponsiveHeader(
                  tv: tv,
                  onOpen: openSection,
                ),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          tv ? 36 : 16,
                          tv ? 10 : 6,
                          tv ? 36 : 16,
                          0,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: _Hero(
                            tv: tv,
                            onWatch: () => openSection('TV ao Vivo'),
                          ),
                        ),
                      ),
                      _SectionTitle(
                        title: 'Acesso rápido',
                        tv: tv,
                        onSeeAll: () => openSection('TV ao Vivo'),
                      ),
                      SliverToBoxAdapter(
                        child: FutureBuilder<List<Channel>>(
                          future: _livePreview,
                          builder: (context, snapshot) {
                            final channels = snapshot.data ?? const <Channel>[];
                            final items = channels
                                .take(6)
                                .map(
                                  (channel) => _PreviewItem(
                                    channel.name,
                                    Icons.live_tv_outlined,
                                    channel.group,
                                    logo: channel.logo,
                                  ),
                                )
                                .toList(growable: false);

                            if (items.isEmpty) {
                              return _PreviewRail(
                                tv: tv,
                                items: const [
                                  _PreviewItem(
                                    'TV ao Vivo',
                                    Icons.live_tv_outlined,
                                    'Abrir canais',
                                  ),
                                  _PreviewItem(
                                    'Favoritos',
                                    Icons.favorite_border,
                                    'Sua seleção',
                                  ),
                                ],
                                onTap: (_) => openSection('TV ao Vivo'),
                              );
                            }

                            return _PreviewRail(
                              tv: tv,
                              items: items,
                              onTap: (_) => openSection('TV ao Vivo'),
                            );
                          },
                        ),
                      ),
                      _SectionTitle(
                        title: tv ? 'Explore o Rocha+' : 'Categorias',
                        tv: tv,
                      ),
                      SliverPadding(
                        padding: EdgeInsets.symmetric(horizontal: tv ? 36 : 16),
                        sliver: SliverGrid.builder(
                          itemCount: sections.length,
                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: tv ? 310 : 190,
                            mainAxisExtent: tv ? 126 : 112,
                            crossAxisSpacing: tv ? 18 : 12,
                            mainAxisSpacing: tv ? 18 : 12,
                          ),
                          itemBuilder: (_, index) {
                            final item = sections[index];
                            return _SectionCard(
                              title: item.$1,
                              icon: item.$2,
                              autofocus: index == 0,
                              onTap: () => openSection(item.$1),
                            );
                          },
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 36)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ResponsiveHeader extends StatelessWidget {
  final bool tv;
  final ValueChanged<String> onOpen;

  const _ResponsiveHeader({
    required this.tv,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final logo = const _RochaWordmark();
    if (!tv) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 10, 8),
        child: Row(
          children: [
            logo,
            const Spacer(),
            IconButton(
              tooltip: 'Transmitir',
              onPressed: () => onOpen('TV ao Vivo'),
              icon: const Icon(Icons.cast, color: RochaColors.playGreen),
            ),
            IconButton(
              tooltip: 'Abrir canais',
              onPressed: () => onOpen('TV ao Vivo'),
              icon: const Icon(Icons.live_tv_outlined),
            ),
          ],
        ),
      );
    }

    const nav = [
      ('Início', Icons.home_outlined),
      ('Ao vivo', Icons.sensors),
      ('Favoritos', Icons.favorite_border),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 14, 36, 10),
      child: Row(
        children: [
          logo,
          const SizedBox(width: 42),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < nav.length; i++)
                  _TopNavButton(
                    label: nav[i].$1,
                    icon: nav[i].$2,
                    selected: i == 0,
                    autofocus: i == 0,
                    onTap: () {
                      if (nav[i].$1 == 'Ao vivo') onOpen('TV ao Vivo');
                      if (nav[i].$1 == 'Favoritos') onOpen('Favoritos');
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          const Icon(Icons.wifi, color: RochaColors.playGreen),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final bool tv;
  final VoidCallback onWatch;

  const _Hero({
    required this.tv,
    required this.onWatch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: tv ? 340 : 310,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tv ? 24 : 22),
        border: Border.all(color: const Color(0xFF27506B)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF070B12),
            RochaColors.cosmicBlue,
            Color(0xFF1B0A27),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2216F34A),
            blurRadius: 30,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: tv ? 24 : -28,
            top: tv ? -28 : -10,
            bottom: tv ? -30 : 0,
            width: tv ? 520 : 260,
            child: Opacity(
              opacity: tv ? .95 : .62,
              child: Image.asset(
                'branding/rocha_plus_icon.webp',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  RochaColors.background.withValues(alpha: .98),
                  RochaColors.background.withValues(alpha: tv ? .72 : .88),
                  Colors.transparent,
                ],
                stops: tv ? const [0, .43, .78] : const [0, .58, 1],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(tv ? 34 : 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: tv ? 650 : 310),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ENTRETENIMENTO SEM LIMITES',
                      style: TextStyle(
                        color: RochaColors.silver.withValues(alpha: .76),
                        letterSpacing: tv ? 4 : 2.1,
                        fontSize: tv ? 15 : 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: tv ? 12 : 8),
                    _RochaWordmark(fontSize: tv ? 58 : 40),
                    SizedBox(height: tv ? 14 : 10),
                    Text(
                      'Canais ao vivo e entretenimento em uma experiência rápida, elegante e pronta para celular e TV.',
                      maxLines: tv ? 2 : 3,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: tv ? 19 : 14,
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: tv ? 24 : 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        _GlowButton(
                          autofocus: tv,
                          onPressed: onWatch,
                          icon: Icons.play_arrow_rounded,
                          label: 'Assistir agora',
                        ),

                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final bool tv;
  final VoidCallback? onSeeAll;

  const _SectionTitle({
    required this.title,
    required this.tv,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) => SliverPadding(
        padding: EdgeInsets.fromLTRB(
          tv ? 36 : 16,
          tv ? 28 : 22,
          tv ? 36 : 16,
          12,
        ),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: tv ? 28 : 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              if (onSeeAll != null)
                TextButton.icon(
                  onPressed: onSeeAll,
                  label: const Text('Ver todos'),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.chevron_right),
                ),
            ],
          ),
        ),
      );
}

class _PreviewItem {
  final String title;
  final IconData icon;
  final String subtitle;
  final String? logo;

  const _PreviewItem(
    this.title,
    this.icon,
    this.subtitle, {
    this.logo,
  });
}

class _PreviewRail extends StatelessWidget {
  final bool tv;
  final List<_PreviewItem> items;
  final ValueChanged<int> onTap;

  const _PreviewRail({
    required this.tv,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = tv ? 280.0 : 170.0;
    final height = tv ? 155.0 : 120.0;
    return SizedBox(
      height: height,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: tv ? 36 : 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(width: tv ? 14 : 10),
        itemBuilder: (_, index) {
          final item = items[index];
          return _FocusableCard(
            width: width,
            autofocus: tv && index == 0,
            onTap: () => onTap(index),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0D2435),
                        Color(0xFF151221),
                        Color(0xFF07080C),
                      ],
                    ),
                  ),
                ),
                if (item.logo != null && item.logo!.isNotEmpty)
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        tv ? 24 : 18,
                        tv ? 14 : 12,
                        tv ? 24 : 18,
                        tv ? 48 : 40,
                      ),
                      child: Image.network(
                        item.logo!,
                        fit: BoxFit.contain,
                        cacheWidth: tv ? 360 : 240,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, __, ___) => Icon(
                          item.icon,
                          size: tv ? 52 : 38,
                          color: RochaColors.playGreen.withValues(alpha: .82),
                        ),
                      ),
                    ),
                  )
                else
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Icon(
                      item.icon,
                      size: tv ? 52 : 38,
                      color: RochaColors.playGreen.withValues(alpha: .82),
                    ),
                  ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: tv ? 19 : 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        item.subtitle,
                        style: const TextStyle(color: RochaColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool autofocus;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) => _FocusableCard(
        autofocus: autofocus,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 34, color: RochaColors.playGreen),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
}

class _FocusableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool autofocus;
  final double? width;

  const _FocusableCard({
    required this.child,
    required this.onTap,
    this.autofocus = false,
    this.width,
  });

  @override
  State<_FocusableCard> createState() => _FocusableCardState();
}

class _FocusableCardState extends State<_FocusableCard> {
  bool focused = false;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.width,
        child: AnimatedScale(
          scale: focused ? 1.025 : 1,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: RochaColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: focused ? RochaColors.playGreen : RochaColors.border,
                width: focused ? 2 : 1,
              ),
              boxShadow: focused
                  ? const [
                      BoxShadow(
                        color: Color(0x5516F34A),
                        blurRadius: 22,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: InkWell(
              autofocus: widget.autofocus,
              onFocusChange: (value) => setState(() => focused = value),
              onTap: widget.onTap,
              child: widget.child,
            ),
          ),
        ),
      );
}

class _TopNavButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool autofocus;
  final VoidCallback onTap;

  const _TopNavButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.autofocus,
    required this.onTap,
  });

  @override
  State<_TopNavButton> createState() => _TopNavButtonState();
}

class _TopNavButtonState extends State<_TopNavButton> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || focused;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: active ? RochaColors.playGreenSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? RochaColors.playGreen : Colors.transparent,
        ),
        boxShadow: focused
            ? const [BoxShadow(color: Color(0x4416F34A), blurRadius: 18)]
            : null,
      ),
      child: InkWell(
        autofocus: widget.autofocus,
        borderRadius: BorderRadius.circular(14),
        onFocusChange: (value) => setState(() => focused = value),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 21),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final bool autofocus;

  const _GlowButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Color(0x5516F34A), blurRadius: 22),
          ],
        ),
        child: FilledButton.icon(
          autofocus: autofocus,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF073A1B),
            foregroundColor: Colors.white,
            side: const BorderSide(color: RochaColors.playGreen, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      );
}

class _RochaWordmark extends StatelessWidget {
  final double fontSize;

  const _RochaWordmark({this.fontSize = 32});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: fontSize * .02),
            child: Icon(
              Icons.workspace_premium,
              size: fontSize * .42,
              color: RochaColors.gold,
            ),
          ),
          Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                height: .95,
              ),
              children: const [
                TextSpan(
                  text: 'Rocha',
                  style: TextStyle(color: RochaColors.gold),
                ),
                TextSpan(
                  text: '+',
                  style: TextStyle(color: RochaColors.playGreen),
                ),
              ],
            ),
          ),
        ],
      );
}
