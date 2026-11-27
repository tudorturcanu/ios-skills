#!/usr/bin/env python3
"""Classify surviving instance counts across repeated cycles of one interaction.

Reads a JSON record of settled per-cycle counts (for example, transcribed from
Instruments Allocations generations or Xcode memory-graph instance counts) and
reports, per type, whether the surviving count keeps growing, levels off, or
stays flat. Read-only: it never runs Instruments or touches the app.
"""
import argparse
import json
import sys
from pathlib import Path

MIN_CYCLES = 3
PLATEAU_STEPS = 2


def _count(value, where):
    if type(value) is not int or value < 0:
        raise ValueError(f'{where} must be a nonnegative integer')
    return value


def classify(points):
    """Classify a list of (cycle, count) pairs sorted by cycle."""
    counts = [count for _, count in points]
    steps = [b - a for a, b in zip(counts, counts[1:])]
    first_cycle, last_cycle = points[0][0], points[-1][0]
    per_cycle = (counts[-1] - counts[0]) / (last_cycle - first_cycle)
    result = {'cycles': [c for c, _ in points], 'counts': counts,
              'change': counts[-1] - counts[0], 'change_per_cycle': per_cycle}
    if all(step == 0 for step in steps):
        result['pattern'] = 'flat'
    elif any(step > 0 for step in steps) and any(step < 0 for step in steps):
        result['pattern'] = 'irregular'
    elif all(step <= 0 for step in steps):
        result['pattern'] = 'shrinking'
    elif len(steps) > PLATEAU_STEPS and all(step == 0 for step in steps[-PLATEAU_STEPS:]):
        result['pattern'] = 'plateau'
    else:
        result['pattern'] = 'growing'
    if result['pattern'] == 'growing':
        gaps = [b - a for a, b in zip(result['cycles'], result['cycles'][1:])]
        # Steady growth: every step adds the same number of instances per elapsed cycle.
        rates = {step / gap for step, gap in zip(steps, gaps)}
        result['steady'] = len(rates) == 1
        result['note'] = ('Survives each settled cycle; trace incoming references to the owner.'
                          if result['steady'] else
                          'Grows unevenly; check for overlapping work or a cache keyed per input.')
    elif result['pattern'] == 'plateau':
        result['note'] = 'Stopped growing; consistent with a bounded cache or deferred cleanup.'
    elif result['pattern'] == 'irregular':
        result['note'] = 'Rises and falls; samples may not be settled at the same point.'
    return result


def analyze(data):
    if not isinstance(data, dict) or type(data.get('schema_version')) is not int or data['schema_version'] != 1:
        raise ValueError('Expected schema_version 1')
    interaction = data.get('interaction')
    if not isinstance(interaction, str) or not interaction.strip():
        raise ValueError('Expected a nonempty interaction description')
    samples = data.get('samples')
    if not isinstance(samples, list) or not samples:
        raise ValueError('Expected a nonempty samples array')
    settled, skipped, seen = [], [], set()
    for index, sample in enumerate(samples):
        if not isinstance(sample, dict):
            raise ValueError(f'samples[{index}] must be an object')
        cycle = sample.get('cycle')
        if type(cycle) is not int or cycle < 0:
            raise ValueError(f'samples[{index}]: cycle must be a nonnegative integer')
        if type(sample.get('settled')) is not bool:
            raise ValueError(f'samples[{index}]: settled must be true or false')
        counts = sample.get('counts')
        if not isinstance(counts, dict) or not counts:
            raise ValueError(f'samples[{index}]: counts must be a nonempty object')
        for name, value in counts.items():
            if not isinstance(name, str) or not name.strip():
                raise ValueError(f'samples[{index}]: type names must be nonempty strings')
            _count(value, f'samples[{index}].counts[{name!r}]')
        footprint = sample.get('footprint_bytes')
        if footprint is not None:
            _count(footprint, f'samples[{index}].footprint_bytes')
        if not sample['settled']:
            skipped.append(cycle)
            continue
        if cycle in seen:
            raise ValueError(f'samples[{index}]: duplicate settled sample for cycle {cycle}')
        seen.add(cycle)
        settled.append(sample)
    settled.sort(key=lambda s: s['cycle'])
    if len(settled) < MIN_CYCLES:
        raise ValueError(f'Need settled samples from at least {MIN_CYCLES} distinct cycles, got {len(settled)}')

    names = sorted({name for s in settled for name in s['counts']})
    types, incomplete = {}, []
    for name in names:
        points = [(s['cycle'], s['counts'][name]) for s in settled if name in s['counts']]
        if len(points) < len(settled):
            # A missing count is not zero; do not guess.
            incomplete.append(name)
            continue
        types[name] = classify(points)

    footprints = [(s['cycle'], s['footprint_bytes']) for s in settled if s.get('footprint_bytes') is not None]
    footprint = classify(footprints) if len(footprints) == len(settled) else None

    order = {'growing': 0, 'irregular': 1, 'plateau': 2, 'shrinking': 3, 'flat': 4}
    ranked = sorted(types, key=lambda n: (order[types[n]['pattern']], -types[n]['change_per_cycle'], n))
    result = {
        'schema_version': 1,
        'interaction': interaction,
        'settled_cycles': [s['cycle'] for s in settled],
        'unsettled_cycles_skipped': sorted(skipped),
        'growing': [n for n in ranked if types[n]['pattern'] == 'growing'],
        'types': {n: types[n] for n in ranked},
        'incomplete_types': incomplete,
        'footprint': footprint,
        'limitations': [
            'Classifies supplied counts only; it does not prove an ownership path.',
            'Compare counts captured at the same settled point in every cycle.',
            'A plateau can be a bounded cache; repeat with different inputs to tell reuse from per-item growth.',
            'Footprint growth alone cannot establish a retained object; check decoded images and buffers too.',
            'Types missing from any settled sample are reported as incomplete, not treated as zero.',
        ],
    }
    if footprint is not None and footprint['pattern'] == 'growing' and not result['growing']:
        result['footprint_note'] = ('Footprint grows while no recorded type does; record non-object '
                                    'allocations such as image and graphics buffers.')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('input', type=Path, help='JSON file in the generations format')
    args = parser.parse_args()
    try:
        result = analyze(json.loads(args.input.read_text()))
    except (OSError, ValueError, RecursionError) as exc:
        print(json.dumps({'error': str(exc)}), file=sys.stderr)
        return 2
    print(json.dumps(result, indent=2, allow_nan=False))
    return 0


if __name__ == '__main__':
    sys.exit(main())
