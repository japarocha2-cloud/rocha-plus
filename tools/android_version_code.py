"""Keep Android update ordering above historical device builds (e.g. 2465)."""
import os
from pathlib import Path

VERSION_CODE_BASE = 3000
MAX_VERSION_CODE = 2_100_000_000

def resolve_version_code(run_number):
    if not isinstance(run_number, str) or not run_number.isascii() or not run_number.isdigit():
        raise ValueError('GITHUB_RUN_NUMBER must be a positive decimal integer')
    value = int(run_number)
    code = VERSION_CODE_BASE + value
    if value < 1 or code > MAX_VERSION_CODE:
        raise ValueError('Android versionCode outside supported range')
    return code

if __name__ == '__main__':
    code = resolve_version_code(os.environ['GITHUB_RUN_NUMBER'])
    with Path(os.environ['GITHUB_ENV']).open('a', encoding='utf-8') as output:
        output.write(f'ROCHA_ANDROID_VERSION_CODE={code}\n')
    print(f'Android versionCode: {code}; workflow run: {os.environ["GITHUB_RUN_NUMBER"]}')
