import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class SubscriptionCheckout {
  static const endpoint = String.fromEnvironment('ROCHA_CHECKOUT_URL');
  static Future<void> open(String uid, String plan) async {
    final uri = Uri.tryParse(endpoint);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty || uri.hasFragment) {
      throw StateError('Checkout indisponível nesta versão.');
    }
    final auth = FirebaseAuth.instance;
    if (auth.currentUser?.uid != uid) throw StateError('Entre novamente.');
    final token = await auth.currentUser!.getIdToken();
    if (token == null || auth.currentUser?.uid != uid) throw StateError('Entre novamente.');
    final response = await http.post(uri, headers: {
      'Authorization': 'Bearer $token', 'Content-Type': 'application/json',
    }, body: jsonEncode({'plan': plan})).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200 || auth.currentUser?.uid != uid) {
      throw StateError('Checkout indisponível. Nenhuma licença foi alterada.');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final url = Uri.parse(body['url'] as String);
    final cents = plan == 'monthly' ? 790 : 8690;
    if (body['plan'] != plan || body['amountCents'] != cents ||
        body['mode'] != 'one_time' || url.scheme != 'https' ||
        url.host != 'www.mercadopago.com.br' || url.userInfo.isNotEmpty ||
        url.hasFragment || url.hasPort || url.path != '/checkout/v1/redirect' ||
        (url.queryParameters['pref_id'] ?? '').isEmpty) {
      throw StateError('Não foi possível validar o checkout.');
    }
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw StateError('Não foi possível abrir o Mercado Pago.');
    }
  }
}

