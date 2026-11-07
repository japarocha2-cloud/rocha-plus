"""Verify host loopback before Android playback; never proves Android audio."""
import argparse
import json
from pathlib import Path
import subprocess
import time
import wave

from run_android import pcm_metrics


def host_tone_observed(path):
    import numpy as np
    metrics = pcm_metrics(path)
    with wave.open(str(path)) as stream:
        rate, channels = stream.getframerate(), stream.getnchannels()
        pcm = np.frombuffer(stream.readframes(stream.getnframes()), dtype='<i2')
    mono = pcm.astype(float).reshape(-1, channels).mean(axis=1) / 32768
    # Recorder startup and shutdown contain silence. Require two whole seconds
    # of the distinct HOST tone; it cannot satisfy Android's 440 Hz gate.
    matching = 0
    for start in range(0, len(mono) - rate + 1, rate):
        segment = mono[start:start + rate]
        spectrum = np.abs(np.fft.rfft(segment * np.hanning(rate))) ** 2
        peak = int(np.argmax(spectrum))
        if (abs(peak - 997) <= 2 and
                spectrum[peak] / max(float(spectrum.sum()), 1e-30) > 0.3 and
                float(np.sqrt(np.mean(segment ** 2))) > 0.001):
            matching += 1
    return dict(metrics, hostToneHz=997, matchingSeconds=matching,
                hostLoopbackVerified=matching >= 2,
                androidAudioVerified=False, method='host_loopback_calibration',
                limitation='Verifies the host recording path only, never Android output')


def calibrate(output):
    output.mkdir(parents=True, exist_ok=True)
    path = output / 'host-calibration.wav'
    report = {'hostLoopbackVerified': False, 'androidAudioVerified': False}
    try:
        with (output / 'host-calibration.log').open('w') as log:
            recorder = subprocess.Popen([
                'ffmpeg', '-nostdin', '-loglevel', 'error', '-y', '-f', 'pulse',
                '-i', 'rocha_lab.monitor', '-t', '7', '-ar', '48000', '-ac', '2',
                '-c:a', 'pcm_s16le', str(path)], stdout=log, stderr=log)
            try:
                # Both processes belong to this Python invocation. The action
                # runner executes each script line in a separate shell.
                time.sleep(1)
                if recorder.poll() is not None:
                    raise RuntimeError('Host PCM recorder exited before tone playback')
                subprocess.run([
                    'ffmpeg', '-nostdin', '-loglevel', 'error', '-f', 'lavfi',
                    '-i', 'sine=frequency=997:sample_rate=48000', '-t', '4',
                    '-f', 'pulse', 'rocha_lab'], stdout=log, stderr=log,
                    check=True, timeout=10)
                if recorder.wait(timeout=12) != 0:
                    raise RuntimeError('Host PCM recorder failed')
            finally:
                if recorder.poll() is None:
                    recorder.kill()
                    recorder.wait(timeout=5)
        report = host_tone_observed(path)
        if not report['hostLoopbackVerified']:
            raise RuntimeError('Host loopback did not capture the 997 Hz calibration tone')
    except Exception as error:
        report['error'] = str(error)
        raise
    finally:
        (output / 'host-calibration.json').write_text(json.dumps(report, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=Path('build/lab/android'))
    calibrate(parser.parse_args().output)
