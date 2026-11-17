"""Build flags for the paid (commercial) official Rocha+ release.

Called by tools/prepare_signed_build.py when the signed CI build is dispatched with
commercial_release=true (.github/workflows/build.yml).
It refuses any configuration that would ship an app that blocks every user
(missing/foreign endpoints) or that carries LAB/experimental switches.
"""
import hashlib
import json
from pathlib import Path

PRODUCTION_HOST = 'southamerica-east1-rocha-plus.cloudfunctions.net'
SELECTION_ASSET = 'branding/lab/c7_validated_selection.json'
# Server-owned prices (functions/checkout.js) and trial (functions/trial_anchor.js).
PLANS_CENTS = {'monthly': 790, 'annual': 8690}
TRIAL_DAYS = 7


def _endpoint(env, name, path):
    # Byte-exact match: no case, userinfo, empty port/query/fragment variants.
    expected = f'https://{PRODUCTION_HOST}{path}'
    if env.get(name, '') != expected:
        raise ValueError(f'{name} deve ser exatamente {expected}')
    return expected


def selection_sha256(root):
    raw = (Path(root) / SELECTION_ASSET).read_bytes()
    # The app hashes utf8.encode(rootBundle.loadString(asset)); BOM/CRLF would diverge.
    if raw.startswith(b'\xef\xbb\xbf') or b'\r' in raw:
        raise ValueError('seleção C7 deve ser UTF-8 sem BOM e sem CRLF')
    text = raw.decode('utf-8')
    data = json.loads(text)
    if data.get('schema') != 'rocha.c7.selection.v1' or not data.get('channels'):
        raise ValueError('seleção C7 do release inválida')
    return hashlib.sha256(text.encode('utf-8')).hexdigest()


def commercial_config(env, root):
    if env.get('ROCHA_COMMERCIAL_RELEASE') != 'true':
        raise ValueError('release comercial exige ROCHA_COMMERCIAL_RELEASE=true')
    return {
        'ROCHA_COMMERCIAL_RELEASE': 'true',
        'ROCHA_EXPERIMENTAL_SUBSCRIPTIONS': 'false',
        'ROCHA_LAB_ONLY': 'false',
        'ROCHA_LAYOUT_PREVIEW': 'false',
        # LAB/alternate access paths are never part of the paid release.
        'ROCHA_CENTRAL_RIGHTS': 'false',
        'ROCHA_FULL_UI_LAB': 'false',
        'ROCHA_LAB_PRESENTATION': 'false',
        'ROCHA_USB_PHYSICAL_TEST': 'false',
        'ROCHA_C7_SUBSCRIPTION_QUERY': 'false',
        'ROCHA_ENTITLEMENT_URL': _endpoint(env, 'ROCHA_ENTITLEMENT_URL', '/entitlement'),
        'ROCHA_CHECKOUT_URL': _endpoint(env, 'ROCHA_CHECKOUT_URL', '/checkout'),
        'ROCHA_CLOSED_CATALOG': 'true',
        'ROCHA_C7_SELECTION_ASSET': SELECTION_ASSET,
        'ROCHA_C7_CATALOG_SHA256': selection_sha256(root),
    }
