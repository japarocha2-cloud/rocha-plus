// Synthetic local transport only; no physical playback.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rocha_plus/src/cast/cast_hls_proxy.dart';

void main() {
  test('HLS relay carries 300 synthetic six-second segments without losing the session URL', () async {
    var sequence = 0;
    var segments = 0;
    final proxy = CastHlsProxy.testing(
      resolve: (_) async => [InternetAddress('8.8.8.8')],
      client: MockClient((request) async {
        if (request.url.path.endsWith('.m3u8')) {
          return http.Response('#EXTM3U\n#EXT-X-TARGETDURATION:6\n'
            '#EXT-X-MEDIA-SEQUENCE:$sequence\n#EXTINF:6,\nsegment-$sequence.ts\n',
            200, headers: {'content-type': 'application/vnd.apple.mpegurl'});
        }
        segments++;
        return http.Response.bytes([0x47, sequence % 256, 0, 1], 200,
          headers: {'content-type': 'video/mp2t'});
      }),
    );
    final receiver = HttpClient();
    addTearDown(() async { receiver.close(force: true); await proxy.close(); });
    final playlist = await proxy.relay(Uri.parse('https://fixture.example/live.m3u8'));
    for (sequence = 0; sequence < 300; sequence++) {
      final response = await (await receiver.getUrl(playlist)).close();
      expect(response.statusCode, 200);
      final body = await http.ByteStream(response).bytesToString();
      expect(body, contains('#EXT-X-MEDIA-SEQUENCE:$sequence'));
      final segment = Uri.parse(body.split('\n').firstWhere((line) => line.startsWith('http')));
      final media = await (await receiver.getUrl(segment)).close();
      expect(media.statusCode, 200);
      expect(await http.ByteStream(media).toBytes(), [0x47, sequence % 256, 0, 1]);
    }
    expect(segments, 300);
    // 300 * 6 = 1800s of declared media; wall-clock playback was NOT measured.
  });
}
