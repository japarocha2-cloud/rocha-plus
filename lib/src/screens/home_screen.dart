import 'package:flutter/material.dart';
import '../theme/rocha_theme.dart';
import '../widgets/rocha_artwork.dart';
import '../widgets/rocha_channel_card.dart';
import '../live/channel.dart';
import '../live/channel_repository.dart';
import '../live/favorites_repository.dart';
import 'live_tv_screen.dart';
import 'news_screen.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  final ChannelRepository? repository;
  final Future<void> Function()? onSignOut;
  const HomeScreen({super.key, this.repository, this.onSignOut});
  static const sections = [
    ('TV ao Vivo', Icons.live_tv_outlined),
    ('Esportes', Icons.sports_soccer_outlined),
    ('Notícias', Icons.newspaper_outlined),
    ('Infantil', Icons.toys_outlined),
    ('Favoritos', Icons.favorite_border),
  ];
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final repository = widget.repository ?? ChannelRepository();
  final favoritesRepository = FavoritesRepository();
  List<Channel> channels = [];
  Set<String> favorites = {};
  bool loading = true;
  bool failed = false;
  bool signingOut = false;
  Future<void> _signOut() async {
    if (signingOut || widget.onSignOut == null) return;
    setState(() => signingOut = true);
    try {
      await widget.onSignOut!();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível sair. Tente novamente.')));
      }
    } finally {
      if (mounted) setState(() => signingOut = false);
    }
  }
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final result = await Future.wait([
        repository.loadBrazilPublicDirectory(), favoritesRepository.load(),
      ]);
      if (mounted) { setState(() {
        channels = result[0] as List<Channel>; favorites = result[1] as Set<String>;
        loading = false; failed = false;
      }); }
    } catch (_) {
      if (mounted) setState(() { loading = false; failed = true; });
    }
  }
  Future<void> _favorite(Channel channel) async {
    final next = {...favorites};
    next.contains(channel.url) ? next.remove(channel.url) : next.add(channel.url);
    try {
      await favoritesRepository.save(next);
      if (mounted) setState(() => favorites = next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível salvar o favorito.')));
      }
    }
  }
  Future<void> _open(String title) async {
    final group = switch (title) {
      'Favoritos' => 'Favoritos', 'Esportes' => 'Esportes',
      'Infantil' => 'Infantil', _ => 'TV aberta',
    };
    await Navigator.push(context, MaterialPageRoute(builder: (_) =>
      title == 'Notícias' ? const NewsScreen() :
        LiveTvScreen(initialGroup: group, repository: widget.repository)));
    if (mounted) { _load(); }
  }
  Widget _menu({bool drawer = false}) => Container(
    key: const ValueKey('official-sidebar'),
    width: 218,
    decoration: const BoxDecoration(
      color: Color(0xFF07060C),
      border: Border(right: BorderSide(color: Color(0xFF272032)))),
    child: ListView(padding: const EdgeInsets.symmetric(vertical: 12), children: [
      if (widget.onSignOut != null) _NavItem(label: signingOut ? 'Saindo...' : 'Sair da conta', icon: Icons.logout,
        onTap: _signOut),
      const SizedBox(height: 174, child: Center(child: RochaBrand())),
      _NavItem(label: 'Início', icon: Icons.home_outlined, selected: true,
        onTap: () { if (drawer) Navigator.pop(context); }),
      ...HomeScreen.sections.map((item) => _NavItem(
        label: item.$1 == 'Favoritos' ? 'Minha Lista' : item.$1, icon: item.$2,
        onTap: () { if (drawer) Navigator.pop(context); _open(item.$1); })),
    ]),
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final wide = constraints.maxWidth >= 900;
    final live = channels.where((c) => c.group == 'TV aberta' &&
      !repository.isBlocked(c) && !repository.isQuarantined(c.url)).take(10).toList();
    final saved = channels.where((c) => favorites.contains(c.url) &&
      !repository.isBlocked(c) && !repository.isQuarantined(c.url)).take(10).toList();
    return Scaffold(
      drawer: wide ? null : Drawer(backgroundColor: RochaColors.background,
        child: SafeArea(child: _menu(drawer: true))),
      body: SafeArea(child: Row(children: [
        if (wide) _menu(),
        Expanded(child: CustomScrollView(key: const ValueKey('home-scroll'), slivers: [
          SliverToBoxAdapter(child: Padding(
            padding: EdgeInsets.fromLTRB(wide ? 28 : 12, 12, wide ? 28 : 12, 8),
            child: Row(children: [
              if (!wide) Builder(builder: (context) => IconButton(
                tooltip: 'Abrir menu', onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu))),
              Expanded(child: InkWell(
                key: const ValueKey('home-search'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => LiveTvScreen(repository: widget.repository))),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFF15101F), borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF766A86))),
                  child: const Row(children: [
                    Icon(Icons.search, color: Colors.white70), SizedBox(width: 10),
                    Expanded(child: Text('Buscar canais…',
                      style: TextStyle(color: Colors.white70))),
                  ]),
                ),
              )),
              IconButton(tooltip: 'Abrir canais para transmitir',
                onPressed: () => _open('TV ao Vivo'),
                icon: const Icon(Icons.cast, color: RochaColors.gold)),
            ]),
          )),
          SliverToBoxAdapter(child: _HomeCardCarousel(wide: wide,
            onOpen: _open)),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
            child: Row(children: [
              const Expanded(child: Text('Explore o Rocha+', style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800))),
              TextButton(onPressed: () => _open('TV ao Vivo'), child: const Text('Ver todos')),
            ]),
          )),
          SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 22),
            sliver: SliverGrid.builder(itemCount: HomeScreen.sections.length,
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: wide ? 300 : 190, mainAxisExtent: wide ? 150 : 120,
                crossAxisSpacing: 12, mainAxisSpacing: 12),
              itemBuilder: (_, index) {
                final item = HomeScreen.sections[index];
                return _CategoryCard(key: ValueKey('category-${item.$1}'),
                  label: item.$1, icon: item.$2, onTap: () => _open(item.$1));
              })),
          if (saved.isNotEmpty) SliverToBoxAdapter(child:
            _row('Minha Lista', saved, () => _open('Favoritos'))),
          SliverToBoxAdapter(child: _row('Canais ao vivo', live, () => _open('TV ao Vivo'))),
          if (loading) const SliverToBoxAdapter(child: Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator()))),
          if (failed) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(24),
            child: OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh),
              label: const Text('Carregar canais')))),
          if (!loading && !failed && live.isEmpty) const SliverToBoxAdapter(
            child: Padding(padding: EdgeInsets.all(24),
              child: Text('Nenhum canal aberto disponível no catálogo neste momento.',
                style: TextStyle(color: Colors.white54)))),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ])),
      ])),
    );
  });
  Widget _row(String title, List<Channel> items, VoidCallback onAll) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(22, 20, 22, 10),
        child: Row(children: [
          Expanded(child: Text(title, style: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.w800))),
          TextButton(onPressed: onAll, child: const Text('Ver todos')),
        ])),
      if (items.isNotEmpty) SizedBox(height: 230, child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 22), scrollDirection: Axis.horizontal,
        itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(width: 180, child: RochaChannelCard(
          channel: items[i], favorite: favorites.contains(items[i].url),
          onFavorite: () => _favorite(items[i]),
          onOpen: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(channel: items[i])));
            if (mounted) _load();
          })),
      )),
    ],
  );
}

