import 'dart:convert';
import 'package:http/http.dart' as http;

class CentralLease {
  final String uid, device, state;
  final bool playbackAllowed;
  final Duration duration;
  final DateTime grantUntil;
  CentralLease(this.uid, this.device, this.state, this.playbackAllowed,
      this.duration, this.grantUntil);

  static CentralLease? parse(dynamic p, {required String uid,
      required String device, required String scope, required int elapsedMs}) {
    if (p is! Map<String, dynamic> || p['contractVersion'] != 1 ||
        p['environment'] != 'central-rights-lab' || p['uid'] != uid ||
        p['device_id'] != device || p['scope'] != scope ||
        p['active'] != true || p['allowed'] != true || elapsedMs < 0 ||
        !(scope == 'homologation' ? p['state'] == 'lab'
            : scope == 'commercial' && ['paid', 'trial'].contains(p['state']))) {
      return null;
    }
    final start = p['serverTime'], end = p['accessUntil'], grant = p['grantUntil'];
    if (start is! int || end is! int || grant is! int || start <= 0 ||
        grant < end || end - start > 60000 || end - start - elapsedMs <= 0) {
      return null;
    }
    return CentralLease(uid, device, p['state'] as String,
        p['playbackAllowed'] == true,
        Duration(milliseconds: end - start - elapsedMs),
        DateTime.fromMillisecondsSinceEpoch(grant, isUtc: true));
  }
}

/// Token source and persistence are supplied by the authenticated app, never UI JSON.
class CentralRightsClient {
  final Uri endpoint;
  final String uid, mobileId, scope;
  final Future<String?> Function() getIdToken;
  final String? Function() currentUid;
  final http.Client httpClient;
  String? sessionToken, tvDevice, userCode, deviceCode;
  CentralRightsClient({required this.endpoint, required this.uid,
    required this.mobileId, required this.getIdToken, required this.currentUid,
    required this.httpClient, this.scope = 'homologation'});

  Future<({Map<String, dynamic> data, int elapsed})> request(
      String action, {bool tv = false, Map<String, dynamic> extra = const {}}) async {
    if (endpoint.scheme != 'https' || endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty || endpoint.hasFragment || currentUid() != uid) {
      throw StateError('Serviço central indisponível.');
    }
    final clock = Stopwatch()..start();
    final token = tv ? sessionToken : await getIdToken();
    if (currentUid() != uid || (!tv && (token == null || token.isEmpty))) {
      throw StateError('Entre novamente para confirmar o acesso.');
    }
    final req = http.Request('POST', endpoint)..followRedirects = false;
    req.headers['Content-Type'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.body = jsonEncode({'action': action, if (!tv) 'mobile_id': mobileId, ...extra});
    final response = await http.Response.fromStream(await httpClient.send(req)
        .timeout(const Duration(seconds: 12))).timeout(const Duration(seconds: 12));
    if (currentUid() != uid || response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Não foi possível confirmar o acesso (${response.statusCode}).');
    }
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) throw StateError('Resposta inválida.');
    return (data: data, elapsed: clock.elapsedMilliseconds);
  }

  Future<void> registerMobile() async {
    await request('register_mobile');
  }
  Future<CentralLease?> status({bool tv = false, bool playback = false}) async {
    try {
      final r = await request(tv ? 'status' : playback ? 'mobile_playback' : 'entitlement',
          tv: tv, extra: tv ? {'playback_active': playback} : const {});
      final device = tv ? tvDevice : 'mobile';
      if (device == null) return null;
      final lease = CentralLease.parse(r.data, uid: uid, device: device,
          scope: scope, elapsedMs: r.elapsed);
      return playback && lease?.playbackAllowed != true ? null : lease;
    } catch (_) { return null; }
  }
  Future<void> stop({bool tv = false}) async {
    try { await request(tv ? 'status' : 'mobile_stop', tv: tv,
        extra: tv ? {'playback_active': false} : const {}); } catch (_) { /* lease expires */ }
  }
  Future<String> startTvPairing() async {
    final r = await request('start', tv: true);
    if (r.data['environment'] != 'central-rights-lab' ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch('${r.data['device_code']}') ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch('${r.data['device_id']}') ||
        !RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$').hasMatch('${r.data['user_code']}')) {
      throw StateError('Código de TV inválido.');
    }
    deviceCode = r.data['device_code'] as String;
    tvDevice = r.data['device_id'] as String;
    return userCode = r.data['user_code'] as String;
  }
  Future<CentralLease?> pollTvPairing() async {
    if (deviceCode == null || tvDevice == null) return null;
    final r = await request('poll', tv: true, extra: {'device_code': deviceCode});
    if (r.data['status'] == 'pending') return null;
    final lease = CentralLease.parse(r.data, uid: uid, device: tvDevice!,
        scope: scope, elapsedMs: r.elapsed);
    if (lease == null || !RegExp(r'^[a-f0-9]{64}$').hasMatch('${r.data['session_token']}')) {
      throw StateError('Sessão da TV inválida.');
    }
    sessionToken = r.data['session_token'] as String;
    return lease;
  }
  Future<void> approveTv(String code) async {
    if (!RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$').hasMatch(code)) {
      throw ArgumentError('Código inválido.');
    }
    await request('approve', extra: {'user_code': code});
  }
}
