#!/usr/bin/env python3
"""Compare graded conditions under evals/PROTOCOL.md. Standard library only.

Each input is a JSON file: {"condition": str, "model": str, "cases": [
  {"id": str, "kind": "defect"|"clean"|"routing", "heldout": bool,
   "criteria": {name: bool}, "false_positives": int}]}
"""
import json
import sys
from pathlib import Path


def score(report):
    held = [c for c in report['cases'] if c.get('heldout')]
    criteria = [v for c in held for v in c['criteria'].values()]
    return {'condition': report['condition'], 'heldout_cases': len(held),
            'passed': sum(criteria), 'total': len(criteria),
            'false_positives': sum(c.get('false_positives', 0) for c in held),
            'clean_controls': sum(1 for c in held if c['kind'] == 'clean')}


def verdict(revised, baselines):
    problems = []
    if revised['heldout_cases'] == 0 or revised['clean_controls'] == 0:
        problems.append('need held-out cases including a clean control')
    for base in baselines:
        if base['heldout_cases'] != revised['heldout_cases'] or base['total'] != revised['total']:
            problems.append(f"{base['condition']}: different case set; not comparable")
    if problems:
        return 'inconclusive: ' + '; '.join(problems)
    beats = all(revised['passed'] > b['passed'] and revised['false_positives'] <= b['false_positives']
                for b in baselines)
    return 'improvement measured on held-out cases' if beats else 'no measured advantage'


def main(argv):
    if len(argv) < 3:
        print('usage: compare_conditions.py REVISED.json BASELINE.json [BASELINE.json ...]', file=sys.stderr)
        return 2
    reports = [json.loads(Path(p).read_text()) for p in argv[1:]]
    if len({r.get('model') for r in reports}) != 1:
        print('inconclusive: conditions used different models', file=sys.stderr)
        return 1
    scores = [score(r) for r in reports]
    for s in scores:
        print(json.dumps(s))
    print(verdict(scores[0], scores[1:]))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
