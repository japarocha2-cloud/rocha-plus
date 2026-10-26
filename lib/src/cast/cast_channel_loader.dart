import 'dart:async';

import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../live/channel.dart';
import '../auth/playback_permission.dart';
import 'cast_playback_evidence.dart';
import 'cast_hls_proxy.dart';

class CastChannelLoader {
  static String contentType(Uri uri) {
    final path = uri.path.toLowerCase();
    if (path.endsWith('.m3u8') || path.endsWith('.m3u')) {
      return 'application/x-mpegURL';
    }
    if (path.endsWith('.mpd')) return 'application/dash+xml';
    if (path.endsWith('.webm')) return 'video/webm';
    if (path.endsWith('.mp4') || path.endsWith('.m4v')) return 'video/mp4';
    // URLs without an extension in the Rocha+ live catalogue are normally HLS.
    return 'application/x-mpegURL';
  }

  static Future<void> loadAndConfirm(Channel channel, Uri uri, {
    PlaybackPermit? permit,
    GoogleCastRemoteMediaClientPlatformInterface? remoteClient,
    Future<void> Function(Duration)? delay,
  }) async {
    final authorization = permit ?? PlaybackPermission.instance.acquire();
    authorization.ensureValid();
    final client = remoteClient ?? GoogleCastRemoteMediaClient.instance;
    final previousStatus = client.mediaStatus;
    final media = GoogleCastMediaInformation(
      contentId: uri.toString(),
      contentUrl: uri,
      contentType: contentType(uri),
      streamType: CastMediaStreamType.live,
      metadata: GoogleCastMovieMediaMetadata(title: channel.name),
    );

    // The plugin acknowledges sending LOAD before the receiver finishes it.
    // Autoplay belongs in LOAD: an immediate separate PLAY can target the old
    // media session or arrive while the receiver still has no media to play.
    await client
        .loadMedia(
          media,
          autoPlay: true,
          playPosition: Duration.zero,
          playbackRate: 1.0,
        )
        .timeout(const Duration(seconds: 8));
    authorization.ensureValid();

    var resumedPausedMedia = false;
    for (var i = 0; i < 120; i++) {
      if (delay == null) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      } else {
        await delay(const Duration(milliseconds: 500));
      }
      authorization.ensureValid();
      final status = client.mediaStatus;
      // A cached status from before LOAD cannot confirm this request or reject
      // it with the idle reason of a previous attempt on the same channel.
      if (identical(status, previousStatus)) continue;
      final state = status?.playerState;
      final info = status?.mediaInformation;
      final matches = CastPlaybackEvidence.matches(
        uri.toString(),
        info?.contentId,
        info?.contentUrl,
      );
      if (CastPlaybackEvidence.confirms(
        requested: uri.toString(),
        contentId: info?.contentId,
        contentUrl: info?.contentUrl,
        playing: state == CastMediaPlayerState.playing,
      )) {
        return;
      }
      if (matches && state == CastMediaPlayerState.paused &&
          !resumedPausedMedia) {
        resumedPausedMedia = true;
        await client.play().timeout(const Duration(seconds: 5));
        authorization.ensureValid();
      }
      if (matches &&
          state == CastMediaPlayerState.idle &&
          const {
            GoogleCastMediaIdleReason.error,
            GoogleCastMediaIdleReason.cancelled,
            GoogleCastMediaIdleReason.finished,
          }.contains(status?.idleReason)) {
        throw StateError('Receiver entrou em idle: ${status?.idleReason}');
      }
    }

    throw TimeoutException(
      'A TV abriu a sessão, mas não confirmou reprodução real do canal.',
    );
  }

  static Future<String> load(Channel channel, GoogleCastDevice device) async {
    final permit = PlaybackPermission.instance.acquire();
    final uri = Uri.parse(channel.url);
    try {
      await loadAndConfirm(channel, uri, permit: permit);
      return uri.toString();
    } catch (_) {
      permit.ensureValid();
      if (contentType(uri) != 'application/x-mpegURL' ||
          !device.isOnLocalNetwork) {
        rethrow;
      }
      final relayUri = await CastHlsProxy.instance.relay(uri,
          ensureAuthorized: permit.ensureValid);
      permit.ensureValid();
      await loadAndConfirm(channel, relayUri, permit: permit);
      return relayUri.toString();
    }
  }
}
