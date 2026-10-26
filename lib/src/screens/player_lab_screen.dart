import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:video_player/video_player.dart';

import '../live/channel.dart';
import '../live/lab_observer.dart';
import '../live/lab_runtime.dart';
import 'feature_lab_screen.dart';
import '../live/player_lab_results.dart';
import '../theme/rocha_theme.dart';
import 'adaptive_player_screen.dart';

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
  int _batchSize = 10;
  Channel? _current;
  final GlobalKey _videoKey = GlobalKey();
  LabRuntime? _runtime;
  final Map<String, dynamic> _phases = {};
  String? _phase;
  final List<Map<String, String>> _failures = [];
  static const _auto = bool.fromEnvironment('LAB_AUTOSTART');
  static const _limit = int.fromEnvironment('LAB_BATCH', defaultValue: 10);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await _results.read();
    _runtime = await LabRuntime.open();
    final phases = await _runtime?.read('phases.json') ?? {};
    _phases.addAll(phases);
    if (!mounted) return;
    setState(() {
      _saved = records;
      _batchSize = _limit;
    });
    final config = await LabRuntime.configuration();
    if (_auto || config['auto'] == true) {
      _batchSize = config['limit'] as int? ?? _limit;
      // Missing export bridge is an infrastructure error, never a successful run.
      if (_runtime == null) {
        setState(() => _status = 'Erro: ponte Android LAB indisponível');
        return;
      }
      await _start();
    }
  }

  Future<void> _checkpoint({bool done = false}) async {
    final box = _videoKey.currentContext?.findRenderObject() as RenderBox?;
    Map<String, double>? rect;
    if (box != null && box.hasSize && mounted) {
      final origin = box.localToGlobal(Offset.zero);
      final scale = MediaQuery.devicePixelRatioOf(context);
      rect = {
        'x': origin.dx * scale,
        'y': origin.dy * scale,
        'width': box.size.width * scale,
        'height': box.size.height * scale,
      };
    }
    await _runtime?.write('status.json', {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'url': _current?.url,
      'channel': _current?.name,
      'phase': _phase,
      'elapsedSeconds': _elapsed,
      'completed': _completed,
      'total': _total,
      'done': done,
      'failures': _failures,
      'videoRect': rect,
    });
  }

  Future<LabSample> _stage(
    Channel channel,
    LabEngine engine,
    int seconds,
    String phase,
  ) async {
    final existing = Map<String, dynamic>.from(
      _phases[channel.url] as Map? ?? {},
    );
    final sample = existing[phase];
    if (sample != null) {
      return LabSample.fromJson(Map<String, dynamic>.from(sample as Map));
    }
    _phase = 'transition';
    _elapsed = 0;
    await _checkpoint();
    await _closePlayers();
    _phase = phase;
    _elapsed = 0;
    await _checkpoint();
    final result = await _runSample(channel, engine, seconds);
    if (!_cancel && mounted) {
      existing[phase] = result.toJson();
      _phases[channel.url] = existing;
      await _runtime?.write('phases.json', _phases);
    }
    return result;
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
    // Stop output while its view still exists, then detach the widget tree.
    if (exo != null && exo.value.isInitialized) {
      try { await exo.pause().timeout(const Duration(seconds: 5)); } catch (_) { /* dispose still required */ }
    }
    if (vlc != null && vlc.value.isInitialized) {
      try { await vlc.stop().timeout(const Duration(seconds: 5)); } catch (_) { /* dispose still required */ }
    }
    _exo = null;
    _vlc = null;
    if (mounted) {
      setState(() {});
      await WidgetsBinding.instance.endOfFrame;
    }
    try {
      if (exo != null) await exo.dispose().timeout(const Duration(seconds: 10));
    } finally {
      if (vlc != null) await vlc.dispose().timeout(const Duration(seconds: 10));
    }
  }

  Future<LabSample> _runSample(
    Channel channel,
    LabEngine engine,
    int seconds,
  ) async {
    final observer = LabObserver(engine);
    final watch = Stopwatch()..start();
    String? failure;
    observer.observe(
      milliseconds: 0,
      position: Duration.zero,
      playing: false,
      buffering: true,
      videoTrack: false,
      audioTrack: false,
    );
    try {
      if (engine == LabEngine.exoPlayer) {
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(channel.url),
        );
        _exo = controller;
        await controller.initialize().timeout(const Duration(seconds: 20));
        if (!mounted || _cancel) throw StateError('Teste interrompido');
        setState(() {});
        await controller.play();
      } else {
        final controller = VlcPlayerController.network(
          channel.url,
          hwAcc: HwAcc.auto,
          autoPlay: true,
          options: VlcPlayerOptions(),
        );
        _vlc = controller;
        setState(() {}); // LibVLC requires its native platform view mounted.
        // VlcPlayer invokes initialize when its Android platform view is ready.
        // Do not invoke initialize twice: await the value notification instead.
        final ready = Completer<void>();
        void onReady() {
          if (controller.value.isInitialized && !ready.isCompleted) {
            ready.complete();
          }
          if (controller.value.errorDescription != VlcPlayerValue.noError &&
              !ready.isCompleted) {
            ready.completeError(StateError(controller.value.errorDescription));
          }
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
    while (!_cancel &&
        mounted &&
        failure == null &&
        watch.elapsed.inSeconds < seconds) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted || _cancel) break;
      final exo = _exo?.value;
      final vlc = _vlc?.value;
      final isExo = engine == LabEngine.exoPlayer;
      observer.observe(
        milliseconds: watch.elapsedMilliseconds,
        position: isExo
            ? (exo?.position ?? Duration.zero)
            : (vlc?.position ?? Duration.zero),
        playing: isExo ? (exo?.isPlaying ?? false) : (vlc?.isPlaying ?? false),
        buffering: isExo
            ? (exo?.isBuffering ?? false)
            : (vlc?.isBuffering ?? false),
        videoTrack: isExo
            ? (exo?.size.width ?? 0) > 0 && (exo?.size.height ?? 0) > 0
            : (vlc?.videoTracksCount ?? 0) > 0,
        // video_player has no audio-track API. Unknown is not false proof.
        audioTrack: isExo ? false : (vlc?.audioTracksCount ?? 0) > 0,
        error: isExo
            ? (exo?.hasError == true ? exo?.errorDescription : null)
            : (vlc?.errorDescription == VlcPlayerValue.noError
                  ? null
                  : vlc?.errorDescription),
      );
      setState(() => _elapsed = watch.elapsed.inSeconds);
      if (_elapsed % 5 == 0) await _checkpoint();
    }
    watch.stop();
    if (failure != null) {
      observer.observe(
        milliseconds: watch.elapsedMilliseconds,
        position: Duration.zero,
        playing: false,
        buffering: false,
        videoTrack: false,
        audioTrack: false,
        error: failure,
      );
    }
    // Persist the completed phase before the next transition touches native
    // decoder/surface resources. A process failure cannot erase this sample.
    return observer.finish(watch.elapsedMilliseconds);
  }

  Future<void> _start() async {
    if (_running || widget.channels.isEmpty) return;
    final pending = widget.channels
        .where((c) => !_saved.containsKey(PlayerLabResults.keyFor(c)))
        .take(_batchSize)
        .toList();
    if (pending.isEmpty) {
      setState(() => _status = 'Todos os canais desta lista já têm registro.');
      await _exportFiles();
      await _checkpoint(done: true);
      return;
    }
    setState(() {
      _running = true;
      _cancel = false;
      _completed = 0;
      _total = pending.length;
    });
    try {
      for (final channel in pending) {
        if (_cancel || !mounted) break;
        _current = channel;
        try {
          setState(() {
            _elapsed = 0;
            _status = 'ExoPlayer • 60 s';
          });
          final exo = await _stage(channel, LabEngine.exoPlayer, 60, 'exo');
          if (_cancel || !mounted) break;
          setState(() {
            _elapsed = 0;
            _status = 'LibVLC • 60 s';
          });
          final vlc = await _stage(channel, LabEngine.libVlc, 60, 'vlc');
          if (_cancel || !mounted) break;
          final winner = chooseLabWinner(exo, vlc);
          setState(() {
            _elapsed = 0;
            _status = '${winner.label} • confirmação 180 s';
          });
          final confirmation = await _stage(
            channel,
            winner,
            180,
            'confirmation',
          );
          if (_cancel || !mounted) break;
          final record = LabRecord(
            channelName: channel.name,
            channelUrl: channel.url,
            group: channel.group,
            testedAt: DateTime.now(),
            exo: exo,
            vlc: vlc,
            confirmation: confirmation,
          );
          await _results.save(channel, record);
          _saved[PlayerLabResults.keyFor(channel)] = record;
          setState(() => _completed++);
          await _exportFiles();
          await _checkpoint();
        } catch (error) {
          // Infrastructure/player exceptions affect this URL, not the whole lot.
          _failures.add({'url': channel.url, 'error': error.toString()});
          await _checkpoint();
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _status = 'Erro: $error');
      }
    } finally {
      try {
        await _closePlayers();
      } catch (error) {
        _failures.add({'url': _current?.url ?? '', 'error': error.toString()});
      }
      await _exportFiles();
      await _checkpoint(done: !_cancel);
      if (mounted) {
        setState(() {
          _running = false;
          _current = null;
          if (!_status.startsWith('Erro:')) {
            _status = _cancel
                ? 'Interrompido; resultados anteriores preservados'
                : 'Lote concluído';
          }
        });
      }
    }
  }

  Future<void> _exportFiles() async {
    final urls = widget.channels.map((c) => c.url).toSet();
    final records =
        _saved.values.where((r) => urls.contains(r.channelUrl)).toList()..sort(
          (a, b) => '${a.group}/${a.channelName}'.compareTo(
            '${b.group}/${b.channelName}',
          ),
        );
    await _runtime?.write(
      'results.json',
      records.map((r) => r.toJson()).toList(),
    );
    String csv(Object? value) =>
        '"${(value ?? '').toString().replaceAll('"', '""')}"';
    final rows = [
      'name,url,category,preferred,status,exo_progress_s,vlc_progress_s,confirmation_progress_s,startup_ms,buffering_ms,stalls,picture_confirmed,sound_confirmed',
    ];
    for (final r in records) {
      rows.add(
        [
          r.channelName,
          r.channelUrl,
          r.group,
          r.preferred?.name,
          r.toJson()['status'],
          r.exo.progressSeconds,
          r.vlc.progressSeconds,
          r.confirmation.progressSeconds,
          r.confirmation.startupMilliseconds,
          r.confirmation.bufferingMilliseconds,
          r.confirmation.stalls,
          r.pictureConfirmed,
          r.soundConfirmed,
        ].map(csv).join(','),
      );
    }
    await _runtime?.writeText('results.csv', '${rows.join('\n')}\n');
    // Only stable AND explicitly audiovisual-checked records enter this export.
    // No export is copied into the production catalogue.
    final approved = records.where(
      (r) =>
          r.preferred != null &&
          r.pictureConfirmed == true &&
          r.soundConfirmed == true,
    );
    String clean(String x) => x.replaceAll(RegExp(r'[\r\n"]'), ' ');
    final playlist = [
      '#EXTM3U',
      '# LAB audiovisual checked; production approval remains separate',
    ];
    for (final r in approved) {
      playlist.add(
        '#EXTINF:-1 group-title="${clean(r.group)}",${clean(r.channelName)}',
      );
      playlist.add(r.channelUrl);
    }
    await _runtime?.writeText(
      'audiovisual-checked.m3u',
      '${playlist.join('\n')}\n',
    );
  }

  Future<void> _export() async {
    await _exportFiles();
    final data = _saved.values.map((r) => r.toJson()).toList();
    await Clipboard.setData(
      ClipboardData(text: const JsonEncoder.withIndent('  ').convert(data)),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Relatório JSON copiado para a área de transferência.'),
        ),
      );
    }
  }

  Future<void> _validate(Channel channel, LabRecord record) async {
    bool picture = record.pictureConfirmed ?? false;
    bool sound = record.soundConfirmed ?? false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: Text('Conferir ${channel.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Confirme apenas após assistir e ouvir no aparelho. '
                'A leitura automática de faixas não comprova imagem nem som.',
              ),
              CheckboxListTile(
                title: const Text('Imagem realmente visível'),
                value: picture,
                onChanged: (v) => refresh(() => picture = v ?? false),
              ),
              CheckboxListTile(
                title: const Text('Áudio realmente audível'),
                value: sound,
                onChanged: (v) => refresh(() => sound = v ?? false),
              ),
            ],
          ),
          actions: [
            if (const bool.fromEnvironment('ROCHA_LAB_ONLY'))
              IconButton(
                tooltip: 'Testar interface, controle e Cast',
                icon: const Icon(Icons.tv),
                onPressed: _current != null
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FeatureLabScreen(),
                        ),
                      ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Salvar verificação'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    final checked = record.withHumanCheck(picture: picture, sound: sound);
    await _results.save(channel, checked);
    if (mounted) {
      setState(() => _saved[PlayerLabResults.keyFor(channel)] = checked);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Rocha+ • Laboratório de players'),
      actions: [
        IconButton(
          tooltip: 'Copiar relatório JSON',
          onPressed: _saved.isEmpty ? null : _export,
          icon: const Icon(Icons.copy_all),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.channels.length} canais • $_completed/$_total nesta execução',
              ),
              const SizedBox(height: 6),
              Text(
                _current == null
                    ? _status
                    : '${_current!.name} — $_status ($_elapsed s)',
              ),
              const SizedBox(height: 8),
              const Text(
                '60 s por player + 180 s de confirmação. Mede avanço, abertura, buffering e travamentos. '
                'Faixas de vídeo/áudio não comprovam imagem visível ou som audível; valide no aparelho.',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<int>(
                    value: [1, 10, 25, 99999].contains(_batchSize)
                        ? _batchSize
                        : 10,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1 canal')),
                      DropdownMenuItem(value: 10, child: Text('10 canais')),
                      DropdownMenuItem(value: 25, child: Text('25 canais')),
                      DropdownMenuItem(value: 99999, child: Text('Todos')),
                    ],
                    onChanged: _running
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _batchSize = value);
                            }
                          },
                  ),
                  FilledButton.icon(
                    onPressed: _running ? null : _start,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Iniciar pendentes'),
                  ),
                  OutlinedButton(
                    onPressed: _running
                        ? () => setState(() => _cancel = true)
                        : null,
                    child: const Text('Parar'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_exo != null || _vlc != null)
          SizedBox(
            key: _videoKey,
            height: 150,
            child: _exo != null
                ? VideoPlayer(_exo!)
                : VlcPlayer(
                    controller: _vlc!,
                    aspectRatio: 16 / 9,
                    placeholder: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
          ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            itemCount: widget.channels.length,
            itemBuilder: (context, index) {
              final channel = widget.channels[index];
              final record = _saved[PlayerLabResults.keyFor(channel)];
              return ListTile(
                dense: true,
                title: Text(channel.name),
                onTap: _running
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AdaptivePlayerScreen(channel: channel),
                        ),
                      ),
                subtitle: Text(
                  record == null
                      ? 'Pendente'
                      : 'Exo ${record.exo.progressSeconds}s / VLC ${record.vlc.progressSeconds}s • '
                            'confirmado ${record.confirmation.progressSeconds}s com ${record.preferred?.label ?? "nenhum"} • '
                            'travamentos ${record.confirmation.stalls} • '
                            'buffer ${(record.confirmation.bufferingMilliseconds / 1000).toStringAsFixed(1)}s',
                ),
                trailing: record == null
                    ? const Text('—')
                    : IconButton(
                        tooltip: 'Verificar imagem e áudio no dispositivo',
                        onPressed: () => _validate(channel, record),
                        icon: Icon(
                          record.pictureConfirmed == true &&
                                  record.soundConfirmed == true
                              ? Icons.verified
                              : Icons.fact_check_outlined,
                          color: RochaColors.playGreen,
                        ),
                      ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
