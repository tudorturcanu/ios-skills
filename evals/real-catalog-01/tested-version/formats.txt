#!/usr/bin/env python3
"""Inspect selected, known format-string keys; never infer call-site arguments."""
import argparse
import json
import re
import sys
from pathlib import Path

# Deliberately restricted: stars, plural tokens, and uncommon conversions require review.
TOKEN = re.compile(r'%(?:(?P<position>[1-9][0-9]*)\$)?(?P<flags>[-+0#\']*)(?P<width>[0-9]*)(?:\.(?P<precision>[0-9]+))?(?P<length>hh|ll|h|l|q|z|t|j|L)?(?P<kind>[@diuoxXfFeEgGaA])')


def signature(value):
    if not isinstance(value, str):
        raise ValueError('Format value must be a string')
    arguments = {}
    sequential = 1
    modes = set()
    cursor = 0
    while cursor < len(value):
        start = value.find('%', cursor)
        if start == -1:
            break
        if value.startswith('%%', start):
            cursor = start + 2
            continue
        match = TOKEN.match(value, start, min(len(value), start + 128))
        if not match:
            return {'supported': False, 'reason': f'Unrecognized or unsupported format at character {start}'}
        position = match['position']
        # Bound numeric parsing; hostile or corrupt files must not trigger integer-conversion failures.
        if position and len(position) > 6:
            return {'supported': False, 'reason': 'Argument index exceeds supported range'}
        index = int(position) if position else sequential
        modes.add('positional' if position else 'sequential')
        if len(modes) > 1:
            return {'supported': False, 'reason': 'Mixed positional and sequential arguments'}
        if not position:
            sequential += 1
        length = match['length'] or ''
        kind = match['kind']
        if kind == '@':
            if '#' in match['flags']:
                return {'supported': False, 'reason': 'Named substitution or unsupported object flags'}
            if length:
                return {'supported': False, 'reason': 'Unsupported object length modifier'}
            argument_type = 'object'
        elif kind in 'diuoxX':
            if length == 'L':
                return {'supported': False, 'reason': 'Unsupported integer length modifier'}
            length = 'll' if length == 'q' else length
            argument_type = ('signed' if kind in 'di' else 'unsigned') + ':' + (length or 'int')
        else:
            if length not in ('', 'L'):
                return {'supported': False, 'reason': 'Unsupported floating-point length modifier'}
            argument_type = 'long-double' if length == 'L' else 'double'
        if index in arguments and arguments[index] != argument_type:
            return {'supported': False, 'reason': f'Argument {index} is used with conflicting types'}
        arguments[index] = argument_type
        cursor = match.end()
    return {'supported': True, 'arguments': {str(k): v for k, v in sorted(arguments.items())}}


def flat_value(node):
    if not isinstance(node, dict):
        raise ValueError('Locale entry must be an object')
    if 'variations' in node or 'substitutions' in node:
        return None
    unit = node.get('stringUnit')
    if not isinstance(unit, dict) or not isinstance(unit.get('value'), str):
        raise ValueError('Expected stringUnit with a string value')
    return unit['value']


def inspect(data, keys, locales):
    if not isinstance(data, dict) or not isinstance(data.get('sourceLanguage'), str) or not isinstance(data.get('strings'), dict):
        raise ValueError('Expected a String Catalog with sourceLanguage and strings')
    source_locale = data['sourceLanguage']
    findings = []
    compared = []
    for key in keys:
        if key not in data['strings']:
            raise ValueError(f'Requested key not found: {key}')
        entry = data['strings'][key]
        if not isinstance(entry, dict):
            raise ValueError(f'Invalid entry: {key}')
        if entry.get('shouldTranslate') is False:
            findings.append({'key': key, 'kind': 'skipped-nontranslatable'})
            continue
        translations = entry.get('localizations', {})
        if not isinstance(translations, dict):
            raise ValueError(f'Invalid localizations: {key}')
        source = flat_value(translations[source_locale]) if source_locale in translations else key
        if source is None:
            findings.append({'key': key, 'kind': 'manual-review', 'reason': 'Source uses variations/substitutions'})
            continue
        before = signature(source)
        if not before['supported']:
            findings.append({'key': key, 'kind': 'manual-review', 'reason': 'Source: '+before['reason']})
            continue
        for locale in locales:
            if locale == source_locale:
                continue
            if locale not in translations:
                findings.append({'key': key, 'locale': locale, 'kind': 'missing-locale-review'})
                continue
            target = flat_value(translations[locale])
            if target is None:
                findings.append({'key': key, 'locale': locale, 'kind': 'manual-review', 'reason': 'Target uses variations/substitutions'})
                continue
            after = signature(target)
            if not after['supported']:
                findings.append({'key': key, 'locale': locale, 'kind': 'manual-review', 'reason': 'Target: '+after['reason']})
                continue
            left, right = before['arguments'], after['arguments']
            compared.append({'key': key, 'locale': locale, 'source_signature': left, 'target_signature': right})
            for index in sorted(set(left) | set(right), key=int):
                if left.get(index) == right.get(index):
                    continue
                kind = 'argument-omitted-review' if index not in right else 'argument-added-review' if index not in left else 'argument-type-change'
                findings.append({'key': key, 'locale': locale, 'argument': int(index), 'kind': kind,
                                 'source_type': left.get(index), 'target_type': right.get(index)})
    return {'compared': compared, 'findings': findings, 'limitations': [
        'Only selected keys known from call sites to be format strings should be checked.',
        'Restricted flat-string grammar; variations, substitutions, dynamic widths, and unsupported syntax need manual review.',
        'Signatures describe declared format types, not the actual arguments supplied by application code.',
        'Added/omitted arguments and missing locales need product/call-site review; they are not automatic runtime defects.',
        'Equal signatures do not prove correct wording, argument meaning, rendering, or localization readiness.']}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('catalog', type=Path)
    p.add_argument('--key', action='append', required=True, help='Repeat only for keys confirmed to be format strings')
    p.add_argument('--locale', action='append', required=True)
    args = p.parse_args()
    try:
        report = inspect(json.loads(args.catalog.read_text()), list(dict.fromkeys(args.key)), list(dict.fromkeys(args.locale)))
    except (OSError, ValueError, RecursionError) as exc:
        print(json.dumps({'error': str(exc)}), file=sys.stderr)
        return 2
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    sys.exit(main())
