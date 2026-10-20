import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'channel.dart';

enum LabEngine { exoPlayer, libVlc }

extension LabEngineLabel on LabEngine {
  String get label => this == LabEngine.exoPlayer ? 'ExoPlayer' : 'LibVLC';
}

/// These are observations from player APIs, not proof of audible sound or
/// rendered frames. Physical playback still requires human/device validation.
class LabSample {
  final LabEngine engine;
  final int elapsedSeconds;
  final int startupMilliseconds;
  final int bufferingMilliseconds;
  final int stalls;
  final int progressSeconds;
  final bool videoTrackDetected;
  final bool audioTrackDetected;
  final String? error;

  const LabSample({
    required this.engine,
    required this.elapsedSeconds,
    required this.startupMilliseconds,
    required this.bufferingMilliseconds,
    required this.stalls,
    required this.progressSeconds,
    required this.videoTrackDetected,
    required this.audioTrackDetected,
    this.error,
  });

  bool get hasProgress => progressSeconds > 0;
  bool stableFor(int seconds) =>
      elapsedSeconds >= seconds &&
      progressSeconds >= seconds * 0.8 &&
      videoTrackDetected &&
      error == null &&
      bufferingMilliseconds <= seconds * 100 &&
      stalls <= 3;
  double get score =>
      (hasProgress ? 100 : 0) +
      (videoTrackDetected ? 12 : 0) +
      (audioTrackDetected ? 8 : 0) +
      progressSeconds * 2 -
      bufferingMilliseconds / 1000 -
      stalls * 10 -
      startupMilliseconds / 1000 -
      (error == null ? 0 : 100);

  Map<String, dynamic> toJson() => {
    'engine': engine.name,
    'elapsedSeconds': elapsedSeconds,
    'startupMilliseconds': startupMilliseconds,
    'bufferingMilliseconds': bufferingMilliseconds,
    'stalls': stalls,
    'progressSeconds': progressSeconds,
    'videoTrackDetected': videoTrackDetected,
    'audioTrackDetected': audioTrackDetected,
    'error': error,
  };

  factory LabSample.fromJson(Map<String, dynamic> value) => LabSample(
    engine: LabEngine.values.byName(value['engine'] as String),
    elapsedSeconds: value['elapsedSeconds'] as int,
    startupMilliseconds: value['startupMilliseconds'] as int,
    bufferingMilliseconds: value['bufferingMilliseconds'] as int,
    stalls: value['stalls'] as int,
    progressSeconds: value['progressSeconds'] as int,
    videoTrackDetected: value['videoTrackDetected'] as bool,
    audioTrackDetected: value['audioTrackDetected'] as bool,
    error: value['error'] as String?,
  );
}

class LabRecord {
  final String channelName;
  final String channelUrl;
  final String group;
  final DateTime testedAt;
  final LabSample exo;
  final LabSample vlc;
  final LabSample confirmation;
  final bool? pictureConfirmed;
  final bool? soundConfirmed;

  const LabRecord({
    required this.channelName,
    required this.channelUrl,
    required this.group,
    required this.testedAt,
    required this.exo,
    required this.vlc,
    required this.confirmation,
    this.pictureConfirmed,
    this.soundConfirmed,
  });

  /// An inconclusive test must not override the working production player.
  LabEngine? get preferred =>
      confirmation.stableFor(180) ? confirmation.engine : null;

  LabRecord withHumanCheck({required bool picture, required bool sound}) =>
      LabRecord(
        channelName: channelName,
        channelUrl: channelUrl,
        group: group,
        testedAt: testedAt,
        exo: exo,
        vlc: vlc,
        confirmation: confirmation,
        pictureConfirmed: picture,
        soundConfirmed: sound,
      );

  Map<String, dynamic> toJson() => {
    'channelName': channelName,
    'channelUrl': channelUrl,
    'group': group,
    'testedAt': testedAt.toIso8601String(),
    'exo': exo.toJson(),
    'vlc': vlc.toJson(),
    'confirmation': confirmation.toJson(),
    'pictureConfirmed': pictureConfirmed,
    'soundConfirmed': soundConfirmed,
    'preferred': preferred?.name,
    'status': preferred == null
        ? 'failed_or_inconclusive'
        : (pictureConfirmed == true && soundConfirmed == true
              ? 'audiovisual_checked'
              : 'awaiting_audiovisual_evidence'),
    'productionApproved': false,
  };

  factory LabRecord.fromJson(Map<String, dynamic> data) => LabRecord(
    channelName: data['channelName'] as String,
    channelUrl: data['channelUrl'] as String,
    group: data['group'] as String,
    testedAt: DateTime.parse(data['testedAt'] as String),
    exo: LabSample.fromJson(Map<String, dynamic>.from(data['exo'] as Map)),
    vlc: LabSample.fromJson(Map<String, dynamic>.from(data['vlc'] as Map)),
    confirmation: LabSample.fromJson(
      Map<String, dynamic>.from(data['confirmation'] as Map),
    ),
    pictureConfirmed: data['pictureConfirmed'] as bool?,
    soundConfirmed: data['soundConfirmed'] as bool?,
  );
}

class PlayerLabResults {
  static const _key = 'rocha_player_lab_v1';

  /// URL disambiguates equally named regional signals and mirrors source changes.
  static String keyFor(Channel channel) => channel.url.trim();

  Future<Map<String, LabRecord>> read() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = jsonDecode(prefs.getString(_key) ?? '{}') as Map;
      final records = <String, LabRecord>{};
      for (final entry in raw.entries) {
        try {
          records[entry.key as String] = LabRecord.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        } on Object {
          // Preserve other channels when one legacy record is malformed.
          continue;
        }
      }
      return records;
    } catch (_) {
      return {};
    }
  }

  Future<void> save(Channel channel, LabRecord record) async {
    final existing = await read();
    existing[keyFor(channel)] = record;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(existing.map((key, value) => MapEntry(key, value.toJson()))),
    );
  }

  Future<LabEngine?> preferred(Channel channel) async =>
      (await read())[keyFor(channel)]?.preferred;
}

LabEngine chooseLabWinner(LabSample exo, LabSample vlc) {
  if (!vlc.hasProgress && exo.hasProgress) return LabEngine.exoPlayer;
  if (!exo.hasProgress && vlc.hasProgress) return LabEngine.libVlc;
  return vlc.score > exo.score ? LabEngine.libVlc : LabEngine.exoPlayer;
}
