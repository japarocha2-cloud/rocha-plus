#!/usr/bin/env python3
"""Drive multiple LAB cohorts, retrieve atomic checkpoints and measured evidence."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess
import time
import wave

PACKAGE = 'com.rochaplus.app.lab'


def adb(*args, timeout=20, binary=False):
    p = subprocess.run(['adb', *args], capture_output=True, timeout=timeout)
    if p.returncode:
        raise RuntimeError(p.stderr.decode(errors='replace'))
    return p.stdout if binary else p.stdout.decode()


def read_remote(run, name):
    return json.loads(adb('exec-out', 'run-as', PACKAGE, 'cat', f'files/rocha-lab/{run}/{name}'))


def pcm_metrics(path):
    import numpy as np
    with wave.open(str(path)) as f:
        if f.getsampwidth() != 2:
            raise ValueError('Expected signed 16-bit PCM')
        rate, channels = f.getframerate(), f.getnchannels()
        pcm = np.frombuffer(f.readframes(f.getnframes()), dtype='<i2').astype(float) / 32768
    full_duration = len(pcm) / (rate * channels)
    # Driver polls asynchronously: discard boundaries so a successor's sound
    # cannot establish output evidence for a silent predecessor.
    if full_duration > 20:
        pcm = pcm[5 * rate * channels:-10 * rate * channels]
    rms = float(np.sqrt(np.mean(pcm ** 2))) if len(pcm) else 0.0
    return {'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'fileDurationSeconds': full_duration,
            'durationSeconds': len(pcm) / (rate * channels),
            'edgeTrimSeconds': {'start': 5, 'end': 10} if full_duration > 20 else {'start': 0, 'end': 0},
            'rmsDbfs': 20 * math.log10(max(rms, 1e-12)),
            'peak': float(np.max(np.abs(pcm))) if len(pcm) else 0.0,
            'nonSilentFraction': float(np.mean(np.abs(pcm) > 0.001)) if len(pcm) else 0.0,
            'method': 'dedicated_emulator_pulseaudio_sink_monitor',
            'limitation': 'Output PCM energy, not human audibility or programme identity'}


def capture(run, state, out, seen):
    from PIL import Image
    import io
    import numpy as np
    url, phase = state.get('url'), state.get('phase')
    seconds = state.get('elapsedSeconds', 0)
    rect = state.get('videoRect')
    if not url or not phase or seconds < 10 or not rect:
        return
    bucket = seconds // 10
    key = (url, phase, bucket)
    if key in seen:
        return
    seen.add(key)
    stem = hashlib.sha256(url.encode()).hexdigest()[:12] + f'-{phase}-{bucket:02d}'
    raw = adb('exec-out', 'screencap', '-p', binary=True)
    frame = Image.open(io.BytesIO(raw)).convert('RGB')
    box = tuple(int(rect[k]) for k in ('x', 'y', 'width', 'height'))
    x, y, width, height = box
    crop = frame.crop((x, y, x + width, y + height))
    crop.save(out / f'{stem}.png')
    pixels = np.asarray(crop).astype(float)
    data = {'url': url, 'phase': phase, 'elapsedSeconds': seconds,
            'rect': rect, 'stddev': float(pixels.std()),
            'sha256': hashlib.sha256((out / f'{stem}.png').read_bytes()).hexdigest(),
            'limitation': 'ROI screenshot; inspect frames, track/progress APIs alone do not prove video'}
    (out / f'{stem}.json').write_text(json.dumps(data, indent=2))


def consolidate(records, out):
    import numpy as np
    from PIL import Image
    reports = []
    for record in records:
        digest = hashlib.sha256(record['channelUrl'].encode()).hexdigest()[:12]
        evidence = {}
        for phase in ['exo', 'vlc', 'confirmation']:
            frames = sorted(out.glob(f'{digest}-{phase}-*.png'))
            differences = []
            for a, b in zip(frames, frames[1:]):
                first = np.asarray(Image.open(a).convert('RGB')).astype(float)
                second = np.asarray(Image.open(b).convert('RGB')).astype(float)
                if first.shape == second.shape:
                    differences.append(float(np.mean(np.abs(first - second))))
            audio_path = out / f'{digest}-{phase}.json'
            wav_path = audio_path.with_suffix('.wav')
            if wav_path.exists():
                try:
                    audio = pcm_metrics(wav_path)
                except Exception as error:
                    audio = {'error': str(error)}
            else:
                audio = {'error': 'PCM artifact missing; metadata alone cannot verify output'}
            # Screenshots are cropped strictly to the video viewport. Motion
            # proves varying displayed pixels, not programme identity/quality.
            motion = len(frames) >= 3 and sum(d > 1.0 for d in differences) >= 2
            pcm = audio.get('durationSeconds', 0) >= 20 and audio.get('rmsDbfs', -240) > -60 and audio.get('nonSilentFraction', 0) > 0.01
            evidence[phase] = {'frames': [f.name for f in frames],
                               'meanAbsoluteFrameDifferences': differences,
                               'changingPixelsObserved': motion,
                               'audioOutputObserved': pcm, 'audio': audio}
        auto_pass = record.get('preferred') is not None and evidence['confirmation']['changingPixelsObserved'] and evidence['confirmation']['audioOutputObserved']
        reports.append(dict(record, measuredEvidence=evidence,
                            automaticAudiovisualPass=auto_pass, productionApproved=False))
    (out / 'measured-results.json').write_text(json.dumps(reports, indent=2))
    lines = ['#EXTM3U', '# LAB automatic pixel/PCM evidence; production approval remains separate']
    for r in sorted(reports, key=lambda r: (r['group'], r['channelName'])):
        if r['automaticAudiovisualPass']:
            name = r['channelName'].replace('\n', ' ').replace('\r', ' ')
            group = r['group'].replace('"', "'")
            lines.extend([f'#EXTINF:-1 group-title="{group}",{name}', r['channelUrl']])
    (out / 'automatic-audiovisual-pass.m3u').write_text('\n'.join(lines) + '\n')
    return reports


def cohort(args, name, offset, count, fixture=False):
    out = Path(args.output) / name
    out.mkdir(parents=True, exist_ok=True)
    adb('shell', 'am', 'force-stop', PACKAGE)
    adb('shell', 'am', 'start', '-n', PACKAGE + '/com.rochaplus.app.LabActivity',
        '--ez', 'lab_auto', 'true', '--ez', 'lab_fixture', str(fixture).lower(),
        '--es', 'lab_run', name, '--ei', 'lab_limit', str(count), '--ei', 'lab_offset', str(offset))
    launched_at = time.time()
    seen, last, recorder, audio_path = set(), None, None, None
    deadline = time.monotonic() + count * 330 + 180
    state = {}
    log = (out / 'logcat.txt').open('w')
    logger = subprocess.Popen(['adb', 'logcat', '-v', 'threadtime'], stdout=log, stderr=subprocess.STDOUT)
    def stop_recording():
        nonlocal recorder
        if recorder is not None:
            recorder.terminate()
            try:
                recorder.wait(timeout=10)
            except subprocess.TimeoutExpired:
                recorder.kill()
                recorder.wait()
            try:
                metrics = pcm_metrics(audio_path)
            except Exception as error:
                metrics = {'error': str(error), 'audioVerified': False}
            audio_path.with_suffix('.json').write_text(json.dumps(metrics, indent=2))
            recorder = None
    try:
        while time.monotonic() < deadline:
            try:
                state = read_remote(name, 'status.json')
                from datetime import datetime
                if datetime.fromisoformat(state['timestamp'].replace('Z', '+00:00')).timestamp() < launched_at - 2:
                    time.sleep(3)
                    continue
                (out / 'status.json').write_text(json.dumps(state, indent=2))
                current = (state.get('url'), state.get('phase'))
                if current != last:
                    stop_recording()
                    last = current
                    if all(current):
                        stem = hashlib.sha256(current[0].encode()).hexdigest()[:12] + '-' + current[1]
                        audio_path = out / f'{stem}.wav'
                        recorder = subprocess.Popen(['ffmpeg', '-nostdin', '-loglevel', 'error', '-y',
                          '-f', 'pulse', '-i', 'rocha_lab.monitor', '-ac', '2', '-ar', '48000',
                          '-c:a', 'pcm_s16le', str(audio_path)], stdout=subprocess.DEVNULL,
                          stderr=(out / 'audio-recorder.log').open('a'))
                capture(name, state, out, seen)
                for filename in ['phases.json', 'results.json']:
                    try:
                        data = read_remote(name, filename)
                        (out / filename).write_text(json.dumps(data, indent=2))
                    except (RuntimeError, ValueError):
                        pass
                if state.get('done'):
                    break
            except (RuntimeError, ValueError, subprocess.TimeoutExpired) as error:
                (out / 'driver-errors.txt').open('a').write(str(error) + '\n')
            time.sleep(3)
        else:
            raise RuntimeError(f'{name}: deadline reached; checkpoints preserved')
        for filename in ['results.csv', 'audiovisual-checked.m3u']:
            (out / filename).write_text(adb('exec-out', 'run-as', PACKAGE, 'cat', f'files/rocha-lab/{name}/{filename}'))
    finally:
        stop_recording()
        logger.terminate()
        logger.wait(timeout=10)
        log.close()
        adb('shell', 'am', 'force-stop', PACKAGE)
    records = json.loads((out / 'results.json').read_text())
    reports = consolidate(records, out)
    print(json.dumps({'cohort': name, 'records': len(records), 'errors': state.get('failures', [])}), flush=True)
    if len(records) != count or state.get('failures'):
        raise RuntimeError(f'{name}: incomplete cohort ({len(records)}/{count})')
    return reports


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--output', default='build/lab/android')
    p.add_argument('--stage', choices=['smoke', 'batch10', 'batch25', 'batch'], required=True)
    p.add_argument('--offset', type=int, default=0)
    p.add_argument('--count', type=int, default=25)
    args = p.parse_args()
    Path(args.output).mkdir(parents=True, exist_ok=True)
    Path(args.output, 'device.txt').write_text(adb('shell', 'getprop'))
    if args.stage == 'smoke':
        records = cohort(args, 'smoke', 0, 2, fixture=True)
        positive, negative = records
        if not positive['exo']['progressSeconds'] >= 40 or not positive['vlc']['progressSeconds'] >= 40:
            raise RuntimeError('Controlled A/V fixture did not play on BOTH engines')
        if positive.get('preferred') is None or negative.get('preferred') is not None:
            raise RuntimeError('Smoke gate rejected: positive/negative discrimination failed')
        for phase in ['exo', 'vlc', 'confirmation']:
            evidence = positive['measuredEvidence'][phase]
            if not evidence['changingPixelsObserved'] or not evidence['audioOutputObserved']:
                raise RuntimeError(f'Controlled A/V output evidence missing for {phase}')
        # Loopback calibration from the known sine-wave fixture is mandatory.
        positive_hash = hashlib.sha256(positive['channelUrl'].encode()).hexdigest()[:12]
        metrics = json.loads(Path(args.output, 'smoke', positive_hash + '-exo.json').read_text())
        if metrics.get('durationSeconds', 0) < 20 or metrics.get('rmsDbfs', -240) < -60:
            raise RuntimeError('Android output loopback calibration failed; audio remains unverified')
    elif args.stage == 'batch':
        if args.offset < 0 or not 1 <= args.count <= 25:
            raise ValueError('Bounded cohorts require nonnegative offset and 1..25 URLs')
        cohort(args, f'batch-{args.offset:04d}', args.offset, args.count)
    else:
        cohort(args, args.stage, 0 if args.stage == 'batch10' else 10,
               10 if args.stage == 'batch10' else 25)


if __name__ == '__main__':
    main()
