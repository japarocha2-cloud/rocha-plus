import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'subscription_access.dart';

/// Device / simultaneous-playback limits (1 phone, 2 TVs, 2 streams).
/// The server decides; this client only asks and obeys. Off unless the build
/// passes `--dart-define=ROCHA_DEVICE_LIMITS=true`.
const deviceLimitsEnabled = bool.fromEnvironment('ROCHA_DEVICE_LIMITS');

enum DeviceKind { phone, tv }

/// Heuristic until a native Android TV (leanback) check exists. Phones have a
/// shortest logical side of ~360-430; a 1080p Android TV reports 960x540, so
/// 480 separates them. Tablets (600+) are counted as TVs.
DeviceKind deviceKindFor(double shortestLogicalSide) =>
    shortestLogicalSide >= 480 ? DeviceKind.tv : DeviceKind.phone;

/// HTTP status and JSON body; status 0 means the server could not be reached.
class DeviceResponse {
  final int status;
  final Map<String, Object?> body;
  const DeviceResponse(this.status, [this.body = const {}]);
  static const unreachable = DeviceResponse(0);
}

typedef DevicePost = Future<DeviceResponse> Function(String route, Map<String, Object?> body);

class LeaseOutcome {
  final bool granted;
  final String? message;
  const LeaseOutcome.granted() : granted = true, message = null;
  const LeaseOutcome.denied(this.message) : granted = false;
}

/// User-facing text for a server refusal. Unknown errors stay generic.
String deviceLimitMessage(DeviceResponse response) {
  if (response.status == 0) {
    return 'Não foi possível confirmar o limite de aparelhos. Confira a conexão e tente novamente.';
  }
  final error = response.body['error'];
  return switch (error) {
    'Phone limit reached' => 'Esta conta já tem 1 celular cadastrado. Este é o limite do plano.',
    'TV limit reached' => 'Esta conta já tem 2 TVs cadastradas. Este é o limite do plano.',
    'Concurrent stream limit reached' =>
      'Esta conta já está assistindo em 2 aparelhos. Encerre uma reprodução para assistir aqui.',
    'Device change limit reached' => 'Limite de trocas de aparelho atingido neste mês.',
    'Entitlement required' => 'Acesso não liberado pelo servidor.',
    'Stream lease expired' => 'A reprodução foi encerrada pelo servidor. Tente novamente.',
    _ => 'Reprodução não autorizada neste aparelho no momento.',
  };
}

/// One playback lease: register device, start, renew by heartbeat, stop.
class StreamLease {
  final DevicePost post;
  final Future<String> Function() deviceId;
  StreamLease({required this.post, required this.deviceId});

  /// Called once when an active lease is lost (refused or not renewed in time).
  void Function(String message)? onLost;

  String? _streamId;
  String? _device;
  Timer? _timer;
  // Heartbeats run 3 times per lease; 3 unreachable in a row = lease elapsed.
  static const _missedHeartbeatsPerLease = 3;
  int _missed = 0;
  Duration _lease = const Duration(seconds: 90);
  bool _heartbeatInFlight = false;
  bool _stopped = false;

  bool get active => _streamId != null;

  Future<LeaseOutcome> start(DeviceKind kind) async {
    if (_stopped) return const LeaseOutcome.denied(null);
    if (active) return const LeaseOutcome.granted();
    final id = _device ??= await deviceId();
    final registered = await post('devices/register', {'deviceId': id, 'kind': kind.name});
    if (registered.status != 200) return LeaseOutcome.denied(deviceLimitMessage(registered));
    if (_stopped) return const LeaseOutcome.denied(null);
    final started = await post('streams/start', {'deviceId': id});
    final streamId = started.body['streamId'];
    if (started.status != 200 || streamId is! String) {
      return LeaseOutcome.denied(deviceLimitMessage(started));
    }
    if (_stopped) {
      // The player closed while the server was granting: give the slot back.
      await post('streams/stop', {'streamId': streamId});
      return const LeaseOutcome.denied(null);
    }
    final seconds = started.body['leaseSeconds'];
    if (seconds is num && seconds >= 15) _lease = Duration(milliseconds: (seconds * 1000).round());
    _streamId = streamId;
    _missed = 0;
    _timer?.cancel();
    // Renew three times per lease so one lost heartbeat does not end playback.
    _timer = Timer.periodic(_lease ~/ _missedHeartbeatsPerLease, (_) => unawaited(_heartbeat()));
    return const LeaseOutcome.granted();
  }

  Future<void> _heartbeat() async {
    final streamId = _streamId;
    if (streamId == null || _heartbeatInFlight) return;
    _heartbeatInFlight = true;
    try {
      final response = await post('streams/heartbeat', {'deviceId': _device, 'streamId': streamId});
      if (_streamId != streamId) return;
      if (response.status == 200) {
        _missed = 0;
      } else if (const {401, 403, 409}.contains(response.status)) {
        _lose(deviceLimitMessage(response)); // explicit refusal: stop now
      } else if (++_missed >= _missedHeartbeatsPerLease) {
        // Offline or transient 5xx/429: keep playing only while the last
        // server lease is still valid.
        _lose(deviceLimitMessage(DeviceResponse.unreachable));
      }
    } finally {
      _heartbeatInFlight = false;
    }
  }

  void _lose(String message) {
    _clear();
    onLost?.call(message);
  }

  void _clear() {
    _timer?.cancel();
    _timer = null;
    _streamId = null;
    _missed = 0;
  }

  /// Releases the slot for good (also one granted later by a pending start).
  /// Best effort: an unreachable server frees it when the lease expires.
  Future<void> stop() async {
    _stopped = true;
    final streamId = _streamId;
    _clear();
    if (streamId != null) await post('streams/stop', {'streamId': streamId});
  }

  /// Real client for builds with the feature on and an HTTPS entitlement URL.
  static StreamLease? production() {
    if (!deviceLimitsEnabled) return null;
    final base = Uri.tryParse(SubscriptionAccess.endpoint);
    if (base == null || base.scheme != 'https' || base.host.isEmpty ||
        !base.path.endsWith('/entitlement')) {
      if (kDebugMode) debugPrint('Rocha+ device limits: ROCHA_ENTITLEMENT_URL must be https://…/entitlement');
      return null;
    }
    return StreamLease(post: (route, body) => _post(base.resolve(route), body),
        deviceId: installId);
  }

  static Future<DeviceResponse> _post(Uri uri, Map<String, Object?> body) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken()
          .timeout(const Duration(seconds: 12));
      if (token == null || token.isEmpty) return DeviceResponse.unreachable;
      final response = await http.post(uri, headers: {
        'Authorization': 'Bearer $token', 'Content-Type': 'application/json',
        'Accept': 'application/json',
      }, body: jsonEncode(body)).timeout(const Duration(seconds: 12));
      final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
      return DeviceResponse(response.statusCode,
          decoded is Map<String, Object?> ? decoded : const {});
    } catch (_) {
      return DeviceResponse.unreachable;
    }
  }

  /// Random per-install ID; reinstalling the app creates a new one.
  static Future<String> installId() async {
    const key = 'rocha.deviceInstallId';
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(key);
    if (existing != null && RegExp(r'^[A-Za-z0-9_-]{16,128}$').hasMatch(existing)) return existing;
    final random = Random.secure();
    final id = base64UrlEncode(List<int>.generate(24, (_) => random.nextInt(256)))
        .replaceAll('=', '');
    await prefs.setString(key, id);
    return id;
  }
}
