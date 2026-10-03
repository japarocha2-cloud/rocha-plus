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

  @override
  void initState() {
    super.initState();
    load();
    search.addListener(() => setState(() {}));
  }

  Future<void> load() async {
    try {
      final result = await repository.loadBrazilPublicDirectory();
      if (mounted) setState(() { channels = result; loading = false; });
    } catch (e) {
      if (mounted) setState(() { error = e.toString(); loading = false; });
    }
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = search.text.trim().toLowerCase();
    final visible = q.isEmpty ? channels : channels.where((c) =>
      c.name.toLowerCase().contains(q) || c.group.toLowerCase().contains(q)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('TV ao Vivo')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar canal ou categoria',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? Center(child: FilledButton(onPressed: () {
                      setState(() { loading = true; error = null; });
                      load();
                    }, child: const Text('Tentar novamente')))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: visible.length,
                      itemBuilder: (_, i) {
                        final channel = visible[i];
                        return Card(
                          child: ListTile(
                            leading: channel.logo == null || channel.logo!.isEmpty
                              ? const Icon(Icons.live_tv)
                              : Image.network(channel.logo!, width: 48, errorBuilder: (_, __, ___) => const Icon(Icons.live_tv)),
                            title: Text(channel.name),
                            subtitle: Text(channel.group),
                            trailing: const Icon(Icons.play_circle_fill, color: RochaColors.ruby),
                            onTap: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => PlayerScreen(channel: channel))),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}
