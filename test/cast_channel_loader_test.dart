import 'dart:async';

import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/auth/playback_permission.dart';
import 'package:rocha_plus/src/cast/cast_channel_loader.dart';
import 'package:rocha_plus/src/live/channel.dart';

const channel = Channel(name: 'Fixture', url: 'https://example.test/live.m3u8');
final uri = Uri.parse(channel.url);

GoggleCastMediaStatus status(CastMediaPlayerState state, {
  String url = 'https://example.test/live.m3u8',
  GoogleCastMediaIdleReason? reason,
}) => GoggleCastMediaStatus(
  mediaSessionID: 1,
  playerState: state,
  idleReason: reason,
  playbackRate: 1,
  volume: 1,
  isMuted: false,
  repeatMode: GoogleCastMediaRepeatMode.off,
  mediaInformation: GoogleCastMediaInformation(
    contentId: url,
    contentUrl: Uri.parse(url),
    contentType: 'application/x-mpegURL',
    streamType: CastMediaStreamType.live,
  ),
);

class Receiver extends Fake
    implements GoogleCastRemoteMediaClientPlatformInterface {
  GoggleCastMediaStatus? current;
  bool? autoplay;
  var plays = 0;
  Future<void> Function()? onLoad;

  @override
  GoggleCastMediaStatus? get mediaStatus => current;

  @override
  Future<void> loadMedia(GoogleCastMediaInformation mediaInfo, {
    bool autoPlay = true,
    Duration playPosition = Duration.zero,
    double playbackRate = 1,
    List<int>? activeTrackIds,
    String? credentials,
    String? credentialsType,
    Map<String, dynamic>? customData,
  }) async {
    autoplay = autoPlay;
    await onLoad?.call();
  }

  @override
  Future<void> play() async { plays++; }
}

void main() {
  test('LOAD requests autoplay and never sends PLAY before new media is ready', () async {
    final receiver = Receiver();
    var polls = 0;
    await CastChannelLoader.loadAndConfirm(channel, uri,
      remoteClient: receiver,
      delay: (_) async {
        polls++;
        expect(receiver.plays, 0);
        receiver.current = status(polls < 50
            ? CastMediaPlayerState.buffering : CastMediaPlayerState.playing);
      },
    );
    expect(receiver.autoplay, isTrue);
    expect(polls, 50); // A slow receiver exceeds the former 20-second window.
    expect(receiver.plays, 0);
  });

  test('PLAY is retried once only after the requested media reports paused', () async {
    final receiver = Receiver();
    var polls = 0;
    await CastChannelLoader.loadAndConfirm(channel, uri,
      remoteClient: receiver,
      delay: (_) async {
        polls++;
        receiver.current = status(polls < 4
            ? CastMediaPlayerState.paused : CastMediaPlayerState.playing);
      },
    );
    expect(receiver.plays, 1);
  });

  test('cached same-channel PLAYING cannot confirm a new LOAD', () async {
    final receiver = Receiver()..current = status(CastMediaPlayerState.playing);
    await expectLater(CastChannelLoader.loadAndConfirm(channel, uri,
      remoteClient: receiver, delay: (_) async {}),
      throwsA(isA<TimeoutException>()));
  });

  test('idle without failure and interrupted transitions may finish loading', () async {
    final receiver = Receiver();
    var polls = 0;
    await CastChannelLoader.loadAndConfirm(channel, uri,
      remoteClient: receiver,
      delay: (_) async {
        polls++;
        receiver.current = polls < 3
            ? status(CastMediaPlayerState.idle,
                reason: polls == 1 ? GoogleCastMediaIdleReason.none
                    : GoogleCastMediaIdleReason.interrupted)
            : status(CastMediaPlayerState.playing);
      },
    );
    expect(polls, 3);
  });

  test('receiver error rejects loading and another channel cannot confirm it', () async {
    final receiver = Receiver();
    await expectLater(CastChannelLoader.loadAndConfirm(channel, uri,
      remoteClient: receiver,
      delay: (_) async {
        receiver.current = status(CastMediaPlayerState.playing,
            url: 'https://example.test/other.m3u8');
      }), throwsA(isA<TimeoutException>()));
    await expectLater(CastChannelLoader.loadAndConfirm(channel, uri,
      remoteClient: receiver,
      delay: (_) async {
        receiver.current = status(CastMediaPlayerState.idle,
            reason: GoogleCastMediaIdleReason.error);
      }), throwsStateError);
  });

  test('revocation during receiver loading prevents PLAY and confirmation', () async {
    final permission = PlaybackPermission();
    final owner = permission.protect();
    permission.grant(owner);
    final receiver = Receiver();
    await expectLater(CastChannelLoader.loadAndConfirm(channel, uri,
      permit: permission.acquire(), remoteClient: receiver,
      delay: (_) async {
        permission.revoke(owner);
        receiver.current = status(CastMediaPlayerState.paused);
      }), throwsStateError);
    expect(receiver.plays, 0);
  });
}
