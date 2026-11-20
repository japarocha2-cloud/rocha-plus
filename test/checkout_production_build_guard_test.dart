import 'package:flutter_test/flutter_test.dart';
import 'package:rocha_plus/src/auth/subscription_checkout.dart';

void main() {
  test('commercial build only accepts production checkout function', () {
    const real = SubscriptionCheckout.productionCheckoutEndpoint;
    expect(SubscriptionCheckout.isEndpointAllowedForBuild(real,
        commercial: true), isTrue);
    for (final invalid in [
      'https://southamerica-east1-rocha-plus-homologacao.cloudfunctions.net/checkout',
      'https://southamerica-east1-rocha-payments-test.cloudfunctions.net/checkout',
      'https://southamerica-east1-rocha-plus.cloudfunctions.net/checkout-test',
      'http://southamerica-east1-rocha-plus.cloudfunctions.net/checkout',
      'https://southamerica-east1-rocha-plus.cloudfunctions.net/checkout?test=1',
    ]) {
      expect(SubscriptionCheckout.isEndpointAllowedForBuild(invalid,
          commercial: true), isFalse, reason: invalid);
    }
  });

  test('LAB may connect to a distinct HTTPS test backend', () {
    expect(SubscriptionCheckout.isEndpointAllowedForBuild(
      'https://southamerica-east1-rocha-plus-homologacao.cloudfunctions.net/checkout',
      commercial: false), isTrue);
  });

  test('commercial build does not enable sandbox flag', () {
    // The release flag is false during default unit tests.
    expect(SubscriptionCheckout.sandboxAllowedInThisBuild,
        SubscriptionCheckout.sandbox && !const bool.fromEnvironment(
          'ROCHA_COMMERCIAL_RELEASE'));
  });
}
