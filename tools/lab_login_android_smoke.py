"""Check the actual signed APK stops at enabled Google login (no user credentials)."""
from pathlib import Path
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

out = Path('login-evidence')
out.mkdir(exist_ok=True)
package = 'com.rochaplus.soultvtest'


def adb(*args):
    return subprocess.check_output(['adb', *args])


def check_login(name):
    adb('shell', 'uiautomator', 'dump', '/sdcard/rl-login.xml')
    xml = adb('exec-out', 'cat', '/sdcard/rl-login.xml')
    (out / f'{name}.xml').write_bytes(xml)
    (out / f'{name}.png').write_bytes(adb('exec-out', 'screencap', '-p'))
    nodes = list(ET.fromstring(xml).iter('node'))
    labels = [n.get('text', '') + ' ' + n.get('content-desc', '') for n in nodes]
    google = [n for n, label in zip(nodes, labels) if 'Entrar com Google' in label]
    assert google, 'Signed APK did not stop at login'
    assert any(n.get('enabled') == 'true' and n.get('clickable') == 'true' for n in google), 'Google login is disabled'
    assert not any('O login ainda não foi ativado' in label or 'Não foi possível iniciar o login' in label for label in labels), labels
    assert not any('21 canais' in label or 'Canais populares' in label for label in labels), 'Unexpected unauthenticated Home access'


adb('install', '-r', sys.argv[1])
adb('logcat', '-c')
adb('shell', 'am', 'start', '-W', '-n', package + '/com.rochaplus.app.MainActivity')
time.sleep(15)
try:
    check_login('login-portrait')
    adb('shell', 'settings', 'put', 'system', 'accelerometer_rotation', '0')
    adb('shell', 'settings', 'put', 'system', 'user_rotation', '1')
    time.sleep(3)
    check_login('login-landscape')
    adb('shell', 'settings', 'put', 'system', 'user_rotation', '0')
    adb('shell', 'am', 'force-stop', package)
    adb('shell', 'am', 'start', '-W', '-n', package + '/com.rochaplus.app.MainActivity')
    time.sleep(5)
    check_login('login-reopened')
finally:
    logs = adb('logcat', '-d').decode(errors='replace')
    (out / 'logcat.txt').write_text(logs)
assert not any(error in logs for error in ['FATAL EXCEPTION', 'debugNeedsLayout', 'EXCEPTION CAUGHT BY', 'A RenderFlex overflowed']), 'Android runtime error; see evidence'
print('PASS: real signed APK requires login; Google enabled; portrait, landscape and reopen without Flutter exceptions.')
print('Pending: physical Google account selection, session persistence and playback after authentication.')
