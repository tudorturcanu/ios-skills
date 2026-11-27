#!/usr/bin/env python3
"""Reproduce read-only checks against a separately obtained pinned Ice Cubes checkout."""
import argparse
import collections
import hashlib
import json
import subprocess
import sys
from pathlib import Path

CASE = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def invoke(script, catalog, extra):
    result = subprocess.run([sys.executable, str(CASE/'tested-version'/script), str(catalog)] + extra,
                            capture_output=True, text=True, timeout=60)
    if result.returncode:
        raise ValueError(result.stderr)
    return json.loads(result.stdout)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--checkout', type=Path, required=True)
    args = parser.parse_args()
    expected = json.loads((CASE/'results.json').read_text())
    checkout = args.checkout.resolve()
    try:
        commit = subprocess.check_output(['git','-C',str(checkout),'rev-parse','HEAD'], text=True).strip()
        if commit != expected['commit']:
            raise ValueError('Checkout is not at the recorded commit')
        for relative, digest in expected['source_files'].items():
            if sha(checkout/relative) != digest:
                raise ValueError('Source differs: ' + relative)
        original_status = subprocess.check_output(['git','-C',str(checkout),'status','--porcelain'], text=True)
        catalog = checkout/'IceCubesApp/Resources/Localization/Localizable.xcstrings'
        locales = ['--locale','de','--locale','fr']
        before = invoke('original-inventory.txt', catalog, locales)
        after = invoke('inventory.txt', catalog, locales)
        keys = [part for key in expected['format_keys'] for part in ['--key',key]]
        formats = invoke('formats.txt', catalog, locales+keys)
        observed = {
            'catalog_entries': after['entry_count'],
            'before_count': len(before['findings']), 'after_count': len(after['findings']),
            'after_kinds': dict(collections.Counter(f['kind'] for f in after['findings'])),
            'removed_findings': [f for f in before['findings'] if f not in after['findings']],
            'added_findings': [f for f in after['findings'] if f not in before['findings']],
            'empty_source_fallbacks': after['empty_source_fallbacks'],
            'format_compared_count': len(formats['compared']), 'format_findings': formats['findings'],
        }
        if any(observed[key] != expected[key] for key in observed):
            raise ValueError('Observed outputs differ from retained results')
        if any(sha(checkout/path) != digest for path,digest in expected['source_files'].items()):
            raise ValueError('Source files changed during inspection')
        final_status = subprocess.check_output(['git','-C',str(checkout),'status','--porcelain'], text=True)
        if final_status != original_status:
            raise ValueError('Checkout status changed during inspection')
        print(json.dumps({'passed': True, 'source_unchanged_by_run': True, **observed}, indent=2))
        return 0
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        print(json.dumps({'error':str(exc)}), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
