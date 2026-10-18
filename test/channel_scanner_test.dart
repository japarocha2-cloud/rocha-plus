import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rocha_plus/src/live/channel.dart';
import 'package:rocha_plus/src/live/channel_scanner.dart';

void main() {
  test('credentials never reach the network and restricted responses remain unverified', () async {
    var calls = 0;
    final scanner = ChannelScanner(MockClient((request) async {
      calls++;
      return http.Response('', int.parse(request.url.path.substring(1)));
    }));
    final results = await scanner.scan([
      const Channel(name: 'Credentials', url: 'https://user:pass@example.com/live'),
      for (final status in [401, 403, 429])
        Channel(name: 'Restricted', url: 'https://example.com/$status'),
    ]);
    expect(calls, 3);
    expect(results['https://user:pass@example.com/live'], ChannelReachability.unavailable);
    for (final status in [401, 403, 429]) {
      expect(results['https://example.com/$status'], ChannelReachability.unverified);
    }
  });

  test('scanner limits concurrency and never equates unsupported HEAD to failure', () async {
    var active = 0;
    var peak = 0;
    final scanner = ChannelScanner(MockClient((request) async {
      expect(request.method, 'HEAD');
      active++;
      if (active > peak) peak = active;
      await Future<void>.delayed(const Duration(milliseconds: 1));
      active--;
      final code = int.parse(request.url.path.substring(1));
      return http.Response('', code);
    }));
    final channels = [200, 405, 501, 503, 302, 200].asMap().entries.map(
      (entry) => Channel(name: 'Canal ${entry.key}',
          url: 'https://example.com/${entry.value}', group: 'Geral')).toList();
    final results = await scanner.scan(channels);
    expect(peak, lessThanOrEqualTo(4));
    expect(results['https://example.com/200'], ChannelReachability.reachable);
    expect(results['https://example.com/405'], ChannelReachability.unverified);
    expect(results['https://example.com/503'], ChannelReachability.unavailable);
    expect(results['https://example.com/302'], ChannelReachability.unverified);
  });
  test('invalid URL is rejected and network failure remains unverified', () async {
    var calls = 0;
    final scanner = ChannelScanner(MockClient((request) async {
      calls++;
      throw StateError('offline');
    }));
    final results = await scanner.scan([
      const Channel(name: 'Bad', url: 'https:', group: 'Geral'),
      const Channel(name: 'Offline', url: 'https://example.com/live', group: 'Geral'),
    ]);
    expect(calls, 1);
    expect(results['https:'], ChannelReachability.unavailable);
    expect(results['https://example.com/live'], ChannelReachability.unverified);
  });
}
