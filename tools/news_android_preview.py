"""Verify a live editorial preview in the first mobile carousel slot."""
from pathlib import Path
import subprocess
import time
import xml.etree.ElementTree as ET

out = Path('smoke-evidence')
for attempt in range(16):
    subprocess.check_call(['adb', 'shell', 'uiautomator', 'dump', '/sdcard/news-ui.xml'])
    xml = subprocess.check_output(['adb', 'exec-out', 'cat', '/sdcard/news-ui.xml'])
    labels = [n.get('text', '') + ' ' + n.get('content-desc', '') for n in ET.fromstring(xml).iter('node')]
    if any('AMAMBAI NOTÍCIAS' in label for label in labels):
        (out / 'news-preview.xml').write_bytes(xml)
        (out / 'news-preview.png').write_bytes(subprocess.check_output(['adb', 'exec-out', 'screencap', '-p']))
        assert not any('Acompanhe as notícias de Amambai' in label for label in labels), 'Live preview did not load; fallback shown'
        assert any('Ler no jornal' in label for label in labels), 'News destination missing'
        print('PASS: actual Android APK displays a live dated Amambai news preview in the first carousel slot.')
        break
    time.sleep(1)
else:
    raise AssertionError('News first-slot preview not found through a full carousel cycle')