class RochaBrand extends StatelessWidget {
  final bool compact;
  const RochaBrand({super.key, this.compact = false});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: compact ? 150 : 230, height: compact ? 50 : 76,
    child: const RochaWordmark());
}

class _HomeCardCarousel extends StatefulWidget {
  final bool wide;
  final Future<void> Function(String title) onOpen;
  const _HomeCardCarousel({required this.wide, required this.onOpen});
  @override
  State<_HomeCardCarousel> createState() => _HomeCardCarouselState();
}

class _HomeCardCarouselState extends State<_HomeCardCarousel> {
  late final PageController controller;
  int selected = 1;
  static const cards = [
    ('Esportes', Icons.sports_soccer_outlined, 'Esportes'),
    ('TV ao Vivo', Icons.live_tv_outlined, 'TV ao Vivo'),
    ('Infantil', Icons.toys_outlined, 'Infantil'),
    ('Notícias', Icons.newspaper_outlined, 'Notícias'),
  ];

  @override
  void initState() {
    super.initState();
    controller = PageController(
      initialPage: selected,
      viewportFraction: widget.wide ? .56 : .70,
    );
  }

  @override
  void dispose() { controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final height = widget.wide ? 300.0 : 300.0;
    return Column(children: [
      SizedBox(
        key: const ValueKey('home-card-carousel'),
        height: height,
        child: PageView.builder(
          controller: controller,
          itemCount: cards.length,
          onPageChanged: (index) => setState(() => selected = index),
          itemBuilder: (context, index) {
            final item = cards[index];
            return AnimatedScale(
              duration: const Duration(milliseconds: 180),
              scale: selected == index ? 1 : (widget.wide ? .86 : .90),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.wide ? 10 : 6, vertical: 10),
                child: _HomeFeatureCard(
                  selected: selected == index,
                  label: item.$1,
                  icon: item.$2,
                  onTap: () => widget.onOpen(item.$3),
                ),
              ),
            );
          },
        ),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(cards.length, (index) => AnimatedContainer(
          key: ValueKey('carousel-dot-$index'),
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: selected == index ? 20 : 7, height: 7,
          decoration: BoxDecoration(
            color: selected == index ? RochaColors.gold : Colors.white24,
            borderRadius: BorderRadius.circular(20),
          ),
        ))),
    ]);
  }
}

