import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../app_release_policy.dart';

enum CheckoutFailure {
  /// ROCHA_CHECKOUT_URL is empty or not a valid https URL in this build.
  notConfigured,
  signedOut,
  unavailable,
  invalidResponse,
  cannotLaunch,
}

/// A checkout failure with a user-facing, specific message (never a bare catch).
class CheckoutException implements Exception {
  final CheckoutFailure failure;
  final String message;
  const CheckoutException(this.failure, this.message);

  @override
  String toString() => 'CheckoutException(${failure.name}): $message';
}

class SubscriptionCheckout {
  static const endpoint = String.fromEnvironment('ROCHA_CHECKOUT_URL');
  /// Sandbox builds (ROCHA_CHECKOUT_SANDBOX=true) also accept the MP sandbox host.
  static const sandbox = bool.fromEnvironment('ROCHA_CHECKOUT_SANDBOX');

  static bool isValidEndpoint(Uri? uri) =>
      uri != null && uri.scheme == 'https' && uri.host.isNotEmpty &&
      uri.userInfo.isEmpty && !uri.hasFragment;

  /// True when this build knows where to create checkouts.
  /// A commercial build must always target the production Firebase checkout.
  /// This checks configuration only; real settlement is verified by the backend.
  static const productionCheckoutEndpoint =
      'https://southamerica-east1-rocha-plus.cloudfunctions.net/checkout';

  static bool isEndpointAllowedForBuild(String url,
      {bool commercial = RochaReleasePolicy.commercialRelease}) {
    final uri = Uri.tryParse(url);
    return isValidEndpoint(uri) &&
        (!commercial || url == productionCheckoutEndpoint);
  }

  static bool get isConfigured => isEndpointAllowedForBuild(endpoint);

  /// No sandbox checkout is accepted in an official commercial build,
  /// regardless of the flag used at compilation.
  static bool get sandboxAllowedInThisBuild =>
      sandbox && !RochaReleasePolicy.commercialRelease;

  static bool isValidCheckoutUrl(Uri url, {bool allowSandbox = false}) =>
      url.scheme == 'https' &&
      (url.host == 'www.mercadopago.com.br' ||
          (allowSandbox && url.host == 'sandbox.mercadopago.com.br')) &&
      url.userInfo.isEmpty && !url.hasFragment && !url.hasPort &&
      url.path == '/checkout/v1/redirect' &&
      (url.queryParameters['pref_id'] ?? '').isNotEmpty;

  /// Collaborators are injectable so the flow is testable without network,
  /// Firebase or a browser.
  static Future<void> open(String uid, String plan, {
    Uri? endpointUri,
    http.Client? client,
    Future<String?> Function()? getToken,
    String? Function()? currentUid,
    Future<bool> Function(Uri url)? launch,
    bool? allowSandbox,
  }) async {
    final uri = endpointUri ?? Uri.tryParse(endpoint);
    if (!isEndpointAllowedForBuild(uri?.toString() ?? '')) {
      throw const CheckoutException(CheckoutFailure.notConfigured,
          'O pagamento não está configurado nesta versão do aplicativo.');
    }
    if (plan != 'monthly' && plan != 'annual') {
      throw ArgumentError.value(plan, 'plan');
    }
    final readUid = currentUid ?? () => FirebaseAuth.instance.currentUser?.uid;
    final readToken = getToken ?? () async =>
        FirebaseAuth.instance.currentUser?.getIdToken();
    const signedOut = CheckoutException(
        CheckoutFailure.signedOut, 'Sua sessão mudou. Entre novamente para assinar.');
    if (readUid() != uid) throw signedOut;
    http.Response response;
    try {
      final token = await readToken().timeout(const Duration(seconds: 15));
      if (token == null || token.isEmpty || readUid() != uid) throw signedOut;
      final headers = {
        'Authorization': 'Bearer $token', 'Content-Type': 'application/json',
      };
      final payload = jsonEncode({'plan': plan});
      response = await (client == null
          ? http.post(uri!, headers: headers, body: payload)
          : client.post(uri!, headers: headers, body: payload))
          .timeout(const Duration(seconds: 30));
    } on CheckoutException {
      rethrow;
    } catch (_) {
      throw const CheckoutException(CheckoutFailure.unavailable,
          'Sem resposta do servidor de pagamento. Confira a conexão e tente novamente. Nenhuma licença foi alterada.');
    }
    if (readUid() != uid) throw signedOut;
    if (response.statusCode != 200) {
      throw CheckoutException(CheckoutFailure.unavailable,
          'Checkout indisponível (código ${response.statusCode}). Nenhuma licença foi alterada.');
    }
    const invalid = CheckoutException(
        CheckoutFailure.invalidResponse, 'Não foi possível validar o checkout.');
    final Map<String, dynamic> body;
    final Uri url;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
      url = Uri.parse(body['url'] as String);
    } catch (_) {
      throw invalid;
    }
    final cents = plan == 'monthly' ? 790 : 8690;
    if (body['plan'] != plan || body['amountCents'] != cents ||
        body['mode'] != 'one_time' ||
        !isValidCheckoutUrl(url,
            allowSandbox: !RochaReleasePolicy.commercialRelease &&
                (allowSandbox ?? sandboxAllowedInThisBuild))) {
      throw invalid;
    }
    var opened = false;
    try {
      final Future<bool> Function(Uri) open = launch ??
          (Uri target) => launchUrl(target, mode: LaunchMode.externalApplication);
      opened = await open(url);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      throw const CheckoutException(
          CheckoutFailure.cannotLaunch, 'Não foi possível abrir o Mercado Pago.');
    }
  }
}
