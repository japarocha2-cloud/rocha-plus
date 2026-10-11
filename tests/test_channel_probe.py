import json
import subprocess
import unittest
from unittest.mock import patch
from tools.channel_probe import probe

CHANNEL = {"name": "Canal exemplo", "url": "https://example.org/live.m3u8", "triagem": "prioridade_player"}

class ProbeTests(unittest.TestCase):
    @patch("tools.channel_probe.subprocess.run")
    def test_video_and_audio(self, run):
        run.return_value = subprocess.CompletedProcess([], 0, json.dumps({"streams": [
            {"codec_type": "video", "codec_name": "h264", "width": 1280, "height": 720},
            {"codec_type": "audio", "codec_name": "aac"}]}), "")
        result = probe(CHANNEL, 4)
        self.assertEqual(result["probe_status"], "video_e_audio")
        self.assertEqual(result["video_codec"], "h264")
        self.assertEqual(result["audio_codec"], "aac")
        self.assertEqual(result["resolution"], "1280x720")

    @patch("tools.channel_probe.subprocess.run")
    def test_no_streams(self, run):
        run.return_value = subprocess.CompletedProcess([], 1, "{}", "unavailable")
        self.assertEqual(probe(CHANNEL, 4)["probe_status"], "sem_midia_detectada")

    @patch("tools.channel_probe.subprocess.run")
    def test_timeout(self, run):
        run.side_effect = subprocess.TimeoutExpired("ffprobe", 4)
        self.assertEqual(probe(CHANNEL, 4)["probe_status"], "tempo_esgotado")

    @patch("tools.channel_probe.subprocess.run")
    def test_invalid_json(self, run):
        run.return_value = subprocess.CompletedProcess([], 1, "invalid", "error")
        self.assertEqual(probe(CHANNEL, 4)["probe_status"], "erro")

if __name__ == "__main__":
    unittest.main()
