import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/live/player_lab_results.dart';

const channel = Channel(name: 'Regional', url: 'https://example.test/live');

void main() {
  test('explicit engine selection bypasses unavailable local preferences', () async {
    for (final engine in LabEngine.values) {
      final selected = Channel(name: channel.name, url: channel.url,
          preferredEngine: engine.name);
      var reads = 0;
      final actual = await resolvePlaybackEngine(selected, readStored: (_) async {
        reads++;
        throw StateError('preferences unavailable');
      });
      expect(actual, engine);
      expect(reads, 0);
    }
  });

  test('stored engine is respected and an absent preference uses ExoPlayer', () async {
    expect(await resolvePlaybackEngine(channel,
        readStored: (_) async => LabEngine.libVlc), LabEngine.libVlc);
    expect(await resolvePlaybackEngine(channel,
        readStored: (_) async => null), LabEngine.exoPlayer);
  });

  test('a storage error selects ExoPlayer instead of leaving selection pending', () async {
    expect(await resolvePlaybackEngine(channel,
        readStored: (_) async => throw StateError('storage failed')),
        LabEngine.exoPlayer);
  });

  test('a stalled preference read has a bounded wait and late completion cannot replace it', () async {
    final pending = Completer<LabEngine?>();
    final resolved = await resolvePlaybackEngine(channel,
        readStored: (_) => pending.future,
        timeout: const Duration(milliseconds: 1));
    expect(resolved, LabEngine.exoPlayer);
    pending.complete(LabEngine.libVlc);
    await Future<void>.delayed(Duration.zero);
    expect(resolved, LabEngine.exoPlayer);
  });
}
