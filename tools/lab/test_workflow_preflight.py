import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class WorkflowPreflightTest(unittest.TestCase):
    def run_workflow_command(self, failures, stage='smoke'):
        root = Path(__file__).resolve().parents[2]
        workflow = (root / '.github/workflows/player-lab-device.yml').read_text()
        # Execute the actual active line consumed by emulator-runner, so a
        # comment swallowing the command cannot silently disable the gate.
        command = next(line.strip() for line in workflow.splitlines()
                       if line.strip().startswith('sh tools/lab/run_preflight.sh '))
        command = command.replace('${{ inputs.stage }}', stage)
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            python = folder / 'python3'
            python.write_text('''#!/bin/sh
echo "$*" >> "$PREFLIGHT_CALLS"
count=$(wc -l < "$PREFLIGHT_CALLS")
if [ "$count" -le "$PREFLIGHT_FAILURES" ]; then exit 1; fi
''')
            python.chmod(0o700)
            sleep = folder / 'sleep'
            sleep.write_text('#!/bin/sh\nexit 0\n')
            sleep.chmod(0o700)
            calls = folder / 'calls'
            env = dict(os.environ, PATH=str(folder) + os.pathsep + os.environ['PATH'],
                       PREFLIGHT_CALLS=str(calls), PREFLIGHT_FAILURES=str(failures))
            result = subprocess.run(['sh', '-c', command], cwd=root, env=env,
                                    capture_output=True, text=True, timeout=5)
            return result.returncode, calls.read_text().splitlines() if calls.exists() else []

    def test_success_runs_once(self):
        code, calls = self.run_workflow_command(0)
        self.assertEqual(code, 0)
        self.assertEqual(len(calls), 1)

    def test_retry_preserves_separate_attempt_evidence(self):
        code, calls = self.run_workflow_command(1)
        self.assertEqual(code, 0)
        self.assertEqual(len(calls), 2)
        self.assertIn('preflight-attempt-1', calls[0])
        self.assertIn('preflight-attempt-2', calls[1])

    def test_failed_retry_blocks_cohort(self):
        code, calls = self.run_workflow_command(2)
        self.assertNotEqual(code, 0)
        self.assertEqual(len(calls), 2)

    def test_non_smoke_stage_does_not_repeat_infrastructure_gate(self):
        code, calls = self.run_workflow_command(0, 'batch10')
        self.assertEqual(code, 0)
        self.assertEqual(calls, [])
