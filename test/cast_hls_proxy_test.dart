import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rocha_plus/src/cast/cast_hls_proxy.dart';

void main() {
  Future<List<InternetAddress>> publicDns(String _) async => [InternetAddress('8.8.8.8')];

  test('relay rewrites variants, keys and segments and forwards original bytes', () async {
    final seen = <String>[];
    final proxy = CastHlsProxy.testing(resolve: publicDns, client: MockClient((request) async {
      seen.add(request.url.toString());
      if (request.url.path.endsWith('master.m3u8')) {
        return http.Response('#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=8000000\nvariant.m3u8\n',
            200, headers: {'content-type': 'application/vnd.apple.mpegurl'});
      }
      if (request.url.path.endsWith('variant.m3u8')) {
        return http.Response('#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI="key.bin"\n#EXTINF:6,\nseg.ts\n',
            200, headers: {'content-type': 'application/vnd.apple.mpegurl'});
      }
      return http.Response.bytes([0, 1, 2, 255], 206,
          headers: {'content-type': 'video/mp2t', 'content-range': 'bytes 0-3/4'});
    }));
    final client = HttpClient();
    addTearDown(() async { client.close(force: true); await proxy.close(); });
    final master = await proxy.relay(Uri.parse('https://media.example/live/master.m3u8'));
    final masterResponse = await (await client.getUrl(master)).close();
    final masterBody = await http.ByteStream(masterResponse).bytesToString();
    expect(masterResponse.headers.value('Access-Control-Allow-Origin'), '*');
    expect(masterBody, contains('BANDWIDTH=8000000'));
    final variant = Uri.parse(masterBody.split('\n').firstWhere((l) => l.startsWith('http')));
    final variantResponse = await (await client.getUrl(variant)).close();
    final body = await http.ByteStream(variantResponse).bytesToString();
    expect(body, isNot(contains('https://media.example')));
    final segment = Uri.parse(body.split('\n').firstWhere((l) => l.startsWith('http')));
    final request = await client.getUrl(segment);
    request.headers.set('Range', 'bytes=0-3');
    final segmentResponse = await request.close();
    expect(segmentResponse.statusCode, 206);
    expect(await http.ByteStream(segmentResponse).toBytes(), [0, 1, 2, 255]);
    final key = Uri.parse(RegExp(r'URI="([^"]+)"').firstMatch(body)!.group(1)!);
    expect((await (await client.getUrl(key)).close()).statusCode, 206);
    expect(seen, containsAll([
      'https://media.example/live/master.m3u8',
      'https://media.example/live/variant.m3u8',
      'https://media.example/live/seg.ts',
      'https://media.example/live/key.bin',
    ]));
    final unknown = master.replace(queryParameters: {'id': 'invalid'});
    expect((await (await client.getUrl(unknown)).close()).statusCode, 404);
    await proxy.close();
    final freshClient = HttpClient();
    addTearDown(() => freshClient.close(force: true));
    await expectLater(freshClient.getUrl(master).then((request) => request.close()),
        throwsA(isA<IOException>()));
  });

  test('relay refuses insecure sources, credentials and private DNS destinations', () async {
    final proxy = CastHlsProxy.testing(client: MockClient((_) async => http.Response('', 200)),
        resolve: (_) async => [InternetAddress('192.168.1.1')]);
    addTearDown(proxy.close);
    for (final source in ['http://example.com/live', 'https://u:p@example.com/live',
        'https://router.example/live']) {
      await expectLater(proxy.relay(Uri.parse(source)), throwsStateError);
    }
  });

  test('relay validates redirects and resolves relative paths at the final location', () async {
    final proxy = CastHlsProxy.testing(resolve: publicDns, client: MockClient((request) async {
      if (request.url.path == '/master.m3u8') {
        return http.Response('', 302, headers: {'location': '/new/master.m3u8'});
      }
      if (request.url.path == '/blocked.m3u8') {
        return http.Response('', 302, headers: {'location': 'http://example.com/unsafe'});
      }
      return http.Response('#EXTM3U\nseg.ts\n', 200);
    }));
    final client = HttpClient();
    addTearDown(() async { client.close(force: true); await proxy.close(); });
    final url = await proxy.relay(Uri.parse('https://media.example/master.m3u8'));
    final response = await (await client.getUrl(url)).close();
    final body = await http.ByteStream(response).bytesToString();
    expect(body, contains('/hls?id='));
    final blocked = await proxy.relay(Uri.parse('https://media.example/blocked.m3u8'));
    expect((await (await client.getUrl(blocked)).close()).statusCode, 502);
  });
}
