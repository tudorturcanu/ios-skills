import importlib.util
import json
import shutil
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('evidence', ROOT/'scripts/validate_evidence.py')
evidence = importlib.util.module_from_spec(spec)
spec.loader.exec_module(evidence)


class EvidenceIntegrityTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        shutil.copytree(ROOT/'evals', self.root/'evals')

    def test_retained_evidence_is_consistent(self):
        self.assertEqual(evidence.validate(self.root), [])

    def test_candidate_edit_invalidates_recorded_grade(self):
        path = self.root/'evals/deeplink-01/runs/revised/RouteCoordinator.swift'
        path.write_text(path.read_text()+'\n// changed candidate\n')
        self.assertTrue(any('grade does not match candidate' in e for e in evidence.validate(self.root)))

    def test_harness_edit_invalidates_all_comparisons(self):
        path = self.root/'evals/deeplink-01/grading/main.swift'
        path.write_text(path.read_text()+'\n// changed harness\n')
        errors = evidence.validate(self.root)
        self.assertEqual(sum('grade does not match harness' in e for e in errors), 3)

    def test_incorrect_totals_are_rejected(self):
        path = self.root/'evals/deeplink-01/runs/revised/grade.json'
        grade = json.loads(path.read_text()); grade['passed'] = 999
        path.write_text(json.dumps(grade))
        self.assertTrue(any('inconsistent recorded totals' in e for e in evidence.validate(self.root)))

    def test_migration_source_edit_invalidates_evidence(self):
        path = self.root/'evals/migration-probe-01/tested-version/probe.swift'
        path.write_text(path.read_text()+'\n// changed source\n')
        self.assertTrue(any('changed tested probe.swift' in e for e in evidence.validate(self.root)))

    def test_missing_migration_negative_control_is_rejected(self):
        path = self.root/'evals/migration-probe-01/results.json'
        report = json.loads(path.read_text()); report['negative_control']['detected'] = False
        path.write_text(json.dumps(report))
        self.assertTrue(any('missing negative control' in e for e in evidence.validate(self.root)))

    def test_frozen_skill_change_is_detected(self):
        path = self.root/'evals/localization-01/tested-version/instructions.txt'
        path.write_text(path.read_text()+'\nChanged instructions.\n')
        self.assertTrue(any('changed historical input' in e for e in evidence.validate(self.root)))

    def edit_storekit_report(self, change):
        path = self.root/'evals/storekit-lifecycle-01/run-observed-transitions/results.json'
        report = json.loads(path.read_text())
        change(report)
        path.write_text(json.dumps(report))
        return evidence.validate_storekit(self.root)

    def test_storekit_empty_to_empty_refund_is_rejected(self):
        def change(report):
            for observation in report['probe']['observations']:
                if observation['phase'] == 'purchased_nonconsumable':
                    observation['verified'] = []
        errors = self.edit_storekit_report(change)
        self.assertTrue(any('refund_removes_entitlement contradicts observations' in e for e in errors))

    def test_storekit_absent_consumable_cannot_prove_finish(self):
        def change(report):
            for observation in report['probe']['observations']:
                if observation['phase'] == 'consumable_unfinished_ids':
                    observation['before'] = []
        errors = self.edit_storekit_report(change)
        self.assertTrue(any('finished_consumable_leaves_unfinished contradicts observations' in e for e in errors))

    def test_storekit_failed_injection_cannot_be_reported_as_exercised(self):
        errors = self.edit_storekit_report(lambda r: r['probe']['checks'].update(unverified_is_not_an_empty_snapshot=True))
        self.assertTrue(any('unverified_is_not_an_empty_snapshot contradicts observations' in e for e in errors))

    def test_storekit_timeout_cannot_be_reported_as_success(self):
        errors = self.edit_storekit_report(lambda r: r.update(passed=True, xcodebuild_returncode=0, xcodebuild_timed_out=False))
        self.assertTrue(any('inconsistent runner outcome' in e for e in errors))
        self.assertTrue(any('runner outcome contradicts command record' in e for e in errors))

    def test_storekit_frozen_input_change_is_rejected(self):
        path = self.root/'evals/storekit-lifecycle-01/run-observed-transitions/source.txt'
        path.write_text(path.read_text()+'\n// changed source\n')
        self.assertTrue(any('changed tested Probe.swift' in e for e in evidence.validate_storekit(self.root)))

    def test_verified_without_prior_failure_cannot_prove_recovery(self):
        probe = {'checks': {'fresh_purchase_is_unverified': False, 'fresh_same_id_verification_recovers': True},
                 'observations': [
                     {'phase': 'consumable_result', 'transaction_id': 1},
                     {'phase': 'fresh_purchase', 'verification': 'verified', 'transaction_id': 2},
                     {'phase': 'fresh_verification_recovery', 'verified_same_id': True,
                      'transaction_id': 2, 'environment': 'Xcode'}]}
        self.assertTrue(any('recovery lacks observed failure' in e for e in evidence.validate_fresh_verification(probe)))

    def test_another_verified_transaction_cannot_prove_recovery(self):
        probe = {'checks': {'fresh_purchase_is_unverified': True, 'fresh_same_id_verification_recovers': True},
                 'observations': [
                     {'phase': 'consumable_result', 'transaction_id': 1},
                     {'phase': 'fresh_purchase', 'verification': 'unverified', 'verification_error': 'invalidSignature', 'transaction_id': 2},
                     {'phase': 'fresh_verification_recovery', 'verified_same_id': True,
                      'transaction_id': 3, 'environment': 'Xcode'}]}
        self.assertTrue(any('recovery lacks observed failure' in e for e in evidence.validate_fresh_verification(probe)))


if __name__ == '__main__':
    unittest.main()
