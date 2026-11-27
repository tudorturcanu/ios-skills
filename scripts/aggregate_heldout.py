#!/usr/bin/env python3
"""Map blind grades back to conditions, write per-skill grading files, and print a summary table.

Usage: aggregate_heldout.py WORK_DIR   (WORK_DIR holds <skill>/{mapping.json,blind/grades.json})
Writes evals/heldout/<skill>/{grading-skill.json,grading-baseline.json,blind-grades.json,mapping.json}.
read_only is recorded true only because the caller verified inputs unchanged; see evals/heldout/README.md.
"""
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1] / 'evals' / 'heldout'
sys.path.insert(0, str(Path(__file__).resolve().parent))
import compare_conditions as cc


def build(condition, mapping, grades):
    cases = []
    for label, key in mapping.items():
        cond, kind = key.split('-')
        if cond != condition:
            continue
        g = grades[label]
        criteria = {k: bool(v) for k, v in g['criteria'].items()}
        criteria['read_only'] = True
        cases.append({'id': kind, 'kind': kind, 'heldout': True, 'criteria': criteria,
                      'false_positives': g.get('false_positives', 0)})
    return {'condition': condition, 'model': 'sonnet', 'cases': cases}


def main(work):
    rows = []
    for skill_dir in sorted(Path(work).iterdir()):
        grades_file = skill_dir / 'blind' / 'grades.json'
        if not grades_file.exists():
            rows.append((skill_dir.name, 'NOT GRADED'))
            continue
        mapping = json.loads((skill_dir / 'mapping.json').read_text())
        grades = json.loads(grades_file.read_text())
        out = REPO / skill_dir.name
        reports = {c: build(c, mapping, grades) for c in ('skill', 'base')}
        reports['base']['condition'] = 'no-skill'
        (out / 'grading-skill.json').write_text(json.dumps(reports['skill'], indent=1) + '\n')
        (out / 'grading-baseline.json').write_text(json.dumps(reports['base'], indent=1) + '\n')
        (out / 'blind-grades.json').write_text(json.dumps(grades, indent=1) + '\n')
        (out / 'mapping.json').write_text(json.dumps(mapping, indent=1) + '\n')
        s, b = cc.score(reports['skill']), cc.score(reports['base'])
        rows.append((skill_dir.name, f"skill {s['passed']}/{s['total']} fp={s['false_positives']} | "
                     f"no-skill {b['passed']}/{b['total']} fp={b['false_positives']} | {cc.verdict(s, [b])}"))
    for name, text in rows:
        print(f'{name}: {text}')


if __name__ == '__main__':
    main(sys.argv[1])
