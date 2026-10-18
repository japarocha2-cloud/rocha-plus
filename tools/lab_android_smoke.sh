#!/usr/bin/env bash
set -euo pipefail
apk="$1"
mode="${2:-current}"
mkdir -p smoke-evidence
adb install -r "$apk"
adb logcat -c
adb shell am start -W -n com.rochaplus.labaudit20261018/com.rochaplus.app.MainActivity
sleep 20
adb exec-out screencap -p > smoke-evidence/home.png
navigation_failed=0
if [ "$mode" = current ]; then
  python3 tools/lab_android_navigation.py || navigation_failed=1
fi
adb logcat -d > smoke-evidence/logcat.txt
adb shell run-as com.rochaplus.labaudit20261018 cat cache/rocha_lab_errors.log > smoke-evidence/flutter-errors.txt || true
cat smoke-evidence/flutter-errors.txt
if [ "$mode" = current ]; then
  test -s smoke-evidence/flutter-errors.txt
  if [ "$(wc -l < smoke-evidence/flutter-errors.txt)" -gt 1 ] || rg -q 'debugNeedsLayout|EXCEPTION CAUGHT BY|FATAL EXCEPTION|A RenderFlex overflowed' smoke-evidence/logcat.txt; then
    tail -250 smoke-evidence/logcat.txt
    exit 1
  fi
  test "$navigation_failed" -eq 0
  for attempt in 1 2 3; do
    adb shell am force-stop com.rochaplus.labaudit20261018
    adb shell am start -W -n com.rochaplus.labaudit20261018/com.rochaplus.app.MainActivity
    sleep 4
    adb shell run-as com.rochaplus.labaudit20261018 cat cache/rocha_lab_errors.log > "smoke-evidence/cold-start-$attempt-errors.txt"
    test "$(wc -l < "smoke-evidence/cold-start-$attempt-errors.txt")" -eq 1
    adb exec-out screencap -p > "smoke-evidence/cold-start-$attempt.png"
  done
  echo 'PASS: no Flutter errors through four cold starts, kids navigation and rotation.'
fi
