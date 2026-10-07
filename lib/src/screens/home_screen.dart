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
  const HomeScreen({super.key, this.repository});
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
      const SizedBox(height: 174, child: RochaArtwork(
        region: Rect.fromLTRB(.014, .01, .15, .254), fit: BoxFit.contain)),
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
          SliverToBoxAdapter(child: _OfficialHero(wide: wide,
            onWatch: () => _open('TV ao Vivo'))),
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
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220, mainAxisExtent: 120,
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
    child: const RochaArtwork(region: Rect.fromLTRB(.225, .15, .525, .241), fit: BoxFit.contain));
}

class _OfficialHero extends StatelessWidget {
  final bool wide;
  final VoidCallback onWatch;
  const _OfficialHero({required this.wide, required this.onWatch});
  @override
  Widget build(BuildContext context) {
    final copy = Padding(padding: EdgeInsets.all(wide ? 34 : 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, children: [
          const RochaBrand(),
          const SizedBox(height: 10),
          const Text('ENTRETENIMENTO\nSEM LIMITES', style: TextStyle(
            fontSize: 16, height: 1.5, letterSpacing: 3, color: RochaColors.silver)),
          const SizedBox(height: 24),
          Container(decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Color(0x55FFC43D), blurRadius: 22)]),
            child: OutlinedButton.icon(
              autofocus: true, onPressed: onWatch,
              style: OutlinedButton.styleFrom(
                foregroundColor: RochaColors.gold, backgroundColor: const Color(0xCC050405),
                side: const BorderSide(color: RochaColors.gold, width: 2),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              icon: const Icon(Icons.play_arrow),
              label: const Text('ASSISTIR AGORA', style: TextStyle(fontWeight: FontWeight.w900))),
          ),
        ],
      ),
    );
    return Container(
      key: const ValueKey('official-hero'),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(colors: [
          Color(0xFF050409), Color(0xFF210937), Color(0xFF08060C)])),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(builder: (context, constraints) => constraints.maxWidth >= 1000 ? SizedBox(height: 360, child: Row(children: [
        Expanded(flex: 4, child: copy),
        const Expanded(flex: 6, child: RochaArtwork(fit: BoxFit.contain)),
      ])) : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 240, child: RochaArtwork(fit: BoxFit.contain)),
        copy,
      ])),
    );
  }
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
