"""Commercial APKs must have a real HTTPS API and a TV pairing endpoint."""
import os
import json
from urllib.parse import urlparse

def valid_endpoint(value):
    uri = urlparse(value)
    return (uri.scheme == 'https' and bool(uri.hostname) and not uri.username
            and not uri.password and not uri.query and not uri.fragment
            and uri.hostname not in {'localhost', 'example.com', 'example.invalid'})

def validate(values):
    # A cross-device release must not split the trial between Spark and billing service.
    if values.get('ROCHA_UNIFIED_RELEASE') == 'true' and values.get('ROCHA_SPARK_TRIAL') == 'true':
        raise ValueError('Unified Android/TV release requires server billing; Spark trial cannot be mixed with TV')
    if values.get('ROCHA_SPARK_TRIAL') == 'true':
        if values.get('ROCHA_SPARK_FIREBASE_PROJECT_ID') != 'rocha-plus':
            raise ValueError('Spark requires the confirmed rocha-plus Firebase project')
        return
    for name in ('ROCHA_BILLING_API_URL', 'ROCHA_ROKU_PAIRING_ENDPOINT'):
        if not valid_endpoint(values.get(name, '')):
            raise ValueError(f'{name}: configure the deployed HTTPS service before generating a commercial APK')

if __name__ == '__main__':
    validate(os.environ)
    if os.environ.get('ROCHA_SPARK_TRIAL') == 'true':
        from pathlib import Path
        cfg = json.loads(Path(os.environ['ROCHA_FIREBASE_FILE']).read_text())
        if cfg.get('ROCHA_FIREBASE_PROJECT_ID') != os.environ['ROCHA_SPARK_FIREBASE_PROJECT_ID']:
            raise ValueError('Signed Firebase configuration does not match the confirmed Spark project')
        print('Spark trial: Firestore rules required; automatic payment and Roku pairing are pending')
    else:
        print('Commercial service URLs configured; live payment/device test still required')
