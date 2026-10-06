import 'package:flutter/material.dart';

import '../live/channel.dart';
import '../live/channel_repository.dart';
import '../live/favorites_repository.dart';
import '../theme/rocha_theme.dart';
import 'player_screen.dart';

class LiveTvScreen extends StatefulWidget {
  final String initialGroup;
  const LiveTvScreen({super.key, this.initialGroup = 'Todos'});

  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends State<LiveTvScreen> {
  final repository = ChannelRepository();
  final favoritesRepository = FavoritesRepository();
  final search = TextEditingController();

  List<Channel> channels = const [];
  Set<String> favorites = {};
  bool loading = true;
  String? error;
  late String selectedGroup;

  @override
  void initState() {
    super.initState();
    selectedGroup = widget.initialGroup;
    load();
  }

  Future<void> load({bool forceRefresh = false}) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait([
        repository.loadBrazilPublicDirectory(forceRefresh: forceRefresh),
        favoritesRepository.load(),
      ]);
      if (!mounted) return;
      setState(() {
        channels = results[0] as List<Channel>;
        favorites = results[1] as Set<String>;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = 'Não foi possível carregar os canais.';
        loading = false;
      });
    }
  }

  Future<void> toggleFavorite(Channel channel) async {
    final next = {...favorites};
    next.contains(channel.url)
        ? next.remove(channel.url)
        : next.add(channel.url);
    setState(() => favorites = next);
    await favoritesRepository.save(next);
  }

  void openChannel(Channel channel) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(channel: channel)),
    );
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = channels.map((c) => c.group).toSet().toList()..sort();
    if (selectedGroup != 'Todos' &&
        selectedGroup != 'Favoritos' &&
        !groups.contains(selectedGroup)) {
      selectedGroup = 'Todos';
    }

    final query = search.text.trim().toLowerCase();
    final visible = channels.where((channel) {
      final matchesSearch = query.isEmpty ||
          channel.name.toLowerCase().contains(query) ||
          channel.group.toLowerCase().contains(query);
      final matchesGroup = selectedGroup == 'Todos' ||
          (selectedGroup == 'Favoritos' &&
              favorites.contains(channel.url)) ||
          channel.group == selectedGroup;
      return matchesSearch && matchesGroup;
    }).toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final tv = constraints.maxWidth >= 900;
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _TopBar(
                  tv: tv,
                  title: selectedGroup == 'Favoritos'
                      ? 'Favoritos'
                      : 'Canais ao vivo',
                  loading: loading,
                  onRefresh: () => load(forceRefresh: true),
                ),
                _SearchAndFilters(
                  tv: tv,
                  controller: search,
                  selectedGroup: selectedGroup,
                  groups: groups,
                  onSearch: () => setState(() {}),
                  onGroup: (group) => setState(() => selectedGroup = group),
                ),
                if (!loading && error == null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      tv ? 36 : 16,
                      4,
                      tv ? 36 : 16,
                      10,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${visible.length} canais disponíveis',
                        style: const TextStyle(color: RochaColors.muted),
                      ),
                    ),
                  ),
                Expanded(
                  child: loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: RochaColors.playGreen,
                          ),
                        )
                      : error != null
                          ? _ErrorState(
                              message: error!,
                              onRetry: () => load(forceRefresh: true),
                            )
                          : visible.isEmpty
                              ? const _EmptyState()
                              : GridView.builder(
                                  padding: EdgeInsets.fromLTRB(
                                    tv ? 36 : 16,
                                    4,
                                    tv ? 36 : 16,
                                    28,
                                  ),
                                  gridDelegate:
                                      SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: tv ? 360 : 250,
                                    mainAxisExtent: tv ? 220 : 178,
                                    crossAxisSpacing: tv ? 18 : 12,
                                    mainAxisSpacing: tv ? 18 : 12,
                                  ),
                                  itemCount: visible.length,
                                  itemBuilder: (_, index) {
                                    final channel = visible[index];
                                    return _ChannelCard(
                                      channel: channel,
                                      favorite:
                                          favorites.contains(channel.url),
                                      autofocus: tv && index == 0,
                                      onFavorite: () =>
                                          toggleFavorite(channel),
                                      onTap: () => openChannel(channel),
                                    );
                                  },
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

class _TopBar extends StatelessWidget {
  final bool tv;
  final String title;
  final bool loading;
  final VoidCallback onRefresh;

