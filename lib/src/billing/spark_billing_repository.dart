import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'billing_repository.dart';

/// Spark-compatible trial storage. Payment confirmation requires an admin;
/// opening a checkout link never creates a paid entitlement.
class SparkBillingRepository implements BillingRepository {
  static const enabled = bool.fromEnvironment('ROCHA_SPARK_TRIAL');
  final String projectId;
  final String accountId;
  final Future<String?> Function() tokenProvider;
  final http.Client client;
  SparkBillingRepository({required this.projectId, required this.accountId,
    required this.tokenProvider, http.Client? client})
      : client = client ?? http.Client();

  factory SparkBillingRepository.forAccount(String uid) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != uid || !user.emailVerified) {
      throw const BillingFailure('Entre com sua conta Google para confirmar o acesso.');
    }
    final google = user.providerData.where((p) => p.providerId == 'google.com');
    if (google.isEmpty || google.first.uid == null) {
      throw const BillingFailure('O teste gratuito desta versão requer login Google.');
    }
    return SparkBillingRepository(
      projectId: Firebase.app().options.projectId, accountId: google.first.uid!,
      tokenProvider: () async {
        final current = FirebaseAuth.instance.currentUser;
        if (current == null || current.uid != uid) return null;
        return current.getIdToken();
      });
  }

  String get _database => 'projects/$projectId/databases/(default)';
  String get _document => '$_database/documents/rochaSparkAccounts/$accountId';

  Future<http.Response> _post(String operation, Map<String, dynamic> body) async {
    if (!RegExp(r'^[a-z][a-z0-9-]{4,61}[a-z0-9]$').hasMatch(projectId) ||
        !RegExp(r'^[0-9]{1,128}$').hasMatch(accountId)) {
      throw const BillingFailure('Configuração do teste gratuito inválida.');
    }
    final token = await tokenProvider();
    if (token == null || token.isEmpty) {
      throw const BillingFailure('Entre novamente para confirmar seu acesso.');
    }
    return client.post(
      Uri.https('firestore.googleapis.com', '/v1/$_database/documents:$operation'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(body)).timeout(const Duration(seconds: 12));
  }

  Future<Map<String, dynamic>> _read() async {
    final response = await _post('batchGet', {'documents': [_document]});
    if (response.statusCode != 200) throw const BillingFailure(
      'Não foi possível confirmar o teste gratuito. Confira a conexão e tente novamente.');
    final decoded = jsonDecode(response.body);
    if (decoded is! List || decoded.length != 1 || decoded.first is! Map<String, dynamic>) {
      throw const BillingFailure('Resposta de acesso inválida.');
    }
    final result = decoded.first as Map<String, dynamic>;
    _time(result['readTime']);
    final found = result['found'];
    if (found != null) {
      if (found is! Map<String, dynamic> || found['name'] != _document ||
          found['fields'] is! Map<String, dynamic>) {
        throw const BillingFailure('Resposta de conta inválida.');
      }
    } else if (result['missing'] != _document) {
      throw const BillingFailure('Resposta de conta inválida.');
    }
    return result;
  }

  DateTime _time(dynamic value) {
    final date = value is String ? DateTime.tryParse(value) : null;
    if (date == null || !value.endsWith('Z')) {
      throw const BillingFailure('Horário do servidor inválido.');
    }
    return date.toUtc();
  }

  @override
  Future<BillingAccess> status() async {
    try {
      var result = await _read();
      if (result['found'] == null) {
        final response = await _post('commit', {'writes': [{
          'update': {'name': _document, 'fields': {'welcomeAcceptedAt': {'nullValue': null}}},
          'updateTransforms': [{'fieldPath': 'trialStartedAt', 'setToServerValue': 'REQUEST_TIME'}],
          'currentDocument': {'exists': false},
        }]});
        // A concurrent login may have created the same Google account first.
        if (response.statusCode != 200 && response.statusCode != 409) {
          throw const BillingFailure('Não foi possível iniciar seu teste gratuito.');
        }
        result = await _read();
      }
      final fields = (result['found'] as Map<String, dynamic>)['fields'] as Map<String, dynamic>;
      final now = _time(result['readTime']);
      final started = _time((fields['trialStartedAt'] as Map?)?['timestampValue']);
      if (started.isAfter(now)) throw const BillingFailure('Prazo de teste inválido.');
      final trialEnds = started.add(const Duration(days: 7));
      DateTime? paidUntil;
      if (fields.containsKey('paidUntil')) {
        paidUntil = _time((fields['paidUntil'] as Map?)?['timestampValue']);
      }
      final accepted = fields['welcomeAcceptedAt'];
      if (accepted is! Map ||
          (!accepted.containsKey('nullValue') && !accepted.containsKey('timestampValue'))) {
        throw const BillingFailure('Registro do aviso inválido.');
      }
      if (accepted.containsKey('timestampValue')) _time(accepted['timestampValue']);
      final paid = paidUntil != null && paidUntil.isAfter(now);
      final trial = trialEnds.isAfter(now);
      final until = paid ? paidUntil! : trialEnds;
      final days = (trialEnds.difference(now).inMilliseconds / Duration.millisecondsPerDay).ceil();
      return BillingAccess(active: paid || trial,
        state: paid ? 'paid' : trial ? 'trial' : 'expired',
        remaining: paid || trial ? until.difference(now) : Duration.zero,
        trialRemainingDays: days.clamp(0, 7),
        expiresAt: paid || trial ? until : null,
        manualPaymentConfirmation: true,
        trialWelcomeNoticeAccepted: accepted.containsKey('timestampValue'));
    } on BillingFailure {
      rethrow;
    } catch (_) {
      throw const BillingFailure('Não foi possível confirmar seu acesso. Tente novamente.');
    }
  }

  @override
  Future<bool> claimTrialWelcomeNotice() async {
    try {
      final result = await _read();
      final fields = (result['found'] as Map<String, dynamic>)['fields'] as Map<String, dynamic>;
      if ((fields['welcomeAcceptedAt'] as Map?)?.containsKey('timestampValue') == true) return false;
      final response = await _post('commit', {'writes': [{
        'transform': {'document': _document, 'fieldTransforms': [
          {'fieldPath': 'welcomeAcceptedAt', 'setToServerValue': 'REQUEST_TIME'},
        ]},
        'currentDocument': {'updateTime': (result['found'] as Map)['updateTime']},
      }]});
      if (response.statusCode == 409) {
        final current = await _read();
        final data = (current['found'] as Map)['fields'] as Map;
        if ((data['welcomeAcceptedAt'] as Map?)?.containsKey('timestampValue') == true) return false;
      }
      if (response.statusCode != 200) throw const BillingFailure('Não foi possível sincronizar a aceitação.');
      return true;
    } on BillingFailure {
      rethrow;
    } catch (_) {
      throw const BillingFailure('Não foi possível sincronizar a aceitação.');
    }
  }

  @override
  Future<Uri> checkout(String plan) async {
    // Existing links are retained. Spark does not verify Mercado Pago payments.
    final link = switch (plan) {
      'monthly' => 'https://mpago.la/2E7yjF4',
      'annual' => 'https://mpago.la/2b9hitF',
      _ => throw const BillingFailure('Plano inválido.'),
    };
    return Uri.parse(link);
  }
}
