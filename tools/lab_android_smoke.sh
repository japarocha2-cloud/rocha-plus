#!/usr/bin/env bash
set -euo pipefail
apk="$1"
mode="${2:-current}"
mkdir -p smoke-evidence
adb install -r "$apk"
adb logcat -c
adb shell am start -W -n com.rochaplus.labpositivos/com.rochaplus.app.MainActivity
sleep 20
adb logcat -d > smoke-evidence/logcat.txt
adb shell run-as com.rochaplus.labpositivos cat cache/rocha_lab_errors.log > smoke-evidence/flutter-errors.txt || true
cat smoke-evidence/flutter-errors.txt
adb exec-out screencap -p > smoke-evidence/home.png
if [ "$mode" = baseline ]; then
  # Diagnostic run records the original APK, even when it reproduces the bug.
  python3 - <<'PY'
from pathlib import Path
s=Path('smoke-evidence/logcat.txt').read_text(errors='replace')
lines=s.splitlines()
for i,line in enumerate(lines):
 if 'debugNeedsLayout' in line or 'EXCEPTION CAUGHT' in line or 'FATAL EXCEPTION' in line:
  print('\n'.join(lines[max(0,i-3):i+65]))
PY
else
  if rg -q 'debugNeedsLayout|EXCEPTION CAUGHT BY|FATAL EXCEPTION|A RenderFlex overflowed' smoke-evidence/logcat.txt; then
    tail -250 smoke-evidence/logcat.txt
    exit 1
  fi
fi
