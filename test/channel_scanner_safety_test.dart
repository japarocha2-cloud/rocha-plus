import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/live/channel_scanner.dart';

void main() {
  const channel = Channel(name: 'Canal demonstrativo', url: 'https://example.org/live.m3u8');

  test('HEAD 404 cannot prove stream playback is unavailable', () async {
    final client = MockClient((request) async {
      expect(request.method, 'HEAD');
      return http.Response('', 404);
    });
    addTearDown(client.close);
    final results = await ChannelScanner(client).scan([channel]);
    expect(results[channel.url], ChannelReachability.unverified);
  });

  test('HEAD 200 is reachability evidence, not decoder approval', () async {
    final client = MockClient((_) async => http.Response('', 200));
    addTearDown(client.close);
    final results = await ChannelScanner(client).scan([channel]);
    expect(results[channel.url], ChannelReachability.reachable);
  });

  test('invalid stream URLs are unavailable without a network request', () async {
    final client = MockClient((_) async => throw StateError('unexpected request'));
    addTearDown(client.close);
    const bad = Channel(name: 'URL inválida', url: 'file:///tmp/test.m3u8');
    final results = await ChannelScanner(client).scan([bad]);
    expect(results[bad.url], ChannelReachability.unavailable);
  });

  test('network errors cannot cause automatic exclusion', () async {
    final client = MockClient((_) async => throw const FormatException('network'));
    addTearDown(client.close);
    final results = await ChannelScanner(client).scan([channel]);
    expect(results[channel.url], ChannelReachability.unverified);
  });
}
