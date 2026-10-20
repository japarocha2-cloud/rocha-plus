import 'dart:async';

import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../live/channel.dart';
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

  static Future<void> loadAndConfirm(Channel channel, Uri uri) async {
    final media = GoogleCastMediaInformation(
      contentId: uri.toString(),
      contentUrl: uri,
      contentType: contentType(uri),
      streamType: CastMediaStreamType.live,
      metadata: GoogleCastMovieMediaMetadata(title: channel.name),
    );

    await GoogleCastRemoteMediaClient.instance
        .loadMedia(
          media,
          autoPlay: true,
          playPosition: Duration.zero,
          playbackRate: 1.0,
        )
        .timeout(const Duration(seconds: 8));
    await GoogleCastRemoteMediaClient.instance.play().timeout(
      const Duration(seconds: 5),
    );

    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final status = GoogleCastRemoteMediaClient.instance.mediaStatus;
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
      if (matches &&
          state == CastMediaPlayerState.idle &&
          status?.idleReason != null) {
        throw StateError('Receiver entrou em idle: ${status?.idleReason}');
      }
    }

    throw TimeoutException(
      'A TV abriu a sessão, mas não confirmou reprodução real do canal.',
    );
  }

  static Future<String> load(Channel channel, GoogleCastDevice device) async {
    final uri = Uri.parse(channel.url);
    try {
      await loadAndConfirm(channel, uri);
      return uri.toString();
    } catch (_) {
      if (contentType(uri) != 'application/x-mpegURL' ||
          !device.isOnLocalNetwork)
        rethrow;
      final relayUri = await CastHlsProxy.instance.relay(uri);
      await loadAndConfirm(channel, relayUri);
      return relayUri.toString();
    }
  }
}
