import hashlib
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from PIL import Image
from run_android import preflight_report


class PreflightTest(unittest.TestCase):
    def evaluate(self, audio, *, rgb=True, frames=4):
        with tempfile.TemporaryDirectory() as directory:
            out = Path(directory)
            url = 'http://10.0.2.2:8765/fixture.mp4'
            digest = hashlib.sha256(url.encode()).hexdigest()[:12]
            for index in range(frames):
                image = Image.new('RGB', (30, 10), 'black')
                if rgb:
                    for band, color in enumerate(['red', 'lime', 'blue']):
                        image.paste(color, (band * 10, 0, (band + 1) * 10, 10))
                image.save(out / f'{digest}-exo-{index:02}.png')
            with patch('run_android.pcm_metrics', return_value=audio):
                report = preflight_report(out, url)
            self.assertTrue((out / 'preflight.json').exists())
            self.assertTrue(report['preflightOnly'])
            self.assertFalse(report['productionApproved'])
            self.assertFalse(report['channelApproval'])
            self.assertFalse((out / 'results.json').exists())
            return report

    def tone(self, **changes):
        return dict(durationSeconds=30, rmsDbfs=-20,
                    dominantFrequencyHz=440, spectralPeakPowerFraction=0.65,
                    **changes)

    def test_rgb_and_known_tone_pass_infrastructure_without_approving_channel(self):
        self.assertTrue(self.evaluate(self.tone())['passed'])

    def test_silence_wrong_tone_short_capture_and_noisy_spectrum_are_rejected(self):
        for field, value in [('rmsDbfs', -98), ('dominantFrequencyHz', 997),
                             ('durationSeconds', 19), ('spectralPeakPowerFraction', 0.1)]:
            with self.subTest(field=field):
                audio = self.tone()
                audio[field] = value
                self.assertFalse(self.evaluate(audio)['passed'])

    def test_missing_or_insufficient_rgb_frames_cannot_pass_on_audio_alone(self):
        self.assertFalse(self.evaluate(self.tone(), rgb=False)['passed'])
        self.assertFalse(self.evaluate(self.tone(), frames=2)['passed'])

    def test_recording_error_cannot_pass(self):
        self.assertFalse(self.evaluate({'error': 'missing recording'})['passed'])


if __name__ == '__main__':
    unittest.main()
