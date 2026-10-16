import 'commercial_config.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class BillingFailure implements Exception {
  final String message;
  const BillingFailure(this.message);
}
class BillingAccess {
  final bool active;
  final String state;
  final Duration remaining;
  final int trialRemainingDays;
  final DateTime? expiresAt;
  final bool subscriptionLinked;
  final bool automaticRenewal;
  final bool trialWelcomeNoticeAccepted;
  final bool manualPaymentConfirmation;
  const BillingAccess({required this.active, required this.state,
    required this.remaining, required this.trialRemainingDays, this.expiresAt,
    this.subscriptionLinked = false, this.automaticRenewal = false,
    this.trialWelcomeNoticeAccepted = false, this.manualPaymentConfirmation = false});
  factory BillingAccess.fromJson(Map<String, dynamic> data) {
    final state = data['state'];
    final active = data['active'];
    final serverTime = data['serverTime'];
    final until = data['accessUntil'];
    final days = data['trialRemainingDays'];
    if (!['trial', 'paid', 'expired'].contains(state) || active is! bool ||
        serverTime is! int || days is! int || days < 0 || days > 7 ||
        (active && (state == 'expired' || until is! int || until <= serverTime)) ||
        (!active && state != 'expired')) {
      throw const BillingFailure('Não foi possível confirmar sua assinatura.');
    }
    return BillingAccess(active: active, state: state as String,
      remaining: Duration(milliseconds: active ? (until as int) - serverTime : 0),
      trialRemainingDays: days, subscriptionLinked: data['recognition'] == 'linked',
      automaticRenewal: data['automaticRenewal'] == true,
      trialWelcomeNoticeAccepted: data['trialWelcomeNoticeAccepted'] == true,
      expiresAt: until is int ? DateTime.fromMillisecondsSinceEpoch(until) : null);
  }
}
abstract class BillingRepository {
  Future<BillingAccess> status();
  Future<Uri> checkout(String plan);
  Future<bool> claimTrialWelcomeNotice();
}
class HttpBillingRepository implements BillingRepository {
  static const configuredEndpoint = String.fromEnvironment('ROCHA_BILLING_API_URL');
  final Uri endpoint;
  final http.Client client;
  final Future<String?> Function() tokenProvider;
  HttpBillingRepository({required String endpoint, required this.tokenProvider,
    http.Client? client}) : endpoint = Uri.parse(endpoint), client = client ?? http.Client();
  factory HttpBillingRepository.forAccount(String uid) => HttpBillingRepository(
    endpoint: configuredEndpoint, tokenProvider: () async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.uid != uid) return null;
      return user.getIdToken();
    });
  Future<Map<String, dynamic>> _request(Map<String, dynamic> body) async {
    if (endpoint.scheme != 'https' || endpoint.host.isEmpty || endpoint.userInfo.isNotEmpty) {
      throw const BillingFailure('O serviço de assinatura ainda não está disponível.');
    }
    try {
      final token = await tokenProvider();
      if (token == null || token.isEmpty) {
        throw const BillingFailure('Entre novamente para confirmar sua assinatura.');
      }
      final response = await client.post(endpoint,
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(body)).timeout(const Duration(seconds: 12));
      if (response.statusCode == 409) {
        throw const BillingFailure('Sua assinatura já foi encontrada. Toque em verificar acesso.');
      }
      if (response.statusCode == 403) {
        throw const BillingFailure('Confirme o e-mail do login para vincular sua assinatura.');
      }
      if (response.statusCode != 200) {
        throw const BillingFailure('Não foi possível confirmar sua assinatura. Tente novamente.');
      }
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        throw const BillingFailure('Resposta de assinatura inválida.');
      }
      return data;
    } on BillingFailure {
      rethrow;
    } catch (_) {
      throw const BillingFailure('Não foi possível conectar ao serviço de assinatura.');
    }
  }
  @override
  Future<BillingAccess> status() async => BillingAccess.fromJson(await _request({'action': 'status'}));
  @override
  Future<bool> claimTrialWelcomeNotice() async {
    final data = await _request({'action': 'claimTrialWelcomeNotice'});
    if (data['showNotice'] is! bool) {
      throw const BillingFailure('Resposta de aviso inválida.');
    }
    return data['showNotice'] == true;
  }
  @override
  Future<Uri> checkout(String plan) async {
    if (CommercialConfig.asaas) throw const BillingFailure(CommercialConfig.setupMessage);
    if (!['monthly', 'annual'].contains(plan)) {
      throw const BillingFailure('Plano inválido.');
    }
    final data = await _request({'action': 'checkout', 'plan': plan});
    final uri = Uri.tryParse(data['checkoutUrl'] is String ? data['checkoutUrl'] as String : '');
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty ||
        (!['mercadopago.com.br', 'www.mercadopago.com.br'].contains(uri.host) &&
          !['https://mpago.la/2E7yjF4', 'https://mpago.la/2b9hitF'].contains(uri.toString()))) {
      throw const BillingFailure('Não foi possível abrir o pagamento.');
    }
    return uri;
  }
}
