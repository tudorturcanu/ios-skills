#!/usr/bin/env python3
"""Execute two pinned app methods with test doubles; never build or modify the app."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

COMMIT = '98098b9c4b5928f89f338203193c2bf40ab7f38c'
SOURCE = 'Packages/StatusKit/Sources/StatusKit/Editor/ToolbarItems.swift'
SOURCE_SHA256 = '29642105c1e81d4f2e828356263c4cc965d1bf70f8baf505ed4efcb1ed2f69a6'
HERE = Path(__file__).resolve().parent


def git(checkout, *args):
    return subprocess.check_output(['git', *args], cwd=checkout, text=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--checkout', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True, help='New results directory')
    args = parser.parse_args()
    checkout = args.checkout.resolve()
    if git(checkout, 'rev-parse', 'HEAD').strip() != COMMIT:
        raise SystemExit('Checkout is not the pinned commit.')
    before_status = git(checkout, 'status', '--porcelain')
    source = (checkout / SOURCE).read_bytes()
    if hashlib.sha256(source).hexdigest() != SOURCE_SHA256:
        raise SystemExit('Reviewed source hash does not match; refusing extraction.')
    template = (HERE / 'harness.swift').read_text()
    lines = source.decode().splitlines()
    # The whole-file hash pins these exact ranges; this is not a Swift parser.
    methods = '\n'.join(lines[186:191] + [''] + lines[212:225])
    program = template.replace('// INSERT_VERIFIED_METHODS', methods)
    with tempfile.TemporaryDirectory(prefix='ios-recovery-probe-') as temp:
        temp = Path(temp)
        swift_file = temp / 'probe.swift'
        executable = temp / 'probe'
        swift_file.write_text(program)
        version = subprocess.check_output(['swiftc', '--version'], text=True).strip()
        subprocess.run(['swiftc', '-swift-version', '6', '-warnings-as-errors', '-parse-as-library',
                        str(swift_file), '-o', str(executable)], check=True)
        raw = subprocess.check_output([str(executable)], text=True)
    observations = json.loads(raw)
    expected = json.loads((HERE / 'expected-observations.json').read_text())
    if observations != expected:
        raise SystemExit('Observed behavior differs from recorded expectations; investigate before grading.')
    if (checkout / SOURCE).read_bytes() != source or git(checkout, 'status', '--porcelain') != before_status:
        raise SystemExit('Checkout source/status changed during the probe.')
    result = {
        'scope': 'Two extracted methods with fake posting and draft insertion; no app or server runtime',
        'observations_match': True,
        'app_correctness_passed': False,
        'source_unchanged': True,
        'source_sha256': SOURCE_SHA256,
        'commit': COMMIT,
        'swift_version': version,
        'harness_sha256': hashlib.sha256((HERE / 'harness.swift').read_bytes()).hexdigest(),
        'runner_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'observations': observations,
        'known_defects_observed': [
            'Partial thread failure loses acknowledged-prefix information in the aggregate result.',
            'Failure recovery inserts root text, omitting failed and unattempted follow-up text.'
        ],
        'limits': [
            'No live requests, actual SwiftData saves, process restarts, UI, or full-app build.',
            'No duplicate server effect is executed; resubmission consequences require server behavior.',
            'Nil-result recovery dispatch is modeled from the caller; the UI handler is not compiled.',
            'The blank-text case proves the guard skips insertion; no media-only request is executed.'
        ]
    }
    args.output.mkdir(parents=True, exist_ok=False)
    (args.output / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
    (args.output / 'stdout.json').write_text(raw)
    print('Five source-method observations reproduced; known recovery defects remain. App unchanged.')


if __name__ == '__main__':
    main()
