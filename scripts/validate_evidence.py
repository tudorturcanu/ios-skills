#!/usr/bin/env python3
"""Check that recorded benchmark outcomes still match their retained evidence."""
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_fresh_verification(probe):
    """Recovery requires an observed failure and a verified result for that same ID."""
    errors = []
    observations = {o['phase']: o for o in probe['observations']}
    checks = probe['checks']
    if 'fresh_purchase_is_unverified' not in checks:
        return errors  # This attempt did not reach the purchase assertion.
    fresh = observations['fresh_purchase']
    failed = fresh['verification'] == 'unverified' and fresh.get('verification_error') == 'invalidSignature'
    if checks['fresh_purchase_is_unverified'] is not failed:
        errors.append('storekit: fresh verification failure contradicts observations')
    if fresh.get('transaction_id') == observations['consumable_result']['transaction_id']:
        errors.append('storekit: fresh purchase reused prior consumable ID')
    if 'fresh_same_id_verification_recovers' in checks:
        recovered = observations['fresh_verification_recovery']
        same_id = fresh.get('transaction_id') is not None and recovered.get('transaction_id') == fresh['transaction_id']
        expected = failed and same_id and recovered['verified_same_id'] is True and recovered['environment'] == 'Xcode'
        if checks['fresh_same_id_verification_recovers'] is not expected:
            errors.append('storekit: fresh recovery lacks observed failure or verified matching transaction')
    return errors


def validate_storekit(root):
    """Accept failed historical runs, but reject changed inputs or unsupported claims."""
    errors = []
    case = root/'evals/storekit-lifecycle-01'
    try:
        index = json.loads((case/'run-index.json').read_text())
        reports = {p.parent.name for p in case.glob('run*/results.json')}
        if set(index) != reports:
            errors.append('storekit: run index does not cover retained reports')
        for name, entry in index.items():
            report = json.loads((case/name/'results.json').read_text())
            if set(entry['inputs']) != set(report['inputs']):
                errors.append(f'storekit/{name}: incomplete input mapping')
            for original, relative in entry['inputs'].items():
                path = (case/relative).resolve()
                if case.resolve() not in path.parents or digest(path) != report['inputs'][original]:
                    errors.append(f'storekit/{name}: changed tested {original}')
            if report.get('created_device') and report['cleanup_deleted'] is not True:
                errors.append(f'storekit/{name}: created simulator lacks cleanup evidence')
            probe = report.get('probe')
            if probe:
                errors.extend(validate_fresh_verification(probe))
                expected = bool(probe['checks']) and all(v is True for v in probe['checks'].values()) and not probe.get('error')
                if probe['passed'] is not expected:
                    errors.append(f'storekit/{name}: inconsistent probe outcome')
                expected_run = expected and report.get('xcodebuild_returncode') == 0
                if report['passed'] is not expected_run:
                    errors.append(f'storekit/{name}: inconsistent runner outcome')

        # Earlier reports deliberately retain vacuous checks; apply this contract
        # only to the revised probe that requires observable transition states.
        report = json.loads((case/'run-observed-transitions/results.json').read_text())
        probe = report['probe']
        observations = {o['phase']: o for o in probe['observations']}
        checks = probe['checks']
        premium = 'org.example.iosskills.premium'
        coins = 'org.example.iosskills.coins'
        def trusted(phase):
            return observations[phase]['verified'] == [premium] and observations[phase]['unverified'] == []
        def empty(phase):
            return observations[phase]['verified'] == [] and observations[phase]['unverified'] == []
        purchased = trusted('purchased_nonconsumable')
        refunded = purchased and trusted('verification_recovered') and empty('after_refund')
        unfinished = observations['consumable_unfinished_ids']
        identifier = unfinished['transaction_id']
        before = identifier in unfinished['before']
        derived = {
            'initial_empty': empty('initial'),
            'purchase_is_local_xcode_transaction': observations['purchase_result']['environment'] == 'Xcode',
            'purchase_entitles': purchased,
            'finish_does_not_remove_nonconsumable': purchased and trusted('finished_nonconsumable'),
            'unverified_is_not_an_empty_snapshot': observations['unverified_nonconsumable']['verified'] == [] and observations['unverified_nonconsumable']['unverified'] == [premium],
            # Historical name means verified after reset, not proven recovery.
            'verification_recovers': trusted('verification_recovered'),
            'refund_removes_entitlement': refunded,
            'grow_only_negative_control_detected': refunded and premium in (observations['purchased_nonconsumable']['verified'] + observations['after_refund']['verified']),
            'consumable_is_local_xcode_transaction': observations['consumable_result']['environment'] == 'Xcode',
            'consumable_absent_from_current_entitlements': coins not in (observations['unfinished_consumable']['verified'] + observations['unfinished_consumable']['unverified']),
            'consumable_in_unfinished_before_finish': before,
            'finished_consumable_leaves_unfinished': before and identifier not in unfinished['after'],
        }
        if set(checks) != set(derived) | {'local_products_loaded'}:
            errors.append('storekit: incomplete final check set')
        for check, observed in derived.items():
            if checks.get(check) is not observed:
                errors.append(f'storekit: {check} contradicts observations')
        commands = json.loads((case/'run-observed-transitions/commands.json').read_text())
        build = next(c for c in commands if c['argv'][0] == 'xcodebuild' and 'test' in c['argv'])
        if report['xcodebuild_returncode'] != build['returncode'] or report['xcodebuild_timed_out'] != build['timed_out']:
            errors.append('storekit: runner outcome contradicts command record')
    except (OSError, ValueError, KeyError, TypeError, StopIteration) as exc:
        errors.append(f'storekit: {exc}')
    return errors


