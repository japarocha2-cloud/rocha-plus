import 'dart:convert';
import 'package:http/http.dart' as http;
import 'channel.dart';
import 'm3u_parser.dart';

class ChannelRepository {
  static final Uri developmentPlaylist =
      Uri.parse('https://iptv-org.github.io/iptv/countries/br.m3u');

  Future<List<Channel>> loadBrazilPublicDirectory() async {
    final res = await http.get(developmentPlaylist).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Não foi possível carregar o catálogo.');
    }
    return M3uParser.parse(utf8.decode(res.bodyBytes));
  }
}
