import 'dart:async';

import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../live/channel.dart';
import '../auth/playback_permission.dart';
import 'cast_playback_evidence.dart';
import 'cast_hls_proxy.dart';
import 'cast_failure.dart';

class CastChannelLoader {
  static int _loadRevision = 0;
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
    void Function()? ensureCurrent,
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

    void check() {
      authorization.ensureValid();
      ensureCurrent?.call();
    }

    // Listen before LOAD: a PLAYING or ERROR event may occur while its
    // acknowledgement is pending, or between two polling intervals.
    final updates = <GoggleCastMediaStatus?>[];
    var observationFailed = false;
    final subscription = client.mediaStatusStream.listen((status) {
      if (status == null || !identical(status, previousStatus)) {
        if (updates.length == 64) updates.removeAt(0);
        updates.add(status);
      }
    }, onError: (Object _) {
      observationFailed = true;
    }, onDone: () {
      observationFailed = true;
    });
    var lastPolled = previousStatus;
    var requestedMediaSeen = false;
    var resumedPausedMedia = false;
    try {
      check();
      try {
        await client.loadMedia(media, autoPlay: true,
            playPosition: Duration.zero, playbackRate: 1.0)
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        check();
        throw CastFailure(CastFailureKind.command);
      }
      check();
      for (var i = 0; i < 120; i++) {
        if (delay == null) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        } else {
          await delay(const Duration(milliseconds: 500));
        }
        check();
        if (observationFailed) throw CastFailure(CastFailureKind.disconnected);
        final polled = client.mediaStatus;
        if (!identical(polled, lastPolled) &&
            !updates.any((status) => identical(status, polled))) {
          updates.add(polled);
        }
        lastPolled = polled;
        final batch = List<GoggleCastMediaStatus?>.of(updates);
        updates.clear();
        if (batch.isEmpty) continue;
        // A burst can contain PLAYING followed by ERROR, PAUSED or a
        // different channel. Only its latest observed state may confirm or
        // receive PLAY; an earlier success must not hide a later failure.
        for (final status in batch) {
          final info = status?.mediaInformation;
          if (CastPlaybackEvidence.matches(
              uri.toString(), info?.contentId, info?.contentUrl)) {
            requestedMediaSeen = true;
          }
        }
        final status = batch.last;
        final state = status?.playerState;
        final info = status?.mediaInformation;
        final matches = CastPlaybackEvidence.matches(
            uri.toString(), info?.contentId, info?.contentUrl);
        if (state == CastMediaPlayerState.idle &&
            const {
              GoogleCastMediaIdleReason.error,
              GoogleCastMediaIdleReason.cancelled,
              GoogleCastMediaIdleReason.finished,
            }.contains(status?.idleReason) &&
            (matches || (info == null && requestedMediaSeen))) {
          throw CastFailure(CastFailureKind.receiver);
        }
        if (CastPlaybackEvidence.confirms(
            requested: uri.toString(), contentId: info?.contentId,
            contentUrl: info?.contentUrl,
            playing: state == CastMediaPlayerState.playing)) {
          check();
          return;
        }
        if (matches && state == CastMediaPlayerState.paused &&
            !resumedPausedMedia) {
          check();
          resumedPausedMedia = true;
          try {
            await client.play().timeout(const Duration(seconds: 5));
          } catch (_) {
            check();
            throw CastFailure(CastFailureKind.command);
          }
          check();
        }
      }
      throw CastConfirmationTimeout();
    } finally {
      await subscription.cancel();
    }
  }

  static Future<String> load(Channel channel, GoogleCastDevice device) async {
    final permit = PlaybackPermission.instance.acquire();
    final uri = Uri.parse(channel.url);
    final revision = ++_loadRevision;
    void ensureCurrent() {
      permit.ensureValid();
      if (revision != _loadRevision) throw CastFailure(CastFailureKind.superseded);
      if (GoogleCastSessionManager.instance.connectionState ==
          GoogleCastConnectState.disconnected) {
        throw CastFailure(CastFailureKind.disconnected);
      }
    }
    try {
      await loadAndConfirm(channel, uri, permit: permit,
          ensureCurrent: ensureCurrent);
      return uri.toString();
    } catch (error) {
      ensureCurrent();
      // Lack of confirmation is inconclusive: do not interrupt a possibly
      // loading receiver with a second LOAD through the relay.
      if (error is! CastFailure || error.kind != CastFailureKind.receiver ||
          contentType(uri) != 'application/x-mpegURL' ||
          !device.isOnLocalNetwork) {
        rethrow;
      }
      final relayUri = await CastHlsProxy.instance.relay(uri,
          ensureAuthorized: ensureCurrent);
      ensureCurrent();
      await loadAndConfirm(channel, relayUri, permit: permit,
          ensureCurrent: ensureCurrent);
      return relayUri.toString();
    }
  }
}
