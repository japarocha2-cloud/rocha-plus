import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../live/channel.dart';
import '../theme/rocha_theme.dart';

class CastControlScreen extends StatefulWidget {
  final Channel channel;
  final String deviceName;

  const CastControlScreen({
    super.key,
    required this.channel,
    required this.deviceName,
  });

  @override
  State<CastControlScreen> createState() => _CastControlScreenState();
}

class _CastControlScreenState extends State<CastControlScreen> {
  bool _busy = false;
  int _tab = 0;

  Future<void> _togglePlayback() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final isPlaying =
          GoogleCastRemoteMediaClient.instance.mediaStatus?.playerState ==
              CastMediaPlayerState.playing;
      if (isPlaying) {
        await GoogleCastRemoteMediaClient.instance.pause();
      } else {
        await GoogleCastRemoteMediaClient.instance.play();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _seekBy(int seconds) async {
    if (_busy) return;
    final current = GoogleCastRemoteMediaClient.instance.playerPosition;
    final target = current + Duration(seconds: seconds);
    final safe = target.isNegative ? Duration.zero : target;
    try {
      await GoogleCastRemoteMediaClient.instance.seek(
        GoogleCastMediaSeekOption(position: safe),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este canal ao vivo não permite avançar ou voltar.'),
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await GoogleCastSessionManager.instance.endSessionAndStopCasting();
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logo = widget.channel.logo;
    return StreamBuilder<GoggleCastMediaStatus?>(
      stream: GoogleCastRemoteMediaClient.instance.mediaStatusStream,
      initialData: GoogleCastRemoteMediaClient.instance.mediaStatus,
      builder: (context, snapshot) {
        final status = snapshot.data;
        final state = status?.playerState;
        final isPlaying = state == CastMediaPlayerState.playing;
        final isConnected = state == CastMediaPlayerState.playing ||
            state == CastMediaPlayerState.paused ||
            state == CastMediaPlayerState.buffering ||
            state == CastMediaPlayerState.loading;
        final statusText = switch (state) {
          CastMediaPlayerState.playing => 'Transmitindo agora',
          CastMediaPlayerState.paused => 'Pausado na TV',
          CastMediaPlayerState.buffering => 'Carregando na TV',
          CastMediaPlayerState.loading => 'Abrindo na TV',
          _ => 'Sem reprodução confirmada',
        };

        return Scaffold(
          backgroundColor: RochaColors.background,
          body: SafeArea(
            child: Column(
              children: [
                _TopBar(
                  onBack: () => Navigator.of(context).pop(),
                  onDisconnect: _disconnect,
                  isConnected: isConnected,
                ),
                _Tabs(
                  index: _tab,
                  onChanged: (value) => setState(() => _tab = value),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: switch (_tab) {
                      1 => _DetailsTab(channel: widget.channel),
                      2 => _ControlsTab(
                          deviceName: widget.deviceName,
                          isPlaying: isPlaying,
                          busy: _busy,
                          statusText: statusText,
                          onTogglePlayback: _togglePlayback,
                          onBack10: () => _seekBy(-10),
                          onForward10: () => _seekBy(10),
                          onDisconnect: _disconnect,
                        ),
                      _ => _LiveTab(
                          channel: widget.channel,
                          deviceName: widget.deviceName,
                          logo: logo,
                          isPlaying: isPlaying,
                          isConnected: isConnected,
                          statusText: statusText,
                          busy: _busy,
                          onTogglePlayback: _togglePlayback,
                          onBack10: () => _seekBy(-10),
                          onForward10: () => _seekBy(10),
                          onDisconnect: _disconnect,
                        ),
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
  final VoidCallback onBack;
  final VoidCallback onDisconnect;
  final bool isConnected;

  const _TopBar({
    required this.onBack,
    required this.onDisconnect,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 4),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Voltar',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, size: 30),
            ),
            const Spacer(),
            const _RochaWordmark(),
            const Spacer(),
            IconButton(
              tooltip: 'Transmitindo',
              onPressed: null,
              icon: Icon(
                isConnected ? Icons.cast_connected : Icons.cast,
                color: isConnected ? RochaColors.playGreen : Colors.white38,
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'disconnect') onDisconnect();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'disconnect',
                  child: Text('Desconectar da TV'),
                ),
              ],
            ),
          ],
        ),
      );
}

class _RochaWordmark extends StatelessWidget {
  const _RochaWordmark();

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            '♛',
            style: TextStyle(
              color: RochaColors.gold,
              fontSize: 16,
              height: .9,
            ),
          ),
          Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              children: [
                TextSpan(
                  text: 'Rocha',
                  style: TextStyle(color: RochaColors.gold),
                ),
                TextSpan(
                  text: '+',
                  style: TextStyle(color: RochaColors.playGreen),
                ),
              ],
            ),
          ),
        ],
      );
}

class _Tabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _Tabs({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = ['Ao vivo', 'Detalhes', 'Controles'];
    return Row(
      children: List.generate(
        labels.length,
        (i) => Expanded(
          child: InkWell(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: index == i ? RochaColors.playGreen : Colors.white12,
                    width: index == i ? 3 : 1,
                  ),
                ),
              ),
              child: Text(
                labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: index == i ? Colors.white : Colors.white54,
                  fontWeight: index == i ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveTab extends StatelessWidget {
  final Channel channel;
  final String deviceName;
  final String? logo;
  final bool isPlaying;
  final bool isConnected;
  final String statusText;
  final bool busy;
  final VoidCallback onTogglePlayback;
  final VoidCallback onBack10;
  final VoidCallback onForward10;
  final VoidCallback onDisconnect;

  const _LiveTab({
    required this.channel,
    required this.deviceName,
    required this.logo,
    required this.isPlaying,
    required this.isConnected,
    required this.statusText,
    required this.busy,
    required this.onTogglePlayback,
    required this.onBack10,
    required this.onForward10,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        child: Column(
          children: [
            _TvHero(channel: channel),
            const SizedBox(height: 22),
            const Icon(
              Icons.cast_connected,
              color: RochaColors.playGreen,
              size: 40,
            ),
            const SizedBox(height: 8),
            const Text(
              'Transmitindo para',
              style: TextStyle(color: Colors.white60, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              deviceName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: RochaColors.playGreen,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            _ConnectedPill(isConnected: isConnected, statusText: statusText),
            const SizedBox(height: 24),
            _ContentCard(channel: channel, logo: logo),
            const SizedBox(height: 24),
            Row(
              children: const [
                Text('AO VIVO', style: TextStyle(color: RochaColors.playGreen, fontWeight: FontWeight.w900)),
                SizedBox(width: 10),
                Expanded(child: Divider(color: Colors.white24)),
              ],
            ),
            const SizedBox(height: 18),
            _PlaybackControls(
              isPlaying: isPlaying,
              busy: busy,
              onTogglePlayback: onTogglePlayback,
              onBack10: onBack10,
              onForward10: onForward10,
            ),
            const SizedBox(height: 24),
            _DeviceCard(
              deviceName: deviceName,
              statusText: statusText,
              onDisconnect: onDisconnect,
            ),
          ],
        ),
      );
}

class _TvHero extends StatelessWidget {
  final Channel channel;
  const _TvHero({required this.channel});

  @override
  Widget build(BuildContext context) => Container(
        height: 210,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF151024),
              Color(0xFF07130C),
              Color(0xFF020204),
            ],
          ),
          border: Border.all(color: Colors.white12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3316F34A),
              blurRadius: 32,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: -30,
              top: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x225A20A8),
                ),
              ),
            ),
            Positioned(
              right: -20,
              bottom: -40,
              child: Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x2216F34A),
                ),
              ),
            ),
            Center(
              child: Container(
                margin: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.black87,
                  border: Border.all(color: RochaColors.gold.withValues(alpha: .5)),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.play_circle_fill_rounded,
                        color: RochaColors.playGreen,
                        size: 72,
                      ),
                      const SizedBox(height: 10),
                      const _RochaWordmark(),
                      const SizedBox(height: 6),
                      Text(
                        channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _ConnectedPill extends StatelessWidget {
  final bool isConnected;
  final String statusText;

  const _ConnectedPill({
    required this.isConnected,
    required this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    final color = isConnected ? RochaColors.playGreen : Colors.orangeAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        border: Border.all(color: color.withValues(alpha: .55)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 9, color: color),
          const SizedBox(width: 8),
          Text(statusText, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  final Channel channel;
  final String? logo;

  const _ContentCard({required this.channel, required this.logo});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0B141C),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [RochaColors.cosmicPurple, Colors.black],
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: logo == null || logo!.isEmpty
                  ? const Icon(Icons.live_tv, size: 48, color: RochaColors.playGreen)
                  : Image.network(
                      logo!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.live_tv,
                        size: 48,
                        color: RochaColors.playGreen,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    channel.group,
                    style: const TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      _Chip('Ao vivo'),
                      _Chip('Rocha+'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: RochaColors.gold.withValues(alpha: .7)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: const TextStyle(color: RochaColors.gold, fontSize: 12),
        ),
      );
}

class _PlaybackControls extends StatelessWidget {
  final bool isPlaying;
  final bool busy;
  final VoidCallback onTogglePlayback;
  final VoidCallback onBack10;
  final VoidCallback onForward10;

  const _PlaybackControls({
    required this.isPlaying,
    required this.busy,
    required this.onTogglePlayback,
    required this.onBack10,
    required this.onForward10,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _RoundAction(
            icon: Icons.replay_10_rounded,
            onPressed: onBack10,
          ),
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF082113),
              border: Border.all(color: RochaColors.playGreen, width: 2),
              boxShadow: const [
                BoxShadow(color: Color(0x6616F34A), blurRadius: 24),
              ],
            ),
            child: IconButton(
              tooltip: isPlaying ? 'Pausar' : 'Reproduzir',
              onPressed: busy ? null : onTogglePlayback,
              iconSize: 42,
              icon: busy
                  ? const CircularProgressIndicator(color: RochaColors.playGreen)
                  : Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
            ),
          ),
          _RoundAction(
            icon: Icons.forward_10_rounded,
            onPressed: onForward10,
          ),
        ],
      );
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _RoundAction({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) => Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0C1720),
          border: Border.all(color: Colors.white12),
        ),
        child: IconButton(onPressed: onPressed, icon: Icon(icon, size: 30)),
      );
}

