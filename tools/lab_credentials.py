"""Resolve a single private LAB bundle without permitting production credentials."""
import base64
import json
from pathlib import Path
import re
import sys

FIELDS = {
    'LAB_KEYSTORE_BASE64': 'ROCHA_LAB_KEYSTORE_BASE64',
    'LAB_KEYSTORE_PASSWORD': 'ROCHA_LAB_KEYSTORE_PASSWORD',
    'LAB_KEY_ALIAS': 'ROCHA_LAB_KEY_ALIAS',
    'ROCHA_LAB_GOOGLE_SERVICES_JSON': 'ROCHA_LAB_GOOGLE_SERVICES_JSON',
}


class LabBundleFormatError(ValueError):
    """Public formatting diagnostic which never contains credential contents."""


def decode_lab_bundle(raw):
    if not isinstance(raw, str) or len(raw) > 2_000_000:
        raise LabBundleFormatError('LAB bundle ausente ou excede limite de tamanho')
    text = raw.strip().lstrip('\ufeff').strip()
    if text.startswith(('https://', 'http://')):
        raise LabBundleFormatError('O secret contem um link; cole o conteudo completo do arquivo, nao sua URL')
    lines = text.splitlines()
    if len(lines) >= 3 and lines[0].strip().lower() in ('```', '```json') and lines[-1].strip() == '```':
        text = '\n'.join(lines[1:-1]).strip()
    if text.startswith('ROCHA_LAB_V1:'):
        try:
            encoded = ''.join(text.removeprefix('ROCHA_LAB_V1:').split())
            text = base64.b64decode(encoded, validate=True).decode('utf-8')
        except (ValueError, UnicodeError):
            raise LabBundleFormatError('Texto LAB incompleto; copie todo o arquivo de configuracao') from None
    for _ in range(2):
        try:
            value = json.loads(text)
        except json.JSONDecodeError as error:
            kind = 'objeto JSON' if text.startswith('{') else 'texto sem abertura JSON'
            raise LabBundleFormatError(
                f'JSON LAB invalido: {kind}; {len(text)} caracteres; linha {error.lineno}, '
                f'coluna {error.colno}. Cole o arquivo completo') from None
        if isinstance(value, dict):
            return value
        if not isinstance(value, str):
            break
        text = value.strip().lstrip('\ufeff').strip()
    raise LabBundleFormatError('O bundle LAB precisa ser um objeto JSON completo')


def lab_environment(env):
    result = dict(env)
    raw = env.get('ROCHA_LAB_BUNDLE_JSON')
    if raw:
        bundle = decode_lab_bundle(raw)
        if (bundle.get('project') != 'rocha-plus-homologacao' or
                bundle.get('package') != 'com.rochaplus.app.lab'):
            raise ValueError('Bundle restrito ao projeto e pacote de homologacao')
        values = bundle.get('secrets', {})
        if not isinstance(values, dict) or set(values) != set(FIELDS.values()):
            raise ValueError('Bundle exige exatamente os quatro campos LAB')
        for target, source in FIELDS.items():
            value = values[source]
            if not isinstance(value, str) or not value:
                raise ValueError('Campo LAB invalido')
            if result.get(target) and result[target] != value:
                raise ValueError('Secrets individuais e bundle LAB inconsistentes')
            result[target] = value
    for field in ('LAB_KEYSTORE_PASSWORD', 'LAB_KEY_ALIAS'):
        if any(c in result.get(field, '') for c in ('\n', '\r', '\x00')):
            raise ValueError('Credencial LAB nao pode conter controles de linha')
    if result.get('LAB_KEY_ALIAS') and not re.fullmatch(r'[A-Za-z0-9_.-]{1,80}', result['LAB_KEY_ALIAS']):
        raise ValueError('Alias LAB invalido')
    if result.get('LAB_KEYSTORE_BASE64'):
        if len(result['LAB_KEYSTORE_BASE64']) > 2_000_000:
            raise ValueError('Chave LAB excede limite')
        base64.b64decode(result['LAB_KEYSTORE_BASE64'], validate=True)
    return result


def export_signing_environment(env, path, stream=None):
    stream = stream if stream is not None else sys.stdout
    env = lab_environment(env)
    fields = ('LAB_KEYSTORE_PASSWORD', 'LAB_KEY_ALIAS')
    if any(not env.get(k) for k in fields):
        raise ValueError('Credenciais LAB incompletas')
    # Mask individual fields, since GitHub initially knows only the whole JSON.
    for field in ('LAB_KEYSTORE_BASE64', *fields):
        if env.get(field):
            print('::add-mask::' + env[field], file=stream)
    with Path(path).open('a') as output:
        for field in fields:
            output.write(field + '=' + env[field] + '\n')
