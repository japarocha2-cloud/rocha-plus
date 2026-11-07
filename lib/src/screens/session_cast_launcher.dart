import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../cast/cast_device_picker.dart';
import '../cast/cast_channel_loader.dart';
import '../cast/cast_failure.dart';
import '../cast/cast_hls_proxy.dart';
import '../cast/cast_readiness.dart';
import '../live/channel_playback_session.dart';
import 'cast_control_screen.dart';

/// Transitional/reconnecting events do not claim a terminal disconnect.
Stream<bool> castConnectionStates() => GoogleCastSessionManager.instance
    .currentSessionStream
    .where(
      (session) =>
          session == null ||
          session.connectionState == GoogleCastConnectState.connected ||
          session.connectionState == GoogleCastConnectState.disconnected,
    )
    .map(
      (session) =>
          session?.connectionState == GoogleCastConnectState.connected,
    );

void closeDisconnectedCastRelay() {
  unawaited(CastHlsProxy.instance.close().catchError((Object _) {}));
}

bool castIsDisconnected() => GoogleCastSessionManager.instance.connectionState ==
    GoogleCastConnectState.disconnected;

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
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Cast indisponível neste aparelho.'),
        ),
      );
    }
    return;
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: CastDevicePicker(
        onSelected: (device) async {
          Navigator.pop(sheet);
          if (!context.mounted) return;
          var sessionConnected = false;
          try {
            final manager = GoogleCastSessionManager.instance;
            if (!await manager
                .startSessionWithDevice(device)
                .timeout(const Duration(seconds: 8))) {
              throw CastFailure(CastFailureKind.connection);
            }
            if (!context.mounted) return;
            if (manager.connectionState != GoogleCastConnectState.connected) {
              await manager.currentSessionStream
                  .firstWhere(
                    (s) =>
                        s?.connectionState == GoogleCastConnectState.connected,
                  )
                  .timeout(const Duration(seconds: 8));
            }
            if (!context.mounted) return;
            sessionConnected = true;
            session.deviceName = device.friendlyName;
            final confirmed = await session.startCasting(
              (channel) => CastChannelLoader.load(channel, device),
              connectionStates: castConnectionStates(),
              isDisconnected: castIsDisconnected,
              onDisconnected: closeDisconnectedCastRelay,
            );
            if (!confirmed || !context.mounted || !session.casting) return;
            await pauseLocal();
            if (!context.mounted || !session.casting) return;
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
            if (manager.connectionState ==
                GoogleCastConnectState.disconnected) {
              session.stopCasting();
            }
          } catch (error) {
            if (error is CastFailure && error.kind == CastFailureKind.superseded) return;
            session.stopCasting();
            try { await CastHlsProxy.instance.close(); } catch (_) { /* cleanup */ }
            try {
              await GoogleCastSessionManager.instance
                  .endSessionAndStopCasting();
            } catch (_) {
              /* original failure */
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(castFailureMessage(sessionConnected
                    ? error : CastFailure(CastFailureKind.connection)))),
              );
            }
          }
        },
      ),
    ),
  );
}
