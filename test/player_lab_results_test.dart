import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/live/lab_observer.dart';
import 'package:rocha_plus/src/live/player_lab_results.dart';

LabSample sample(
  LabEngine engine, {
  int progress = 15,
  int stalls = 0,
  String? error,
}) => LabSample(
  engine: engine,
  elapsedSeconds: 60,
  startupMilliseconds: 1200,
  bufferingMilliseconds: 0,
  stalls: stalls,
  progressSeconds: progress,
  videoTrackDetected: true,
  audioTrackDetected: false,
  error: error,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'prefers reproducible playback and rejects inconclusive confirmation',
    () {
      final exo = sample(LabEngine.exoPlayer, progress: 28);
      final vlc = sample(LabEngine.libVlc, progress: 0);
      expect(chooseLabWinner(exo, vlc), LabEngine.exoPlayer);
      final failed = LabRecord(
        channelName: 'Canal',
        channelUrl: 'https://example.org/live',
        group: 'Geral',
        testedAt: DateTime.utc(2026),
        exo: exo,
        vlc: vlc,
        confirmation: sample(LabEngine.exoPlayer, progress: 0),
      );
      expect(failed.preferred, isNull);
    },
  );

  test('observer records buffering and stalled playback separately', () {
    final observer = LabObserver(LabEngine.libVlc);
    observer.observe(
      milliseconds: 0,
      position: Duration.zero,
      playing: true,
      buffering: true,
      videoTrack: false,
      audioTrack: false,
    );
    observer.observe(
      milliseconds: 1000,
      position: Duration.zero,
      playing: true,
      buffering: true,
      videoTrack: false,
      audioTrack: true,
    );
    observer.observe(
      milliseconds: 2000,
      position: Duration.zero,
      playing: true,
      buffering: false,
      videoTrack: true,
      audioTrack: true,
    );
    observer.observe(
      milliseconds: 3000,
      position: const Duration(seconds: 1),
      playing: true,
      buffering: false,
      videoTrack: true,
      audioTrack: true,
    );
    final result = observer.finish(3000);
    expect(result.bufferingMilliseconds, 1000);
    expect(result.stalls, 0);
    expect(result.progressSeconds, 1);
    expect(result.videoTrackDetected, isTrue);
    expect(result.audioTrackDetected, isTrue);
  });

  test(
    'result survives repository reload and keeps separate regional URLs',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repo = PlayerLabResults();
      const a = Channel(name: 'Record', url: 'https://example.org/a');
      const b = Channel(name: 'Record', url: 'https://example.org/b');
      final exo = sample(LabEngine.exoPlayer);
      final vlc = sample(LabEngine.libVlc);
      await repo.save(
        a,
        LabRecord(
          channelName: a.name,
          channelUrl: a.url,
          group: a.group,
          testedAt: DateTime.utc(2026),
          exo: exo,
          vlc: vlc,
          confirmation: vlc,
        ),
      );
      expect(await PlayerLabResults().preferred(a), isNull);
      expect((await PlayerLabResults().read())[a.url]?.vlc.progressSeconds, 15);
      expect(await PlayerLabResults().preferred(b), isNull);
    },
  );
}
