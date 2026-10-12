import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rocha_plus/src/live/channel_repository.dart';

void main() {
  setUp(ChannelRepository.resetSessionHealthForTests);

  test('strict demo with no approved URLs never requests remote playlists', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response('unexpected', 500);
    });
    final repository = ChannelRepository(
      client: client,
      verifiedOnly: true,
      approvedUrls: {},
    );

    expect(await repository.loadBrazilPublicDirectory(), isEmpty);
    expect(requests, 0);
  });

  test('strict demo remains empty on repeated loads', () async {
    final client = MockClient((request) async {
      fail('Remote channel directory must not be requested');
    });
    final repository = ChannelRepository(
      client: client,
      verifiedOnly: true,
      approvedUrls: {},
    );

    expect(await repository.loadBrazilPublicDirectory(), isEmpty);
    expect(await repository.loadBrazilPublicDirectory(forceRefresh: true), isEmpty);
  });
}
