import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/sports/caze_tv_source.dart';

void main() {
  test('rejects URLs and malformed values', () {
    expect(CazeTvSource.isValidVideoId('abcdefghijk'), isTrue);
    expect(CazeTvSource.isValidVideoId('abc_DEF-123'), isTrue);
    expect(CazeTvSource.isValidVideoId('https://youtube.com/watch?v=x'), isFalse);
    expect(CazeTvSource.isValidVideoId('../playlist'), isFalse);
    expect(CazeTvSource.isValidVideoId(''), isFalse);
  });

  test('unconfigured source does not invent a transmission', () {
    if (CazeTvSource.configuredVideoId.isEmpty) {
      expect(CazeTvSource.officialVideoId, isNull);
      expect(CazeTvSource.embedUri, isNull);
    }
  });
}
