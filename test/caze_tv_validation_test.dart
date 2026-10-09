import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rocha_plus/src/sports/caze_tv_validation.dart';

void main() {
  Map<String, dynamic> metadata(String author) => {
    'type': 'video', 'provider_name': 'YouTube', 'author_url': author,
  };

  test('accepts only exact official publisher URLs', () {
    expect(CazeTvValidation.isOfficialAuthor('https://www.youtube.com/@CazeTV'), isTrue);
    expect(CazeTvValidation.isOfficialAuthor(
      'https://www.youtube.com/channel/UCZiYbVptd3PVPf4f6eR6UaQ'), isTrue);
    for (final url in [
      'https://www.youtube.com/@CazeTVfake',
      'https://www.youtube.com.evil.test/@CazeTV',
      'https://evil.test/@CazeTV',
      'http://www.youtube.com/@CazeTV',
      'https://user@www.youtube.com/@CazeTV',
      'https://www.youtube.com/@CazeTV?other=1',
    ]) {
      expect(CazeTvValidation.isOfficialAuthor(url), isFalse, reason: url);
    }
  });

  test('validates metadata on YouTube and does not request media', () async {
    final client = MockClient((request) async {
      expect(request.url.scheme, 'https');
      expect(request.url.host, 'www.youtube.com');
      expect(request.url.path, '/oembed');
      expect(request.url.queryParameters['url'],
        'https://www.youtube.com/watch?v=abcdefghijk');
      return http.Response(jsonEncode(metadata(
        'https://www.youtube.com/@CazeTV')), 200);
    });
    addTearDown(client.close);
    expect(await CazeTvValidation.verify('abcdefghijk', client: client), isTrue);
  });

  test('fails closed for wrong author, unavailable and malformed responses', () async {
    for (final response in [
      http.Response(jsonEncode(metadata('https://www.youtube.com/@someone')), 200),
      http.Response('{}', 200),
      http.Response('invalid json', 200),
      http.Response('unavailable', 404),
      http.Response('denied', 403),
    ]) {
      final client = MockClient((_) async => response);
      expect(await CazeTvValidation.verify('abcdefghijk', client: client), isFalse);
      client.close();
    }
  });

  test('invalid identifiers never cause a request; network failures are unavailable', () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      throw http.ClientException('offline');
    });
    addTearDown(client.close);
    expect(await CazeTvValidation.verify('../playlist', client: client), isFalse);
    expect(requests, 0);
    expect(await CazeTvValidation.verify('abcdefghijk', client: client), isFalse);
    expect(requests, 1);
  });
}
