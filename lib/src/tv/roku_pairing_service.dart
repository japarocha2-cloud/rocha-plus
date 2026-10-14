import 'dart:convert';
import 'package:http/http.dart' as http;

class RokuPairingFailure implements Exception {
  final String message;
  const RokuPairingFailure(this.message);
}

class RokuPairingService {
  static const configuredEndpoint = String.fromEnvironment('ROCHA_ROKU_PAIRING_ENDPOINT');
  final Uri endpoint;
  final http.Client client;
  final Future<String?> Function() tokenProvider;
  RokuPairingService({required String endpoint, required this.tokenProvider, http.Client? client})
      : endpoint = Uri.parse(endpoint), client = client ?? http.Client();
  static bool get isConfigured => configuredEndpoint.startsWith('https://');
  Future<void> approve(String value) async {
    final code = value.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^[A-HJ-NP-Z2-9]{8}$').hasMatch(code)) {
      throw const RokuPairingFailure('Digite os oito caracteres exibidos na TV.');
    }
    if (endpoint.scheme != 'https' || endpoint.host.isEmpty || endpoint.userInfo.isNotEmpty) {
      throw const RokuPairingFailure('A conexão à TV ainda não está disponível.');
    }
    try {
      final token = await tokenProvider();
      if (token == null || token.isEmpty) {
        throw const RokuPairingFailure('Entre na sua conta do Rocha+ antes de conectar a TV.');
      }
      final response = await client.post(endpoint,
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          body: jsonEncode({'action': 'approve', 'user_code': code}))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['status'] == 'approved') return;
      }
      final message = switch (response.statusCode) {
        401 => 'Sua sessão expirou. Entre novamente para conectar a TV.',
        409 => 'Esse código já foi confirmado por outra conta.',
        410 => 'O código expirou. Gere outro na TV.',
        429 => 'Aguarde um momento e tente novamente.',
        _ => 'Não foi possível conectar a TV. Confira a conexão e tente novamente.',
      };
      throw RokuPairingFailure(message);
    } on RokuPairingFailure {
      rethrow;
    } catch (_) {
      throw const RokuPairingFailure('Não foi possível conectar a TV. Tente novamente.');
    }
  }
}
