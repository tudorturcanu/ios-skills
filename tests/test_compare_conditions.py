import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
import compare_conditions as cc


def report(name, passed, fp=0, clean=True):
    cases = [{'id': 'a', 'kind': 'defect', 'heldout': True,
              'criteria': {'x': passed >= 1, 'y': passed >= 2}, 'false_positives': fp}]
    if clean:
        cases.append({'id': 'c', 'kind': 'clean', 'heldout': True, 'criteria': {'none': True}})
    return cc.score({'condition': name, 'cases': cases})


class CompareTests(unittest.TestCase):
    def test_improvement_requires_beating_every_baseline(self):
        self.assertEqual(cc.verdict(report('r', 2), [report('b', 1)]), 'improvement measured on held-out cases')
        self.assertEqual(cc.verdict(report('r', 2), [report('b', 1), report('c', 2)]), 'no measured advantage')

    def test_more_false_positives_blocks_claim(self):
        self.assertEqual(cc.verdict(report('r', 2, fp=1), [report('b', 1)]), 'no measured advantage')

    def test_missing_clean_control_is_inconclusive(self):
        self.assertTrue(cc.verdict(report('r', 2, clean=False), [report('b', 1, clean=False)]).startswith('inconclusive'))

    def test_ungraded_cases_are_ignored(self):
        s = cc.score({'condition': 'r', 'cases': [{'id': 'a', 'kind': 'defect', 'heldout': False, 'criteria': {'x': True}}]})
        self.assertEqual(s['total'], 0)


if __name__ == '__main__':
    unittest.main()
