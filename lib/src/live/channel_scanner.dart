import 'dart:async';
import 'package:http/http.dart' as http;
import 'channel.dart';

enum ChannelReachability { reachable, unavailable, unverified }

class ChannelScanner {
  final http.Client client;
  ChannelScanner(this.client);

  // Reachability is distinct from decoder playback and content authorization.
  Future<Map<String, ChannelReachability>> scan(List<Channel> channels) async {
    var next = 0;
    final results = <String, ChannelReachability>{};
    Future<void> worker() async {
      while (next < channels.length) {
        final channel = channels[next++];
        final uri = Uri.tryParse(channel.url);
        if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http') ||
            uri.host.isEmpty || uri.userInfo.isNotEmpty) {
          results[channel.url] = ChannelReachability.unavailable;
          continue;
        }
        try {
          final request = http.Request('HEAD', uri)..followRedirects = false;
          final response = await client.send(request).timeout(const Duration(seconds: 5));
          await response.stream.listen((_) {}).cancel();
          // HEAD is only a reachability hint. Some streaming origins reject
          // HEAD with 404/410/5xx while GET/HLS playback still succeeds.
          // Do not pronounce a stream dead without actual playback evidence.
          results[channel.url] = response.statusCode >= 200 && response.statusCode < 300
              ? ChannelReachability.reachable
              : ChannelReachability.unverified;
        } catch (_) {
          results[channel.url] = ChannelReachability.unverified;
        }
      }
    }
    await Future.wait(List.generate(channels.length < 4 ? channels.length : 4, (_) => worker()));
    return results;
  }
}
