import 'dart:async';
import '../news/news_carousel_card.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import '../tv/roku_pairing_service.dart';
import '../tv/roku_pairing_screen.dart';
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
import 'subscription_screen.dart';
import '../ads/ganhebr_destination.dart';

class HomeScreen extends StatefulWidget {
  final ChannelRepository? repository;
  final Future<void> Function()? onSignOut;
  final bool previewOnly;
  final String? accountId;
  final WidgetBuilder? subscriptionBuilder;
  const HomeScreen({super.key, this.repository, this.onSignOut,
    this.previewOnly = false, this.accountId, this.subscriptionBuilder});
  static const sections = [
    ('TV ao Vivo', Icons.live_tv_outlined),
    ('Esportes', Icons.sports_soccer_outlined),
    ('Infantil', Icons.toys_outlined),
    ('Notícias', Icons.newspaper_outlined),
    ('Favoritos', Icons.favorite_border),
  ];
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final repository = widget.repository ?? ChannelRepository();
  late final favoritesRepository = FavoritesRepository(accountId: widget.accountId);
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
  void initState() {
    super.initState();
    if (widget.previewOnly) {
      loading = false;
    } else {
      _load();
    }
  }
  Future<void> _load() async {
    if (widget.previewOnly) return;
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
    if (widget.previewOnly) return;
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
    if (title == 'Assinaturas') {
      await Navigator.push(context, MaterialPageRoute(
        builder: widget.subscriptionBuilder ?? (_) => const SubscriptionScreen()));
      return;
    }
    if (widget.previewOnly) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Prévia do layout: canais, player e transmissão exigem login ativo.')));
      return;
    }
    final group = switch (title) {
      'Favoritos' => 'Favoritos', 'Esportes' => 'Esportes',
      'Infantil' => 'Infantil', _ => 'TV aberta',
    };
    await Navigator.push(context, MaterialPageRoute(builder: (_) =>
      title == 'Notícias' ? NewsScreen(accountId: widget.accountId) :
        LiveTvScreen(initialGroup: group, repository: widget.repository, accountId: widget.accountId)));
    if (mounted) { _load(); }
  }
  Widget _menu({bool drawer = false}) => Container(
    key: const ValueKey('official-sidebar'),
    width: 218,
    decoration: const BoxDecoration(
      color: Color(0xFF07060C),
      border: Border(right: BorderSide(color: Color(0xFF272032)))),
    child: ListView(padding: const EdgeInsets.symmetric(vertical: 12), children: [
      if (widget.onSignOut != null) _NavItem(label: signingOut ? 'Saindo...' :
        (widget.previewOnly ? 'Sair da prévia' : 'Sair da conta'), icon: Icons.logout,
        onTap: _signOut),
      const SizedBox(height: 174, child: Center(child: RochaBrand())),
      _NavItem(label: 'Início', icon: Icons.home_outlined, selected: true,
        onTap: () { if (drawer) Navigator.pop(context); }),
      ...HomeScreen.sections.map((item) => _NavItem(
        label: item.$1 == 'Favoritos' ? 'Minha Lista' : item.$1, icon: item.$2,
        onTap: () { if (drawer) Navigator.pop(context); _open(item.$1); })),
      _NavItem(label: 'Assinaturas', icon: Icons.workspace_premium_outlined,
        onTap: () { if (drawer) Navigator.pop(context); _open('Assinaturas'); }),
    ]),
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    // Resolve parent constraints once. Nested cards receive finite dimensions
    // instead of scheduling more deferred layout callbacks during updates.
    final media = MediaQuery.of(context);
    final wide = constraints.maxWidth >= 900;
    final contentWidth = constraints.maxWidth - media.padding.horizontal - (wide ? 218 : 0);
    final gridWidth = math.max(0.0, contentWidth - 44);
    final columns = wide ? math.max(1, (gridWidth / 232).ceil()) : 2;
    final tileWidth = math.max(0.0, (gridWidth - 12 * (columns - 1)) / columns);
    final tileSize = Size(tileWidth, wide ? 120 : tileWidth / .82);
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
                onTap: () {
                  if (widget.previewOnly) {
                    _open('TV ao Vivo');
                  } else {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => LiveTvScreen(repository: widget.repository, accountId: widget.accountId)));
                  }
                },
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
              if (!widget.previewOnly && RokuPairingService.isConfigured)
                IconButton(tooltip: 'Conectar TV', icon: const Icon(Icons.connected_tv),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
                    RokuPairingScreen(service: RokuPairingService(
                      endpoint: RokuPairingService.configuredEndpoint,
                      tokenProvider: () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) return null;
                        return user.getIdToken();
                      },
                    ))))),
              IconButton(tooltip: 'Abrir canais para transmitir',
                onPressed: () => _open('TV ao Vivo'),
                icon: const Icon(Icons.cast, color: RochaColors.gold)),
            ]),
          )),
          if (widget.previewOnly) const SliverToBoxAdapter(child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('MODO DE PRÉVIA: somente layout. Canais e espelhamento desativados.',
              key: ValueKey('home-preview-notice'),
              style: TextStyle(color: RochaColors.gold, fontWeight: FontWeight.w700)))),
          SliverToBoxAdapter(child: _FeaturedCarousel(
            wide: wide, availableWidth: contentWidth, onOpen: (section) { _open(section); })),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
            child: Row(children: [
              const Expanded(child: Text('Explore o Rocha+', style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800))),
              TextButton(onPressed: () => _open('TV ao Vivo'), child: const Text('Ver todos')),
            ]),
          )),
          SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 22),
            sliver: SliverGrid.builder(itemCount: wide ? HomeScreen.sections.length : 4,
              gridDelegate: wide
                ? const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220, mainAxisExtent: 120,
                    crossAxisSpacing: 12, mainAxisSpacing: 12)
                : const SliverGridDelegateWithFixedCrossAxisCount(
                    // Two columns keep the approved portrait covers at their native ratio.
                    crossAxisCount: 2, mainAxisSpacing: 12,
                    crossAxisSpacing: 12, childAspectRatio: .82),
              itemBuilder: (_, index) {
                final item = HomeScreen.sections[index];
                return _CategoryCard(key: ValueKey('category-${item.$1}'),
                  label: item.$1, icon: item.$2, mobileArtwork: !wide, tileSize: tileSize,
                  onTap: () => _open(item.$1));
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
          if (!widget.previewOnly && !loading && !failed && live.isEmpty) const SliverToBoxAdapter(
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


/// Navigation-only featured carousel: the approved artwork and palette stay intact.
class _FeaturedCarousel extends StatefulWidget {
  final bool wide;
  final double availableWidth;
  final ValueChanged<String> onOpen;
  const _FeaturedCarousel({required this.wide, required this.availableWidth, required this.onOpen});

  @override
  State<_FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<_FeaturedCarousel>
    with WidgetsBindingObserver {
  static const autoAdvanceInterval = Duration(seconds: 6);
  static const transitionDuration = Duration(milliseconds: 400);
  static const newsEnabled = bool.fromEnvironment('ROCHA_NEWS_CAROUSEL');
  int get initialPage => newsEnabled && !widget.wide ? 3000 : 3001;

  late final PageController controller;
  Timer? _autoTimer;
  late int currentPage;
  int selected = 1;
  bool _dragging = false;
  bool _appActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    currentPage = initialPage;
    selected = initialPage % 3;
    controller = PageController(initialPage: initialPage, viewportFraction: .84);
    _restartAuto();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    if (_appActive) {
      _restartAuto();
    } else {
      _autoTimer?.cancel();
    }
  }

  void _restartAuto() {
    _autoTimer?.cancel();
    if (!_appActive || _dragging) return;
    _autoTimer = Timer.periodic(autoAdvanceInterval, (_) {
      if (!mounted || !controller.hasClients) return;
      _move(1, automatic: true);
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  void _move(int direction, {bool automatic = false}) {
    if (!controller.hasClients || _dragging) return;
    if (!automatic) _restartAuto();
    controller.animateToPage(currentPage + direction,
      duration: transitionDuration, curve: Curves.easeInOutCubic);
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: EdgeInsets.fromLTRB(widget.wide ? 24 : 14, 0,
      widget.wide ? 24 : 14, 8), child: Row(children: [
      const Expanded(child: Text('Destaques', style: TextStyle(
        fontSize: 17, fontWeight: FontWeight.w800))),
      IconButton(tooltip: 'Destaque anterior',
        onPressed: () => _move(-1), icon: const Icon(Icons.chevron_left)),
      IconButton(tooltip: 'Próximo destaque',
        onPressed: () => _move(1), icon: const Icon(Icons.chevron_right)),
    ])),
    SizedBox(
      // Each phone page is 84% of the viewport, minus its two 5px gutters.
      // Match that actual card width to a landscape 16:9 advertising slot.
      height: widget.wide ? 304 : math.max(0.0, (widget.availableWidth * .84 - 10) * 9 / 16),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification &&
              notification.dragDetails != null) {
            _dragging = true;
            _autoTimer?.cancel();
          } else if (notification is ScrollEndNotification && _dragging) {
            _dragging = false;
            _restartAuto();
          }
          return false;
        },
        child: PageView.builder(
          key: const ValueKey('home-featured-carousel'),
          controller: controller,
          onPageChanged: (value) => setState(() {
            currentPage = value;
            selected = value % 3;
          }),
          itemBuilder: (context, page) => AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.fromLTRB(5, selected == page % 3 ? 0 : 20,
              5, selected == page % 3 ? 0 : 20),
            child: widget.wide ? switch (page % 3) {
              0 => _FeatureCategory(key: const ValueKey('feature-sports'),
                icon: Icons.sports_soccer_outlined, label: 'Esportes ao vivo',
                onTap: () => widget.onOpen('Esportes')),
              1 => _OfficialHero(wide: true,
                onWatch: () => widget.onOpen('TV ao Vivo')),
              _ => _FeatureCategory(key: const ValueKey('feature-kids'),
                icon: Icons.toys_outlined, label: 'Espaço infantil',
                onTap: () => widget.onOpen('Infantil')),
            } : switch (page % 3) {
              0 => newsEnabled
                  ? const NewsCarouselCard(key: ValueKey('sponsor-slot-1'))
                  : const _BauTestBanner(key: ValueKey('sponsor-slot-1')),
              1 => newsEnabled
                  ? const _BauTestBanner(key: ValueKey('sponsor-slot-2'))
                  : _SponsoredPlaceholder(
                key: const ValueKey('sponsor-slot-2'),
                cardWidth: widget.availableWidth * .84 - 10,
                artwork: 'branding/ads/publicidade_jornal.png',
                title: 'Publicidade Rocha+', icon: Icons.stars_outlined),
              _ => _SponsoredPlaceholder(
                key: const ValueKey('sponsor-slot-3'),
                cardWidth: widget.availableWidth * .84 - 10,
                title: 'Divulgue seu negócio', icon: Icons.storefront_outlined),
            },
          ),
        ),
      )),
  ]);
}


