import 'dart:convert';
import 'package:flutter/services.dart';
import '../live/channel.dart';
import '../live/channel_repository.dart';

/// Reads the preserved LAB approval snapshot; never falls back to candidates.
class ApprovedCatalogRepository extends ChannelRepository {
  final Future<String> Function() read;
  ApprovedCatalogRepository({Future<String> Function()? read})
      : read =
            read ?? (() => rootBundle.loadString('branding/lab_approved.json'));

  @override
  Future<List<Channel>> loadBrazilPublicDirectory(
      {bool forceRefresh = false}) async {
    final rows = jsonDecode(await read());
    if (rows is! List) throw const FormatException('Snapshot inválido');
    final channels = <Channel>[];
    for (final row in rows) {
      if (row is! Map ||
          row['status'] != 'automatic_audiovisual_pass' ||
          row['eligible'] != true ||
          row['blocked'] == true) {
        continue;
      }
      final name = row['name'], url = row['url'], group = row['group'];
      if (name is! String || name.isEmpty || url is! String || group is! String) {
        continue;
      }
      final uri = Uri.tryParse(url);
      if (uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        continue;
      }
      final result = row['result'];
      if (result is! Map || result['channelUrl'] != url) continue;
      final preferred = result['preferred'];
      if (!['exoPlayer', 'libVlc'].contains(preferred)) continue;
      final phase = preferred == 'exoPlayer' ? 'exo' : 'vlc';
      bool stable(dynamic sample, String engine, int seconds) =>
          sample is Map &&
          sample['engine'] == engine &&
          sample['error'] == null &&
          sample['elapsedSeconds'] is int &&
          sample['elapsedSeconds'] >= seconds &&
          sample['progressSeconds'] is int &&
          sample['progressSeconds'] >= seconds * 0.8 &&
          sample['progressSeconds'] <= sample['elapsedSeconds'] &&
          sample['startupMilliseconds'] is int &&
          sample['startupMilliseconds'] >= 0 &&
          sample['bufferingMilliseconds'] is int &&
          sample['bufferingMilliseconds'] >= 0 &&
          sample['bufferingMilliseconds'] <= seconds * 100 &&
          sample['stalls'] is int &&
          sample['stalls'] >= 0 &&
          sample['stalls'] <= 3 &&
          sample['videoTrackDetected'] == true;
      if (!stable(result[phase], preferred as String, 60) ||
          !stable(result['confirmation'], preferred, 180)) {
        continue;
      }
      final evidence = result['measuredEvidence'];
      bool observed(String phase) =>
          evidence is Map &&
          evidence[phase] is Map &&
          evidence[phase]['changingPixelsObserved'] == true &&
          evidence[phase]['audioOutputObserved'] == true;
      if (!observed(phase) || !observed('confirmation')) continue;
      channels.add(Channel(
          name: name,
          url: url,
          group: group,
          preferredEngine: preferred,
          logo: row['logo'] is String ? row['logo'] as String : null));
    }
    if (channels.isEmpty) {
      throw const FormatException('Nenhum canal aprovado disponível');
    }
    return List.unmodifiable(channels);
  }

  // Preserve approved rows and order; transient failures do not hide channels.
  @override
  bool isBlocked(Channel channel) => false;
  @override
  bool isQuarantined(String url) => false;
}
