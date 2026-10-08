import 'package:flutter/material.dart';
import '../live/channel.dart';
import '../live/channel_search.dart';
import '../live/channel_repository.dart';
import '../live/channel_scanner.dart';
import '../live/favorites_repository.dart';
import '../theme/rocha_theme.dart';
import 'player_screen.dart';
import '../widgets/rocha_channel_card.dart';

class LiveTvScreen extends StatefulWidget {
  final String initialGroup;
  final ChannelRepository? repository;
  const LiveTvScreen({super.key, this.initialGroup = 'Todos', this.repository});
  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends State<LiveTvScreen> {
  late final ChannelRepository repository;
  bool scanning = false;
  Map<String, ChannelReachability> reachability = {};
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
    repository = widget.repository ?? ChannelRepository();
    selectedGroup = widget.initialGroup;
    load();
  }

  Future<void> load({bool forceRefresh = false}) async {
    setState(() { loading = true; error = null; });
    try {
      final results = await Future.wait([
        repository.loadBrazilPublicDirectory(forceRefresh: forceRefresh),
        favoritesRepository.load(),
      ]);
      if (mounted) {
        setState(() {
          channels = results[0] as List<Channel>;
          favorites = results[1] as Set<String>;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { error = 'Não foi possível carregar os canais.'; loading = false; });
    }
  }

  Future<void> scan(List<Channel> visible) async {
    setState(() => scanning = true);
    final sample = visible.take(40).toList();
    try {
      final results = await repository.scanChannels(sample);
      if (!mounted) return;
      setState(() => reachability.addAll(results));
      final accessible = results.values.where((v) => v == ChannelReachability.reachable).length;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        '${results.length} endereços verificados; $accessible acessíveis. Teste a reprodução no Player.',
      )));
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }

  Future<void> hideChannel(Channel channel) async {
    try {
      await repository.blockChannel(channel);
      if (!mounted) return;
      setState(() => channels = channels.where((c) => !repository.isBlocked(c)).toList());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível salvar o bloqueio.')),
        );
      }
    }
  }

  Future<void> toggleFavorite(Channel channel) async {
    final next = {...favorites};
    next.contains(channel.url) ? next.remove(channel.url) : next.add(channel.url);
    setState(() => favorites = next);
    await favoritesRepository.save(next);
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const preferredGroups = ['TV aberta', 'Esportes', 'Notícias', 'Infantil', 'Geral'];
    final available = channels.map((c) => c.group).toSet();
    final groups = preferredGroups.where(available.contains).toList();
    final requestedGroup = widget.initialGroup;
    final keepRequestedEmptyGroup = requestedGroup != 'Todos' &&
        requestedGroup != 'Favoritos' &&
        selectedGroup == requestedGroup;
    if (!loading && selectedGroup != 'Todos' &&
        selectedGroup != 'Favoritos' &&
        !groups.contains(selectedGroup) &&
        !keepRequestedEmptyGroup) {
      selectedGroup = 'Todos';
    }

    final q = search.text;
    final visible = channels.where((c) {
      final technicalGroup = c.group.contains(';');
      if (technicalGroup || repository.isQuarantined(c.url) || repository.isBlocked(c)) return false;
      final matchesSearch = channelMatchesSearch(c, q);
      final matchesGroup = selectedGroup == 'Todos' ||
          (selectedGroup == 'Favoritos' && favorites.contains(c.url)) ||
          c.group == selectedGroup;
      return matchesSearch && matchesGroup;
    }).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          selectedGroup == 'Favoritos'
              ? 'Favoritos'
              : selectedGroup == 'Esportes'
                  ? 'Esportes'
                  : selectedGroup == 'Infantil'
                      ? 'Infantil'
                      : selectedGroup == 'Notícias' ? 'Notícias' : 'TV ao Vivo',
        ),
        actions: [
          IconButton(
            tooltip: 'Verificar disponibilidade de até 40 canais',
            onPressed: loading || scanning || visible.isEmpty ? null : () => scan(visible),
            icon: scanning ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.fact_check_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'Opções dos canais',
            onSelected: (_) async {
              try {
                await repository.restoreUserBlockedChannels();
                if (mounted) await load(forceRefresh: true);
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Não foi possível restaurar os canais.')),
                  );
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'restore', child: Text('Restaurar canais ocultos')),
            ],
          ),
          IconButton(
            tooltip: 'Atualizar canais',
            onPressed: loading ? null : () => load(forceRefresh: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar canal ou categoria',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        if (!loading && error == null && channels.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                _GroupChip(label: 'Todos', selected: selectedGroup == 'Todos',
                  onSelected: () => setState(() => selectedGroup = 'Todos')),
                _GroupChip(label: 'Favoritos', selected: selectedGroup == 'Favoritos',
                  onSelected: () => setState(() => selectedGroup = 'Favoritos')),
                ...groups.map((group) => _GroupChip(
                  label: group,
                  selected: selectedGroup == group,
                  onSelected: () => setState(() => selectedGroup = group),
                )),
              ],
            ),
          ),
        if (!loading && error == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${visible.length} canais', style: const TextStyle(color: Colors.white54)),
            ),
          ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator(color: RochaColors.ruby))
              : error != null
                  ? _ErrorState(message: error!, onRetry: () => load(forceRefresh: true))
                  : visible.isEmpty
                      ? const _EmptyState()
                      : LayoutBuilder(builder: (context, constraints) {
                          final columns = (constraints.maxWidth / 230).floor().clamp(2, 7);
                          return GridView.builder(
                            key: const ValueKey('channel-grid'),
                            padding: const EdgeInsets.all(16),
                            itemCount: visible.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns, childAspectRatio: .70,
                              crossAxisSpacing: 12, mainAxisSpacing: 12),
                            itemBuilder: (_, i) {
                              final channel = visible[i];
                              return RochaChannelCard(
                                channel: channel, favorite: favorites.contains(channel.url),
                                availability: reachability[channel.url] == ChannelReachability.unavailable
                                    ? 'Endereço indisponível na última verificação' : null,
                                onFavorite: () => toggleFavorite(channel),
                                onHide: () => hideChannel(channel),
                                onOpen: () async {
                                  await Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => PlayerScreen(channel: channel)));
                                  if (mounted) setState(() {});
                                });
                            },
                          );
                        }),
        ),
      ]),
    );
  }
}

class _GroupChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  const _GroupChip({required this.label, required this.selected, required this.onSelected});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(label: Text(label), selected: selected,
      onSelected: (_) => onSelected(), selectedColor: RochaColors.wine,
      side: BorderSide(color: selected ? RochaColors.gold : Colors.white24)),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.cloud_off, size: 46, color: RochaColors.ruby),
      const SizedBox(height: 12), Text(message, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      FilledButton.icon(autofocus: true, onPressed: onRetry,
        icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
    ]),
  ));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => const Center(child: Padding(
    padding: EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.search_off, size: 46, color: Colors.white38),
      SizedBox(height: 12), Text('Nenhum canal encontrado.'),
      SizedBox(height: 4),
      Text('Tente outro nome, categoria ou adicione favoritos.',
        style: TextStyle(color: Colors.white54), textAlign: TextAlign.center),
    ]),
  ));
}
