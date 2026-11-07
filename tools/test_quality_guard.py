from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


class QualityGuardTest(unittest.TestCase):
    def run_guard(self, file, content):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'tools').mkdir()
            script = root / 'tools/rocha_quality_guard.py'
            shutil.copyfile(Path(__file__).with_name('rocha_quality_guard.py'), script)
            (root / 'lib').mkdir()
            (root / 'lib/contracts.dart').write_text(
                '// Esportes Notícias Infantil Tela cheia Transmitir para TV '
                'VideoPlayerController.networkUrl Conectando… reportPlaybackFailure', encoding='utf8')
            target = root / file
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content, encoding='utf8')
            return subprocess.run([sys.executable, str(script)], capture_output=True, text=True)

    def test_installed_vendor_files_do_not_create_runtime_findings(self):
        result = self.run_guard('backend/entitlement/node_modules/vendor/package.json',
                                '{"homepage": "http://example.invalid/vendor"}')
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_owned_backend_modules_still_block_insecure_runtime_urls(self):
        result = self.run_guard('backend/entitlement/server.mjs',
                                'const endpoint = "http://example.invalid/unsafe";')
        self.assertEqual(result.returncode, 1)
        self.assertIn('backend/entitlement/server.mjs', result.stdout)

    def test_owned_backend_modules_still_block_fixed_secrets(self):
        result = self.run_guard('backend/entitlement/server.mjs',
                                'const secret = "TEST-NOT-A-REAL-SECRET";')
        self.assertEqual(result.returncode, 1)
        self.assertIn('possível segredo', result.stdout)
