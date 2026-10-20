import 'dart:convert';

import 'package:flutter/services.dart';

import 'channel.dart';
import 'channel_identity.dart';
import 'lab_runtime.dart';
import 'channel_blocks.dart';
import 'channel_repository.dart';

/// A generated, auditable candidate snapshot. Never imported by production.
Future<List<Channel>> loadLabCatalog() async {
  final config = await LabRuntime.configuration();
  if (config['fixture'] == true) {
    return const [
      Channel(
        name: 'LAB controlled A/V fixture',
        url: 'http://10.0.2.2:8765/fixture.mp4',
        group: 'LAB',
      ),
      Channel(
        name: 'LAB deliberate HTTP 404',
        url: 'http://10.0.2.2:8765/not-found.m3u8',
        group: 'LAB',
      ),
    ];
  }
  final offset = config['offset'] as int? ?? 0;
  final limit = config['limit'] as int? ?? 0;
  final raw = await rootBundle.loadString('branding/lab_candidates.json');
  final rows = jsonDecode(raw) as List;
  final userBlocked = await ChannelBlocks().load();
  final repo = ChannelRepository();
  final seen = <String>{};
  final channels = <Channel>[];
  for (final value in rows) {
    final row = Map<String, dynamic>.from(value as Map);
    if (row['eligible'] != true || row['blocked'] == true) continue;
    final channel = Channel(
      name: row['name'] as String,
      url: row['url'] as String,
      group: row['group'] as String? ?? 'Outros',
      logo: row['logo'] as String?,
    );
    if (repo.isBlocked(channel) || !seen.add(channel.url)) continue;
    // Persistent blocks are normally loaded by ChannelRepository's remote path.
    // This loader does not use that path, so honor them explicitly.
    if (userBlocked.contains(channelIdentity(channel.name))) continue;
    channels.add(channel);
  }
  final selected = channels.skip(offset);
  return (limit > 0 ? selected.take(limit) : selected).toList();
}
