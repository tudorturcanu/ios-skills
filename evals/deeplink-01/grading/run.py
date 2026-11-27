#!/usr/bin/env python3
"""Compile a candidate against fixed behavior checks without editing it."""
import argparse
import hashlib
import json
import subprocess
import tempfile
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('candidate', type=Path)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
candidate = args.candidate.resolve()
harness = Path(__file__).with_name('main.swift')
result = {'candidate_sha256': hashlib.sha256(candidate.read_bytes()).hexdigest(),
          'harness_sha256': hashlib.sha256(harness.read_bytes()).hexdigest(),
          'toolchain': subprocess.check_output(['xcrun','swift','--version'], text=True).strip()}
with tempfile.TemporaryDirectory(prefix='deeplink-grade-') as tmp:
    binary = Path(tmp) / 'grade'
    compiled = subprocess.run(['xcrun','swiftc',str(candidate),str(harness),'-o',str(binary)], capture_output=True, text=True, timeout=90)
    result['compiled'] = compiled.returncode == 0
    result['compiler_output'] = compiled.stderr
    if result['compiled']:
        executed = subprocess.run([str(binary)], capture_output=True, text=True, timeout=10)
        result['exit_code'] = executed.returncode
        if executed.returncode == 0:
            result['checks'] = json.loads(executed.stdout)
            result['passed'] = sum(x['passed'] for x in result['checks'])
            result['total'] = len(result['checks'])
        else:
            result['runtime_error'] = executed.stderr
args.output.write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ('checks','toolchain')}, indent=2))
