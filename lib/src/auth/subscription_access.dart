import 'dart:convert';
import 'central_rights_runtime.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// A display snapshot from the server, never a locally calculated grant.
class SubscriptionAccessResult {
  final String uid;
  final bool allowed;
  final String? reason;
  final DateTime? expiresAt;
  /// Server clock when the answer was produced, and the device clock when it
  /// arrived. Their difference corrects a wrong device clock in countdowns.
  final DateTime? serverTime;
  final DateTime? receivedAt;

  const SubscriptionAccessResult({
    required this.uid, required this.allowed, this.reason, this.expiresAt,
    this.serverTime, this.receivedAt,
  });

  // Epoch milliseconds accepted from the server only within a sane window.
  static DateTime? _epoch(Object? raw) {
    if (raw is! int) return null;
    final min = DateTime.utc(2020).millisecondsSinceEpoch;
    final max = DateTime.utc(2100).millisecondsSinceEpoch;
    if (raw < min || raw > max) return null;
    return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
  }

  /// Server-confirmed time left, measured on the server clock. Null when the
  /// server did not supply an expiry; never invented locally.
  Duration? remaining(DateTime deviceNow) {
    final end = expiresAt;
    if (end == null) return null;
    final offset = (serverTime != null && receivedAt != null)
        ? serverTime!.difference(receivedAt!)
        : Duration.zero;
    return end.difference(deviceNow.toUtc().add(offset));
  }

  static SubscriptionAccessResult? fromPayload(Object? payload, String uid,
      {DateTime Function()? clock}) {
    if (payload is! Map<String, dynamic> || payload['uid'] != uid ||
        payload['allowed'] is! bool) {
      return null;
    }
    final allowed = payload['allowed'] as bool;
    final suppliedReason = payload['reason'];
    final reason = (allowed && (suppliedReason == 'paid' || suppliedReason == 'trial')) ||
            (!allowed && suppliedReason == 'expired')
        ? suppliedReason as String
        : null;
    // Optional metadata must never invent a trial, paid status or expiration.
    final raw = payload['expiresAt'];
    DateTime? expiresAt;
    if (reason != null && raw is String &&
        RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$')
            .hasMatch(raw)) {
      final offset = RegExp(r'[+-](\d{2}):(\d{2})$').firstMatch(raw);
      final validOffset = offset == null ||
          (int.parse(offset.group(1)!) < 24 && int.parse(offset.group(2)!) < 60);
      final parts = [int.parse(raw.substring(0, 4)),
        int.parse(raw.substring(5, 7)), int.parse(raw.substring(8, 10))];
      final date = DateTime.utc(parts[0], parts[1], parts[2]);
      if (validOffset && date.year == parts[0] && date.month == parts[1] &&
          date.day == parts[2] && int.parse(raw.substring(11, 13)) < 24 &&
          int.parse(raw.substring(14, 16)) < 60 &&
          int.parse(raw.substring(17, 19)) < 60) {
        expiresAt = DateTime.tryParse(raw)?.toUtc();
      }
    }
    // Numeric contract (expiresAtMs/serverTimeMs) wins over the legacy string.
    if (reason != null) expiresAt = _epoch(payload['expiresAtMs']) ?? expiresAt;
    return SubscriptionAccessResult(
        uid: uid, allowed: allowed, reason: reason, expiresAt: expiresAt,
        serverTime: _epoch(payload['serverTimeMs']),
        receivedAt: (clock ?? DateTime.now)().toUtc());
  }

  String get label => switch (reason) {
    'lab' => 'Homologação temporária confirmada pelo servidor',
    'trial' => 'Teste gratuito confirmado pelo servidor',
    'paid' => 'Acesso pago confirmado pelo servidor',
    'expired' => 'Acesso expirado segundo o servidor',
    _ => allowed ? 'Acesso confirmado pelo servidor' : 'Acesso não liberado pelo servidor',
  };
}

/// Authorization remains server-owned; reason and dates are presentation only.
class SubscriptionAccess {
  static const endpoint = String.fromEnvironment('ROCHA_ENTITLEMENT_URL');

  static Future<bool> isAllowed(String uid) async =>
      (await check(uid))?.allowed == true;

  static Future<SubscriptionAccessResult?> check(String uid, {
    http.Client? client,
    Uri? endpointUri,
    Future<String?> Function()? getToken,
    String? Function()? currentUid,
  }) async {
    if (CentralRightsRuntime.enabled) {
      final lease = await CentralRightsRuntime.check(uid);
      return lease == null ? null : SubscriptionAccessResult(
          uid: uid, allowed: true, reason: lease.state, expiresAt: lease.grantUntil);
    }
    final uri = endpointUri ?? Uri.tryParse(endpoint);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty || uri.hasFragment) {
      return null;
    }
    try {
      final readUid = currentUid ?? () => FirebaseAuth.instance.currentUser?.uid;
      final readToken = getToken ?? () async =>
          FirebaseAuth.instance.currentUser?.getIdToken();
      if (readUid() != uid) return null;
      final token = await readToken().timeout(const Duration(seconds: 12));
      if (token == null || token.isEmpty || readUid() != uid) return null;
      final headers = {'Authorization': 'Bearer $token', 'Accept': 'application/json'};
      final response = await (client == null
          ? http.get(uri, headers: headers)
          : client.get(uri, headers: headers)).timeout(const Duration(seconds: 12));
      if (readUid() != uid || response.statusCode != 200) return null;
      return SubscriptionAccessResult.fromPayload(jsonDecode(response.body), uid);
    } catch (_) {
      return null;
    }
  }
}

/// "X dias, XX horas e XX minutos restantes" (whole minutes, never rounded up).
String remainingLabel(Duration left) {
  if (left <= Duration.zero) return 'Teste gratuito encerrado';
  if (left < const Duration(minutes: 1)) return 'Menos de 1 minuto restante';
  final days = left.inDays;
  final hours = left.inHours % 24;
  final minutes = left.inMinutes % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return '$days ${days == 1 ? 'dia' : 'dias'}, ${two(hours)} '
      '${hours == 1 ? 'hora' : 'horas'} e ${two(minutes)} '
      '${minutes == 1 ? 'minuto' : 'minutos'} restantes';
}
