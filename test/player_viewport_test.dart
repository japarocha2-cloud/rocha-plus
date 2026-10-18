import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/widgets/player_viewport.dart';

void main() {
  for (final size in [const Size(360, 640), const Size(1920, 1080)]) {
    testWidgets('video keeps aspect ratio and controls keep touch size at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: PlayerViewport(
        aspectRatio: 16 / 9,
        video: const SizedBox(key: Key('video')),
        overlays: const [
          Positioned(right: 8, bottom: 8,
            child: SizedBox(key: Key('control'), width: 48, height: 48)),
        ],
      ))));
      final video = tester.getSize(find.byKey(const Key('video')));
      expect(video.width / video.height, closeTo(16 / 9, .001));
      expect(video.width, lessThanOrEqualTo(size.width));
      expect(video.height, lessThanOrEqualTo(size.height));
      expect(tester.getSize(find.byKey(const Key('control'))), const Size(48, 48));
      expect(tester.takeException(), isNull);
    });
  }
}
