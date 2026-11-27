#!/usr/bin/env python3
"""Inspect a local AASA JSON and signed entitlements plist without network calls."""
import argparse
import json
import plistlib
import sys
from pathlib import Path


def inspect(aasa, entitlements, host):
    if not isinstance(aasa, dict) or not isinstance(entitlements, dict):
        raise ValueError('Expected AASA and entitlements dictionaries')
    if not host or any(c in host for c in '/:?#*'):
        raise ValueError('Host must be an exact DNS hostname, without scheme, port, path, or wildcard')
    host = host.lower().rstrip('.')
    identifier = entitlements.get('application-identifier')
    if not isinstance(identifier, str) or not identifier:
        raise ValueError('Signed entitlements must include application-identifier')
    domains = entitlements.get('com.apple.developer.associated-domains', [])
    if not isinstance(domains, list) or any(not isinstance(v, str) for v in domains):
        raise ValueError('Associated domains must be an array of strings')
    matches = []
    for domain in domains:
        if not domain.startswith('applinks:'):
            continue
        value = domain[len('applinks:'):].split('?', 1)[0].lower()
        if value == host or (value.startswith('*.') and host.endswith('.' + value[2:])):
            matches.append(domain)
    applinks = aasa.get('applinks', {})
    if not isinstance(applinks, dict):
        raise ValueError('applinks must be an object')
    details = applinks.get('details', [])
    if not isinstance(details, list):
        raise ValueError('This inspector supports array-form applinks.details only')
    selected = []
    for index, detail in enumerate(details):
        if not isinstance(detail, dict):
            raise ValueError(f'details[{index}] must be an object')
        identifiers = detail.get('appIDs', [detail['appID']] if 'appID' in detail else [])
        if not isinstance(identifiers, list) or any(not isinstance(v, str) for v in identifiers):
            raise ValueError(f'details[{index}] appIDs must be strings')
        if identifier in identifiers:
            selected.append({'index': index, 'paths': detail.get('paths'), 'components': detail.get('components')})
    alternate_mode_entries = [entry for entry in matches if '?' in entry]
    findings = []
    if not matches:
        findings.append('No matching applinks entitlement for host')
    elif len(alternate_mode_entries) == len(matches):
        findings.append('Host matched only entries with query qualifiers; verify alternate mode on the intended build and device')
    if not selected:
        findings.append('No AASA details entry contains the signed application identifier')
    return {'application_identifier': identifier, 'host': host, 'matching_domain_entries': matches,
            'matching_entries_with_query_qualifiers': alternate_mode_entries,
            'matching_aasa_details': selected,
            'findings': findings,
            'limitations': ['Local identity check only; does not evaluate URL matching rules.',
                            'Does not verify HTTPS, redirects, CDN state, installed signing, OS association, or delivery.',
                            'Entitlements must come from the intended signed build; a project plist is not proof.']}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('aasa', type=Path)
    p.add_argument('--entitlements', type=Path, required=True)
    p.add_argument('--host', required=True)
    args = p.parse_args()
    try:
        result = inspect(json.loads(args.aasa.read_text()), plistlib.loads(args.entitlements.read_bytes()), args.host)
    except (OSError, ValueError, RecursionError, plistlib.InvalidFileException) as exc:
        print(json.dumps({'error': str(exc)}), file=sys.stderr)
        return 2
    print(json.dumps(result, indent=2))
    return 0


if __name__ == '__main__':
    sys.exit(main())
