import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

const labEntitlementUrl =
    'https://southamerica-east1-rocha-plus-homologacao.cloudfunctions.net/entitlementReadOnly';

class LabAccess {
  final bool allowed;
  final Duration lifetime;
  const LabAccess(this.allowed, this.lifetime);
  static const denied = LabAccess(false, Duration.zero);
}

/// Never invokes the legacy endpoint, which may create a trial on GET.
class LabEntitlement {
  static Future<LabAccess> check(
    String uid, {
    http.Client? client,
    Future<String?> Function()? getToken,
    String? Function()? currentUid,
    String endpoint = const String.fromEnvironment('ROCHA_LAB_ENTITLEMENT_URL'),
  }) async {
    if (uid.isEmpty || endpoint != labEntitlementUrl) return LabAccess.denied;
    final owner = currentUid ?? () => FirebaseAuth.instance.currentUser?.uid;
    final token =
        getToken ?? () async => FirebaseAuth.instance.currentUser?.getIdToken();
    final transport = client ?? http.Client();
    final elapsed = Stopwatch()..start();
    try {
      if (owner() != uid) return LabAccess.denied;
      final bearer = await token().timeout(const Duration(seconds: 10));
      if (bearer == null || bearer.isEmpty || owner() != uid) {
        return LabAccess.denied;
      }
      final request = http.Request('GET', Uri.parse(endpoint))
        ..followRedirects = false
        ..headers['Authorization'] = 'Bearer $bearer';
      final response = await (() async {
        final streamed = await transport.send(request);
        return http.Response.fromStream(streamed);
      })().timeout(const Duration(seconds: 10));
      if (response.statusCode != 200 || owner() != uid) return LabAccess.denied;
      final data = jsonDecode(response.body);
      if (data is! Map ||
          data['uid'] != uid ||
          data['readOnly'] != true ||
          data['allowed'] != true ||
          !['trial', 'paid', 'admin'].contains(data['reason'])) {
        return LabAccess.denied;
      }
      final ttl = data['validForMs'];
      if (ttl is! int || ttl <= 0 || ttl > 60000) return LabAccess.denied;
      final remaining = Duration(milliseconds: ttl) - elapsed.elapsed;
      return remaining > Duration.zero
          ? LabAccess(true, remaining)
          : LabAccess.denied;
    } catch (_) {
      return LabAccess.denied;
    } finally {
      if (client == null) transport.close();
    }
  }
}
