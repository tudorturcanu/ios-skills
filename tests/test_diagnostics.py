import importlib.util
import json
import plistlib
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load(skill, script):
    path = ROOT / skill / 'scripts' / (script + '.py')
    spec = importlib.util.spec_from_file_location(script, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


catalog = load('ios-localization-audit', 'catalog_inventory')
aasa = load('ios-deeplink-doctor', 'aasa_inspect')
ips = load('ios-crash-triage', 'ips_inventory')


def unit(state='translated', value='Bonjour'):
    return {'stringUnit': {'state': state, 'value': value}}


class CatalogTests(unittest.TestCase):
    def inspect(self, entry, locales=None):
        return catalog.inventory({'sourceLanguage': 'en', 'strings': {'hello': entry}}, locales or ['fr'])

    def test_missing_locale(self):
        self.assertEqual(self.inspect({})['findings'][0]['kind'], 'missing-locale')

    def test_source_key_is_fallback(self):
        self.assertEqual(self.inspect({}, ['en'])['findings'], [])

    def test_intentional_nontranslation(self):
        result = self.inspect({'shouldTranslate': False})
        self.assertEqual(result['findings'], [])
        self.assertEqual(result['skipped_nontranslatable'], ['hello'])

    def test_empty_key_missing_locale_uses_empty_fallback(self):
        result = catalog.inventory({'sourceLanguage':'en','strings':{'':{}}}, ['de'])
        self.assertEqual(result['findings'], [])
        self.assertEqual(result['empty_source_fallbacks'], [{'key':'','locale':'de'}])

    def test_empty_key_with_meaningful_source_is_not_skipped(self):
        result = catalog.inventory({'sourceLanguage':'en','strings':{'':{'localizations':{'en':unit(value='Title')}}}}, ['de'])
        self.assertEqual(result['findings'][0]['kind'], 'missing-locale')

    def test_semantic_key_with_explicit_empty_source_uses_empty_fallback(self):
        result = self.inspect({'localizations':{'en':unit(value='')}})
        self.assertEqual(result['findings'], [])
        self.assertEqual(result['empty_source_fallbacks'], [{'key':'hello','locale':'fr'}])

    def test_source_variations_are_not_assumed_empty(self):
        entry = {'localizations':{'en':{'variations':{'plural':{'one':unit(value=''),'other':unit(value='%lld')}}}}}
        result = catalog.inventory({'sourceLanguage':'en','strings':{'':entry}}, ['de'])
        self.assertEqual(result['findings'][0]['kind'], 'missing-locale')

    def test_empty_target_needing_review_is_still_reported(self):
        result = catalog.inventory({'sourceLanguage':'en','strings':{'':{'localizations':{'de':unit('needs_review','')}}}}, ['de'])
        self.assertEqual(result['findings'][0]['kind'], 'translation-state')

    def test_nested_plural_draft(self):
        result = self.inspect({'localizations': {'fr': {'variations': {'plural': {
            'one': unit(), 'other': unit('needs_review')}}}}})
        self.assertEqual(len(result['findings']), 1)
        self.assertEqual(result['findings'][0]['path'], '/variations/plural/other/stringUnit')

    def test_substitution_and_device_variations(self):
        node = {'substitutions': {'count': {'argNum': 1, 'formatSpecifier': 'lld', 'variations': {
            'plural': {'other': {'variations': {'device': {'iphone': unit('new')}}}}}}}}
        result = self.inspect({'localizations': {'fr': node}})
        self.assertEqual(len(result['findings']), 1)
        self.assertEqual(result['findings'][0]['state'], 'new')

    def test_reordered_placeholders_are_not_flagged(self):
        self.assertEqual(self.inspect({'localizations': {'fr': unit(value='%2$@ %1$lld')}})['findings'], [])

    def test_empty_translation_is_not_automatically_an_error(self):
        self.assertEqual(self.inspect({'localizations': {'fr': unit(value='')}})['findings'], [])

    def test_stale_extraction_is_separate(self):
        result = self.inspect({'extractionState': 'stale', 'localizations': {'fr': unit()}})
        self.assertEqual([f['kind'] for f in result['findings']], ['stale-extraction'])

    def test_unknown_state_is_visible(self):
        self.assertEqual(self.inspect({'localizations': {'fr': unit('future-state')}})['findings'][0]['state'], 'future-state')

    def test_invalid_node_fails_explicitly(self):
        with self.assertRaises(ValueError):
            self.inspect({'localizations': {'fr': {'variations': []}}})


class AASATests(unittest.TestCase):
    def inspect(self, details, domains=None, host='shop.example.com'):
        return aasa.inspect({'applinks': {'details': details}}, {
            'application-identifier': 'OLDPREFIX.com.example.app',
            'com.apple.developer.team-identifier': 'NEWTEAM',
            'com.apple.developer.associated-domains': domains or ['applinks:shop.example.com']}, host)

    def test_legacy_identifier_uses_app_prefix_not_team(self):
        result = self.inspect([{'appID': 'OLDPREFIX.com.example.app', 'paths': ['*']}])
        self.assertEqual(result['findings'], [])

    def test_modern_array_preserves_exclusion_rules(self):
        components = [{'#': 'no', 'exclude': True}, {'/': '/products/*'}]
        result = self.inspect([{'appIDs': ['OLDPREFIX.com.example.app'], 'components': components}])
        self.assertEqual(result['matching_aasa_details'][0]['components'], components)

    def test_wrong_identifier(self):
        self.assertEqual(len(self.inspect([{'appID': 'NEWTEAM.com.example.app'}])['findings']), 1)

    def test_wildcard_does_not_cover_apex(self):
        result = self.inspect([], ['applinks:*.example.com'], 'example.com')
        self.assertEqual(result['matching_domain_entries'], [])

    def test_wildcard_covers_subdomain(self):
        qualified = 'applinks:*.example.com?mode=developer'
        details = [{'appID': 'OLDPREFIX.com.example.app', 'paths': ['*']}]
        result = self.inspect(details, [qualified])
        self.assertEqual(result['matching_domain_entries'], [qualified])
        self.assertEqual(result['matching_entries_with_query_qualifiers'], [qualified])
        self.assertEqual(len(result['findings']), 1)

    def test_public_domain_match_alongside_alternate_mode(self):
        public = 'applinks:shop.example.com'
        qualified = public + '?mode=developer'
        details = [{'appID': 'OLDPREFIX.com.example.app', 'paths': ['*']}]
        result = self.inspect(details, [qualified, public])
        self.assertEqual(result['matching_entries_with_query_qualifiers'], [qualified])
        self.assertEqual(result['findings'], [])

    def test_suffix_spoof_does_not_match(self):
        self.assertEqual(self.inspect([], ['applinks:*.example.com'], 'evilexample.com')['matching_domain_entries'], [])

    def test_webcredentials_is_not_applinks(self):
        self.assertEqual(self.inspect([], ['webcredentials:shop.example.com'])['matching_domain_entries'], [])

    def test_unsupported_details_rejected(self):
        with self.assertRaises(ValueError):
            self.inspect({'some-app': {}})

    def test_url_is_not_hostname(self):
        with self.assertRaises(ValueError):
            self.inspect([], host='https://example.com/path')


class IPSTests(unittest.TestCase):
    def report(self):
        return {'procName': 'Demo', 'faultingThread': 0, 'threads': [{'frames': [{'imageIndex': 0, 'imageOffset': 12}]}],
                'usedImages': [{'name': 'Demo', 'uuid': 'UUID-A', 'base': 4096, 'arch': 'arm64'}]}

    def test_two_json_documents(self):
        result = ips.inventory(json.dumps({'bug_type': '309'}) + '\n' + json.dumps(self.report()))
        self.assertEqual(result['document_count'], 2)
        self.assertEqual(result['bug_type'], '309')
        self.assertEqual(result['faulting_frames'][0]['uuid'], 'UUID-A')
        self.assertEqual(result['faulting_frames'][0]['instruction_address_hex'], '0x100c')
        self.assertEqual(result['thread_selection'], 'faultingThread')

    def test_does_not_fabricate_symbols(self):
        result = ips.inventory(json.dumps(self.report()))
        self.assertNotIn('symbol', result['faulting_frames'][0])

    def test_triggered_thread_fallback(self):
        report = self.report()
        report.pop('faultingThread')
        report['threads'][0]['triggered'] = True
        report['threads'].insert(0, {})
        result = ips.inventory(json.dumps(report))
        self.assertEqual(len(result['faulting_frames']), 1)
        self.assertIsNone(result['faulting_thread_index'])
        self.assertEqual(result['selected_thread_index'], 1)
        self.assertEqual(result['thread_selection'], 'triggered')

    def test_multiple_triggered_threads_are_ambiguous(self):
        report = self.report()
        report['faultingThread'] = -1
        report['threads'][0]['triggered'] = True
        report['threads'].append({'triggered': True})
        result = ips.inventory(json.dumps(report))
        self.assertIsNone(result['selected_thread_index'])
        self.assertEqual(result['thread_selection'], 'ambiguous_triggered')
        self.assertEqual(result['faulting_frames'], [])

    def test_invalid_offset_does_not_produce_address(self):
        report = self.report()
        for offset in (-1, True, '12', 1.5):
            with self.subTest(offset=offset):
                report['threads'][0]['frames'][0]['imageOffset'] = offset
                result = ips.inventory(json.dumps(report))
                self.assertNotIn('instruction_address_hex', result['faulting_frames'][0])

    def test_negative_image_index_does_not_select_last_image(self):
        report = self.report()
        report['threads'][0]['frames'][0]['imageIndex'] = -1
        result = ips.inventory(json.dumps(report))
        self.assertNotIn('uuid', result['faulting_frames'][0])
        self.assertNotIn('instruction_address_hex', result['faulting_frames'][0])

    def test_noncrash_report_is_not_diagnosed(self):
        result = ips.inventory(json.dumps({'bug_type': '298', 'processes': []}))
        self.assertEqual(result['faulting_frames'], [])
        self.assertTrue(result['limitations'])

    def test_invalid_trailing_input(self):
        with self.assertRaises(ValueError):
            ips.inventory(json.dumps(self.report()) + '\nnot json')

    def test_empty_input(self):
        with self.assertRaises(ValueError):
            ips.inventory('')

    def test_malformed_frames(self):
        report = self.report()
        report['threads'][0]['frames'] = [1]
        with self.assertRaises(ValueError):
            ips.inventory(json.dumps(report))


class CLITests(unittest.TestCase):
    def test_all_clis_read_only_and_json(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            fixtures = {
                'catalog.json': json.dumps({'sourceLanguage': 'en', 'strings': {'Save': {}}}).encode(),
                'aasa.json': json.dumps({'applinks': {'details': []}}).encode(),
                'signed.plist': plistlib.dumps({'application-identifier': 'PREFIX.app'}),
                'report.ips': json.dumps({'bug_type': '298'}).encode(),
            }
            for name, content in fixtures.items():
                (root / name).write_bytes(content)
            cases = [(catalog, ['catalog.json', '--locale', 'de']),
                     (aasa, ['aasa.json', '--entitlements', 'signed.plist', '--host', 'example.com']),
                     (ips, ['report.ips'])]
            for module, args in cases:
                result = subprocess.run([sys.executable, module.__file__] + args, cwd=root, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('limitations', json.loads(result.stdout))
            self.assertEqual({p.name: p.read_bytes() for p in root.iterdir()}, fixtures)

    def test_deep_json_has_structured_error(self):
        cases = [
            (catalog.__file__, ['--locale', 'de']),
            (aasa.__file__, ['--entitlements', 'unused.plist', '--host', 'example.com']),
            (ips.__file__, []),
            (str(ROOT/'ios-localization-audit/scripts/check_format_arguments.py'), ['--key', 'message', '--locale', 'de']),
            (str(ROOT/'ios-launch-profiler/scripts/compare_launch_samples.py'), ['--baseline', 'before', '--candidate', 'after']),
        ]
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp)/'deep.json'
            source.write_text('[' * 2000 + '0' + ']' * 2000)
            for script, args in cases:
                with self.subTest(script=script):
                    result = subprocess.run([sys.executable, script, str(source)] + args, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 2)
                    self.assertIn('error', json.loads(result.stderr))

    def test_invalid_input_exit_two(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / 'bad.json'
            source.write_text('not json')
            for module, args in [(catalog, ['--locale', 'de']), (ips, []),
                                 (aasa, ['--entitlements', str(source), '--host', 'example.com'])]:
                result = subprocess.run([sys.executable, module.__file__, str(source)] + args, capture_output=True, text=True)
                self.assertEqual(result.returncode, 2)
                self.assertIn('error', json.loads(result.stderr))


if __name__ == '__main__':
    unittest.main()
