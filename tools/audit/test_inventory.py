import contextlib
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from inventory import scan

class InventoryIntegrationTest(unittest.TestCase):
    def test_detects_duplicates_invalid_json_and_bad_link_without_mutation(self):
        with tempfile.TemporaryDirectory() as folder, contextlib.chdir(folder):
            def git(*args):
                return subprocess.check_output(['git', *args], stderr=subprocess.DEVNULL)
            git('init')
            Path('copy-a.txt').write_text('same bytes')
            Path('copy-b.txt').write_text('same bytes')
            Path('bad.json').write_text('{')
            Path('README.md').write_text('[valid](copy-a.txt) [broken](missing.txt)')
            git('add', '.')
            git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-m', 'fixture')
            before=git('status', '--porcelain')
            result=scan('HEAD')
            self.assertEqual(len(result['duplicateGroups']),1)
            self.assertEqual(result['formatFailures'][0]['path'],'bad.json')
            self.assertEqual([x['target'] for x in result['markdownTargetsToReview']],['missing.txt'])
            self.assertEqual(git('status','--porcelain'),before)
            self.assertTrue(Path('bad.json').exists())

if __name__=='__main__':
    unittest.main()
