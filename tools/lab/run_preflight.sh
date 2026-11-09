#!/bin/sh
# The emulator action executes each script line in a separate shell. Keep the
# retry and its exit status in one process; never turn failed PCM into a pass.
set -eu
if [ "${1:?cohort stage required}" != "smoke" ]; then
    exit 0
fi
if python3 tools/lab/run_android.py --stage preflight --output build/lab/android/preflight-attempt-1; then
    exit 0
fi
echo 'Android RGB/PCM preflight failed; retrying once after settling.' >&2
sleep 12
python3 tools/lab/run_android.py --stage preflight --output build/lab/android/preflight-attempt-2
