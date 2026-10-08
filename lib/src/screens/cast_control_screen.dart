import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import '../live/channel.dart';
import '../theme/rocha_theme.dart';
import '../widgets/rocha_artwork.dart';

class CastControlScreen extends StatefulWidget {
  final Channel channel;
  final String deviceName;
  final String? confirmedContentId;
  const CastControlScreen({super.key, required this.channel,
    required this.deviceName, required this.confirmedContentId});
  @override
  State<CastControlScreen> createState() => _CastControlScreenState();
}

class _CastControlScreenState extends State<CastControlScreen> {
  bool busy = false;
  Future<void> _action(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try { await action(); }
    catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível enviar o comando para a TV.')));
      }
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => StreamBuilder<GoggleCastMediaStatus?>(
    stream: GoogleCastRemoteMediaClient.instance.mediaStatusStream,
    initialData: GoogleCastRemoteMediaClient.instance.mediaStatus,
    builder: (context, snapshot) {
      final status = snapshot.data;
      final state = status?.playerState;
      final matches = widget.confirmedContentId != null &&
          status?.mediaInformation?.contentId == widget.confirmedContentId;
      final connected = GoogleCastSessionManager.instance.connectionState ==
          GoogleCastConnectState.connected && matches;
      final playing = connected && state == CastMediaPlayerState.playing;
      final label = !connected ? 'Sem reprodução confirmada' : switch (state) {
        CastMediaPlayerState.playing => 'Transmitindo agora',
        CastMediaPlayerState.paused => 'Pausado na TV',
        CastMediaPlayerState.buffering => 'Carregando na TV',
        CastMediaPlayerState.loading => 'Abrindo na TV',
        _ => 'Sem reprodução confirmada',
      };
      return CastControlView(
        channel: widget.channel, deviceName: widget.deviceName,
        status: label, connected: connected, playing: playing, busy: busy,
        onBack: () => Navigator.pop(context),
        onToggle: () => _action(() async {
          if (playing) { await GoogleCastRemoteMediaClient.instance.pause(); }
          else { await GoogleCastRemoteMediaClient.instance.play(); }
        }),
        onDisconnect: () => _action(() async {
          await GoogleCastSessionManager.instance.endSessionAndStopCasting();
          if (context.mounted) { Navigator.pop(context); }
        }),
      );
    },
  );
}

/// Native controls over approved illustrative artwork; no simulated stream or duration.
class CastControlView extends StatefulWidget {
  final Channel channel;
  final String deviceName;
  final String status;
  final bool connected;
  final bool playing;
  final bool busy;
  final VoidCallback onBack;
  final VoidCallback onToggle;
  final VoidCallback onDisconnect;
  const CastControlView({super.key, required this.channel, required this.deviceName,
    required this.status, required this.connected, required this.playing, this.busy = false,
    required this.onBack, required this.onToggle, required this.onDisconnect});
  @override
  State<CastControlView> createState() => _CastControlViewState();
}
class _CastControlViewState extends State<CastControlView> {
  int tab = 0;

  Widget _artwork() => const AspectRatio(aspectRatio: 16 / 9,
    child: ClipRRect(borderRadius: BorderRadius.all(Radius.circular(18)),
      child: RochaArtwork(room: true,
        region: Rect.fromLTRB(0, .155, 1, .418))));

