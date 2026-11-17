import hashlib
import re
import unittest
from pathlib import Path

from commercial_release_config import (PLANS_CENTS, PRODUCTION_HOST, SELECTION_ASSET,
                                       TRIAL_DAYS, commercial_config)

ROOT = Path(__file__).resolve().parents[1]
GOOD = {'ROCHA_COMMERCIAL_RELEASE': 'true',
        'ROCHA_ENTITLEMENT_URL': f'https://{PRODUCTION_HOST}/entitlement',
        'ROCHA_CHECKOUT_URL': f'https://{PRODUCTION_HOST}/checkout'}


class CommercialReleaseConfigTest(unittest.TestCase):
    def test_complete_production_configuration(self):
        config = commercial_config(GOOD, ROOT)
        self.assertEqual(config['ROCHA_COMMERCIAL_RELEASE'], 'true')
        self.assertEqual(config['ROCHA_EXPERIMENTAL_SUBSCRIPTIONS'], 'false')
        self.assertEqual(config['ROCHA_LAB_ONLY'], 'false')
        self.assertEqual(config['ROCHA_CLOSED_CATALOG'], 'true')
        self.assertEqual(config['ROCHA_C7_SELECTION_ASSET'], SELECTION_ASSET)
        expected = hashlib.sha256((ROOT / SELECTION_ASSET).read_bytes()).hexdigest()
        self.assertEqual(config['ROCHA_C7_CATALOG_SHA256'], expected)
        for lab_switch in ('ROCHA_CENTRAL_RIGHTS', 'ROCHA_FULL_UI_LAB', 'ROCHA_LAB_PRESENTATION',
                           'ROCHA_USB_PHYSICAL_TEST', 'ROCHA_C7_SUBSCRIPTION_QUERY'):
            self.assertEqual(config[lab_switch], 'false', lab_switch)

    def test_refuses_build_that_would_block_everyone_or_point_elsewhere(self):
        bad = [
            {},
            dict(GOOD, ROCHA_COMMERCIAL_RELEASE='false'),
            dict(GOOD, ROCHA_ENTITLEMENT_URL=''),
            dict(GOOD, ROCHA_CHECKOUT_URL=''),
            dict(GOOD, ROCHA_ENTITLEMENT_URL=GOOD['ROCHA_ENTITLEMENT_URL'].replace('https', 'http')),
            # Homologation (sandbox payments) can never be the commercial backend.
            dict(GOOD, ROCHA_CHECKOUT_URL='https://southamerica-east1-rocha-plus-homologacao'
                                          '.cloudfunctions.net/checkout'),
            dict(GOOD, ROCHA_ENTITLEMENT_URL=GOOD['ROCHA_ENTITLEMENT_URL'] + '?x=1'),
            dict(GOOD, ROCHA_CHECKOUT_URL=GOOD['ROCHA_ENTITLEMENT_URL']),
            # Parser-lenient variants reported by the security review.
            dict(GOOD, ROCHA_ENTITLEMENT_URL=f'https://@{PRODUCTION_HOST}/entitlement'),
            dict(GOOD, ROCHA_ENTITLEMENT_URL=f'https://{PRODUCTION_HOST}:/entitlement'),
            dict(GOOD, ROCHA_ENTITLEMENT_URL=f'https://{PRODUCTION_HOST}/entitlement?'),
            dict(GOOD, ROCHA_ENTITLEMENT_URL=f'https://{PRODUCTION_HOST}/entitlement#'),
            dict(GOOD, ROCHA_ENTITLEMENT_URL=f'https://{PRODUCTION_HOST.upper()}/entitlement'),
        ]
        for env in bad:
            with self.subTest(env=env), self.assertRaises(ValueError):
                commercial_config(env, ROOT)

    def test_prices_and_trial_match_server_and_app(self):
        checkout = (ROOT / 'functions/checkout.js').read_text(encoding='utf-8')
        self.assertIn('PLANS = Object.freeze({monthly: %d, annual: %d})'
                      % (PLANS_CENTS['monthly'], PLANS_CENTS['annual']), checkout)
        trial = (ROOT / 'functions/trial_anchor.js').read_text(encoding='utf-8')
        self.assertIn('TRIAL_MS = %d * 24 * 60 * 60 * 1000' % TRIAL_DAYS, trial)
        screen = (ROOT / 'lib/src/screens/subscription_screen.dart').read_text(encoding='utf-8')
        # Dart source escapes the currency sign: 'R\$ 7,90 por mês'.
        self.assertTrue(re.search(r"R\\\$ 7,90 por mês", screen))
        self.assertTrue(re.search(r"R\\\$ 86,90 por ano", screen))


if __name__ == '__main__':
    unittest.main()
