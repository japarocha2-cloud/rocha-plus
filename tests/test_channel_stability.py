import subprocess
import unittest
from unittest.mock import patch
from tools.channel_stability import run_check

ROW = {"name":"Teste","url":"https://example.invalid/test.m3u8"}

class StabilityTests(unittest.TestCase):
    @patch("tools.channel_stability.time.monotonic", side_effect=[1, 32])
    @patch("tools.channel_stability.subprocess.run")
    def test_finished(self, run, clock):
        run.return_value = subprocess.CompletedProcess([], 0, "out_time_ms=30000000\n", "")
        self.assertEqual(run_check(ROW,30,50)["v4_status"], "completou_teste")

    @patch("tools.channel_stability.time.monotonic", side_effect=[1, 2])
    @patch("tools.channel_stability.subprocess.run")
    def test_short(self, run, clock):
        run.return_value = subprocess.CompletedProcess([], 0, "out_time_ms=9000000\n", "")
        self.assertEqual(run_check(ROW,30,50)["v4_status"], "terminou_antes_do_prazo")

    @patch("tools.channel_stability.time.monotonic", side_effect=[1, 51])
    @patch("tools.channel_stability.subprocess.run", side_effect=subprocess.TimeoutExpired("ffmpeg",50))
    def test_timeout(self, run, clock):
        self.assertEqual(run_check(ROW,30,50)["v4_status"], "tempo_esgotado")

if __name__ == "__main__":
    unittest.main()
