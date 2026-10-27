import 'dart:async';

import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/auth/playback_permission.dart';
import 'package:rocha_plus/src/cast/cast_channel_loader.dart';
import 'package:rocha_plus/src/cast/cast_failure.dart';
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
  final updates = StreamController<GoggleCastMediaStatus?>.broadcast(sync: true);
  Receiver() { addTearDown(updates.close); }
  @override
  Stream<GoggleCastMediaStatus?> get mediaStatusStream => updates.stream;
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
  test('PLAYING received during LOAD acknowledgement confirms the requested media', () async {
    final receiver = Receiver();
    receiver.onLoad = () async {
      receiver.current = status(CastMediaPlayerState.playing);
    };
    await CastChannelLoader.loadAndConfirm(channel, uri,
        remoteClient: receiver, delay: (_) async {});
    expect(receiver.autoplay, isTrue);
    expect(receiver.plays, 0);
  });

  test('another paused channel cannot trigger PLAY for this LOAD', () async {
    final receiver = Receiver();
    await expectLater(CastChannelLoader.loadAndConfirm(channel, uri,
      remoteClient: receiver,
      delay: (_) async {
        receiver.current = status(CastMediaPlayerState.paused,
            url: 'https://example.test/other.m3u8');
      }), throwsA(isA<TimeoutException>()));
    expect(receiver.plays, 0);
  });

  test('LOAD failure propagates without PLAY or false confirmation', () async {
    final receiver = Receiver();
    receiver.onLoad = () async { throw StateError('LOAD rejected'); };
    await expectLater(CastChannelLoader.loadAndConfirm(channel, uri,
        remoteClient: receiver, delay: (_) async {}), throwsStateError);
    expect(receiver.plays, 0);
  });
  test('a receiver update emitted during LOAD is not lost between polling intervals', () async {
    final receiver = Receiver();
    receiver.onLoad = () async {
      expect(receiver.updates.hasListener, isTrue);
      receiver.updates.add(status(CastMediaPlayerState.playing));
      // Model a stale getter; the event itself is authoritative receiver data.
    };
    await CastChannelLoader.loadAndConfirm(channel, uri,
        remoteClient: receiver, delay: (_) async {});
    expect(receiver.updates.hasListener, isFalse);
    expect(receiver.plays, 0);
  });

  test('receiver error without metadata after requested buffering is a media error', () async {
    final receiver = Receiver();
    receiver.onLoad = () async {
      receiver.updates.add(status(CastMediaPlayerState.buffering));
      receiver.updates.add(GoggleCastMediaStatus(
        mediaSessionID: 1, playerState: CastMediaPlayerState.idle,
        idleReason: GoogleCastMediaIdleReason.error, playbackRate: 1,
        volume: 1, isMuted: false, repeatMode: GoogleCastMediaRepeatMode.off,
      ));
    };
    await expectLater(CastChannelLoader.loadAndConfirm(channel, uri,
      remoteClient: receiver, delay: (_) async {}),
      throwsA(isA<CastFailure>().having((e) => e.kind, 'kind', CastFailureKind.receiver)));
    expect(receiver.updates.hasListener, isFalse);
  });

  test('disconnect during loading prevents PLAY and releases the status subscription', () async {
    final receiver = Receiver();
    var disconnected = false;
    await expectLater(CastChannelLoader.loadAndConfirm(channel, uri,
      remoteClient: receiver,
      ensureCurrent: () {
        if (disconnected) throw CastFailure(CastFailureKind.disconnected);
      },
      delay: (_) async {
        disconnected = true;
        receiver.updates.add(status(CastMediaPlayerState.paused));
      }),
      throwsA(isA<CastFailure>().having((e) => e.kind, 'kind', CastFailureKind.disconnected)));
    expect(receiver.plays, 0);
    expect(receiver.updates.hasListener, isFalse);
  });

  test('status stream errors are consumed and do not become a media timeout', () async {
    final receiver = Receiver();
    receiver.onLoad = () async { receiver.updates.addError(StateError('native transport')); };
    await expectLater(CastChannelLoader.loadAndConfirm(channel, uri,
        remoteClient: receiver, delay: (_) async {}),
        throwsA(isA<CastFailure>().having((e) => e.kind, 'kind', CastFailureKind.disconnected)));
    expect(receiver.updates.hasListener, isFalse);
  });

  test('reconnection retries after a timeout without reusing cached confirmation', () async {
    final receiver = Receiver();
    await expectLater(CastChannelLoader.loadAndConfirm(channel, uri,
        remoteClient: receiver, delay: (_) async {}),
        throwsA(isA<CastConfirmationTimeout>()));
    expect(receiver.updates.hasListener, isFalse);
    receiver.onLoad = () async { receiver.updates.add(status(CastMediaPlayerState.playing)); };
    await CastChannelLoader.loadAndConfirm(channel, uri,
        remoteClient: receiver, delay: (_) async {});
    expect(receiver.updates.hasListener, isFalse);
  });

  test('Cast messages distinguish failures and never echo sensitive exception details', () {
    final messages = [
      castFailureMessage(CastConfirmationTimeout()),
      for (final kind in CastFailureKind.values) castFailureMessage(CastFailure(kind)),
    ];
    expect(messages.toSet(), hasLength(messages.length));
    expect(castFailureMessage(StateError('https://user:secret@example.test/?token=private')),
        isNot(contains('secret')));
    expect(castFailureMessage(StateError('token=private')), isNot(contains('private')));
  });
  test('a later receiver error overrides PLAYING in the same event burst', () async {
    final receiver = Receiver();
    receiver.onLoad = () async {
      receiver.updates.add(status(CastMediaPlayerState.playing));
      receiver.updates.add(status(CastMediaPlayerState.idle,
          reason: GoogleCastMediaIdleReason.error));
    };
    await expectLater(CastChannelLoader.loadAndConfirm(channel, uri,
        remoteClient: receiver, delay: (_) async {}),
        throwsA(isA<CastFailure>().having((e) => e.kind, 'kind', CastFailureKind.receiver)));
    expect(receiver.plays, 0);
    expect(receiver.updates.hasListener, isFalse);
  });

  test('a paused event superseded by error must not send PLAY', () async {
    final receiver = Receiver();
    receiver.onLoad = () async {
      receiver.updates.add(status(CastMediaPlayerState.paused));
      receiver.updates.add(status(CastMediaPlayerState.idle,
          reason: GoogleCastMediaIdleReason.error));
    };
    await expectLater(CastChannelLoader.loadAndConfirm(channel, uri,
        remoteClient: receiver, delay: (_) async {}), throwsStateError);
    expect(receiver.plays, 0);
  });

  test('a paused event superseded by PLAYING needs no extra PLAY', () async {
    final receiver = Receiver();
    receiver.onLoad = () async {
      receiver.updates.add(status(CastMediaPlayerState.paused));
      receiver.updates.add(status(CastMediaPlayerState.playing));
    };
    await CastChannelLoader.loadAndConfirm(channel, uri,
        remoteClient: receiver, delay: (_) async {});
    expect(receiver.plays, 0);
  });

  test('a later different channel cannot inherit an earlier PLAYING confirmation', () async {
    final receiver = Receiver();
    receiver.onLoad = () async {
      receiver.updates.add(status(CastMediaPlayerState.playing));
      receiver.updates.add(status(CastMediaPlayerState.playing,
          url: 'https://example.test/other.m3u8'));
    };
    await expectLater(CastChannelLoader.loadAndConfirm(channel, uri,
        remoteClient: receiver, delay: (_) async {}),
        throwsA(isA<CastConfirmationTimeout>()));
    expect(receiver.plays, 0);
  });

  test('polling cannot append an earlier event after a newer receiver error', () async {
    final receiver = Receiver();
    receiver.onLoad = () async {
      final playing = status(CastMediaPlayerState.playing);
      receiver.updates.add(playing);
      receiver.current = playing;
      receiver.updates.add(status(CastMediaPlayerState.idle,
          reason: GoogleCastMediaIdleReason.error));
    };
    await expectLater(CastChannelLoader.loadAndConfirm(channel, uri,
        remoteClient: receiver, delay: (_) async {}), throwsStateError);
    expect(receiver.plays, 0);
  });

  test('clearing receiver media invalidates an earlier PLAYING event', () async {
    final receiver = Receiver();
    receiver.onLoad = () async {
      receiver.updates.add(status(CastMediaPlayerState.playing));
      receiver.updates.add(null);
    };
    await expectLater(CastChannelLoader.loadAndConfirm(channel, uri,
        remoteClient: receiver, delay: (_) async {}),
        throwsA(isA<CastConfirmationTimeout>()));
    expect(receiver.updates.hasListener, isFalse);
  });
}
