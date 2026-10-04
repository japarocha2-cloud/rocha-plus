import 'package:flutter/material.dart';
import '../live/channel.dart';
import '../live/channel_repository.dart';
import '../theme/rocha_theme.dart';
import 'player_screen.dart';

class LiveTvScreen extends StatefulWidget {
  const LiveTvScreen({super.key});
  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends State<LiveTvScreen> {
  final repository = ChannelRepository();
  final search = TextEditingController();
  List<Channel> channels = const [];
  bool loading = true;
  String? error;
  String selectedGroup = 'Todos';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool forceRefresh = false}) async {
    setState(() { loading = true; error = null; });
    try {
      final result = await repository.loadBrazilPublicDirectory(forceRefresh: forceRefresh);
      if (mounted) setState(() { channels = result; loading = false; });
    } catch (_) {
      if (mounted) setState(() { error = 'Não foi possível carregar os canais.'; loading = false; });
    }
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = channels.map((c) => c.group).toSet().toList()..sort();
    if (selectedGroup != 'Todos' && !groups.contains(selectedGroup)) {
      selectedGroup = 'Todos';
    }

    final q = search.text.trim().toLowerCase();
    final visible = channels.where((c) {
      final matchesSearch = q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          c.group.toLowerCase().contains(q);
      final matchesGroup = selectedGroup == 'Todos' || c.group == selectedGroup;
      return matchesSearch && matchesGroup;
    }).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TV ao Vivo'),
        actions: [
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
                _GroupChip(
                  label: 'Todos',
                  selected: selectedGroup == 'Todos',
                  onSelected: () => setState(() => selectedGroup = 'Todos'),
                ),
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
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: visible.length,
                          itemBuilder: (_, i) {
                            final channel = visible[i];
                            return Card(
                              child: ListTile(
                                leading: channel.logo == null || channel.logo!.isEmpty
                                    ? const Icon(Icons.live_tv)
                                    : Image.network(
                                        channel.logo!,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.live_tv),
                                      ),
                                title: Text(channel.name),
                                subtitle: Text(channel.group),
                                trailing: const Icon(Icons.play_circle_fill, color: RochaColors.ruby),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => PlayerScreen(channel: channel)),
                                ),
                              ),
                            );
                          },
                        ),
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
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onSelected(),
          selectedColor: RochaColors.wine,
          side: BorderSide(color: selected ? RochaColors.ruby : Colors.white24),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, size: 46, color: RochaColors.ruby),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              autofocus: true,
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ]),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.search_off, size: 46, color: Colors.white38),
            SizedBox(height: 12),
            Text('Nenhum canal encontrado.'),
            SizedBox(height: 4),
            Text('Tente outro nome ou categoria.', style: TextStyle(color: Colors.white54)),
          ]),
        ),
      );
}
