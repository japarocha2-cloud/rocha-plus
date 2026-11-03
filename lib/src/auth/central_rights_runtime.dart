import 'dart:math';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'central_rights_client.dart';

/// Opt-in only. Never used by the frozen APKs or the original branch.
class CentralRightsRuntime {
  static const enabled = bool.fromEnvironment('ROCHA_CENTRAL_RIGHTS', defaultValue: false);
  static const isTv = String.fromEnvironment('ROCHA_CENTRAL_DEVICE_KIND') == 'tv';
  static const url = String.fromEnvironment('ROCHA_CENTRAL_RIGHTS_URL');
  static const scope = String.fromEnvironment('ROCHA_CENTRAL_RIGHTS_SCOPE', defaultValue: 'homologation');
  static Future<CentralRightsClient>? _client;
  static String? _uid;
  static bool tvPaired = false;
  static Future<CentralRightsClient> client(String uid) {
    if (!enabled) throw StateError('Cliente central desativado.');
    if (_uid != uid) { _uid = uid; _client = null; tvPaired = false; }
    return _client ??= _create(uid);
  }
  static Future<CentralRightsClient> _create(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('central-lab-mobile-id');
    if (id == null || !RegExp(r'^[a-f0-9]{64}$').hasMatch(id)) {
      final random = Random.secure();
      id = List.generate(32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      await prefs.setString('central-lab-mobile-id', id);
    }
    final result = CentralRightsClient(endpoint: Uri.parse(url), uid: uid, mobileId: id,
        scope: scope, httpClient: http.Client(),
        currentUid: () => FirebaseAuth.instance.currentUser?.uid,
        getIdToken: () async => FirebaseAuth.instance.currentUser?.getIdToken());
    final saved = prefs.getString('central-lab-tv-$uid');
    if (isTv && saved != null) {
      try {
        final record = jsonDecode(saved) as Map;
        if (record['uid'] == uid && record['endpoint'] == url &&
            RegExp(r'^[a-f0-9]{64}$').hasMatch('${record['token']}') &&
            RegExp(r'^[a-f0-9]{64}$').hasMatch('${record['device']}')) {
          result.sessionToken = record['token'] as String;
          result.tvDevice = record['device'] as String;
        }
      } catch (_) { /* invalid local metadata cannot grant access */ }
    }
    return result;
  }
  static Future<void> freshLogin(String uid) async {
    if (enabled && !isTv) await (await client(uid)).registerMobile();
  }
  static Future<CentralLease?> check(String uid, {bool playback = false}) async {
    if (!enabled) return null;
    try { return await (await client(uid)).status(tv: isTv, playback: playback); }
    catch (_) { return null; }
  }
  static Future<bool> restoreTv(String uid) async {
    tvPaired = await check(uid) != null;
    return tvPaired;
  }
  static Future<void> saveTv(String uid) async {
    final value = await client(uid);
    if (value.sessionToken == null || value.tvDevice == null) return;
    await (await SharedPreferences.getInstance()).setString('central-lab-tv-$uid',
        jsonEncode({'uid': uid, 'endpoint': url, 'token': value.sessionToken, 'device': value.tvDevice}));
    tvPaired = true;
  }
  static Future<void> stop() async {
    final existing = _client;
    if (!enabled || existing == null) return;
    try { await (await existing).stop(tv: isTv); } catch (_) { /* fail closed */ }
  }
  static Future<void> clear() async {
    await stop();
    if (isTv && _client != null && _uid != null) {
      try {
        await (await _client!).request('logout', tv: true);
        await (await SharedPreferences.getInstance()).remove('central-lab-tv-$_uid');
      } catch (_) { /* no confirmed unlink; session expires on server */ }
    }
    _client = null; _uid = null; tvPaired = false;
  }
}