class _HomeFeatureCard extends StatefulWidget {
  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _HomeFeatureCard({required this.selected, required this.label,
    required this.icon, required this.onTap});
  @override
  State<_HomeFeatureCard> createState() => _HomeFeatureCardState();
}

class _HomeFeatureCardState extends State<_HomeFeatureCard> {
  bool focused = false;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF050409), Color(0xFF210937), Color(0xFF08060C)]),
      border: Border.all(
        color: widget.selected || focused ? RochaColors.gold : const Color(0xFF4A286A),
        width: widget.selected || focused ? 2 : 1),
      boxShadow: focused ? const [BoxShadow(color: Color(0x55FFC43D), blurRadius: 20)] : const [],
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      autofocus: widget.selected,
      onFocusChange: (value) => setState(() => focused = value),
      onTap: widget.onTap,
      child: Stack(children: [
        Positioned.fill(child: Opacity(
          opacity: .42,
          child: const RochaArtwork(fit: BoxFit.cover),
        )),
        const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xE6050409)]),
        ))),
        Positioned(left: 20, right: 20, bottom: 22,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Icon(widget.icon, color: RochaColors.gold, size: 30),
            const SizedBox(width: 12),
            Expanded(child: Text(widget.label, style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900))),
            const Icon(Icons.chevron_right, color: RochaColors.silver),
          ])),
      ]),
    ),
  );
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;
  const _NavItem({required this.label, required this.icon,
    required this.onTap, this.selected = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    child: Container(decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      gradient: selected ? const LinearGradient(colors: [Color(0xFF8518EC), Color(0xFF351069)]) : null),
      child: Material(type: MaterialType.transparency, child: ListTile(leading: Icon(icon, color: Colors.white70),
        title: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        onTap: onTap))),
  );
}

class _CategoryCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _CategoryCard({super.key, required this.label, required this.icon, required this.onTap});
  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}
class _CategoryCardState extends State<_CategoryCard> {
  bool focused = false;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 130),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF24113D), Color(0xFF0B0A11)]),
      border: Border.all(color: focused ? RochaColors.gold : const Color(0xFF4A286A),
        width: focused ? 2 : 1),
      boxShadow: focused ? const [BoxShadow(color: Color(0x555A20A8), blurRadius: 18)] : []),
    child: InkWell(onTap: widget.onTap, borderRadius: BorderRadius.circular(14),
      onFocusChange: (v) => setState(() => focused = v),
      child: Padding(padding: const EdgeInsets.all(15), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(widget.icon, color: RochaColors.gold, size: 28),
          const Spacer(),
          Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        ]))),
  );
}
