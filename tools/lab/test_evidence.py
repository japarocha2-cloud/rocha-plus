from pathlib import Path
import tempfile
import unittest
import wave
import hashlib
from unittest.mock import patch
from run_android import consolidate, pcm_metrics


class EvidenceTest(unittest.TestCase):
    def test_track_or_preference_without_pixels_and_pcm_cannot_pass(self):
        with tempfile.TemporaryDirectory() as d:
            result = consolidate([{'channelUrl': 'https://example.org/live',
              'channelName': 'Channel', 'group': 'TV ao Vivo', 'preferred': 'exoPlayer'}], Path(d))
            self.assertFalse(result[0]['automaticAudiovisualPass'])
            self.assertFalse(result[0]['productionApproved'])
            self.assertEqual((Path(d) / 'automatic-audiovisual-pass.m3u').read_text().count('#EXTINF'), 0)

    def measured_record(self, out):
        from PIL import Image
        url = 'https://example.org/live'
        digest = hashlib.sha256(url.encode()).hexdigest()[:12]
        for phase in ['exo', 'vlc', 'confirmation']:
            for index, color in enumerate(['black', 'white', 'red']):
                path = out / f'{digest}-{phase}-{index:02}.png'
                Image.new('RGB', (16, 16), color).save(path)
                path.with_suffix('.json').write_text('{"focusConfirmed": true}')
            (out / f'{digest}-{phase}.wav').touch()
        def sample(engine, seconds):
            return dict(engine=engine, elapsedSeconds=seconds,
                        startupMilliseconds=100, bufferingMilliseconds=0,
                        stalls=0, progressSeconds=seconds - 2,
                        videoTrackDetected=True, error=None)
        return dict(channelUrl=url, channelName='Channel', group='TV ao Vivo',
                    preferred='exoPlayer', exo=sample('exoPlayer', 60),
                    vlc=sample('libVlc', 60), confirmation=sample('exoPlayer', 180))

    def check_measured(self, mutate, expected):
        with tempfile.TemporaryDirectory() as directory:
            out = Path(directory)
            record = self.measured_record(out)
            mutate(record, out)
            with patch('run_android.pcm_metrics', return_value={
                    'durationSeconds': 45, 'rmsDbfs': -20, 'nonSilentFraction': 0.9}):
                report = consolidate([record], out)[0]
            self.assertEqual(report['automaticAudiovisualPass'], expected)

    def test_healthy_selected_engine_can_pass_when_alternative_failed(self):
        self.check_measured(lambda r, _: r['vlc'].update(error='failed'), True)

    def test_confirmation_alone_does_not_approve_short_initial_phase(self):
        self.check_measured(lambda r, _: r['exo'].update(elapsedSeconds=59), False)

    def test_preferred_cannot_disagree_with_confirmation_engine(self):
        self.check_measured(lambda r, _: r.update(preferred='libVlc'), False)

    def test_selected_engine_requires_initial_pcm_artifact(self):
        self.check_measured(lambda r, out: next(out.glob('*-exo.wav')).unlink(), False)

    def test_invalid_negative_metrics_cannot_pass(self):
        self.check_measured(lambda r, _: r['exo'].update(bufferingMilliseconds=-1), False)

    def test_silent_output_is_measured_as_silence(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / 'silent.wav'
            with wave.open(str(path), 'wb') as f:
                f.setnchannels(2)
                f.setsampwidth(2)
                f.setframerate(48000)
                f.writeframes(b'\x00' * (48000 * 2 * 2))
            result = pcm_metrics(path)
            self.assertEqual(result['durationSeconds'], 1)
            self.assertEqual(result['nonSilentFraction'], 0)
            self.assertLess(result['rmsDbfs'], -100)

    def test_successor_audio_at_recording_boundary_cannot_confirm_predecessor(self):
        import numpy as np
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / 'transition.wav'
            pcm = np.zeros(60 * 48000, dtype='<i2')
            pcm[-3 * 48000:] = 10000
            with wave.open(str(path), 'wb') as f:
                f.setnchannels(1)
                f.setsampwidth(2)
                f.setframerate(48000)
                f.writeframes(pcm.tobytes())
            result = pcm_metrics(path)
            self.assertEqual(result['fileDurationSeconds'], 60)
            self.assertEqual(result['durationSeconds'], 45)
            self.assertEqual(result['nonSilentFraction'], 0)

    def test_static_picture_and_audio_energy_are_still_inconclusive(self):
        from PIL import Image
        with tempfile.TemporaryDirectory() as d:
            out = Path(d)
            url = 'https://example.org/live'
            stem = hashlib.sha256(url.encode()).hexdigest()[:12] + '-confirmation'
            for i in range(3):
                Image.new('RGB', (16, 16), '#112233').save(out / f'{stem}-{i:02}.png')
            import numpy as np
            samples = (np.sin(np.arange(45 * 48000) * (2 * np.pi * 440 / 48000)) * 10000).astype('<i2')
            with wave.open(str(out / f'{stem}.wav'), 'wb') as f:
                f.setnchannels(1)
                f.setsampwidth(2)
                f.setframerate(48000)
                f.writeframes(samples.tobytes())
            result = consolidate([{'channelUrl': url, 'channelName': 'Channel',
              'group': 'TV ao Vivo', 'preferred': 'exoPlayer'}], out)[0]
            self.assertTrue(result['measuredEvidence']['confirmation']['audioOutputObserved'])
            self.assertFalse(result['automaticAudiovisualPass'])


if __name__ == '__main__':
    unittest.main()
