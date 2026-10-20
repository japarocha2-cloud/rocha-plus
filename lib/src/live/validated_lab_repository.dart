import 'dart:convert';

import 'package:flutter/services.dart';

import 'channel.dart';
import 'lab_runtime.dart';
import 'channel_repository.dart';
import 'catalog_presentation.dart';
import 'player_lab_results.dart';

/// Only the evidence-approved snapshot feeds the feature laboratory UI.
/// Never falls back to live candidate lists when this asset is empty.
class ValidatedLabRepository extends ChannelRepository {
  ValidatedLabRepository({Future<String> Function()? read})
    : _read = read ?? _readSnapshot;
  static Future<String> _readSnapshot() async {
    final runtime = await LabRuntime.open();
    final imported = await runtime?.read('validated-catalog.json');
    if (imported != null && imported['channels'] is List) {
      return jsonEncode(imported['channels']);
    }
    return rootBundle.loadString('branding/lab_approved.json');
  }

  final Future<String> Function() _read;
  @override
  Future<List<Channel>> loadBrazilPublicDirectory({
    bool forceRefresh = false,
  }) async {
    final raw = jsonDecode(await _read()) as List;
    final channels = <String, Channel>{};
    for (final value in raw) {
      try {
        final row = Map<String, dynamic>.from(value as Map);
        if (row['status'] != 'automatic_audiovisual_pass' ||
            row['blocked'] == true ||
            row['eligible'] != true) {
          continue;
        }
        final result = Map<String, dynamic>.from(row['result'] as Map);
        final record = LabRecord.fromJson(result);
        final confirmation =
            (result['measuredEvidence'] as Map)['confirmation'] as Map;
        if (record.preferred == null ||
            confirmation['changingPixelsObserved'] != true ||
            confirmation['audioOutputObserved'] != true ||
            record.channelUrl != row['url']) {
          continue;
        }
        final channel = Channel(
          name: row['name'] as String,
          url: row['url'] as String,
          logo: row['logo'] as String?,
          group: repositoryCategory(row['group'] as String),
          genres: (row['genres'] as List? ?? const [])
              .whereType<String>()
              .toList(),
          preferredEngine: record.preferred?.name,
        );
        final uri = Uri.tryParse(channel.url);
        if (uri == null ||
            !['http', 'https'].contains(uri.scheme) ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty ||
            isBlocked(channel) ||
            isQuarantined(channel.url)) {
          continue;
        }
        channels.putIfAbsent(channel.url, () => channel);
      } on Object {
        continue;
      }
    }
    return popularChannelsFirst(channels.values);
  }
}
