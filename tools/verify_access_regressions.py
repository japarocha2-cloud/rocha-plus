"""Compare all Flutter tests with the immutable Baú baseline; never hide failures."""
import json
from pathlib import Path
import subprocess
import tempfile

BASELINE = 'fa1f048b1960a706ba143a145a1608c4d4329922'
EXPECTED = {
    'Home and login fit phone/TV viewport Size(320.0, 568.0) with enlarged text',
    'Home and login fit phone/TV viewport Size(960.0, 540.0) with enlarged text',
    'Home and login fit phone/TV viewport Size(1920.0, 1080.0) with enlarged text',
    'official Home, grid and Cast adapt at Size(320.0, 568.0)',
}


def run_suite(directory):
    run = subprocess.run(['flutter', 'test', '--reporter', 'json'], cwd=directory,
                         text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    tests, results = {}, []
    completed = False
    for line in run.stdout.splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if event.get('type') == 'testStart':
            tests[event['test']['id']] = event['test']
        if event.get('type') == 'testDone':
            test = tests.get(event['testID'], {})
            if not test.get('hidden', False):
                results.append({'name': test.get('name', '<unknown>'),
                                'result': event.get('result'), 'skipped': event.get('skipped', False)})
        if event.get('type') == 'done':
            completed = True
    if not completed or not results or run.returncode not in (0, 1):
        raise RuntimeError('Flutter suite did not complete: ' + run.stderr[-3000:])
    failures = sorted(row['name'] for row in results if row['result'] != 'success' and not row['skipped'])
    return {'passed': sum(row['result'] == 'success' and not row['skipped'] for row in results),
            'skipped': sum(row['skipped'] for row in results),
            'failed': failures, 'exitCode': run.returncode, 'results': results}


def main():
    root = Path(__file__).resolve().parent.parent
    candidate = run_suite(root)
    # Get the pinned frozen tree read-only. Never checkout or modify frozen refs.
    with tempfile.TemporaryDirectory(prefix='rocha-access-baseline-') as temp:
        subprocess.run(['git', 'archive', BASELINE, '-o', temp + '/baseline.tar'], cwd=root, check=True)
        directory = Path(temp) / 'source'
        directory.mkdir()
        subprocess.run(['tar', '-xf', temp + '/baseline.tar', '-C', str(directory)], check=True)
        subprocess.run(['flutter', 'pub', 'get'], cwd=directory, check=True,
                       stdout=subprocess.DEVNULL)
        baseline = run_suite(directory)
    exact_baseline = set(baseline['failed']) == EXPECTED
    no_new_failures = set(candidate['failed']) == set(baseline['failed'])
    report = {'baselineCommit': BASELINE,
              'candidateCommit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
              'baseline': baseline, 'candidate': candidate,
              'baselineMatchesDocumentedFailures': exact_baseline,
              'noNewFailures': no_new_failures,
              'allTestsGreen': not candidate['failed'],
              'productionWrites': False, 'realCharges': False}
    evidence = root / 'build' / 'access-flow-evidence.json'
    evidence.parent.mkdir(exist_ok=True)
    evidence.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in report.items() if k not in ('baseline', 'candidate')}, indent=2))
    print(f"Baseline: {baseline['passed']} passed; {len(baseline['failed'])} failed")
    print(f"Candidate: {candidate['passed']} passed; {len(candidate['failed'])} failed")
    for failure in candidate['failed']:
        print('Existing layout failure: ' + failure)
    if not exact_baseline or not no_new_failures or candidate['skipped']:
        raise SystemExit('Unexpected regression, skipped tests, or baseline changed; APK build blocked')


if __name__ == '__main__':
    main()
