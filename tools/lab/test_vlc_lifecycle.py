import unittest
from patch_vlc_lifecycle import patch, OLD


class LifecyclePatchTest(unittest.TestCase):
    def test_decoder_stops_and_detaches_before_texture_release(self):
        result = patch('void dispose() {\n' + OLD + '\n}')
        self.assertLess(result.index('mediaPlayer.stop()'), result.index('textureView.dispose()'))
        self.assertLess(result.index('detachViews()'), result.index('textureEntry.release()'))
        self.assertLess(result.index('textureEntry.release()'), result.index('mediaPlayer.release()'))

    def test_unexpected_or_already_patched_native_code_is_rejected(self):
        with self.assertRaises(ValueError):
            patch('different native implementation')
        with self.assertRaises(ValueError):
            patch(patch(OLD))


if __name__ == '__main__':
    unittest.main()
