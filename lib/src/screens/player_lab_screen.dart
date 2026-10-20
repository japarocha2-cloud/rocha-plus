import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:video_player/video_player.dart';

import '../live/channel.dart';
import '../live/lab_observer.dart';
import '../live/player_lab_results.dart';
import '../theme/rocha_theme.dart';

/// Opt-in laboratory only. Never mutate the frozen production catalogue.
class PlayerLabScreen extends StatefulWidget {
  final List<Channel> channels;
  const PlayerLabScreen({super.key, required this.channels});

  @override
  State<PlayerLabScreen> createState() => _PlayerLabScreenState();
}

class _PlayerLabScreenState extends State<PlayerLabScreen> {
  final PlayerLabResults _results = PlayerLabResults();
  Map<String, LabRecord> _saved = {};
  VideoPlayerController? _exo;
  VlcPlayerController? _vlc;
  bool _running = false;
  bool _cancel = false;
  String _status = 'Pronto para iniciar';
  int _completed = 0;
  int _elapsed = 0;
  int _total = 0;
  Channel? _current;

  @override
  void initState() {
    super.initState();
    _results.read().then((records) {
      if (mounted) setState(() => _saved = records);
    });
  }

  @override
  void dispose() {
    _cancel = true;
    _exo?.dispose();
    _vlc?.dispose();
    super.dispose();
  }

  Future<void> _closePlayers() async {
    final exo = _exo;
    final vlc = _vlc;
    if (mounted) setState(() { _exo = null; _vlc = null; });
    if (exo != null) await exo.dispose();
    if (vlc != null) await vlc.dispose();
  }

