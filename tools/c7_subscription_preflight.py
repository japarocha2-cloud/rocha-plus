"""Safe binding metadata only: never print or persist secret/config values."""
import json
import os
from lab_credentials import lab_environment

PACKAGE = 'com.rochaplus.app.labc7'
CERT_SHA1 = 'e1ad9a7e3b7388721756f5b7dc6195f8135cd4bd'

def inspect(env):
    result = {name: bool(env.get(key)) for name, key in {
        'officialReadCredentialBound': 'FIREBASE_SERVICE_ACCOUNT_JSON',
        'receivingPaymentCredentialBound': 'MP_RECEIVING_ACCESS_TOKEN',
        'sandboxCredentialBound': 'MP_TEST_ACCESS_TOKEN',
    }.items()}
    result.update(labBundleValid=True, labFirebaseConfigPresent=False,
                  labProjectMatches=False, c7PackageClientPresent=False,
                  c7CertificateRegistered=False, webOAuthClientPresent=False)
    try:
        resolved = lab_environment(env)
        raw = resolved.get('ROCHA_LAB_GOOGLE_SERVICES_JSON')
        result['labFirebaseConfigPresent'] = bool(raw)
        if not raw:
            return result
        config = json.loads(raw)
        result['labProjectMatches'] = config.get('project_info', {}).get('project_id') == 'rocha-plus-homologacao'
        clients = [c for c in config.get('client', []) if c.get('client_info', {}).get('android_client_info', {}).get('package_name') == PACKAGE]
        result['c7PackageClientPresent'] = len(clients) == 1
        if len(clients) == 1:
            oauth = clients[0].get('oauth_client', [])
            result['c7CertificateRegistered'] = any(c.get('client_type') == 1 and
                c.get('android_info', {}).get('package_name') == PACKAGE and
                c.get('android_info', {}).get('certificate_hash', '').replace(':', '').lower() == CERT_SHA1 for c in oauth)
            result['webOAuthClientPresent'] = any(c.get('client_type') == 3 for c in oauth)
    except (ValueError, TypeError, AttributeError):
        result['labBundleValid'] = False
    return result

if __name__ == '__main__':
    # Metadata checks do not prove IAM, live authentication or server access.
    print('::notice title=C7 subscription configuration metadata::'+json.dumps(inspect(os.environ),sort_keys=True))
