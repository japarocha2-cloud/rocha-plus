from pathlib import Path
import tempfile
import unittest
import wave
import hashlib
from run_android import consolidate, pcm_metrics


class EvidenceTest(unittest.TestCase):
    def test_track_or_preference_without_pixels_and_pcm_cannot_pass(self):
        with tempfile.TemporaryDirectory() as d:
            result = consolidate([{'channelUrl': 'https://example.org/live',
              'channelName': 'Channel', 'group': 'TV ao Vivo', 'preferred': 'exoPlayer'}], Path(d))
            self.assertFalse(result[0]['automaticAudiovisualPass'])
            self.assertFalse(result[0]['productionApproved'])
            self.assertEqual((Path(d) / 'automatic-audiovisual-pass.m3u').read_text().count('#EXTINF'), 0)

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
