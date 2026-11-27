import copy
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SKILL = Path(__file__).resolve().parents[1] / 'ios-memory-growth'
PATH = SKILL / 'scripts/compare_generations.py'
spec = importlib.util.spec_from_file_location('memory_generations', PATH)
generations = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generations)


def dataset(**series):
    cycles = len(next(iter(series.values())))
    return {'schema_version': 1, 'interaction': 'open and dismiss picker', 'samples': [
        {'cycle': i + 1, 'settled': True, 'counts': {name: values[i] for name, values in series.items()}}
        for i in range(cycles)]}


class MemoryGenerationTests(unittest.TestCase):
    def pattern(self, values):
        return generations.analyze(dataset(T=values))['types']['T']['pattern']

    def test_patterns(self):
        self.assertEqual(self.pattern([1, 2, 3, 4]), 'growing')
        self.assertEqual(self.pattern([3, 3, 3]), 'flat')
        self.assertEqual(self.pattern([10, 20, 30, 30, 30]), 'plateau')
        self.assertEqual(self.pattern([1, 3, 2]), 'irregular')
        self.assertEqual(self.pattern([5, 3, 3]), 'shrinking')

    def test_single_trailing_zero_step_is_still_growing(self):
        # One quiet step is not enough evidence that growth stopped.
        self.assertEqual(self.pattern([1, 2, 3, 3]), 'growing')

    def test_steady_and_uneven_growth(self):
        steady = generations.analyze(dataset(T=[1, 2, 3, 4]))['types']['T']
        self.assertTrue(steady['steady'])
        self.assertEqual(steady['change_per_cycle'], 1)
        uneven = generations.analyze(dataset(T=[1, 2, 5, 6]))['types']['T']
        self.assertFalse(uneven['steady'])

    def test_steady_rate_accounts_for_cycle_gaps(self):
        data = dataset(T=[1, 3, 5])
        for sample, cycle in zip(data['samples'], (1, 3, 5)):
            sample['cycle'] = cycle
        result = generations.analyze(data)['types']['T']
        self.assertTrue(result['steady'])
        self.assertEqual(result['change_per_cycle'], 1)

    def test_growing_types_ranked_first_by_rate(self):
        result = generations.analyze(dataset(A=[1, 1, 1], B=[1, 2, 3], C=[2, 4, 6]))
        self.assertEqual(result['growing'], ['C', 'B'])
        self.assertEqual(list(result['types'])[-1], 'A')

    def test_unsettled_samples_are_skipped(self):
        data = dataset(T=[1, 1, 1])
        data['samples'].append({'cycle': 2, 'settled': False, 'counts': {'T': 9}})
        result = generations.analyze(data)
        self.assertEqual(result['types']['T']['pattern'], 'flat')
        self.assertEqual(result['unsettled_cycles_skipped'], [2])

    def test_missing_count_is_incomplete_not_zero(self):
        data = dataset(T=[1, 2, 3], U=[0, 0, 0])
        del data['samples'][1]['counts']['U']
        result = generations.analyze(data)
        self.assertEqual(result['incomplete_types'], ['U'])
        self.assertNotIn('U', result['types'])

    def test_footprint_growth_without_object_growth_is_flagged(self):
        data = dataset(T=[1, 1, 1])
        for sample, size in zip(data['samples'], (100, 200, 300)):
            sample['footprint_bytes'] = size
        result = generations.analyze(data)
        self.assertEqual(result['footprint']['pattern'], 'growing')
        self.assertIn('footprint_note', result)

    def test_invalid_inputs(self):
        cases = []
        base = dataset(T=[1, 2, 3])
        for mutate in (
            lambda d: d.update(schema_version=2),
            lambda d: d.update(interaction=' '),
            lambda d: d.update(samples=[]),
            lambda d: d['samples'][0].update(cycle=-1),
            lambda d: d['samples'][0].update(cycle=True),
            lambda d: d['samples'][0].update(settled='yes'),
            lambda d: d['samples'][0]['counts'].update(T=1.5),
            lambda d: d['samples'][0]['counts'].update(T=-1),
            lambda d: d['samples'][0].update(counts={}),
            lambda d: d['samples'][1].update(cycle=1),
            lambda d: d['samples'].pop(),
            lambda d: d['samples'][0].update(footprint_bytes='big'),
        ):
            data = copy.deepcopy(base)
            mutate(data)
            cases.append(data)
        for data in cases:
            with self.subTest(data=data), self.assertRaises(ValueError):
                generations.analyze(data)

    def test_synthetic_reference_example(self):
        data = json.loads((SKILL / 'references/synthetic-generations.json').read_text())
        result = generations.analyze(data)
        self.assertEqual(result['growing'], ['PickerCoordinator', 'PickerModel'])
        self.assertEqual(result['types']['ThumbnailCacheEntry']['pattern'], 'plateau')
        self.assertEqual(result['types']['PickerRowView']['pattern'], 'flat')
        self.assertEqual(result['unsettled_cycles_skipped'], [3])

    def test_cli(self):
        with tempfile.TemporaryDirectory() as tmp:
            good = Path(tmp, 'good.json')
            good.write_text(json.dumps(dataset(T=[1, 2, 3])))
            run = subprocess.run([sys.executable, str(PATH), str(good)], capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertEqual(json.loads(run.stdout)['growing'], ['T'])
            bad = Path(tmp, 'bad.json')
            bad.write_text('{"schema_version": 1}')
            run = subprocess.run([sys.executable, str(PATH), str(bad)], capture_output=True, text=True)
            self.assertEqual(run.returncode, 2)
            self.assertIn('error', json.loads(run.stderr))


if __name__ == '__main__':
    unittest.main()
