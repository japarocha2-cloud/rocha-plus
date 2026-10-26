#!/usr/bin/env python3
"""Observe actual feature routes on Android; never inject unvalidated channels."""
import json
from pathlib import Path
import re
import time
import xml.etree.ElementTree as ET
from run_android import adb, PACKAGE

OUT = Path('build/lab/android/feature-ui')


def snapshot(name):
    window = adb('shell', 'dumpsys', 'window')
    focus = re.search(r'mCurrentFocus=([^\n]+)', window)
    if not focus or PACKAGE not in focus.group(1):
        raise RuntimeError('LAB is not the focused Android application')
    (OUT / f'{name}.png').write_bytes(adb('exec-out', 'screencap', '-p', binary=True))
    adb('shell', 'uiautomator', 'dump', '/sdcard/rocha-ui.xml')
    xml = adb('exec-out', 'cat', '/sdcard/rocha-ui.xml')
    (OUT / f'{name}.xml').write_text(xml)
    return ET.fromstring(xml)


def label(node):
    return node.get('content-desc') or node.get('text') or ''


def find_card(name):
    for attempt in range(10):
        tree = snapshot(f'find-{name}-{attempt}')
        for node in tree.iter('node'):
            if label(node).strip() == name:
                bounds = [int(n) for n in re.findall(r'\d+', node.get('bounds', ''))]
                if len(bounds) == 4 and bounds[2] > bounds[0] and bounds[3] > bounds[1]:
                    return bounds
        size = adb('shell', 'wm', 'size')
        width, height = map(int, re.findall(r'(\d+)x(\d+)', size)[-1])
        adb('shell', 'input', 'swipe', str(width // 2), str(height * 4 // 5),
            str(width // 2), str(height // 3), '450')
        time.sleep(1)
    raise RuntimeError(f'Category {name} not observed in Android UI')


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    report = {'checks': [], 'catalogueMutation': False, 'physicalCastTested': False}
    try:
        adb('shell', 'am', 'force-stop', PACKAGE)
        adb('shell', 'am', 'start', '-n', f'{PACKAGE}/com.rochaplus.app.LabActivity',
            '--ez', 'lab_features', 'true', '--es', 'lab_run', 'feature-ui')
        time.sleep(5)
        snapshot('home')
        for category in ['Filmes', 'Religiosos']:
            x1, y1, x2, y2 = find_card(category)
            adb('shell', 'input', 'tap', str((x1 + x2) // 2), str((y1 + y2) // 2))
            time.sleep(2)
            tree = snapshot(category.lower())
            observed = [label(n).strip() for n in tree.iter('node') if label(n).strip()]
            if not any(category == item for item in observed) or 'Atualizar canais' not in observed:
                raise RuntimeError(f'Category title {category} not observed after activation')
            report['checks'].append({'category': category, 'opened': True, 'labels': observed})
            adb('shell', 'input', 'keyevent', '4')
            time.sleep(1)
        report['status'] = 'pass'
    except Exception as error:
        report.update(status='failed_or_inconclusive', error=str(error))
        raise
    finally:
        (OUT / 'ui-report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
        (OUT / 'logcat.txt').write_text(adb('logcat', '-d'))


if __name__ == '__main__':
    main()
