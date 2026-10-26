"""Verify an APK and report certificate fingerprints without depending on signer labels."""
import os
from pathlib import Path
import re
import subprocess
import sys


def certificate_fingerprints(output):
    # apksigner uses numbered labels for v1/v2 and SDK-range labels for v3/v3.1.
    # Never confuse a public-key digest or a source stamp with the APK signer.
    pattern = r'^Signer (?:#\d+|\(minSdkVersion=[^\r\n]+\)) certificate SHA-1 digest: ([0-9a-fA-F]{40})\s*$'
    fingerprints = list(dict.fromkeys(re.findall(pattern, output, re.MULTILINE)))
    if not fingerprints:
        raise ValueError('Verified APK output contained no recognized signer certificate SHA-1 digest')
    return fingerprints


def report(apk, signer, summary):
    if not apk.is_file():
        raise FileNotFoundError(f'APK missing: {apk}')
    if not signer.is_file() or not os.access(signer, os.X_OK):
        raise FileNotFoundError(f'Executable apksigner missing: {signer}')
    result = subprocess.run([str(signer), 'verify', '--print-certs', str(apk)],
                            capture_output=True, text=True, timeout=90)
    # Public certificate diagnostics only: no keystore, environment or secrets.
    print(f'apksigner: {signer}; exit code: {result.returncode}', flush=True)
    print(result.stdout, end='', flush=True)
    print(result.stderr, end='', file=sys.stderr, flush=True)
    result.check_returncode()
    fingerprints = certificate_fingerprints(result.stdout)
    with summary.open('a') as stream:
        stream.write('### Certificado do APK experimental\n')
        for fingerprint in fingerprints:
            stream.write(f'SHA-1 do certificado do APK: `{fingerprint}`\n')
        stream.write('Diagnóstico de assinatura LAB; não comprova login Firebase. '
                     'Sem chave LAB estável, a assinatura debug pode mudar entre execuções.\n')
    return fingerprints


if __name__ == '__main__':
    try:
        report(Path(sys.argv[1]), Path(sys.argv[2]), Path(os.environ['GITHUB_STEP_SUMMARY']))
    except Exception as error:
        print(f'APK certificate verification failed: {error}', file=sys.stderr)
        sys.exit(1)
