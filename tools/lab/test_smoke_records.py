import unittest
from run_android import smoke_records


class SmokeRecordOrderTest(unittest.TestCase):
    def test_export_alphabetical_order_does_not_turn_the_second_positive_into_the_negative(self):
        first = {'channelUrl': 'http://10.0.2.2:8765/fixture.mp4'}
        second = {'channelUrl': 'http://10.0.2.2:8765/fixture.mp4?channel=second'}
        negative = {'channelUrl': 'http://10.0.2.2:8765/not-found.m3u8'}
        self.assertEqual(smoke_records([first, negative, second]), (first, second, negative))

    def test_duplicate_or_missing_fixture_is_rejected(self):
        first = {'channelUrl': 'http://10.0.2.2:8765/fixture.mp4'}
        with self.assertRaises(ValueError):
            smoke_records([first, first, first])


if __name__ == '__main__':
    unittest.main()
