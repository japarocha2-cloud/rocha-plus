"""Isolated signed Firebase homologation. Never accepts the official project."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

from prepare_signed_build import subscription_config
from report_apk_certificate import report as report_certificate
from lab_credentials import lab_environment, export_signing_environment, LabBundleFormatError

PROJECT = 'rocha-plus-homologacao'
PACKAGE = 'com.rochaplus.app.lab'
BRANCH = 'refs/heads/feat/dual-player-lab-20261020'


def firebase_configuration(source):
    info = source.get('project_info', {})
    if info.get('project_id') != PROJECT:
        raise ValueError('Homologacao exige o projeto experimental correto')
    clients = [c for c in source.get('client', [])
               if c.get('client_info', {}).get('android_client_info', {}).get('package_name') == PACKAGE]
    if len(clients) != 1:
        raise ValueError('Exige um unico app Android com pacote .lab')
    client = clients[0]
    oauth = client.get('oauth_client', [])
    web_ids = {o.get('client_id') for o in oauth if o.get('client_type') == 3}
    if len(web_ids) != 1 or not all(isinstance(v, str) and v.endswith('.apps.googleusercontent.com') for v in web_ids):
        raise ValueError('Cliente OAuth web ausente ou ambiguo')
    fingerprints = sorted({o.get('android_info', {}).get('certificate_hash', '').lower()
                           for o in oauth if o.get('client_type') == 1 and
                           o.get('android_info', {}).get('package_name') == PACKAGE})
    if not fingerprints or any(not re.fullmatch('[0-9a-f]{40}', v) for v in fingerprints):
        raise ValueError('Cadastre SHA-1 da chave LAB no Firebase e baixe novamente google-services.json')
    keys = client.get('api_key', [])
    config = {
        'ROCHA_FIREBASE_PROJECT_ID': PROJECT,
        'ROCHA_FIREBASE_APP_ID': client.get('client_info', {}).get('mobilesdk_app_id'),
        'ROCHA_FIREBASE_API_KEY': keys[0].get('current_key') if len(keys) == 1 else None,
        'ROCHA_FIREBASE_SENDER_ID': str(info.get('project_number', '')),
        'ROCHA_GOOGLE_SERVER_CLIENT_ID': next(iter(web_ids)),
    }
    if any(not isinstance(v, str) or not v for v in config.values()):
        raise ValueError('Configuracao Firebase incompleta')
    if not config['ROCHA_FIREBASE_APP_ID'].startswith('1:' + config['ROCHA_FIREBASE_SENDER_ID'] + ':android:'):
        raise ValueError('App ID e numero do projeto inconsistentes')
    return config, fingerprints


def prepare(root, private, env):
    if env.get('GITHUB_REF') != BRANCH or env.get('GITHUB_EVENT_NAME') != 'workflow_dispatch':
        raise ValueError('Homologacao assinada exige disparo manual na branch experimental')
    env = lab_environment(env)
    names = ['ROCHA_LAB_GOOGLE_SERVICES_JSON', 'LAB_KEYSTORE_BASE64',
             'LAB_KEYSTORE_PASSWORD', 'LAB_KEY_ALIAS']
    if any(not env.get(k) for k in names):
        raise ValueError('Secrets de homologacao ausentes; nenhum fallback para producao')
    config, fingerprints = firebase_configuration(json.loads(env[names[0]]))
    config.update(subscription_config(env))
    key_bytes = base64.b64decode(env['LAB_KEYSTORE_BASE64'], validate=True)
    if not key_bytes:
        raise ValueError('Chave LAB vazia')
    root, private = Path(root), Path(private)
    gradle = root / 'android/app/build.gradle.kts'
    text = gradle.read_text()
    if 'rochaHomologation' in text or '    buildTypes {' not in text:
        raise ValueError('Scaffold Android inesperado')
    manifest = root / 'android/app/src/main/AndroidManifest.xml'
    tree = ET.parse(manifest)
    app = tree.getroot().find('application')
    if app is None:
        raise ValueError('Application Android ausente')
    private.mkdir(parents=True, exist_ok=True, mode=0o700)
    private.chmod(0o700)
    for name, value in [('lab.keystore', key_bytes),
                        ('firebase.json', json.dumps(config).encode()),
                        ('expected.json', json.dumps({'project': PROJECT, 'package': PACKAGE,
                                                     'certificateSha1': fingerprints}).encode())]:
        path = private / name
        path.touch(mode=0o600)
        path.chmod(0o600)
        path.write_bytes(value)
    # Original signing preparation remains unchanged. Only this generated
    # scaffold receives a release application ID suffix and dedicated LAB key.
    text += '''
android {
    signingConfigs {
        create("rochaHomologation") {
            storeFile = file(System.getenv("ROCHA_HOMOLOGATION_KEYSTORE"))
            storePassword = System.getenv("LAB_KEYSTORE_PASSWORD")
            keyAlias = System.getenv("LAB_KEY_ALIAS")
            keyPassword = System.getenv("LAB_KEYSTORE_PASSWORD")
        }
    }
    buildTypes {
        getByName("release") {
            applicationIdSuffix = ".lab"
            signingConfig = signingConfigs.getByName("rochaHomologation")
        }
    }
}
'''
    gradle.write_text(text)
    app.set('{http://schemas.android.com/apk/res/android}label', 'Rocha+ Homologação')
    ET.register_namespace('android', 'http://schemas.android.com/apk/res/android')
    tree.write(manifest, encoding='utf-8', xml_declaration=True)
    return private / 'firebase.json', private / 'lab.keystore'


def verify(apk, build_tools, expected_file, summary, output):
    expected = json.loads(Path(expected_file).read_text())
    if expected.get('project') != PROJECT or expected.get('package') != PACKAGE:
        raise ValueError('Metadados fora da homologacao')
    badging = subprocess.run([str(Path(build_tools) / 'aapt'), 'dump', 'badging', str(apk)],
                             capture_output=True, text=True, check=True, timeout=90).stdout
    match = re.search(r"^package: name='([^']+)'", badging, re.MULTILINE)
    if not match or match[1] != PACKAGE:
        raise ValueError('APK nao possui pacote .lab; upload bloqueado')
    digests = report_certificate(Path(apk), Path(build_tools) / 'apksigner', Path(summary))
    if not set(d.lower() for d in digests).issubset(set(expected.get('certificateSha1', []))):
        raise ValueError('Certificado do APK nao cadastrado no OAuth Android enviado; upload bloqueado')
    result = {'project': PROJECT, 'package': PACKAGE, 'certificateMatchesConfiguration': True,
              'apkSha256': hashlib.sha256(Path(apk).read_bytes()).hexdigest(),
              'productionApproved': False, 'physicalLoginValidation': 'pending',
              'cloudAccessValidated': False}
    Path(output).parent.mkdir(parents=True, exist_ok=True)
    Path(output).write_text(json.dumps(result, indent=2))
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=['prepare', 'verify'])
    parser.add_argument('--private', type=Path, required=True)
    parser.add_argument('--build-tools', type=Path)
    args = parser.parse_args()
    try:
        if args.operation == 'prepare':
            config, key = prepare(Path.cwd(), args.private, os.environ)
            export_signing_environment(os.environ, os.environ['GITHUB_ENV'])
            with open(os.environ['GITHUB_ENV'], 'a') as stream:
                stream.write(f'ROCHA_HOMOLOGATION_CONFIG={config}\nROCHA_HOMOLOGATION_KEYSTORE={key}\n')
            print('Homologacao preparada; dados privados omitidos.')
        else:
            verify(Path('build/app/outputs/flutter-apk/app-release.apk'), args.build_tools,
                   args.private / 'expected.json', os.environ['GITHUB_STEP_SUMMARY'],
                   'build/qa/homologation.json')
            print('Pacote e certificado de homologacao verificados. Login fisico pendente.')
    except LabBundleFormatError as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
    except Exception as error:
        # Do not print parser/subprocess errors that could include JSON secrets.
        print('Homologacao bloqueada: confira projeto .lab, OAuth Android/SHA-1, chave LAB e scaffold. '
              f'Tipo de falha: {type(error).__name__}.', file=sys.stderr)
        sys.exit(1)
