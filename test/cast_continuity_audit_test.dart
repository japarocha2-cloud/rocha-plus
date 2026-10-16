// Automated fixtures only: no physical TV, video decoder or live channel.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rocha_plus/src/billing/billing_controller.dart';
import 'package:rocha_plus/src/billing/billing_repository.dart';
import 'package:rocha_plus/src/cast/cast_hls_proxy.dart';

class TimedAccessFixture implements BillingRepository {
  Duration elapsed = Duration.zero;
  final Duration deadline;
  final String state;
  int requests = 0;
  TimedAccessFixture(this.state, this.deadline);
  @override
  Future<BillingAccess> status() async {
    requests++;
    final remaining = deadline - elapsed;
    return BillingAccess(active: remaining > Duration.zero,
      state: remaining > Duration.zero ? state : 'expired',
      remaining: remaining > Duration.zero ? remaining : Duration.zero,
      trialRemainingDays: remaining > Duration.zero ? 1 : 0,
      trialWelcomeNoticeAccepted: true);
  }
  @override
  Future<bool> claimTrialWelcomeNotice() async => false;
  @override
  Future<Uri> checkout(String plan) => throw StateError('No checkout in endurance fixtures');
}

void main() {
  for (final state in ['trial', 'paid']) {
    testWidgets('30 virtual minutes: $state remains allowed through every refresh', (tester) async {
      final repository = TimedAccessFixture(state, const Duration(days: 1));
      final controller = BillingController(repository);
      await controller.initialize();
      for (var minute = 1; minute <= 30; minute++) {
        repository.elapsed = Duration(minutes: minute);
        await tester.pump(const Duration(minutes: 1));
        await tester.pump();
        expect(controller.allowed, isTrue, reason: '$state at virtual minute $minute');
        expect(controller.error, isNull);
      }
      expect(repository.requests, greaterThanOrEqualTo(31));
      controller.dispose();
      await tester.pump();
    });
  }

  testWidgets('virtual server deadline closes access and never creates a new trial', (tester) async {
    final repository = TimedAccessFixture('trial', const Duration(minutes: 10));
    final controller = BillingController(repository);
    await controller.initialize();
    for (var minute = 1; minute <= 12; minute++) {
      repository.elapsed = Duration(minutes: minute);
      await tester.pump(const Duration(minutes: 1));
      await tester.pump();
      expect(controller.allowed, minute < 10, reason: 'virtual minute $minute');
    }
    expect(controller.access!.state, 'expired');
    controller.dispose();
    await tester.pump();
  });

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