/// Mobile-only test banner, displayed only in the phone carousel.
class _BauTestBanner extends StatelessWidget {
  const _BauTestBanner({super.key});

  Future<void> _open(BuildContext context) async {
    final adult = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Publicidade externa'),
        content: const Text('Você confirma que tem 18 anos ou mais e deseja visitar o site do anunciante?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar 18+')),
        ],
      ),
    );
    if (adult != true) return;
    final launched = await openGanheBrBanner(
      verifiedAdult: adult == true, mobilePhoneLayout: true);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Não foi possível abrir a página do anunciante.')));
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF100B22),
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => _open(context),
      child: Container(
        key: const ValueKey('bau-test-banner'),
        decoration: BoxDecoration(
          border: Border.all(color: RochaColors.gold.withValues(alpha: .75)),
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF24113D), Color(0xFF0B0A11)]),
        ),
        child: const SizedBox.expand(
          child: Image(
            image: AssetImage('branding/ads/bau.png'),
            fit: BoxFit.contain,
          ),
        ),
      ),
    ),
  );
}

/// Other advertising placeholders. No external redirect.
class _SponsoredPlaceholder extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? artwork;
  final double cardWidth;
  const _SponsoredPlaceholder({super.key, required this.title, required this.icon,
    this.artwork, required this.cardWidth});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: const LinearGradient(begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF24113D), Color(0xFF0B0A11)]),
      border: Border.all(color: RochaColors.gold.withValues(alpha: .65))),
    clipBehavior: Clip.antiAlias,
    child: Stack(fit: StackFit.expand, children: [
      if (artwork != null) ...[
        Image.asset(artwork!, fit: BoxFit.cover, excludeFromSemantics: true),
        const DecoratedBox(decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x44050409), Color(0xCC050409)]))),
      ],
    // Keep vertical gestures with the Home scroll view. Scale only when
    // enlarged text cannot fit the landscape card's available height.
    Padding(
      padding: const EdgeInsets.all(14),
      child: Center(child: FittedBox(fit: BoxFit.scaleDown,
        child: SizedBox(width: math.max(0.0, cardWidth - 30),
          child: Row(children: [
            Icon(icon, size: 44, color: RochaColors.gold),
            const SizedBox(width: 14),
            Expanded(child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Espaço publicitário',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            ])),
          ])),
      )),
    ),
    ]),
  );
}

