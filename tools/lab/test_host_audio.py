from pathlib import Path
import tempfile
import unittest
import wave

import numpy as np

from calibrate_host_audio import host_tone_observed


class HostCalibrationTest(unittest.TestCase):
    def measure(self, frequency, amplitude):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'host.wav'
            rate = 48000
            samples = np.zeros(7 * rate, dtype='<i2')
            samples[rate:5 * rate] = (np.sin(np.arange(4 * rate) *
                (2 * np.pi * frequency / rate)) * amplitude).astype('<i2')
            with wave.open(str(path), 'wb') as stream:
                stream.setnchannels(1)
                stream.setsampwidth(2)
                stream.setframerate(rate)
                stream.writeframes(samples.tobytes())
            return host_tone_observed(path)

    def test_silence_and_wrong_tone_fail_host_calibration(self):
        self.assertFalse(self.measure(997, 0)['hostLoopbackVerified'])
        self.assertFalse(self.measure(440, 10000)['hostLoopbackVerified'])

    def test_host_tone_after_startup_silence_never_approves_android(self):
        result = self.measure(997, 10000)
        self.assertTrue(result['hostLoopbackVerified'])
        self.assertFalse(result['androidAudioVerified'])


if __name__ == '__main__':
    unittest.main()
