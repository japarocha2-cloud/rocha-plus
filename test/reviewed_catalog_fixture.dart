import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rocha_plus/src/live/channel_repository.dart';
import 'package:rocha_plus/src/live/m3u_parser.dart';

// Convert each test's local M3U fixture to explicit reviewed entries.
// Production never fetches these fixture playlists.
ChannelRepository reviewedFixtureRepository({required http.Client client}) =>
    ChannelRepository(client: client, catalogLoader: () async {
      final response = await client.get(ChannelRepository.developmentPlaylist);
      return jsonEncode(M3uParser.parse(utf8.decode(response.bodyBytes))
          .map((c) => {'name': c.name, 'url': c.url, 'logo': c.logo,
            'group': c.group, 'approved': true, 'status': 'approved'}).toList());
    });
