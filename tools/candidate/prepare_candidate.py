"""Independent candidate identity/signing; never uses LAB or official secrets."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import sys

IDENTITY = json.loads(Path(__file__).with_name('identity.json').read_text())
PROJECT = IDENTITY['firebaseProject']
PACKAGE = IDENTITY['package']
REPO = Path(__file__).resolve().parents[2]
ENDPOINT = f'https://southamerica-east1-{PROJECT}.cloudfunctions.net/entitlement'


def private_path(path, root=REPO):
    path = Path(path).resolve()
    if path == Path(root).resolve() or Path(root).resolve() in path.parents:
        raise ValueError('Candidate private material must stay outside the repository')
    return path


def write_private(path, value):
    # Never follow a pre-existing symlink to another file.
    if path.is_symlink():
        raise ValueError('Private symlink is forbidden')
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descriptor, 'w') as stream:
        os.fchmod(stream.fileno(), 0o600)
        stream.write(json.dumps(value, indent=2))


def inspect_signing(private):
    private = private_path(private)
    metadata = private / 'signing.json'
    if private.stat().st_mode & 0o077 or metadata.is_symlink() or metadata.stat().st_mode & 0o077:
        raise ValueError('Candidate signing permissions must be private')
    data = json.loads(metadata.read_text())
    if data.get('alias') != 'rocha-candidate-20261028' or not data.get('password'):
        raise ValueError('Missing independent candidate signing identity')
    key = private / 'candidate.p12'
    if not key.is_file() or key.is_symlink() or key.stat().st_mode & 0o077:
        raise ValueError('Candidate keystore missing')
    result = subprocess.run(['keytool', '-J-Duser.language=en', '-J-Duser.country=US',
        '-list', '-v', '-keystore', str(key), '-alias', data['alias'],
        '-storepass:env', 'ROCHA_CANDIDATE_STORE_PASSWORD'],
        env=os.environ | {'ROCHA_CANDIDATE_STORE_PASSWORD': data['password']},
        capture_output=True, text=True, check=True, timeout=90)
    fingerprints = {}
    for name, length in [('SHA1', 40), ('SHA256', 64)]:
        match = re.search(r'^\s*' + name + r':\s*([A-Fa-f0-9:]+)\s*$', result.stdout, re.MULTILINE)
        value = match[1].replace(':', '').lower() if match else ''
        if not re.fullmatch('[a-f0-9]{' + str(length) + '}', value):
            raise ValueError('Invalid candidate certificate fingerprint')
        fingerprints[name] = value
    return fingerprints


def init_signing(private):
    private = private_path(private)
    if (private / 'candidate.p12').exists() or (private / 'signing.json').exists():
        raise ValueError('Candidate signing already exists; refusing replacement')
    private.mkdir(parents=True, exist_ok=True, mode=0o700)
    private.chmod(0o700)
    password = secrets.token_urlsafe(40)
    data = {'alias': 'rocha-candidate-20261028', 'password': password}
    key = private / 'candidate.p12'
    subprocess.run(['keytool', '-genkeypair', '-noprompt', '-storetype', 'PKCS12',
        '-keystore', str(key), '-alias', data['alias'], '-keyalg', 'RSA', '-keysize', '3072',
        '-validity', '3650', '-dname', 'CN=Rocha Candidate Development,OU=Homologacao,O=Rocha,C=BR',
        '-storepass:env', 'ROCHA_CANDIDATE_STORE_PASSWORD',
        '-keypass:env', 'ROCHA_CANDIDATE_STORE_PASSWORD'],
        env=os.environ | {'ROCHA_CANDIDATE_STORE_PASSWORD': password},
        capture_output=True, text=True, check=True, timeout=90)
    key.chmod(0o600)
    write_private(private / 'signing.json', data)
    return inspect_signing(private)


def firebase_configuration(source, fingerprints):
    info = source.get('project_info', {})
    if info.get('project_id') != PROJECT or not re.fullmatch(r'\d+', str(info.get('project_number', ''))):
        raise ValueError('Candidate requires its own Firebase project')
    clients = [c for c in source.get('client', []) if
        c.get('client_info', {}).get('android_client_info', {}).get('package_name') == PACKAGE]
    if len(clients) != 1:
        raise ValueError('Candidate Android registration missing or ambiguous')
    client = clients[0]
    oauth = client.get('oauth_client', [])
    web = {o.get('client_id') for o in oauth if o.get('client_type') == 3}
    android = {o.get('android_info', {}).get('certificate_hash', '').lower()
        for o in oauth if o.get('client_type') == 1 and
        o.get('android_info', {}).get('package_name') == PACKAGE}
    if (len(web) != 1 or not all(isinstance(v, str) and v.endswith('.apps.googleusercontent.com') for v in web)
            or android != {fingerprints['SHA1']}):
        raise ValueError('Candidate OAuth must match its independent certificate and web client')
    keys = client.get('api_key', [])
    config = {'ROCHA_FIREBASE_PROJECT_ID': PROJECT,
        'ROCHA_FIREBASE_APP_ID': client.get('client_info', {}).get('mobilesdk_app_id'),
        'ROCHA_FIREBASE_API_KEY': keys[0].get('current_key') if len(keys) == 1 else None,
        'ROCHA_FIREBASE_SENDER_ID': str(info['project_number']),
        'ROCHA_GOOGLE_SERVER_CLIENT_ID': next(iter(web))}
    if any(not isinstance(v, str) or not v for v in config.values()) or not config[
            'ROCHA_FIREBASE_APP_ID'].startswith('1:' + str(info['project_number']) + ':android:'):
        raise ValueError('Candidate Firebase configuration is incomplete')
    return config


def require_approved_signer(fingerprints):
    approved = json.loads(Path(__file__).with_name('signer-public.json').read_text())
    if fingerprints != approved:
        raise ValueError('Candidate certificate must match approved public signing identity')


def prepare(root, private, source, env):
    root, private = Path(root), private_path(private, root)
    if env.get('GITHUB_REF') != IDENTITY['branch'] or env.get('GITHUB_EVENT_NAME') != 'workflow_dispatch':
        raise ValueError('Candidate preparation requires manual isolated branch')
    fingerprints = inspect_signing(private)
    require_approved_signer(fingerprints)
    config = firebase_configuration(source, fingerprints)
    enabled = env.get('ROCHA_CANDIDATE_SUBSCRIPTIONS', 'false')
    endpoint = env.get('ROCHA_CANDIDATE_ENTITLEMENT_URL', '')
    if enabled not in ('true', 'false') or endpoint != (ENDPOINT if enabled == 'true' else ''):
        raise ValueError('Candidate endpoint must belong only to candidate Firebase project')
    config.update({'ROCHA_EXPERIMENTAL_SUBSCRIPTIONS': enabled, 'ROCHA_ENTITLEMENT_URL': endpoint,
        'ROCHA_LAB_ONLY': 'false', 'ROCHA_LAYOUT_PREVIEW': 'false'})
    gradle = root / 'android/app/build.gradle.kts'
    text = gradle.read_text()
    replacements = {
        'applicationId = "com.rochaplus.app"': 'applicationId = "' + PACKAGE + '"',
        'applicationIdSuffix = ".lab"': 'applicationIdSuffix = ".debug"',
        'signingConfig = signingConfigs.getByName("debug")':
            'signingConfig = signingConfigs.getByName("rochaCandidate")',
    }
    if 'rochaCandidate' in text or text.count('    buildTypes {') != 1:
        raise ValueError('Unexpected candidate scaffold')
    for old in replacements:
        if text.count(old) != 1:
            raise ValueError('Unexpected application ID or signing scaffold')
    for old, new in replacements.items():
        text = text.replace(old, new)
    signing = '''    signingConfigs {
        create("rochaCandidate") {
            storeFile = file(System.getenv("ROCHA_CANDIDATE_KEYSTORE"))
            storePassword = System.getenv("ROCHA_CANDIDATE_STORE_PASSWORD")
            keyAlias = System.getenv("ROCHA_CANDIDATE_KEY_ALIAS")
            keyPassword = System.getenv("ROCHA_CANDIDATE_STORE_PASSWORD")
        }
    }
'''
    text = text.replace('    buildTypes {', signing + '    buildTypes {')
    # All validation precedes mutation. Private configuration never enters the repo.
    write_private(private / 'dart-define.json', config)
    write_private(private / 'expected.json', IDENTITY | {'fingerprints': fingerprints,
        'subscriptionEnforcementConfigured': enabled == 'true', 'endpoint': endpoint})
    gradle.write_text(text)
    return private / 'dart-define.json'


def verify(apk, build_tools, private):
    private = private_path(private)
    expected = json.loads((private / 'expected.json').read_text())
    if any(expected.get(k) != IDENTITY[k] for k in IDENTITY):
        raise ValueError('Candidate identity metadata mismatch')
    fingerprints = inspect_signing(private)
    require_approved_signer(fingerprints)
    if expected.get('fingerprints') != fingerprints:
        raise ValueError('Candidate signing metadata mismatch')
    tools = Path(build_tools)
    badging = subprocess.run([str(tools / 'aapt'), 'dump', 'badging', str(apk)],
        capture_output=True, text=True, check=True, timeout=90).stdout
    package = re.search(r"^package: name='([^']+)' versionCode='([^']+)' versionName='([^']+)'", badging, re.MULTILINE)
    native = re.search(r'^native-code: (.+)$', badging, re.MULTILINE)
    abis = re.findall(r"'([^']+)'", native[1]) if native else []
    if (not package or package.groups() != (PACKAGE, str(IDENTITY['versionCode']), IDENTITY['versionName'])
            or 'arm64-v8a' not in abis or not set(abis) <= {'armeabi-v7a', 'arm64-v8a', 'x86_64'}):
        raise ValueError('Candidate package/version/ABI mismatch')
    signed = subprocess.run([str(tools / 'apksigner'), 'verify', '--print-certs', str(apk)],
        capture_output=True, text=True, check=True, timeout=90).stdout
    for kind, size in [('1', 40), ('256', 64)]:
        pattern = (r'^(?:Signer #\d+|V[1-4](?:\.\d+)? Signer:?) certificate SHA-' + kind +
            r' digest: ([0-9a-fA-F]{' + str(size) + r'})\s*$')
        values = {v.lower() for v in re.findall(pattern, signed, re.MULTILINE)}
        if values != {fingerprints['SHA' + kind]}:
            raise ValueError('APK certificate does not match candidate signing')
    return {'package': PACKAGE, 'versionName': IDENTITY['versionName'], 'versionCode': IDENTITY['versionCode'],
        'abis': abis, 'apkSha256': hashlib.sha256(Path(apk).read_bytes()).hexdigest(),
        'certificate': fingerprints, 'productionApproved': False, 'physicalValidation': 'pending'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=['init-signing', 'prepare', 'verify'])
    parser.add_argument('--private', type=Path, required=True)
    parser.add_argument('--google-services', type=Path)
    parser.add_argument('--apk', type=Path)
    parser.add_argument('--build-tools', type=Path)
    args = parser.parse_args()
    try:
        if args.operation == 'init-signing':
            print(json.dumps(init_signing(args.private), indent=2))  # Public cert only.
        elif args.operation == 'prepare':
            prepare(REPO, args.private, json.loads(args.google_services.read_text()), os.environ)
            print('Candidate prepared; private configuration omitted.')
        else:
            print(json.dumps(verify(args.apk, args.build_tools, args.private), indent=2))
    except Exception as error:
        print('Candidate blocked: ' + type(error).__name__ + '; private details omitted.', file=sys.stderr)
        sys.exit(1)
