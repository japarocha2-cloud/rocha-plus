import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/live/tv_fullscreen_policy.dart';

void main() {
  test('Android TV navigation opens fullscreen even on smaller displays', () {
    const media = MediaQueryData(
      size: Size(800, 450),
      navigationMode: NavigationMode.directional,
    );
    expect(shouldStartTvFullscreen(media, TargetPlatform.android), isTrue);
  });

  test('large Android TV display has a fallback for traditional navigation', () {
    const media = MediaQueryData(size: Size(960, 540));
    expect(shouldStartTvFullscreen(media, TargetPlatform.android), isTrue);
  });

  test('phone portrait remains in normal player layout', () {
    const media = MediaQueryData(size: Size(412, 915));
    expect(shouldStartTvFullscreen(media, TargetPlatform.android), isFalse);
  });

  test('phone landscape remains in normal player layout', () {
    const media = MediaQueryData(size: Size(915, 412));
    expect(shouldStartTvFullscreen(media, TargetPlatform.android), isFalse);
  });

  test('desktop width alone does not enable Android TV player layout', () {
    const media = MediaQueryData(size: Size(1920, 1080));
    expect(shouldStartTvFullscreen(media, TargetPlatform.windows), isFalse);
  });
}
