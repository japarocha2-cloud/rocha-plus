import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows) VideoPlayerMediaKit.ensureInitialized(windows: true);
  runApp(const MaterialApp(title: 'R.L Laboratorio', home: ChannelLab()));
}

class LabChannel {
  String name, url, verdict;
  LabChannel(this.name, this.url, [this.verdict = 'pendente']);
  Map<String, dynamic> toJson() => {'name': name, 'url': url, 'verdict': verdict};
  factory LabChannel.fromJson(Map<String, dynamic> j) =>
      LabChannel(j['name'] as String, j['url'] as String, j['verdict'] as String? ?? 'pendente');
}

class ChannelLab extends StatefulWidget {
  const ChannelLab({super.key});
  @override State<ChannelLab> createState() => _ChannelLabState();
}

class _ChannelLabState extends State<ChannelLab> {
  final link = TextEditingController();
  final name = TextEditingController();
  final entries = <LabChannel>[];
  String filter = 'todos';
  String message = '';
  @override void initState() { super.initState(); _restore(); }
  @override void dispose() { link.dispose(); name.dispose(); super.dispose(); }
  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = jsonDecode(prefs.getString('rocha-lab-v1') ?? '[]') as List;
      if (mounted) setState(() => entries.addAll(raw.map((x) => LabChannel.fromJson(Map<String, dynamic>.from(x)))));
    } catch (_) { if (mounted) setState(() => message = 'Lista salva inválida.'); }
  }
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rocha-lab-v1', jsonEncode(entries.map((e) => e.toJson()).toList()));
  }
  bool _valid(String url) {
    final u = Uri.tryParse(url);
    return u != null && (u.scheme == 'https' || u.scheme == 'http') && u.host.isNotEmpty;
  }
  void _add(String title, String url) {
    final clean = url.trim();
    if (!_valid(clean)) return;
    if (entries.any((e) => e.url == clean)) return;
    entries.add(LabChannel(title.trim().isEmpty ? 'Canal ${entries.length + 1}' : title.trim(), clean));
  }
  Future<void> _manual() async {
    final previous = entries.length;
    setState(() { _add(name.text, link.text); message = entries.length > previous ? 'Canal adicionado.' : 'Link inválido ou duplicado.'; });
    if (entries.length > previous) { await _save(); link.clear(); name.clear(); }
  }
  Future<void> _import() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
      if (result == null) return;
      final file = result.files.single;
      final bytes = file.bytes ?? (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null) throw const FormatException('Arquivo inacessível');
      final raw = utf8.decode(bytes, allowMalformed: true);
      if (!raw.trimLeft().startsWith('#EXTM3U')) throw const FormatException('Arquivo M3U inválido');
      final count = entries.length;
      var title = '';
      for (final line in const LineSplitter().convert(raw)) {
        final v = line.trim();
        if (v.startsWith('#EXTINF:')) {
          final comma = v.lastIndexOf(',');
          title = comma >= 0 ? v.substring(comma + 1).trim() : 'Canal';
        } else if (v.isNotEmpty && !v.startsWith('#')) {
          _add(title, v);
          title = '';
        }
      }
      setState(() => message = 'Importados ${entries.length - count} canais novos.');
      await _save();
    } catch (e) { if (mounted) setState(() => message = 'Falha ao importar: $e'); }
  }
  Future<void> _mark(LabChannel item, String verdict) async {
    setState(() => item.verdict = verdict);
    await _save();
  }
  Future<void> _export() async {
    final good = entries.where((e) => e.verdict == 'positivo').toList();
    if (good.isEmpty) { setState(() => message = 'Marque pelo menos um canal como positivo.'); return; }
    final text = '#EXTM3U\n${good.map((e) => '#EXTINF:-1 group-title="Rocha+ Lab aprovados",${e.name}\n${e.url}\n').join()}';
    try {
      final dir = await getTemporaryDirectory();
      final out = File('${dir.path}/rocha_lab_positivos.m3u');
      await out.writeAsString(text, flush: true);
      await SharePlus.instance.share(ShareParams(files: [XFile(out.path)], text: 'Canais positivos do Rocha+ Lab'));
      if (mounted) setState(() => message = 'Exportados ${good.length} canais positivos.');
    } catch (e) { if (mounted) setState(() => message = 'Falha ao exportar: $e'); }
  }
  @override Widget build(BuildContext context) {
    final shown = entries.where((e) => filter == 'todos' || e.verdict == filter).toList();
    final positive = entries.where((e) => e.verdict == 'positivo').length;
    return Scaffold(
      appBar: AppBar(title: const Text('R.L • Laboratório de Canais')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        const Text('Aplicativo local de testes. Não altera o catálogo oficial.'),
        const SizedBox(height: 8),
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome do canal (opcional)')),
        TextField(controller: link, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Link HTTP / HTTPS do canal')),
        Wrap(spacing: 8, children: [
          FilledButton(onPressed: _manual, child: const Text('Adicionar link')),
          OutlinedButton(onPressed: _import, child: const Text('Importar arquivo .m3u')),
          FilledButton.tonal(onPressed: _export, child: Text('Exportar positivos ($positive)')),
        ]),
        if (message.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(message)),
        Wrap(spacing: 6, children: [
          for (final f in ['todos', 'pendente', 'positivo', 'as vezes', 'falha'])
            ChoiceChip(label: Text(f), selected: filter == f, onSelected: (_) => setState(() => filter = f)),
        ]),
        Text('Total: ${entries.length} • Exibidos: ${shown.length}'),
        for (final item in shown)
          Card(child: Padding(padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            SelectableText(item.url, maxLines: 2),
            Text('Situação: ${item.verdict}'),
            Wrap(spacing: 4, children: [
              OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LabPlayer(item))), child: const Text('▶ Testar')),
              TextButton(onPressed: () => _mark(item, 'positivo'), child: const Text('✅ Positivo')),
              TextButton(onPressed: () => _mark(item, 'as vezes'), child: const Text('⚠️ Às vezes')),
              TextButton(onPressed: () => _mark(item, 'falha'), child: const Text('❌ Falha')),
            ]),
          ]))),
      ]),
    );
  }
}

class LabPlayer extends StatefulWidget {
  final LabChannel entry;
  const LabPlayer(this.entry, {super.key});
  @override State<LabPlayer> createState() => _LabPlayerState();
}
class _LabPlayerState extends State<LabPlayer> {
  VideoPlayerController? controller;
  String error = '';
  bool busy = true;
  @override void initState() { super.initState(); _start(); }
  Future<void> _start() async {
    setState(() { busy = true; error = ''; });
    await controller?.dispose();
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.entry.url));
    try {
      await controller!.initialize().timeout(const Duration(seconds: 25));
      await controller!.play();
      if (mounted) setState(() => busy = false);
    } catch (e) { if (mounted) setState(() { busy = false; error = 'Não foi possível reproduzir: $e'; }); }
  }
  @override void dispose() { controller?.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.entry.name)),
    body: Column(children: [
      AspectRatio(aspectRatio: 16 / 9, child: Center(child: busy ? const CircularProgressIndicator()
        : error.isNotEmpty ? Text(error, textAlign: TextAlign.center)
        : AspectRatio(aspectRatio: controller!.value.aspectRatio, child: VideoPlayer(controller!)))),
      FilledButton(onPressed: _start, child: const Text('Tentar novamente')),
      const Text('Marque o resultado na lista após assistir e conferir áudio.'),
    ]),
  );
}
