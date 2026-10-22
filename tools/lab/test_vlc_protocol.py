import unittest
from verify_vlc_protocol import verify


class ProtocolTest(unittest.TestCase):
    def test_known_vlc_wire_protocol_regression_is_rejected(self):
        def source(version, prefix):
            return 'Pigeon (v' + version + ')\n' + '\n'.join('"' + prefix + '.VlcPlayerApi.' + m + '"' for m in ['initialize', 'create', 'dispose'])
        dart = source('0.2.1', 'dev.flutter.pigeon')
        self.assertEqual(verify(dart, dart)['dartPigeon'], '0.2.1')
        with self.assertRaises(ValueError):
            verify(source('25.2.0', 'dev.flutter.pigeon.flutter_vlc_player_platform_interface'), dart)


if __name__ == '__main__':
    unittest.main()
