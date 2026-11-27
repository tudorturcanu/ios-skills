import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('probe_process', ROOT/'evals/storekit-lifecycle-01/probe_process.py')
probe_process = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe_process)


class ProbeProcessTests(unittest.TestCase):
    def test_success_retains_both_streams(self):
        records = []
        output = probe_process.run_recorded(
            [sys.executable, '-c', 'import sys; print("result"); print("diagnostic", file=sys.stderr)'], records)
        self.assertEqual(output, 'result')
        self.assertEqual(records[0]['stderr'], 'diagnostic\n')
        self.assertFalse(records[0]['timed_out'])

    def test_timeout_keeps_output_and_log(self):
        records = []
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory)/'command.log'
            probe_process.run_recorded(
                [sys.executable, '-u', '-c', 'import time; print("entered test phase", flush=True); time.sleep(30)'],
                records, timeout=0.5, check=False, log_path=log)
            self.assertIn('entered test phase', log.read_text())
        self.assertTrue(records[0]['timed_out'])
        self.assertEqual(records[0]['returncode'], 124)
        self.assertNotEqual(records[0]['process_returncode'], 0)

    def test_checked_failure_is_recorded_before_raising(self):
        records = []
        with self.assertRaisesRegex(RuntimeError, 'exited 7'):
            probe_process.run_recorded([sys.executable, '-c', 'print("failed setup"); raise SystemExit(7)'], records)
        self.assertEqual(records[0]['returncode'], 7)
        self.assertIn('failed setup', records[0]['stdout'])


if __name__ == '__main__':
    unittest.main()
