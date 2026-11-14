import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


class QualityGuardHttpTest(unittest.TestCase):
    """Runs the guard against a temporary copy of lib/ and tools/ only."""

    def run_guard_with(self, runtime_json: str) -> subprocess.CompletedProcess:
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            shutil.copytree(REPO / "lib", root / "lib")
            (root / "tools").mkdir()
            shutil.copy2(REPO / "tools" / "rocha_quality_guard.py", root / "tools")
            (root / "lib" / "lab_runtime.json").write_text(runtime_json, encoding="utf-8")
            return subprocess.run(
                [sys.executable, "-B", str(root / "tools" / "rocha_quality_guard.py")],
                capture_output=True, text=True, check=False,
            )

    def test_loopback_ipv4_is_allowed(self):
        result = self.run_guard_with('{"relay": "http://127.0.0.1:8080/x"}')
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_localhost_is_allowed(self):
        result = self.run_guard_with('{"relay": "http://localhost:8080/x"}')
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_public_http_is_blocked(self):
        result = self.run_guard_with('{"stream": "http://example.com/live.m3u8"}')
        self.assertEqual(result.returncode, 1)
        self.assertIn("URL HTTP insegura", result.stdout)


if __name__ == "__main__":
    unittest.main()