class _FeatureCategory extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _FeatureCategory({super.key, required this.icon,
    required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF24113D), Color(0xFF0B0A11)]),
      border: Border.all(color: const Color(0xFF4A286A))),
    clipBehavior: Clip.antiAlias,
    child: Material(type: MaterialType.transparency, child: InkWell(
      onTap: onTap,
      child: Center(child: Padding(padding: const EdgeInsets.all(14),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 42, color: RochaColors.gold),
          const SizedBox(height: 14),
          Text(label, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        ]))),
    )),
  );
}

class _OfficialHero extends StatelessWidget {
  final bool wide;
  final VoidCallback onWatch;
  const _OfficialHero({required this.wide, required this.onWatch});

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('official-hero'),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: const LinearGradient(colors: [
        Color(0xFF050409), Color(0xFF210937), Color(0xFF08060C)])),
    clipBehavior: Clip.antiAlias,
    child: Stack(fit: StackFit.expand, children: [
      if (wide)
        Image.asset('branding/home-tv-galaxy.png',
          key: const ValueKey('tv-galaxy-background'),
          fit: BoxFit.cover, alignment: Alignment.centerRight)
      else
        const RochaArtwork(fit: BoxFit.cover),
      const DecoratedBox(decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Color(0xDD050409), Color(0x99050409), Color(0x22050409)],
          stops: [0, .6, 1]))),
      Align(alignment: Alignment.centerLeft, child: Padding(
        padding: EdgeInsets.all(wide ? 26 : 16),
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          RochaBrand(compact: !wide),
          SizedBox(height: wide ? 8 : 6),
          Text('ENTRETENIMENTO\nSEM LIMITES', style: TextStyle(
            fontSize: wide ? 14 : 12, height: 1.35,
            letterSpacing: wide ? 2 : 1.3, color: RochaColors.silver)),
          SizedBox(height: wide ? 14 : 12),
          OutlinedButton.icon(
            autofocus: true, onPressed: onWatch,
            style: OutlinedButton.styleFrom(
              foregroundColor: RochaColors.gold,
              backgroundColor: const Color(0xCC050405),
              side: const BorderSide(color: RochaColors.gold, width: 2),
              padding: EdgeInsets.symmetric(horizontal: wide ? 18 : 12, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.play_arrow),
            label: const Text('ASSISTIR AGORA',
              style: TextStyle(fontWeight: FontWeight.w900))),
        ]),
      )),
    ]),
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
  final Size tileSize;
  final bool mobileArtwork;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _CategoryCard({super.key, required this.label, required this.icon,
    required this.onTap, required this.tileSize, this.mobileArtwork = false});
  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}
