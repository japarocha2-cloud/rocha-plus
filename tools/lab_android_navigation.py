"""Exercise the packaged lab UI without opening third-party streams."""
from pathlib import Path
import re
import subprocess
import time
import xml.etree.ElementTree as ET

EVIDENCE = Path('smoke-evidence')
def adb(*args):
    return subprocess.check_output(['adb', *args])
def hierarchy(name):
    adb('shell', 'uiautomator', 'dump', '/sdcard/rocha-lab-ui.xml')
    xml = adb('exec-out', 'cat', '/sdcard/rocha-lab-ui.xml')
    (EVIDENCE / name).write_bytes(xml)
    return ET.fromstring(xml)
def label(node):
    return node.get('text', '') + ' ' + node.get('content-desc', '')
def bounds(node):
    return [int(x) for x in re.findall(r'\d+', node.get('bounds', ''))]

for attempt in range(5):
    root = hierarchy(f'home-ui-{attempt}.xml')
    candidates = [n for n in root.iter('node') if 'Infantil' in label(n) and len(bounds(n)) == 4]
    if candidates:
        node = min(candidates, key=lambda n: (bounds(n)[2]-bounds(n)[0])*(bounds(n)[3]-bounds(n)[1]))
        x1, y1, x2, y2 = bounds(node)
        adb('shell', 'input', 'tap', str((x1+x2)//2), str((y1+y2)//2))
        break
    sizes = [bounds(n) for n in root.iter('node') if len(bounds(n)) == 4]
    width, height = max(b[2] for b in sizes), max(b[3] for b in sizes)
    adb('shell', 'input', 'swipe', str(width//2), str(int(height*.82)), str(width//2), str(int(height*.30)), '450')
    time.sleep(1)
else:
    raise AssertionError('Infantil navigation target was not found in Android UI')
time.sleep(3)
root = hierarchy('kids-ui.xml')
(EVIDENCE / 'kids.png').write_bytes(adb('exec-out', 'screencap', '-p'))
labels = [label(n) for n in root.iter('node')]
assert any('Infantil' in x for x in labels), labels
assert any('21 canais' in x for x in labels), labels
assert not any('Não foi possível carregar' in x for x in labels), labels
adb('shell', 'input', 'keyevent', '4')
time.sleep(1)
adb('shell', 'settings', 'put', 'system', 'accelerometer_rotation', '0')
adb('shell', 'settings', 'put', 'system', 'user_rotation', '1')
time.sleep(2)
(EVIDENCE / 'home-landscape.png').write_bytes(adb('exec-out', 'screencap', '-p'))
adb('shell', 'settings', 'put', 'system', 'user_rotation', '0')
time.sleep(2)
print('PASS: Android Home -> Infantil (21 channels) -> Home -> rotation')
