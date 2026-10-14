import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/live/m3u_parser.dart';

// Synthetic reviewed evidence is for UI fixtures only, never production admission.
ChannelRepository reviewedFixtureRepository({required http.Client client}) =>
    ChannelRepository(client: client, quarantineLoader: () async => '[]',
      catalogLoader: () async {
        final response = await client.get(ChannelRepository.developmentPlaylist);
        return jsonEncode(M3uParser.parse(utf8.decode(response.bodyBytes)).map((c) => {
          'name': c.name, 'url': c.url, 'logo': c.logo, 'group': c.group,
          'approved': true, 'status': 'approved',
          'evidence': {'decoded_seconds': 30, 'video_codec': 'h264', 'audio_codec': 'aac'},
        }).toList());
      });
