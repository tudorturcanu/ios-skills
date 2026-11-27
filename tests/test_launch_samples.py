import copy
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

PATH = Path(__file__).resolve().parents[1] / 'ios-launch-profiler/scripts/compare_launch_samples.py'
spec = importlib.util.spec_from_file_location('launch_samples', PATH)
launch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launch)


def dataset():
    conditions = dict(zip(launch.CONDITIONS, ('phone-A', 'iOS-fixture', 'Release', 'detached',
                        'existing-install', 'seed-v1', 'offline', 'process-launch', 'documented-warm',
                        'process-start-to-first-frame', 'fixture-clock')))
    return {'schema_version': 1, 'samples': [
        {'sample_id': str(i), 'variant': variant, 'duration_ms': duration, 'conditions': dict(conditions)}
        for i, (variant, duration) in enumerate([('before', 100), ('before', 120), ('after', 80), ('after', 100)])]}


class LaunchSampleTests(unittest.TestCase):
    def run_comparison(self, data=None):
        return launch.compare(dataset() if data is None else data, 'before', 'after')

    def test_median_change(self):
        result = self.run_comparison()['cohorts'][0]['comparison']
        self.assertEqual(result['median_change_ms'], -20)
        self.assertAlmostEqual(result['median_change_percent'], -20 / 110 * 100)
        self.assertEqual(result['direction'], 'lower')
        self.assertTrue(result['observed_ranges_overlap'])
        self.assertTrue(result['exploratory_small_sample'])

    def test_each_changed_condition_prevents_pooling(self):
        for key in launch.CONDITIONS:
            with self.subTest(key=key):
                data = dataset()
                for sample in data['samples'][2:]:
                    sample['conditions'][key] += '-different'
                cohorts = self.run_comparison(data)['cohorts']
                self.assertEqual(len(cohorts), 2)
                self.assertTrue(all(c['comparison'] is None for c in cohorts))

    def test_extra_condition_is_not_ignored(self):
        data = dataset()
        data['samples'][0]['conditions']['thermal_state'] = 'hot'
        result = self.run_comparison(data)
        self.assertEqual(len(result['cohorts']), 2)
        self.assertEqual(result['cohorts'][1]['variants']['before']['count'], 1)

    def test_unknown_conditions_suppress_comparison(self):
        data = dataset()
        for sample in data['samples']:
            sample['conditions']['cache_state'] = 'unknown'
        self.assertIsNone(self.run_comparison(data)['cohorts'][0]['comparison'])

    def test_missing_condition_is_error(self):
        data = dataset(); del data['samples'][0]['conditions']['debugger']
        with self.assertRaises(ValueError): self.run_comparison(data)

    def test_invalid_durations(self):
        for value in [float('nan'), float('inf'), 10**400, -1, 0, True, '100', None]:
            with self.subTest(value=value):
                data = dataset(); data['samples'][0]['duration_ms'] = value
                with self.assertRaises(ValueError): self.run_comparison(data)

    def test_duplicate_sample_is_error(self):
        data = dataset(); data['samples'].append(copy.deepcopy(data['samples'][0]))
        with self.assertRaises(ValueError): self.run_comparison(data)

    def test_no_outlier_removal(self):
        data = dataset(); data['samples'][0]['duration_ms'] = 100000
        summary = self.run_comparison(data)['cohorts'][0]['variants']['before']
        self.assertEqual(summary['max_ms'], 100000)
        self.assertEqual(summary['count'], 2)

    def test_single_sample_spread_is_unknown(self):
        data = dataset(); data['samples'] = [data['samples'][0], data['samples'][2]]
        summary = self.run_comparison(data)['cohorts'][0]['variants']['before']
        self.assertIsNone(summary['sample_stdev_ms'])

    def test_same_variant_is_error(self):
        with self.assertRaises(ValueError): launch.compare(dataset(), 'before', 'before')

    def test_unrepresentable_statistics_fail_explicitly(self):
        data = dataset()
        for sample in data['samples']:
            sample['duration_ms'] = 1e308
        with self.assertRaises(ValueError): self.run_comparison(data)

    def test_cli_is_read_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'samples.json'; original = json.dumps(dataset()); path.write_text(original)
            result = subprocess.run([sys.executable, str(PATH), str(path), '--baseline', 'before', '--candidate', 'after'], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout)['sample_count'], 4)
            self.assertEqual(path.read_text(), original)
            self.assertEqual(len(list(Path(tmp).iterdir())), 1)

    def test_cli_invalid_input(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'bad.json'; path.write_text('{"schema_version":1,"samples":[]}')
            result = subprocess.run([sys.executable, str(PATH), str(path), '--baseline', 'before', '--candidate', 'after'], capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn('error', json.loads(result.stderr))
            oversized = dataset(); oversized['samples'][0]['duration_ms'] = 10**400
            path.write_text(json.dumps(oversized))
            result = subprocess.run([sys.executable, str(PATH), str(path), '--baseline', 'before', '--candidate', 'after'], capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn('error', json.loads(result.stderr))


if __name__ == '__main__':
    unittest.main()
