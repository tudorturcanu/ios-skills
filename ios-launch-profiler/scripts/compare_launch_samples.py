#!/usr/bin/env python3
"""Compare supplied launch samples within explicitly matching measurement conditions."""
import argparse
import json
import math
import statistics
import sys
from pathlib import Path

CONDITIONS = ('device', 'os', 'configuration', 'debugger', 'install_state',
              'data_state', 'network', 'launch_kind', 'cache_state', 'interval', 'instrumentation')


def summarize(samples):
    values = [sample['duration_ms'] for sample in samples]
    median = statistics.median(values)
    if not math.isfinite(median):
        raise ValueError('Sample magnitude exceeds representable summary statistics')
    return {'count': len(values), 'median_ms': median,
            'min_ms': min(values), 'max_ms': max(values),
            'sample_stdev_ms': statistics.stdev(values) if len(values) > 1 else None,
            'sample_ids': [s['sample_id'] for s in samples], 'durations_ms': values}


def compare(data, baseline, candidate):
    if not baseline or not candidate or baseline == candidate:
        raise ValueError('Baseline and candidate must be distinct nonempty variant names')
    if not isinstance(data, dict) or type(data.get('schema_version')) is not int or data['schema_version'] != 1:
        raise ValueError('Expected schema_version 1')
    samples = data.get('samples')
    if not isinstance(samples, list) or not samples:
        raise ValueError('Expected a nonempty samples array')
    groups = {}
    seen = set()
    for index, sample in enumerate(samples):
        if not isinstance(sample, dict):
            raise ValueError(f'samples[{index}] must be an object')
        sample_id, variant = sample.get('sample_id'), sample.get('variant')
        if not isinstance(sample_id, str) or not sample_id.strip() or sample_id in seen:
            raise ValueError(f'samples[{index}] needs a unique nonempty sample_id')
        seen.add(sample_id)
        if not isinstance(variant, str) or not variant.strip():
            raise ValueError(f'{sample_id}: missing variant')
        duration = sample.get('duration_ms')
        try:
            finite = type(duration) in (int, float) and math.isfinite(duration)
        except OverflowError:
            finite = False
        if not finite or duration <= 0:
            raise ValueError(f'{sample_id}: duration_ms must be a positive finite number')
        conditions = sample.get('conditions')
        if not isinstance(conditions, dict):
            raise ValueError(f'{sample_id}: missing conditions object')
        missing = set(CONDITIONS) - set(conditions)
        if missing:
            raise ValueError(f'{sample_id}: missing conditions {sorted(missing)}')
        # Include extra conditions too, so an added thermal-state dimension is not ignored.
        for key, value in conditions.items():
            if not isinstance(value, str) or not value.strip():
                raise ValueError(f'{sample_id}: condition {key} must be a nonempty string')
        key = tuple(sorted(conditions.items()))
        groups.setdefault(key, {}).setdefault(variant, []).append(sample)
    cohorts = []
    for key, variants in groups.items():
        conditions = dict(key)
        stats = {variant: summarize(rows) for variant, rows in variants.items()}
        item = {'conditions': conditions, 'variants': stats, 'comparison': None}
        unknown = [k for k, v in key if v.strip().lower() in ('unknown', 'unspecified')]
        if unknown:
            item['comparison_unavailable'] = 'Unknown conditions: ' + ', '.join(unknown)
        elif baseline not in variants or candidate not in variants:
            item['comparison_unavailable'] = 'Both requested variants are not present in this cohort'
        else:
            before, after = stats[baseline], stats[candidate]
            delta = after['median_ms'] - before['median_ms']
            percent = delta / before['median_ms'] * 100
            if not math.isfinite(percent):
                raise ValueError('Median percentage change exceeds representable range')
            item['comparison'] = {
                'baseline': baseline, 'candidate': candidate,
                'median_change_ms': delta,
                'median_change_percent': percent,
                'direction': 'lower' if delta < 0 else 'higher' if delta > 0 else 'equal',
                'observed_ranges_overlap': max(before['min_ms'], after['min_ms']) <= min(before['max_ms'], after['max_ms']),
                'exploratory_small_sample': min(before['count'], after['count']) < 5,
            }
        cohorts.append(item)
    return {'schema_version': 1, 'sample_count': len(samples), 'cohorts': cohorts,
            'limitations': ['Descriptive comparison of supplied measurements, not a new device benchmark.',
                            'Matching labels do not prove equivalent real conditions or causation.',
                            'No significance test; observed range overlap is not a confidence interval.',
                            'No samples or outliers are discarded. Negative median change means lower duration.',
                            'First-frame and ready-to-interact intervals are kept separate; inspect both.']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path)
    parser.add_argument('--baseline', required=True)
    parser.add_argument('--candidate', required=True)
    args = parser.parse_args()
    try:
        result = compare(json.loads(args.input.read_text()), args.baseline, args.candidate)
    except (OSError, ValueError, RecursionError) as exc:
        print(json.dumps({'error': str(exc)}), file=sys.stderr)
        return 2
    print(json.dumps(result, indent=2, allow_nan=False))
    return 0


if __name__ == '__main__':
    sys.exit(main())
