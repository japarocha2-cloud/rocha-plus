"""Restore private release inputs only in an explicitly dispatched build."""
import base64
import json
import os
from urllib.parse import urlsplit
import ipaddress
from pathlib import Path

def subscription_config(env):
    enabled = env.get('ROCHA_SUBSCRIPTION_LAB', 'false')
    if enabled not in ('true', 'false'):
        raise ValueError('Opcao experimental invalida')
    result = {'ROCHA_EXPERIMENTAL_SUBSCRIPTIONS': enabled,
              'ROCHA_LAB_ONLY': 'false', 'ROCHA_LAYOUT_PREVIEW': 'false',
              'ROCHA_ENTITLEMENT_URL': ''}
    if enabled == 'false':
        return result
    if env.get('GITHUB_REF') != 'refs/heads/feat/dual-player-lab-20261020':
        raise ValueError('Bloqueio permitido apenas na branch experimental')
    endpoint = env.get('ROCHA_ENTITLEMENT_URL', '')
    parsed = urlsplit(endpoint)
    host = parsed.hostname or ''
    try:
        ipaddress.ip_address(host)
        is_ip = True
    except ValueError:
        is_ip = False
    if (parsed.scheme != 'https' or not host or '.' not in host or is_ip
            or host.endswith(('.localhost', '.local'))
            or parsed.username is not None or parsed.password is not None
            or parsed.port not in (None, 443) or parsed.query or parsed.fragment
            or not parsed.path or any(c.isspace() for c in endpoint)):
        raise ValueError('Servico experimental exige URL HTTPS publica sem credenciais')
    result['ROCHA_ENTITLEMENT_URL'] = endpoint
    return result

def prepare(root, private, env):
    names = ('ROCHA_KEYSTORE_BASE64', 'ROCHA_KEYSTORE_PASSWORD',
             'ROCHA_KEY_ALIAS', 'ROCHA_FIREBASE_CONFIG_JSON')
    missing = [name for name in names if not env.get(name)]
    if missing:
        raise ValueError('Secrets ausentes: ' + ', '.join(missing))
    config = json.loads(env['ROCHA_FIREBASE_CONFIG_JSON'])
    required = ('ROCHA_FIREBASE_PROJECT_ID', 'ROCHA_FIREBASE_APP_ID',
                'ROCHA_FIREBASE_API_KEY', 'ROCHA_FIREBASE_SENDER_ID',
                'ROCHA_GOOGLE_SERVER_CLIENT_ID')
    if any(not config.get(name) for name in required):
        raise ValueError('Configuracao Firebase incompleta')
    if config['ROCHA_FIREBASE_PROJECT_ID'] != 'rocha-plus':
        raise ValueError('Projeto Firebase inesperado')
    if config['ROCHA_FIREBASE_APP_ID'] != '1:977269532083:android:7f7b15eff64a6a443f97c6':
        raise ValueError('App Firebase inesperado')
    # Controlled build modes cannot be injected through the Firebase JSON.
    config.update(subscription_config(env))
    private = Path(private)
    private.mkdir(parents=True, exist_ok=True)
    key = private / 'release.p12'
    key.write_bytes(base64.b64decode(env['ROCHA_KEYSTORE_BASE64'], validate=True))
    key.chmod(0o600)
    config_path = private / 'firebase.json'
    config_path.write_text(json.dumps(config), encoding='utf-8')
    config_path.chmod(0o600)
    gradle = Path(root) / 'android/app/build.gradle.kts'
    text = gradle.read_text(encoding='utf-8')
    needle = 'signingConfig = signingConfigs.getByName("debug")'
    if needle not in text or '    buildTypes {' not in text:
        raise ValueError('Formato Gradle inesperado; assinatura nao aplicada')
    block = '''    signingConfigs {
        create("rochaRelease") {
            storeFile = file(System.getenv("ROCHA_SIGNING_FILE"))
            storeType = "PKCS12"
            storePassword = System.getenv("ROCHA_KEYSTORE_PASSWORD")
            keyAlias = System.getenv("ROCHA_KEY_ALIAS")
            keyPassword = System.getenv("ROCHA_KEYSTORE_PASSWORD")
        }
    }
'''
    text = text.replace('    buildTypes {', block + '    buildTypes {', 1)
    text = text.replace(needle, 'signingConfig = signingConfigs.getByName("rochaRelease")')
    gradle.write_text(text, encoding='utf-8')
    return key, config_path

if __name__ == '__main__':
    try:
        key, config = prepare(Path.cwd(), Path(os.environ['RUNNER_TEMP']) / 'rocha-private', os.environ)
        with open(os.environ['GITHUB_ENV'], 'a', encoding='utf-8') as output:
            output.write(f'ROCHA_SIGNING_FILE={key}\nROCHA_FIREBASE_FILE={config}\n')
        print('Configuracao privada preparada; valores omitidos.')
    except (ValueError, KeyError):
        raise SystemExit('Configuracao assinada invalida. Confira os Secrets e, no teste de bloqueio, a branch experimental e a URL HTTPS.')
