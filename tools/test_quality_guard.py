import os
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
            return subprocess.run([sys.executable, str(script)], capture_output=True, text=True,
                                  env={**os.environ, 'GITHUB_HEAD_REF': '', 'GITHUB_REF_NAME': 'main'})

    def test_installed_vendor_files_do_not_create_runtime_findings(self):
        result = self.run_guard('backend/entitlement/node_modules/vendor/package.json',
                                '{"homepage": "http://example.invalid/vendor"}')
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_owned_backend_modules_still_block_insecure_runtime_urls(self):
        result = self.run_guard('backend/entitlement/server.mjs',
                                'const endpoint = "http://example.invalid/unsafe";')
        self.assertEqual(result.returncode, 1)
        self.assertIn('backend/entitlement/server.mjs', result.stdout)

    def test_empty_stream_query_does_not_consume_the_next_json_field_as_secret(self):
        result = self.run_guard('docs/catalog.json',
                                '{"url":"https://example.invalid/live?token=",\n"status":"Confirmado PC"}')
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_catalog_path_does_not_grant_http_exception_on_main(self):
        result = self.run_guard('branding/c7/selection.json',
                                '{"url":"http://example.invalid/unsafe"}')
        self.assertEqual(result.returncode, 1)
        self.assertIn('URL HTTP insegura', result.stdout)

    def test_owned_backend_modules_still_block_fixed_secrets(self):
        result = self.run_guard('backend/entitlement/server.mjs',
                                'const secret = "TEST-NOT-A-REAL-SECRET";')
        self.assertEqual(result.returncode, 1)
        self.assertIn('possível segredo', result.stdout)

    def run_repo_guard(self, branch):
        script = Path(__file__).with_name('rocha_quality_guard.py')
        return subprocess.run([sys.executable, str(script)], capture_output=True, text=True,
                              env={**os.environ, 'GITHUB_HEAD_REF': '', 'GITHUB_REF_NAME': branch})

    def test_frozen_540_catalog_passes_on_any_new_lab_branch(self):
        result = self.run_repo_guard('lab/nova-branch-isolada-teste')
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_frozen_catalog_still_blocked_on_main(self):
        result = self.run_repo_guard('main')
        self.assertEqual(result.returncode, 1)
        self.assertIn('URL HTTP insegura', result.stdout)

    def test_tampered_selection_blocked_even_on_lab_branch(self):
        repo = Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive = subprocess.run(['git', '-C', str(repo), 'archive', 'HEAD'], capture_output=True, check=True)
            subprocess.run(['tar', '-x', '-C', str(root)], input=archive.stdout, check=True)
            shutil.copyfile(Path(__file__).with_name('rocha_quality_guard.py'), root / 'tools/rocha_quality_guard.py')
            target = root / 'branding/lab/c7_validated_selection.json'
            raw = target.read_bytes()
            index = raw.index(b'"url": "') + len(b'"url": "')
            target.write_bytes(raw[:index] + b'X' + raw[index:])
            result = subprocess.run([sys.executable, str(root / 'tools/rocha_quality_guard.py')],
                                    capture_output=True, text=True,
                                    env={**os.environ, 'GITHUB_HEAD_REF': '', 'GITHUB_REF_NAME': 'lab/qualquer'})
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertIn('integrity', result.stdout)
