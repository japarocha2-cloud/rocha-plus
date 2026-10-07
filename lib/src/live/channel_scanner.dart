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
        if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
          results[channel.url] = ChannelReachability.unavailable;
          continue;
        }
        try {
          final request = http.Request('HEAD', uri)..followRedirects = false;
          final response = await client.send(request).timeout(const Duration(seconds: 5));
          await response.stream.listen((_) {}).cancel();
          results[channel.url] = response.statusCode >= 200 && response.statusCode < 300
              ? ChannelReachability.reachable
              : (response.statusCode >= 300 && response.statusCode < 400) ||
                      response.statusCode == 405 || response.statusCode == 501
                  ? ChannelReachability.unverified
                  : ChannelReachability.unavailable;
        } catch (_) {
          results[channel.url] = ChannelReachability.unverified;
        }
      }
    }
    await Future.wait(List.generate(channels.length < 4 ? channels.length : 4, (_) => worker()));
    return results;
  }
}
