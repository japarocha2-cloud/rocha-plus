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

  test('WebView identifies the installed Rocha+ Android application', () {
    final referrer = Uri.parse(CazeTvSource.appHttpReferer);
    expect(referrer.scheme, 'https');
    expect(referrer.host, 'com.rochaplus.app');
    expect(referrer.path, '/');
  });

  test('unconfigured source does not invent a transmission', () {
    if (CazeTvSource.configuredVideoId.isEmpty) {
      expect(CazeTvSource.officialVideoId, isNull);
      expect(CazeTvSource.embedUri, isNull);
    }
  });

  test('configured source only produces a YouTube HTTPS embed', () {
    final uri = CazeTvSource.embedUri;
    if (uri == null) return;
    expect(uri.scheme, 'https');
    expect(uri.host, 'www.youtube.com');
    expect(uri.path, '/embed/${CazeTvSource.officialVideoId}');
    expect(uri.queryParameters['controls'], '1');
    expect(uri.queryParameters['playsinline'], '1');
  });
}