  Future<LabSample> _runSample(Channel channel, LabEngine engine, int seconds) async {
    await _closePlayers();
    final observer = LabObserver(engine);
    final watch = Stopwatch()..start();
    String? failure;
    try {
      if (engine == LabEngine.exoPlayer) {
        final controller = VideoPlayerController.networkUrl(Uri.parse(channel.url));
        _exo = controller;
        await controller.initialize().timeout(const Duration(seconds: 20));
        if (!mounted || _cancel) throw StateError('Teste interrompido');
        setState(() {});
        await controller.play();
      } else {
        final controller = VlcPlayerController.network(channel.url,
          hwAcc: HwAcc.auto, autoPlay: true, options: VlcPlayerOptions());
        _vlc = controller;
        setState(() {}); // LibVLC requires its native platform view mounted.
        // VlcPlayer invokes initialize when its Android platform view is ready.
        // Do not invoke initialize twice: await the value notification instead.
        final ready = Completer<void>();
        void onReady() {
          if (controller.value.isInitialized && !ready.isCompleted) ready.complete();
          if (controller.value.errorDescription != VlcPlayerValue.noError &&
              !ready.isCompleted) ready.completeError(
                StateError(controller.value.errorDescription));
        }
        controller.addListener(onReady);
        onReady();
        try {
          await ready.future.timeout(const Duration(seconds: 20));
        } finally {
          controller.removeListener(onReady);
        }
      }
    } catch (error) {
      failure = error.toString();
    }

    // Test time starts at the request, including initialization latency.
    // A failed open is recorded promptly; normal tests run for their full window.
    while (!_cancel && mounted && failure == null && watch.elapsed.inSeconds < seconds) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted || _cancel) break;
      final exo = _exo?.value;
      final vlc = _vlc?.value;
      final isExo = engine == LabEngine.exoPlayer;
      observer.observe(
        milliseconds: watch.elapsedMilliseconds,
        position: isExo ? (exo?.position ?? Duration.zero) :
            (vlc?.position ?? Duration.zero),
        playing: isExo ? (exo?.isPlaying ?? false) :
            (vlc?.isPlaying ?? false),
        buffering: isExo ? (exo?.isBuffering ?? false) :
            (vlc?.isBuffering ?? false),
        videoTrack: isExo ? (exo?.size.width ?? 0) > 0 &&
            (exo?.size.height ?? 0) > 0 : (vlc?.videoTracksCount ?? 0) > 0,
        // video_player has no audio-track API. Unknown is not false proof.
        audioTrack: isExo ? false : (vlc?.audioTracksCount ?? 0) > 0,
        error: isExo ? (exo?.hasError == true ? exo?.errorDescription : null)
            : (vlc?.errorDescription == VlcPlayerValue.noError ? null :
                vlc?.errorDescription),
      );
      setState(() => _elapsed = watch.elapsed.inSeconds);
    }
    watch.stop();
    if (failure != null) {
      observer.observe(milliseconds: watch.elapsedMilliseconds,
        position: Duration.zero, playing: false, buffering: false,
        videoTrack: false, audioTrack: false, error: failure);
    }
    final result = observer.finish(watch.elapsedMilliseconds);
    await _closePlayers();
    return result;
  }

  Future<void> _start() async {
    if (_running || widget.channels.isEmpty) return;
    final pending = widget.channels.where((c) =>
        !_saved.containsKey(PlayerLabResults.keyFor(c))).toList();
    if (pending.isEmpty) {
      setState(() => _status = 'Todos os canais desta lista já têm registro.');
      return;
    }
    setState(() { _running = true; _cancel = false; _completed = 0;
      _total = pending.length; });
    try {
      for (final channel in pending) {
        if (_cancel || !mounted) break;
        _current = channel;
        setState(() { _elapsed = 0; _status = 'ExoPlayer • 60 s'; });
        final exo = await _runSample(channel, LabEngine.exoPlayer, 60);
        if (_cancel || !mounted) break;
        setState(() { _elapsed = 0; _status = 'LibVLC • 60 s'; });
        final vlc = await _runSample(channel, LabEngine.libVlc, 60);
        if (_cancel || !mounted) break;
        final winner = chooseLabWinner(exo, vlc);
        setState(() { _elapsed = 0; _status = '${winner.label} • confirmação 180 s'; });
        final confirmation = await _runSample(channel, winner, 180);
        if (_cancel || !mounted) break;
        final record = LabRecord(channelName: channel.name,
          channelUrl: channel.url, group: channel.group,
          testedAt: DateTime.now(), exo: exo, vlc: vlc,
          confirmation: confirmation);
        await _results.save(channel, record);
        _saved[PlayerLabResults.keyFor(channel)] = record;
        setState(() => _completed++);
      }
    } catch (error) {
      if (mounted) setState(() => _status = 'Erro: $error');
    } finally {
      await _closePlayers();
      if (mounted) setState(() { _running = false; _current = null;
        if (!_status.startsWith('Erro:')) _status = _cancel
          ? 'Interrompido; resultados anteriores preservados'
          : 'Lote concluído'; });
    }
  }

  Future<void> _export() async {
    final data = _saved.values.map((r) => r.toJson()).toList();
    await Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(data)));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Relatório JSON copiado para a área de transferência.')));
  }

  Future<void> _validate(Channel channel, LabRecord record) async {
    bool picture = record.pictureConfirmed ?? false;
    bool sound = record.soundConfirmed ?? false;
    final accepted = await showDialog<bool>(context: context, builder: (dialogContext) =>
      StatefulBuilder(builder: (context, refresh) => AlertDialog(
        title: Text('Conferir ${channel.name}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Confirme apenas após assistir e ouvir no aparelho. '
            'A leitura automática de faixas não comprova imagem nem som.'),
          CheckboxListTile(title: const Text('Imagem realmente visível'),
            value: picture, onChanged: (v) => refresh(() => picture = v ?? false)),
          CheckboxListTile(title: const Text('Áudio realmente audível'),
            value: sound, onChanged: (v) => refresh(() => sound = v ?? false)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Salvar verificação')),
        ],
      )));
    if (accepted != true) return;
    final checked = record.withHumanCheck(picture: picture, sound: sound);
    await _results.save(channel, checked);
    if (mounted) setState(() => _saved[PlayerLabResults.keyFor(channel)] = checked);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Rocha+ • Laboratório de players'), actions: [
      IconButton(tooltip: 'Copiar relatório JSON', onPressed: _saved.isEmpty ? null : _export,
        icon: const Icon(Icons.copy_all)),
    ]),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${widget.channels.length} canais • $_completed/$_total nesta execução'),
          const SizedBox(height: 6),
          Text(_current == null ? _status : '${_current!.name} — $_status ($_elapsed s)'),
          const SizedBox(height: 8),
          const Text('60 s por player + 180 s de confirmação. Mede avanço, abertura, buffering e travamentos. '
            'Faixas de vídeo/áudio não comprovam imagem visível ou som audível; valide no aparelho.',
            style: TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 12),
          Row(children: [
            FilledButton.icon(onPressed: _running ? null : _start,
              icon: const Icon(Icons.play_arrow), label: const Text('Iniciar pendentes')),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _running ? () => setState(() => _cancel = true) : null,
              child: const Text('Parar')),
          ]),
        ])),
      if (_exo != null) SizedBox(height: 150,
        child: VideoPlayer(_exo!)),
      if (_vlc != null) SizedBox(height: 150,
        child: VlcPlayer(controller: _vlc!, aspectRatio: 16 / 9,
          placeholder: const Center(child: CircularProgressIndicator()))),
      const Divider(),
      Expanded(child: ListView.builder(itemCount: widget.channels.length,
        itemBuilder: (context, index) {
          final channel = widget.channels[index];
          final record = _saved[PlayerLabResults.keyFor(channel)];
          return ListTile(dense: true, title: Text(channel.name),
            subtitle: Text(record == null ? 'Pendente' :
              'Exo ${record.exo.progressSeconds}s / VLC ${record.vlc.progressSeconds}s • '
              'confirmado ${record.confirmation.progressSeconds}s com ${record.preferred?.label ?? "nenhum"} • '
              'travamentos ${record.confirmation.stalls} • '
              'buffer ${(record.confirmation.bufferingMilliseconds / 1000).toStringAsFixed(1)}s'),
            trailing: record == null ? const Text('—') : IconButton(
              tooltip: 'Verificar imagem e áudio no dispositivo',
              onPressed: () => _validate(channel, record),
              icon: Icon(record.pictureConfirmed == true && record.soundConfirmed == true
                ? Icons.verified : Icons.fact_check_outlined,
                color: RochaColors.playGreen)));
        })),
    ]),
  );
}