class _DeviceCard extends StatelessWidget {
  final String deviceName;
  final String statusText;
  final VoidCallback onDisconnect;

  const _DeviceCard({
    required this.deviceName,
    required this.statusText,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0B141C),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            const Icon(Icons.tv_rounded, color: RochaColors.playGreen, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deviceName,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    statusText,
                    style: const TextStyle(color: RochaColors.playGreen),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: onDisconnect,
              icon: const Icon(Icons.cast_connected),
              label: const Text('Desconectar'),
            ),
          ],
        ),
      );
}

class _DetailsTab extends StatelessWidget {
  final Channel channel;
  const _DetailsTab({required this.channel});

  @override
  Widget build(BuildContext context) => ListView(
        key: const ValueKey('details'),
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.live_tv, size: 72, color: RochaColors.playGreen),
          const SizedBox(height: 20),
          Text(
            channel.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Text(
            channel.group,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 26),
          const Text(
            'Canal ao vivo sendo transmitido pela Rocha+. A reprodução e o estado da sessão ficam sincronizados com a TV enquanto o Cast estiver conectado.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
        ],
      );
}

class _ControlsTab extends StatelessWidget {
  final String deviceName;
  final bool isPlaying;
  final bool busy;
  final String statusText;
  final VoidCallback onTogglePlayback;
  final VoidCallback onBack10;
  final VoidCallback onForward10;
  final VoidCallback onDisconnect;

  const _ControlsTab({
    required this.deviceName,
    required this.isPlaying,
    required this.busy,
    required this.statusText,
    required this.onTogglePlayback,
    required this.onBack10,
    required this.onForward10,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) => ListView(
        key: const ValueKey('controls'),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 30),
          Text(
            deviceName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            statusText,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 38),
          _PlaybackControls(
            isPlaying: isPlaying,
            busy: busy,
            onTogglePlayback: onTogglePlayback,
            onBack10: onBack10,
            onForward10: onForward10,
          ),
          const SizedBox(height: 42),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF231017),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(54),
            ),
            onPressed: onDisconnect,
            icon: const Icon(Icons.cast_connected),
            label: const Text('Desconectar da TV'),
          ),
        ],
      );
}