def validate(root=ROOT):
    errors = []
    for case, filename in [('localization-01', 'input-manifest.json'), ('deeplink-01', 'manifest.json'), ('format-arguments-01', 'manifest.json'), ('real-catalog-01', 'manifest.json'), ('widget-review-01', 'manifest.json'), ('offline-recovery-01', 'manifest.json'), ('photo-permissions-01', 'manifest.json'), ('storekit-lifecycle-01', 'manifest.json')]:
        try:
            manifest = json.loads((root/'evals'/case/filename).read_text())
            for relative, expected in manifest.items():
                path = (root/relative).resolve()
                if root.resolve() not in path.parents:
                    errors.append(f'{case}: evidence path outside repository: {relative}')
                elif digest(path) != expected:
                    errors.append(f'{case}: changed historical input: {relative}')
        except (OSError, ValueError) as exc:
            errors.append(f'{case}: {exc}')
    case = root/'evals/deeplink-01'
    for condition in ('no-skill', 'revised', 'comparator'):
        try:
            run = case/'runs'/condition
            grade = json.loads((run/'grade.json').read_text())
            if grade['candidate_sha256'] != digest(run/'RouteCoordinator.swift'):
                errors.append(f'{condition}: grade does not match candidate')
            if grade['harness_sha256'] != digest(case/'grading/main.swift'):
                errors.append(f'{condition}: grade does not match harness')
            checks = grade['checks']
            if grade['total'] != len(checks) or grade['passed'] != sum(c['passed'] for c in checks):
                errors.append(f'{condition}: inconsistent recorded totals')
        except (OSError, ValueError, KeyError, TypeError) as exc:
            errors.append(f'{condition}: {exc}')
    try:
        case = root/'evals/migration-probe-01'
        report = json.loads((case/'results.json').read_text())
        for key, filename in [('source_sha256', 'probe.swift'), ('runner_sha256', 'runner.txt')]:
            if report[key] != digest(case/'tested-version'/filename):
                errors.append(f'migration-probe: changed tested {filename}')
        if not report['passed'] or len(report['cases']) != 6 or not all(c['passed'] and c['reopened'] and c['source_unchanged'] for c in report['cases']):
            errors.append('migration-probe: incomplete positive-path evidence')
        if not report['negative_control']['detected'] or not report['negative_control']['names_lost']:
            errors.append('migration-probe: missing negative control')
    except (OSError, ValueError, KeyError, TypeError) as exc:
        errors.append(f'migration-probe: {exc}')
    errors.extend(validate_storekit(root))
    return errors


if __name__ == '__main__':
    failures = validate()
    if failures:
        print('\n'.join(failures), file=sys.stderr)
        sys.exit(1)
    print('Recorded benchmark inputs, candidates, grader hashes, and totals match retained evidence.')
