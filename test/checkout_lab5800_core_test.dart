import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rocha_plus/src/auth/subscription_checkout.dart';

const prodUrl = 'https://www.mercadopago.com.br/checkout/v1/redirect?pref_id=123';
const sandboxUrl = 'https://sandbox.mercadopago.com.br/checkout/v1/redirect?pref_id=123';

String reply(String url, {String plan = 'monthly', int? cents, String mode = 'one_time'}) =>
    jsonEncode({
      'url': url, 'plan': plan, 'mode': mode,
      'amountCents': cents ?? (plan == 'monthly' ? 790 : 8690),
    });

void main() {
  group('isValidCheckoutUrl', () {
    bool ok(String url, {bool sandbox = false}) =>
        SubscriptionCheckout.isValidCheckoutUrl(Uri.parse(url), allowSandbox: sandbox);
    const path = '/checkout/v1/redirect?pref_id=123';

    test('production host is accepted', () {
      expect(ok('https://www.mercadopago.com.br$path'), isTrue);
    });
    test('sandbox host only with the explicit sandbox flag', () {
      expect(ok('https://sandbox.mercadopago.com.br$path'), isFalse);
      expect(ok('https://sandbox.mercadopago.com.br$path', sandbox: true), isTrue);
    });
    test('rejects unsafe or malformed urls even in sandbox mode', () {
      for (final bad in [
        'http://www.mercadopago.com.br$path',
        'https://user@www.mercadopago.com.br$path',
        'https://www.mercadopago.com.br:8443$path',
        'https://www.mercadopago.com.br$path#x',
        'https://www.mercadopago.com.br/other?pref_id=123',
        'https://www.mercadopago.com.br/checkout/v1/redirect',
        'https://evil.mercadopago.com.br.example.com$path',
        'https://sandbox.mercadopago.com.br.evil.test$path',
      ]) {
        expect(ok(bad, sandbox: true), isFalse, reason: bad);
      }
    });
    test('the sandbox flag is off unless the build defines it', () {
      expect(SubscriptionCheckout.sandbox, isFalse);
    }, skip: SubscriptionCheckout.sandbox
        ? 'ROCHA_CHECKOUT_SANDBOX is defined in this run' : null);
  });

  group('SubscriptionCheckout.open', () {
    final endpoint = Uri.parse('https://example.test/checkout');
    late int posts;
    late List<Uri> launched;

    Future<void> run({
      required String body,
      int status = 200,
      bool? sandbox,
      bool launchResult = true,
      Uri? endpointUri,
      String plan = 'monthly',
      String? uidNow = 'u1',
    }) {
      final client = MockClient((request) async {
        posts++;
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer fixture');
        expect(jsonDecode(request.body), {'plan': plan});
        return http.Response(body, status);
      });
      addTearDown(client.close);
      return SubscriptionCheckout.open('u1', plan,
          endpointUri: endpointUri ?? endpoint,
          client: client,
          getToken: () async => 'fixture',
          currentUid: () => uidNow,
          allowSandbox: sandbox,
          launch: (url) async {
            launched.add(url);
            return launchResult;
          });
    }

    Future<CheckoutFailure> failureOf(Future<void> call) async {
      try {
        await call;
      } on CheckoutException catch (error) {
        expect(error.message, isNotEmpty);
        return error.failure;
      }
      fail('expected a CheckoutException');
    }

    setUp(() {
      posts = 0;
      launched = [];
    });

    test('production url is opened', () async {
      await run(body: reply(prodUrl));
      expect(launched, [Uri.parse(prodUrl)]);
    });

    test('sandbox url is rejected by default and never launched', () async {
      expect(await failureOf(run(body: reply(sandboxUrl))), CheckoutFailure.invalidResponse);
      expect(await failureOf(run(body: reply(sandboxUrl), sandbox: false)),
          CheckoutFailure.invalidResponse);
      expect(launched, isEmpty);
    });

    test('sandbox url is accepted only with the explicit sandbox flag', () async {
      await run(body: reply(sandboxUrl), sandbox: true);
      expect(launched, [Uri.parse(sandboxUrl)]);
    });

    test('the sandbox flag does not relax plan, price or mode checks', () async {
      for (final body in [
        reply(sandboxUrl, cents: 1),
        reply(sandboxUrl, mode: 'subscription'),
        reply(sandboxUrl, plan: 'annual'),
        'not json',
        '[]',
      ]) {
        expect(await failureOf(run(body: body, sandbox: true)),
            CheckoutFailure.invalidResponse, reason: body);
      }
      expect(launched, isEmpty);
    });

    test('missing checkout url is a specific error before any network call', () async {
      for (final bad in [Uri.parse('http://example.test/c'), Uri.parse('https:///c'),
          Uri.parse('https://u@example.test/c'), Uri.parse('https://example.test/c#x')]) {
        expect(await failureOf(run(body: '{}', endpointUri: bad)),
            CheckoutFailure.notConfigured, reason: '$bad');
      }
      expect(posts, 0);
    });

    test('default endpoint is unconfigured when ROCHA_CHECKOUT_URL is not defined', () async {
      expect(SubscriptionCheckout.isConfigured, isFalse);
      expect(await failureOf(SubscriptionCheckout.open('u1', 'monthly')),
          CheckoutFailure.notConfigured);
    }, skip: SubscriptionCheckout.isConfigured
        ? 'ROCHA_CHECKOUT_URL is defined in this run' : null);

    test('server and network failures are reported as unavailable', () async {
      expect(await failureOf(run(body: '{}', status: 503)), CheckoutFailure.unavailable);
      final offline = MockClient((_) async => throw http.ClientException('offline'));
      addTearDown(offline.close);
      expect(await failureOf(SubscriptionCheckout.open('u1', 'monthly',
          endpointUri: endpoint, client: offline,
          getToken: () async => 'fixture', currentUid: () => 'u1',
          launch: (_) async => true)), CheckoutFailure.unavailable);
    });

    test('a different signed-in account never reaches the server', () async {
      expect(await failureOf(run(body: reply(prodUrl), uidNow: 'someone-else')),
          CheckoutFailure.signedOut);
      expect(await failureOf(run(body: reply(prodUrl), uidNow: null)),
          CheckoutFailure.signedOut);
      expect(posts, 0);
    });

    test('a browser that cannot be opened is a specific error', () async {
      expect(await failureOf(run(body: reply(prodUrl), launchResult: false)),
          CheckoutFailure.cannotLaunch);
    });
  });
}
