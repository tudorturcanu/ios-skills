import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

PATH = Path(__file__).resolve().parents[1]/'swiftdata-migration-checker/scripts/run_migration_probe.py'
spec = importlib.util.spec_from_file_location('migration_probe', PATH)
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


class MigrationProbeChecks(unittest.TestCase):
    def validate_snapshot(self, result):
        with patch.object(probe, 'execute', return_value=json.dumps(result)):
            return probe.check_snapshot(Path('unused-binary'), 'open3', Path('unused-store'), 'records', Path('unused-log'), expected_prior='1.0.0')

    def test_preserved_records_and_versions_pass(self):
        result = {'records': probe.EXPECTED, 'storeVersions': ['3.0.0'], 'priorVersions': ['1.0.0']}
        self.assertEqual(self.validate_snapshot(result), result)

    def test_equal_counts_with_lost_values_fail(self):
        records = [dict(record, name='') for record in probe.EXPECTED]
        with self.assertRaises(RuntimeError):
            self.validate_snapshot({'records': records, 'storeVersions': ['3.0.0'], 'priorVersions': ['1.0.0']})

    def test_wrong_schema_with_correct_values_fails(self):
        with self.assertRaises(RuntimeError):
            self.validate_snapshot({'records': probe.EXPECTED, 'storeVersions': ['1.0.0'], 'priorVersions': ['1.0.0']})

    def test_missing_source_metadata_fails(self):
        with self.assertRaises(RuntimeError):
            self.validate_snapshot({'records': probe.EXPECTED, 'storeVersions': ['3.0.0']})

    def test_wrong_source_version_fails(self):
        with self.assertRaises(RuntimeError):
            self.validate_snapshot({'records': probe.EXPECTED, 'storeVersions': ['3.0.0'], 'priorVersions': ['2.0.0']})

    def test_existing_output_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as tmp:
            sentinel = Path(tmp)/'keep.txt';sentinel.write_text('Keep this existing content.')
            result = subprocess.run([sys.executable, str(PATH), '--output', tmp], capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertEqual(sentinel.read_text(), 'Keep this existing content.')
            self.assertEqual([p.name for p in Path(tmp).iterdir()], ['keep.txt'])


if __name__ == '__main__':
    unittest.main()
