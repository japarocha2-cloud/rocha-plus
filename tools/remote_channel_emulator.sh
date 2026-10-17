#!/usr/bin/env bash
set -euo pipefail
log=/tmp/remote-channel-runtime.log
evidence=/tmp/remote-channel-evidence.log
: > "$evidence"
trap 'adb logcat -d > "$log"; tail -80 "$log"' EXIT
wait_playing() {
  local name="$1"
  for attempt in $(seq 1 60); do
    adb logcat -d > "$log"
    if grep -Fq "ROCHA_REMOTE_PLAYING name=$name " "$log"; then
      grep -F "ROCHA_REMOTE_PLAYING name=$name " "$log" | tee -a "$evidence"
      return
    fi
    sleep 1
  done
  echo "Native playback was not confirmed for $name" >&2
  return 1
}
adb install build/app/outputs/flutter-apk/app-release.apk
adb logcat -c
adb shell am start -n com.rochaplus.remoteprobe/com.rochaplus.app.MainActivity
wait_playing 'Kuriakos Kids'
adb logcat -c
adb shell input keyevent 166
wait_playing '3ABN Kids'
grep -Fq 'ROCHA_REMOTE_SELECTION name=3ABN Kids' "$log"
adb logcat -c
adb shell input keyevent 167
wait_playing 'Kuriakos Kids'
grep -Fq 'ROCHA_REMOTE_SELECTION name=Kuriakos Kids' "$log"
adb logcat -c
adb shell input keyevent 19
wait_playing '3ABN Kids'
adb logcat -c
adb shell input keyevent 23
adb shell input keyevent 20
sleep 2
adb logcat -d > "$log"
if grep -q 'ROCHA_REMOTE_SELECTION' "$log"; then
  echo 'Directional focus navigation unexpectedly changed channel' >&2
  exit 1
fi
echo 'ROCHA_REMOTE_KEYS_OK: CH+, CH-, D-pad fallback and visible control navigation' | tee -a "$evidence"
