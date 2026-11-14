import json, re, unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class E2EClosedCatalogTests(unittest.TestCase):
    def test_e2e_build_enables_closed_catalog(self):
        text = (ROOT / '.github/workflows/assinatura-e2e-apk.yml').read_text(encoding='utf-8')
        self.assertIn('--dart-define=ROCHA_CLOSED_CATALOG=true', text)
        self.assertNotIn('ROCHA_FULL_UI_LAB', text)  # real app entry/auth must stay

    def test_policy_reads_closed_catalog_flag(self):
        text = (ROOT / 'lib/src/live/c7_catalog_policy.dart').read_text(encoding='utf-8')
        self.assertIn("bool.fromEnvironment('ROCHA_CLOSED_CATALOG')", text)

    def test_selection_has_479_plus_4_and_caze_first_in_sports(self):
        data = json.loads((ROOT / 'branding/c7/selection.json').read_text(encoding='utf-8'))
        channels = data['channels']
        self.assertEqual((data['baseCount'], data['additionCount'], len(channels)), (479, 4, 483))
        self.assertEqual([c['name'] for c in channels if c['group'] == 'Esportes'][0], 'CazéTV')
        # Owner policy keeps all 483. The only shared URL is the declared
        # Telecine Action addition vs. base 'Telecine Action (1080p)'; report, never delete.
        shared = [u for u in {c['url'] for c in channels} if sum(c['url'] == u for c in channels) > 1]
        self.assertEqual(shared, ['http://46.151.196.223:14326/'])

    def test_founder_prices_and_checkout_amounts_agree(self):
        screen = (ROOT / 'lib/src/screens/subscription_screen.dart').read_text(encoding='utf-8')
        client = (ROOT / 'lib/src/auth/subscription_checkout.dart').read_text(encoding='utf-8')
        server = (ROOT / 'functions/checkout.js').read_text(encoding='utf-8')
        for t in ('R\\$ 7,90 por mês', 'R\\$ 86,90 por ano', 'Plano Fundador', 'Teste gratuito de até 7 dias'):
            self.assertIn(t, screen)
        self.assertIn("'monthly' ? 790 : 8690", client)
        self.assertRegex(server, r'monthly:\s*790,\s*annual:\s*8690')
        self.assertNotRegex(screen, r'4,50|49,50')


if __name__ == '__main__':
    unittest.main()
