import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../cast/cast_device_picker.dart';
import '../cast/cast_channel_loader.dart';
import '../cast/cast_hls_proxy.dart';
import '../cast/cast_readiness.dart';
import '../live/channel_playback_session.dart';
import 'cast_control_screen.dart';

Future<void> launchSessionCast(
  BuildContext context,
  ChannelPlaybackSession session, {
  required Future<void> Function() pauseLocal,
}) async {
  if (session.busy) return;
  if (session.casting) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CastControlScreen(
          channel: session.current,
          session: session,
          deviceName: session.deviceName ?? 'TV',
          confirmedContentId: session.confirmedContentId,
        ),
      ),
    );
    return;
  }
  if (!await CastReadiness.ready) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Cast indisponível neste aparelho.'),
        ),
      );
    return;
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: CastDevicePicker(
        onSelected: (device) async {
          Navigator.pop(sheet);
          try {
            final manager = GoogleCastSessionManager.instance;
            if (!await manager
                .startSessionWithDevice(device)
                .timeout(const Duration(seconds: 8))) {
              throw StateError('Sessão Cast recusada');
            }
            if (manager.connectionState != GoogleCastConnectState.connected) {
              await manager.currentSessionStream
                  .firstWhere(
                    (s) =>
                        s?.connectionState == GoogleCastConnectState.connected,
                  )
                  .timeout(const Duration(seconds: 8));
            }
            session.deviceName = device.friendlyName;
            await session.startCasting(
              (channel) => CastChannelLoader.load(channel, device),
            );
            await pauseLocal();
            if (!context.mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CastControlScreen(
                  channel: session.current,
                  session: session,
                  deviceName: device.friendlyName,
                  confirmedContentId: session.confirmedContentId,
                ),
              ),
            );
            if (manager.connectionState == GoogleCastConnectState.disconnected)
              session.stopCasting();
          } catch (_) {
            session.stopCasting();
            await CastHlsProxy.instance.close();
            try {
              await GoogleCastSessionManager.instance
                  .endSessionAndStopCasting();
            } catch (_) {
              /* original failure */
            }
            if (context.mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'A TV não confirmou a reprodução. Tente novamente.',
                  ),
                ),
              );
          }
        },
      ),
    ),
  );
}
