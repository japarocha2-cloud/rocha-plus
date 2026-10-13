"""Commercial APKs must have a real HTTPS API and a TV pairing endpoint."""
import os
from urllib.parse import urlparse

def valid_endpoint(value):
    uri = urlparse(value)
    return (uri.scheme == 'https' and bool(uri.hostname) and not uri.username
            and not uri.password and not uri.query and not uri.fragment
            and uri.hostname not in {'localhost', 'example.com', 'example.invalid'})

def validate(values):
    for name in ('ROCHA_BILLING_API_URL', 'ROCHA_ROKU_PAIRING_ENDPOINT'):
        if not valid_endpoint(values.get(name, '')):
            raise ValueError(f'{name}: configure the deployed HTTPS service before generating a commercial APK')

if __name__ == '__main__':
    validate(os.environ)
    print('Commercial service URLs configured; live payment/device test still required')
