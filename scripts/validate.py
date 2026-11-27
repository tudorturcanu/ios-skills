#!/usr/bin/env python3
"""Validate skill metadata, references, and packaging."""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = {
    'app-store-audit', 'ios-memory-growth',
    'ios-accessibility-audit', 'ios-crash-triage', 'ios-deeplink-doctor',
    'ios-launch-profiler', 'ios-localization-audit', 'ios-offline-sync-review',
    'ios-permission-flow-tester', 'storekit-entitlement-debugger',
    'swiftdata-migration-checker', 'widget-data-consistency',
}


def validate(root=ROOT):
    errors = []
    found = {p.name for p in root.iterdir() if (p / 'SKILL.md').is_file()}
    if found != EXPECTED:
        errors.append(f'Skill set differs: missing={EXPECTED-found}, extra={found-EXPECTED}')
    for name in sorted(found):
        folder = root / name
        try:
            text = (folder / 'SKILL.md').read_text()
            match = re.match(r'^---\nname: ([a-z0-9-]+)\ndescription: (.+)\n---\n\n(.+)', text, re.S)
            if not match:
                raise ValueError('Invalid frontmatter or missing body')
            declared, description, body = match.groups()
            if name not in {'app-store-audit', 'ios-memory-growth'} or description.startswith('"'):
                description = json.loads(description)
            if declared != name or len(name) > 64:
                raise ValueError('Name does not match folder or exceeds 64 characters')
            if not isinstance(description, str) or not 1 <= len(description) <= 1024:
                raise ValueError('Description must be a nonempty string of at most 1024 characters')
            if '<' in description or '>' in description:
                raise ValueError('Description contains angle brackets')
            if re.search(r'\[TODO:|TBD|PLACEHOLDER', body):
                raise ValueError('Unfinished scaffold')
            if name != 'ios-memory-growth':
                metadata = (folder / 'agents' / 'openai.yaml').read_text().splitlines()
                if metadata[0] != 'interface:':
                    raise ValueError('Missing UI interface')
                interface = {}
                for line in metadata[1:]:
                    key, value = line.strip().split(': ', 1)
                    interface[key] = json.loads(value)
                if not 25 <= len(interface['short_description']) <= 64:
                    raise ValueError('UI description must be 25–64 characters')
                if '$' + name not in interface['default_prompt']:
                    raise ValueError('Default prompt must invoke this skill')
            for markdown in folder.rglob('*.md'):
                for target in re.findall(r'\]\(([^)]+)\)', markdown.read_text()):
                    if '://' not in target and not target.startswith('#'):
                        resolved = (markdown.parent / target.split('#')[0]).resolve()
                        if folder.resolve() not in resolved.parents or not resolved.is_file():
                            raise ValueError(f'Broken or nonportable reference: {target}')
        except (OSError, ValueError, KeyError, IndexError) as exc:
            errors.append(f'{name}: {exc}')
    return errors


if __name__ == '__main__':
    failures = validate()
    for failure in failures:
        print(failure, file=sys.stderr)
    if failures:
        sys.exit(1)
    print(f'Validated {len(EXPECTED)} skills: metadata, references, and packaging.')