  const _TopBar({
    required this.tv,
    required this.title,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          tv ? 36 : 10,
          tv ? 18 : 8,
          tv ? 28 : 8,
          8,
        ),
        child: Row(
          children: [
            IconButton(
              autofocus: tv,
              tooltip: 'Voltar',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: tv ? 30 : 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            const Icon(Icons.sensors, color: RochaColors.playGreen),
            const SizedBox(width: 8),
            if (tv)
              const Text(
                'ROCHA+ AO VIVO',
                style: TextStyle(
                  color: RochaColors.playGreen,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Atualizar canais',
              onPressed: loading ? null : onRefresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      );
}

class _SearchAndFilters extends StatelessWidget {
  final bool tv;
  final TextEditingController controller;
  final String selectedGroup;
  final List<String> groups;
  final VoidCallback onSearch;
  final ValueChanged<String> onGroup;

  const _SearchAndFilters({
    required this.tv,
    required this.controller,
    required this.selectedGroup,
    required this.groups,
    required this.onSearch,
    required this.onGroup,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <String>['Todos', 'Favoritos', ...groups];
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            tv ? 36 : 16,
            8,
            tv ? 36 : 16,
            10,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: tv ? 760 : double.infinity),
            child: TextField(
              controller: controller,
              onChanged: (_) => onSearch(),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar canal ou categoria',
              ),
            ),
          ),
        ),
        SizedBox(
          height: tv ? 58 : 48,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: tv ? 36 : 16),
            scrollDirection: Axis.horizontal,
            itemCount: chips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final group = chips[index];
              return _GroupChip(
                label: group,
                selected: selectedGroup == group,
                onSelected: () => onGroup(group),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ChannelCard extends StatefulWidget {
  final Channel channel;
  final bool favorite;
  final bool autofocus;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  const _ChannelCard({
    required this.channel,
    required this.favorite,
    required this.autofocus,
    required this.onTap,
    required this.onFavorite,
  });

  @override
  State<_ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<_ChannelCard> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
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
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: InkWell(
          autofocus: widget.autofocus,
          onFocusChange: (value) => setState(() => focused = value),
          onTap: widget.onTap,
          child: Stack(
            children: [
              Positioned.fill(
                child: widget.channel.logo == null ||
                        widget.channel.logo!.isEmpty
                    ? const _FallbackArt()
                    : Image.network(
                        widget.channel.logo!,
                        fit: BoxFit.cover,
                        cacheWidth: 520,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, __, ___) => const _FallbackArt(),
                      ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0x33000000),
                        Color(0xF205040A),
                      ],
                      stops: [0, .44, 1],
                    ),
                  ),
                ),
              ),
              const Positioned(
                left: 12,
                top: 12,
                child: _LiveBadge(),
              ),
              Positioned(
                right: 6,
                top: 6,
                child: IconButton(
                  tooltip: widget.favorite
                      ? 'Remover dos favoritos'
                      : 'Adicionar aos favoritos',
                  onPressed: widget.onFavorite,
                  icon: Icon(
                    widget.favorite
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: widget.favorite
                        ? RochaColors.playGreen
                        : Colors.white,
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.channel.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(color: Colors.black, blurRadius: 5),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.channel.group,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: RochaColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FallbackArt extends StatelessWidget {
  const _FallbackArt();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              RochaColors.cosmicBlue,
              RochaColors.wine,
              RochaColors.background,
            ],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.live_tv,
            size: 54,
            color: RochaColors.playGreen,
          ),
        ),
      );
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFD91527),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 7, color: Colors.white),
            SizedBox(width: 6),
            Text(
              'AO VIVO',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
}

class _GroupChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _GroupChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        selectedColor: RochaColors.playGreenSoft,
        backgroundColor: RochaColors.surface,
        side: BorderSide(
          color: selected ? RochaColors.playGreen : RochaColors.border,
        ),
        labelStyle: TextStyle(
          color: selected ? Colors.white : RochaColors.muted,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off,
                size: 46,
                color: RochaColors.playGreen,
              ),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                autofocus: true,
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 46, color: Colors.white38),
              SizedBox(height: 12),
              Text('Nenhum canal encontrado.'),
              SizedBox(height: 4),
              Text(
                'Tente outro nome, categoria ou adicione favoritos.',
                style: TextStyle(color: RochaColors.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}