  Widget _deviceSummary() => Column(children: [
    Icon(Icons.tv_outlined, color: widget.connected
      ? RochaColors.playGreen : Colors.white38, size: 44),
    const SizedBox(height: 8),
    Text(widget.connected ? 'Transmitindo para' : 'Dispositivo',
      style: const TextStyle(color: Colors.white60)),
    const SizedBox(height: 5),
    Text(widget.deviceName, textAlign: TextAlign.center, style: const TextStyle(
      color: RochaColors.playGreen, fontSize: 26, fontWeight: FontWeight.w900)),
    const SizedBox(height: 12),
    Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(30),
        color: const Color(0xFF072116),
        border: Border.all(color: RochaColors.playGreen.withValues(alpha: .35))),
      child: Text(widget.status, textAlign: TextAlign.center,
        style: TextStyle(color: widget.connected ? RochaColors.playGreen : Colors.white54))),
  ]);

  Widget _channelInfo() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: const Color(0xFF0A141B),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white12)),
    child: Row(children: [
      SizedBox(width: 70, height: 80, child: widget.channel.logo == null
        ? const Icon(Icons.live_tv, color: RochaColors.playGreen, size: 40)
        : Image.network(widget.channel.logo!, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.live_tv,
              color: RochaColors.playGreen, size: 40))),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.channel.name, maxLines: 3, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(widget.channel.group, style: const TextStyle(color: RochaColors.gold)),
        const SizedBox(height: 8),
        const Text('Canal ao vivo', style: TextStyle(color: Colors.white54)),
      ])),
    ]),
  );

  Widget _controls() => Column(children: [
    const SizedBox(height: 28),
    const Row(children: [
      Text('AO VIVO', style: TextStyle(color: RochaColors.playGreen,
        fontWeight: FontWeight.w800)),
      SizedBox(width: 12),
      Expanded(child: Divider(color: Color(0xFF16F34A))),
    ]),
    const SizedBox(height: 20),
    Container(width: 92, height: 92,
      decoration: BoxDecoration(shape: BoxShape.circle,
        color: const Color(0xFF072015),
        border: Border.all(color: RochaColors.playGreen, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x6616F34A), blurRadius: 28)]),
      child: IconButton(
        autofocus: true,
        tooltip: widget.playing ? 'Pausar na TV' : 'Reproduzir na TV',
        onPressed: widget.busy || !widget.connected ? null : widget.onToggle,
        iconSize: 48, icon: Icon(widget.playing ? Icons.pause : Icons.play_arrow))),
    const SizedBox(height: 26),
  ]);

  Widget _details() => Column(children: [
    _deviceSummary(),
    const SizedBox(height: 22),
    if (tab != 2) _channelInfo(),
    if (tab != 1) _controls(),
    OutlinedButton.icon(
      onPressed: widget.busy ? null : widget.onDisconnect,
      icon: const Icon(Icons.cast_connected),
      label: const Text('Desconectar da TV'),
      style: OutlinedButton.styleFrom(foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18))),
  ]);

  /// TV: content and controls sit side by side. Phone: the same controls stack
  /// vertically. Tabs, Cast session state and actions are deliberately unchanged.
  Widget _responsiveContent(BoxConstraints constraints) {
    final wide = constraints.maxWidth >= 900;
    return SingleChildScrollView(
      key: const ValueKey('cast-scroll'),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          child: wide && tab == 0
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 5, child: _artwork()),
                const SizedBox(width: 24),
                Expanded(flex: 4, child: _details()),
              ])
            : Column(children: [
                if (tab == 0) _artwork(),
                if (tab == 0) const SizedBox(height: 18),
                _details(),
              ]),
        ),
      )),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF040B10),
    body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          IconButton(tooltip: 'Voltar', onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back)),
          const Expanded(child: SizedBox(height: 62, child: RochaWordmark())),
          Icon(widget.connected ? Icons.cast_connected : Icons.cast,
            color: widget.connected ? RochaColors.playGreen : Colors.white38),
          const SizedBox(width: 16),
        ])),
      Row(children: List.generate(3, (i) => Expanded(child: InkWell(
        onTap: () => setState(() => tab = i),
        child: Container(padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(
            width: tab == i ? 3 : 1,
            color: tab == i ? RochaColors.playGreen : Colors.white12))),
          child: Text(['Ao vivo', 'Detalhes', 'Controles'][i],
            textAlign: TextAlign.center,
            style: TextStyle(color: tab == i ? Colors.white : Colors.white54,
              fontWeight: FontWeight.w700))))))),
      Expanded(child: LayoutBuilder(builder: (context, constraints) =>
        _responsiveContent(constraints))),
    ])),
  );
}
