#!/usr/bin/env python3
"""Read-only String Catalog inventory; never edits or approves translations."""
import argparse
import json
import sys
from pathlib import Path


def units(node, path=''):
    if not isinstance(node, dict):
        return
    if 'stringUnit' in node:
        unit = node['stringUnit']
        if not isinstance(unit, dict) or not isinstance(unit.get('value'), str):
            raise ValueError(f'Invalid stringUnit at {path}')
        yield path + '/stringUnit', unit
    for key in ('variations', 'substitutions'):
        child = node.get(key, {})
        if not isinstance(child, dict):
            raise ValueError(f'Invalid {key} at {path}')
        for name, value in child.items():
            if not isinstance(value, dict):
                raise ValueError(f'Invalid {key}/{name} at {path}')
            # A substitutions entry owns variations; a variation owns categories.
            if key == 'substitutions':
                yield from units(value, f'{path}/{key}/{name}')
            else:
                for category, entry in value.items():
                    if not isinstance(entry, dict):
                        raise ValueError(f'Invalid variation at {path}/{name}/{category}')
                    yield from units(entry, f'{path}/{key}/{name}/{category}')


def inventory(data, locales):
    if not isinstance(data, dict) or not isinstance(data.get('sourceLanguage'), str):
        raise ValueError('Expected a catalog object with sourceLanguage')
    strings = data.get('strings')
    if not isinstance(strings, dict):
        raise ValueError('Expected strings dictionary')
    findings = []
    skipped = []
    for key, entry in sorted(strings.items()):
        if not isinstance(entry, dict):
            raise ValueError(f'Invalid entry: {key}')
        if entry.get('shouldTranslate') is False:
            skipped.append(key)
            continue
        translations = entry.get('localizations', {})
        if not isinstance(translations, dict):
            raise ValueError(f'Invalid localizations: {key}')
        if entry.get('extractionState') == 'stale':
            findings.append({'key': key, 'kind': 'stale-extraction', 'severity': 'review'})
        for locale in locales:
            if locale == data['sourceLanguage'] and locale not in translations:
                continue  # Source keys can supply the source text.
            if locale not in translations:
                findings.append({'key': key, 'locale': locale, 'kind': 'missing-locale', 'severity': 'review'})
                continue
            if not isinstance(translations[locale], dict):
                raise ValueError(f'Invalid locale entry: {key}/{locale}')
            leaves = list(units(translations[locale]))
            if not leaves:
                findings.append({'key': key, 'locale': locale, 'kind': 'no-string-units', 'severity': 'review'})
            for path, unit in leaves:
                state = unit.get('state', 'unspecified')
                if state != 'translated':
                    findings.append({'key': key, 'locale': locale, 'path': path,
                                     'kind': 'translation-state', 'state': state, 'severity': 'review'})
    return {'source_language': data['sourceLanguage'], 'requested_locales': locales,
            'entry_count': len(strings), 'skipped_nontranslatable': skipped, 'findings': findings,
            'limitations': ['Inventory only; missing locale may intentionally use fallback.',
                            'Does not validate language quality, placeholders, plural completeness, extraction, or rendering.']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('catalog', type=Path)
    parser.add_argument('--locale', action='append', required=True, help='Repeat for each intended locale')
    args = parser.parse_args()
    try:
        result = inventory(json.loads(args.catalog.read_text()), list(dict.fromkeys(args.locale)))
    except (OSError, ValueError) as exc:
        print(json.dumps({'error': str(exc)}), file=sys.stderr)
        return 2
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    sys.exit(main())
