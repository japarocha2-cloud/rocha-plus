"""Verify first-slot news; explicitly distinguish live data from publisher HTTP 403."""
from pathlib import Path
import json
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
        fallback = any('Acompanhe as notícias de Amambai' in label for label in labels)
        logcat = subprocess.check_output(['adb', 'logcat', '-d']).decode(errors='replace')
        if fallback:
            assert '[RochaNews] http=403' in logcat, 'Preview missing without a confirmed publisher HTTP 403; inspect logs'
            result = {'live_fetch_verified': False, 'publisher_http_status': 403,
                      'fallback_verified': True, 'physical_network_test_required': True}
            print('PASS: first-slot fallback handles confirmed publisher HTTP 403 without breaking Home.')
            print('LIVE NEWS FETCH NOT VERIFIED: physical network verification required.')
        else:
            result = {'live_fetch_verified': True, 'fallback_verified': False}
            print('PASS: actual Android APK displays a live dated Amambai news preview in the first carousel slot.')
        (out / 'news-verification.json').write_text(json.dumps(result, indent=2))
        assert any('Ler no jornal' in label for label in labels), 'News destination missing'
        break
    time.sleep(1)
else:
    raise AssertionError('News first-slot preview not found through a full carousel cycle')