class _CategoryCardState extends State<_CategoryCard> {
  bool focused = false;
  // The approved illustrations are shared by phone and TV without resizing cards.
  String? get _coverAsset {
    final name = switch (widget.label) {
      'TV ao Vivo' => 'tv_ao_vivo',
      'Esportes' => 'esportes',
      'Infantil' => 'infantil',
      'Notícias' => 'noticias',
      _ => null,
    };
    if (name == null) return null;
    return 'branding/categories/mobile/$name.png';
  }
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 130),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF24113D), Color(0xFF0B0A11)]),
      border: Border.all(color: focused ? RochaColors.gold : const Color(0xFF4A286A),
        width: focused ? 2 : 1),
      boxShadow: focused ? const [BoxShadow(color: Color(0x555A20A8), blurRadius: 18)] : []),
    child: InkWell(onTap: widget.onTap, borderRadius: BorderRadius.circular(14),
      onFocusChange: (v) => setState(() => focused = v),
      child: Stack(fit: StackFit.expand, children: [
        // Keep the frozen card geometry; frame the presenter/ball on the right.
        if (_coverAsset != null) Image.asset(_coverAsset!,
          fit: widget.mobileArtwork ? BoxFit.cover : BoxFit.contain,
          alignment: widget.mobileArtwork &&
              (widget.label == 'TV ao Vivo' || widget.label == 'Esportes')
            ? Alignment.centerRight : Alignment.center,
          errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        const DecoratedBox(decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x08050409), Color(0xE8050409)]))),
        Builder(builder: (context) {
          // Covers remain full-bleed; fit the overlay to tiny 4-column
          // phone cards and to enlarged accessibility text on TV.
          final inset = focused ? 4 : 2;
          final compact = widget.tileSize.width - inset < 120 || widget.tileSize.height - inset < 135;
          final tiny = widget.tileSize.height - inset < 105;
          if (tiny) {
            // Avoid vertical Flex overflow on narrow four-column phone grids.
            return Padding(
              padding: const EdgeInsets.all(4),
              child: Stack(children: [
                Align(alignment: Alignment.topRight,
                  child: Icon(widget.icon, color: RochaColors.gold, size: 14)),
                Align(alignment: Alignment.bottomLeft,
                  child: Column(mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.label, maxLines: 1,
                        overflow: TextOverflow.ellipsis, softWrap: false,
                        style: const TextStyle(fontSize: 9,
                          fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Container(height: 2, width: 18, color: RochaColors.gold),
                    ])),
              ]),
            );
          }
          return Padding(
            padding: EdgeInsets.all(compact ? 7 : 15),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Align(alignment: Alignment.topRight,
                child: Icon(widget.icon, color: RochaColors.gold,
                  size: tiny ? 14 : (compact ? 19 : 28))),
              const Spacer(),
              Text(widget.label, maxLines: tiny ? 1 : 2,
                overflow: TextOverflow.ellipsis, softWrap: true,
                style: TextStyle(fontSize: tiny ? 9 : (compact ? 11 : 17),
                  fontWeight: FontWeight.w800)),
              SizedBox(height: tiny ? 2 : (compact ? 4 : 8)),
              Container(height: 2, width: tiny ? 18 : (compact ? 22 : 34),
                color: RochaColors.gold),
            ]),
          );
        }),
      ])),
  );
}
