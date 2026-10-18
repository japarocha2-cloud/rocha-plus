import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'src/live/channel.dart';
import 'src/screens/player_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Rocha+ Laboratório TV Morena',
    home: MorenaLab(),
  ));
}

class MorenaLab extends StatefulWidget {
  const MorenaLab({super.key});
  @override
  State<MorenaLab> createState() => _MorenaLabState();
}

class _MorenaLabState extends State<MorenaLab> {
  late final Future<List<Channel>> channels = _load();

  Future<List<Channel>> _load() async {
    final data = jsonDecode(await rootBundle.loadString('catalog/approved.json')) as List;
    final candidates = data.whereType<Map>().where((item) =>
      item['experimental'] == true &&
      item['release_scope'] == 'owner_testing_only' &&
      (item['name']?.toString().startsWith('TV Morena') ?? false));
    return candidates.map((item) => Channel(
      name: item['name'].toString(),
      url: item['url'].toString(),
      group: 'TV aberta',
    )).toList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF100B1B),
    appBar: AppBar(title: const Text('Rocha+ | Laboratório TV Morena')),
    body: FutureBuilder<List<Channel>>(
      future: channels,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Erro ao carregar catálogo: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.isEmpty) return const Center(child: Text('Nenhum canal de teste encontrado.'));
        return ListView(children: [
          const Padding(padding: EdgeInsets.all(16), child: Text(
            'Teste técnico isolado. Sem login, assinatura ou pagamentos. Fontes ainda não verificadas.',
            style: TextStyle(color: Colors.white70),
          )),
          for (final channel in snapshot.data!)
            ListTile(
              title: Text(channel.name, style: const TextStyle(color: Colors.white)),
              subtitle: const Text('Abrir teste de imagem e áudio', style: TextStyle(color: Colors.white54)),
              trailing: const Icon(Icons.play_arrow, color: Colors.amber),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => PlayerScreen(channel: channel))),
            ),
        ]);
      },
    ),
  );
}
