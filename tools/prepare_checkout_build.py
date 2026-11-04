"""Prepare isolated checkout APK from a privately reviewed configuration."""
import base64
import json
import os
from pathlib import Path
from urllib.parse import urlsplit

def validate(bundle):
    required = ('verified_by', 'verified_at', 'firebase_project_id', 'firebase_app_id',
                'firebase_sender_id', 'firebase_api_key', 'google_server_client_id',
                'android_package', 'signing_sha256', 'checkout_url', 'entitlement_url',
                'backend_project_id', 'backend_token_audience', 'merchant_id')
    missing = [key for key in required if not bundle.get(key)]
    if missing:
        raise ValueError('Campos ausentes: ' + ', '.join(missing))
    if (bundle.get('checkout_enabled') is not False or
            bundle.get('payment_mode') != 'one_time' or
            bundle['android_package'] != 'com.rochaplus.app.checkout' or
            bundle['firebase_project_id'] != bundle['backend_project_id'] or
            bundle['firebase_project_id'] != bundle['backend_token_audience'] or
            bundle.get('backend_kind') != 'firebase_entitlements' or
            bundle.get('identity_binding') != 'firebase_uid'):
        raise ValueError('Identidade/backend/modo nao verificados para checkout isolado')
    if len(bundle['signing_sha256'].replace(':', '')) != 64:
        raise ValueError('Certificado SHA256 invalido')
    for key, function in [('checkout_url', 'checkout'), ('entitlement_url', 'entitlement')]:
        u = urlsplit(bundle[key])
        expected = 'southamerica-east1-' + bundle['backend_project_id'] + '.cloudfunctions.net'
        if (u.scheme != 'https' or u.hostname != expected or u.path != '/' + function or
                u.username or u.password or u.query or u.fragment or u.port not in (None, 443)):
            raise ValueError('Endpoint nao corresponde ao projeto Firebase verificado')
    return {
        'ROCHA_FIREBASE_PROJECT_ID': bundle['firebase_project_id'],
        'ROCHA_FIREBASE_APP_ID': bundle['firebase_app_id'],
        'ROCHA_FIREBASE_API_KEY': bundle['firebase_api_key'],
        'ROCHA_FIREBASE_SENDER_ID': bundle['firebase_sender_id'],
        'ROCHA_GOOGLE_SERVER_CLIENT_ID': bundle['google_server_client_id'],
        'ROCHA_CHECKOUT_URL': bundle['checkout_url'],
        'ROCHA_ENTITLEMENT_URL': bundle['entitlement_url'],
        'ROCHA_CENTRAL_RIGHTS': 'false', 'ROCHA_EXPERIMENTAL_SUBSCRIPTIONS': 'false',
        'ROCHA_LAB_ONLY': 'false', 'ROCHA_LAYOUT_PREVIEW': 'false',
    }

def main():
    names = ('ROCHA_CHECKOUT_HOMOLOGATION_JSON', 'ROCHA_KEYSTORE_BASE64',
             'ROCHA_KEYSTORE_PASSWORD', 'ROCHA_KEY_ALIAS')
    missing = [key for key in names if not os.environ.get(key)]
    if missing:
        raise ValueError('Configuracoes privadas ausentes: ' + ', '.join(missing))
    bundle = json.loads(os.environ[names[0]])
    defines = validate(bundle)
    private = Path(os.environ['RUNNER_TEMP']) / 'rocha-checkout-private'
    private.mkdir(mode=0o700, exist_ok=True)
    key = private / 'release.p12'
    key.write_bytes(base64.b64decode(os.environ['ROCHA_KEYSTORE_BASE64'], validate=True))
    key.chmod(0o600)
    config = private / 'defines.json'
    config.write_text(json.dumps(defines))
    config.chmod(0o600)
    gradle = Path('android/app/build.gradle.kts')
    source = gradle.read_text()
    needle = 'signingConfig = signingConfigs.getByName("debug")'
    if needle not in source or '    buildTypes {' not in source:
        raise ValueError('Scaffold Android inesperado')
    block = '''    signingConfigs {
        create("checkoutHomologation") {
            storeFile = file(System.getenv("ROCHA_SIGNING_FILE"))
            storeType = "PKCS12"
            storePassword = System.getenv("ROCHA_KEYSTORE_PASSWORD")
            keyAlias = System.getenv("ROCHA_KEY_ALIAS")
            keyPassword = System.getenv("ROCHA_KEYSTORE_PASSWORD")
        }
    }
'''
    source = source.replace('    buildTypes {', block + '    buildTypes {', 1)
    source = source.replace(needle, 'signingConfig = signingConfigs.getByName("checkoutHomologation")')
    source += '\nandroid { buildTypes { getByName("release") { applicationIdSuffix = ".checkout" } } }\n'
    gradle.write_text(source)
    manifest = Path('android/app/src/main/AndroidManifest.xml')
    import xml.etree.ElementTree as ET
    tree = ET.parse(manifest)
    app = tree.getroot().find('application')
    app.set('{http://schemas.android.com/apk/res/android}label', 'Rocha+ Checkout HOM')
    # Kotlin source package differs from isolated application ID.
    for activity in app.findall('activity'):
        if activity.get('{http://schemas.android.com/apk/res/android}name') == '.MainActivity':
            activity.set('{http://schemas.android.com/apk/res/android}name', 'com.rochaplus.app.MainActivity')
    tree.write(manifest, encoding='utf-8', xml_declaration=True)
    with open(os.environ['GITHUB_ENV'], 'a') as output:
        output.write(f'ROCHA_SIGNING_FILE={key}\nROCHA_FIREBASE_FILE={config}\n')
    # Compare actual signing certificate without printing private key material.
    import subprocess, hashlib
    cert = subprocess.run(['keytool', '-exportcert', '-keystore', str(key),
        '-storetype', 'PKCS12', '-storepass:env', 'ROCHA_KEYSTORE_PASSWORD',
        '-alias', os.environ['ROCHA_KEY_ALIAS']], check=True, capture_output=True).stdout
    expected = bundle['signing_sha256'].replace(':', '').lower()
    if hashlib.sha256(cert).hexdigest() != expected:
        raise ValueError('Certificado diverge da configuracao Firebase revisada')
    print('Configuracao isolada validada estruturalmente; validacao runtime ainda obrigatoria.')

if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, TypeError, OSError):
        raise SystemExit('Configuracao de checkout ausente ou invalida. Verifique o bundle revisado e os secrets de assinatura; valores omitidos.')
