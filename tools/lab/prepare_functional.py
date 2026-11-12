"""Fail-closed preflight for the second-phone LAB. Never generates a key."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import urllib.error
import urllib.request

PROJECT = 'rocha-plus-homologacao'
PACKAGE = 'com.rochaplus.app.lab'
SHA1 = 'ede061140453a6d9736efe5325376e348a32f6a8'
SHA256 = '1d206944cc0f2d14c280fc16e66aad0677f0847589b726e8d0ec549b5aff9cc7'
ENDPOINT = f'https://southamerica-east1-{PROJECT}.cloudfunctions.net/entitlementReadOnly'


def configuration(source):
    info = source.get('project_info', {})
    if info.get('project_id') != PROJECT:
        raise ValueError('Firebase LAB project required')
    clients = [c for c in source.get('client', []) if
               c.get('client_info', {}).get('android_client_info', {}).get('package_name') == PACKAGE]
    if len(clients) != 1:
        raise ValueError('Exactly one Android LAB app required')
    client = clients[0]
    oauth = client.get('oauth_client', [])
    fingerprints = {str(o.get('android_info', {}).get('certificate_hash', '')).lower()
                    for o in oauth if o.get('client_type') == 1 and
                    o.get('android_info', {}).get('package_name') == PACKAGE}
    if SHA1 not in fingerprints:
        raise ValueError('Existing second-phone signer is not registered in LAB OAuth')
    web = {o.get('client_id') for o in oauth if o.get('client_type') == 3}
    if len(web) != 1 or not all(isinstance(v, str) and v.endswith('.apps.googleusercontent.com') for v in web):
        raise ValueError('One Google web OAuth client required')
    keys = client.get('api_key', [])
    sender = str(info.get('project_number', ''))
    app = client.get('client_info', {}).get('mobilesdk_app_id')
    if not sender.isdigit() or not isinstance(app, str) or not app.startswith(f'1:{sender}:android:'):
        raise ValueError('Inconsistent LAB app identity')
    key = keys[0].get('current_key') if len(keys) == 1 else None
    if not isinstance(key, str) or not key:
        raise ValueError('Firebase API configuration missing')
    return {
        'ROCHA_FIREBASE_PROJECT_ID': PROJECT, 'ROCHA_FIREBASE_APP_ID': app,
        'ROCHA_FIREBASE_SENDER_ID': sender, 'ROCHA_FIREBASE_API_KEY': key,
        'ROCHA_GOOGLE_SERVER_CLIENT_ID': next(iter(web)),
        'ROCHA_APPLE_ENABLED': 'false', 'ROCHA_FUNCTIONAL_LAB': 'true',
        'ROCHA_LAB_ENTITLEMENT_URL': ENDPOINT,
        'ROCHA_LAYOUT_PREVIEW': 'false',
    }


def verify_catalog(path):
    data = path.read_bytes()
    rows = json.loads(data)
    if not isinstance(rows, list) or not rows:
        raise ValueError('Approved LAB snapshot is empty; no candidate fallback allowed')
    for row in rows:
        if not isinstance(row, dict) or row.get('status') != 'automatic_audiovisual_pass' or row.get('eligible') is not True or row.get('blocked') is True:
            raise ValueError('Approval evidence required for every snapshot row')
        result = row.get('result')
        if not isinstance(result, dict) or result.get('preferred') != 'exoPlayer':
            raise ValueError('Snapshot requires a player not yet supported by this isolated LAB')
    return hashlib.sha256(data).hexdigest()


def verify_signer(store, env):
    if not env.get('LAB_KEY_ALIAS') or not env.get('LAB_KEYSTORE_PASSWORD'):
        raise ValueError('Existing LAB signing credentials required')
    result = subprocess.run(['keytool', '-J-Duser.language=en', '-list', '-v',
        '-keystore', str(store), '-storepass:env', 'LAB_KEYSTORE_PASSWORD',
        '-alias', env['LAB_KEY_ALIAS']], env=env, capture_output=True, text=True)
    if result.returncode or 'PrivateKeyEntry' not in result.stdout:
        raise ValueError('Existing LAB private key could not be validated')
    for label, expected in [('SHA1', SHA1), ('SHA256', SHA256)]:
        match = re.search(r'\b' + label + r':\s*([0-9A-Fa-f:]+)', result.stdout)
        if not match or match.group(1).replace(':', '').lower() != expected:
            raise ValueError('Unexpected signer; historical Moto installation must stay untouched')


def verify_backend():
    # Only the new read-only route is probed, without credentials or account IDs.
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, *args):
            return None
    try:
        with urllib.request.build_opener(NoRedirect).open(ENDPOINT, timeout=10):
            raise ValueError('Read-only backend must reject unauthenticated requests')
    except urllib.error.HTTPError as error:
        if error.code != 401:
            raise ValueError('Read-only LAB entitlement endpoint unavailable') from None
    except urllib.error.URLError:
        raise ValueError('Read-only LAB entitlement endpoint unreachable') from None


def main():
    root = Path.cwd()
    try:
        raw = os.environ.get('ROCHA_LAB_GOOGLE_SERVICES_JSON')
        if not raw:
            raise ValueError('ROCHA_LAB_GOOGLE_SERVICES_JSON is missing')
        try:
            source = json.loads(raw)
        except (ValueError, TypeError):
            raise ValueError('LAB Firebase JSON is invalid; private input suppressed') from None
        if not isinstance(source, dict):
            raise ValueError('LAB Firebase JSON must be an object')
        config = configuration(source)
        digest = verify_catalog(root / 'branding/lab_approved.json')
        verify_signer(root / '.rocha-private-lab/lab.keystore', dict(os.environ))
        verify_backend()
        private = root / '.rocha-private-lab'
        private.mkdir(exist_ok=True, mode=0o700)
        target = private / 'firebase.json'
        target.write_text(json.dumps(config), encoding='utf-8')
        target.chmod(0o600)
        print('LAB configuration validated; credentials suppressed')
        print('Approved catalog SHA-256: ' + digest)
    except (ValueError, OSError) as error:
        # All validation messages above are static; never dump raw JSON or keytool logs.
        if isinstance(error, OSError):
            print('::error::Required local LAB preflight input unavailable', file=sys.stderr)
        else:
            print('::error::' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
