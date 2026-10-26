import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Production access can only be granted by the account-scoped payment backend.
/// A local clock, login, or payment link is never sufficient.
class SubscriptionAccess {
  static const endpoint = String.fromEnvironment('ROCHA_ENTITLEMENT_URL');

  static Future<bool> isAllowed(String uid) async {
    final uri = Uri.tryParse(endpoint);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.uid != uid) return false;
      final token = await user.getIdToken().timeout(const Duration(seconds: 12));
      if (token == null || token.isEmpty) return false;
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return false;
      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) return false;
      // Server must verify Firebase ID token, derive UID from it, and check
      // authoritative paid-through/trial-through timestamps at server time.
      return payload['uid'] == uid && payload['allowed'] == true;
    } catch (_) {
      return false;
    }
  }
}
