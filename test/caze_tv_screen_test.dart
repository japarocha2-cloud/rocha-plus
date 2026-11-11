import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/screens/caze_tv_screen.dart';

void main() {
  test('CazéTV integration stays on official embedded playback contract', () {
    expect(CazeTvScreen.usesOfficialYouTubeEmbed, isTrue);
    expect(CazeTvScreen.extractsMediaStream, isFalse);
  });

  test('CazéTV accepts only a YouTube-shaped 11 character video id', () {
    expect(CazeTvScreen.isValidVideoId('abcdefghijk'), isTrue);
    expect(CazeTvScreen.isValidVideoId('abc_DEF-123'), isTrue);
    expect(CazeTvScreen.isValidVideoId('https://youtu.be/x'), isFalse);
    expect(CazeTvScreen.isValidVideoId('../playlist'), isFalse);
    expect(CazeTvScreen.isValidVideoId('short'), isFalse);
  });
}
