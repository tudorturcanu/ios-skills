import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

PATH = Path(__file__).resolve().parents[1]/'ios-localization-audit/scripts/check_format_arguments.py'
spec = importlib.util.spec_from_file_location('format_arguments', PATH)
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)


def unit(value): return {'stringUnit': {'state': 'translated', 'value': value}}
def catalog(source, target):
    return {'sourceLanguage':'en', 'strings':{'message':{'localizations':{'en':unit(source),'de':unit(target)}}}}


class FormatArgumentsTests(unittest.TestCase):
    def check(self, source, target): return checker.inspect(catalog(source,target), ['message'], ['de'])

    def test_reordering(self):
        self.assertEqual(self.check('%@ has %lld', '%2$lld für %1$@')['findings'], [])

    def test_type_change(self):
        finding = self.check('%@ has %lld', '%1$lld %2$@')['findings']
        self.assertEqual([f['kind'] for f in finding], ['argument-type-change']*2)

    def test_repeated_positional_argument(self):
        self.assertEqual(self.check('%@', '%1$@ / %1$@')['findings'], [])

    def test_literal_percent(self):
        self.assertEqual(self.check('%lld%%', '%1$lld%%')['findings'], [])

    def test_precision_and_width_do_not_change_type(self):
        self.assertEqual(self.check('%08.2f', '%1$+.4e')['findings'], [])

    def test_integer_presentation_does_not_change_type(self):
        self.assertEqual(self.check('%u', '%1$X')['findings'], [])

    def test_documented_long_long_alias(self):
        self.assertEqual(self.check('%qd', '%1$lld')['findings'], [])

    def test_signedness_is_visible(self):
        self.assertEqual(self.check('%d', '%u')['findings'][0]['kind'], 'argument-type-change')

    def test_omission_is_review_not_crash_claim(self):
        self.assertEqual(self.check('%@', 'Willkommen')['findings'][0]['kind'], 'argument-omitted-review')

    def test_addition_is_review(self):
        self.assertEqual(self.check('Willkommen', '%@')['findings'][0]['kind'], 'argument-added-review')

    def test_unsupported_grammar_is_not_declared_matching(self):
        for value in ['%*.*f', '%2$*1$d', '%#@count@', '%c', '%s', '%n', '% d', '%', '%0$@', '%1$@ %d', '%1$@ %1$lld']:
            with self.subTest(value=value):
                self.assertFalse(checker.signature(value)['supported'])
                report = self.check(value,value)
                self.assertEqual(report['compared'], [])
                self.assertEqual(report['findings'][0]['kind'], 'manual-review')

    def test_large_index_does_not_crash(self):
        self.assertFalse(checker.signature('%'+'9'*5000+'$@')['supported'])

    def test_source_value_overrides_semantic_key(self):
        self.assertEqual(self.check('%@', '%d')['compared'][0]['source_signature'], {'1':'object'})

    def test_key_is_fallback_source(self):
        data = {'sourceLanguage':'en','strings':{'Hello %@':{'localizations':{'de':unit('Hallo %1$@')}}}}
        self.assertEqual(checker.inspect(data,['Hello %@'],['de'])['findings'], [])

    def test_plural_target_is_manual(self):
        data = catalog('%lld', '%lld')
        data['strings']['message']['localizations']['de']={'variations':{'plural':{'one':unit('One'),'other':unit('%lld')}}}
        self.assertEqual(checker.inspect(data,['message'],['de'])['findings'][0]['kind'], 'manual-review')

    def test_nontranslatable_is_skipped(self):
        data=catalog('%@','%d');data['strings']['message']['shouldTranslate']=False
        self.assertEqual(checker.inspect(data,['message'],['de'])['findings'], [{'key':'message','kind':'skipped-nontranslatable'}])

    def test_unknown_key_is_error(self):
        with self.assertRaises(ValueError): checker.inspect(catalog('%@','%@'),['missing'],['de'])

    def test_missing_locale_is_review(self):
        self.assertEqual(checker.inspect(catalog('%@','%@'),['message'],['fr'])['findings'][0]['kind'], 'missing-locale-review')

    def test_cli_read_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'Localizable.xcstrings';original=json.dumps(catalog('%@','%lld'));path.write_text(original)
            result=subprocess.run([sys.executable,str(PATH),str(path),'--key','message','--locale','de'],capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertEqual(json.loads(result.stdout)['findings'][0]['kind'],'argument-type-change')
            self.assertEqual(path.read_text(),original)
            self.assertEqual(len(list(Path(tmp).iterdir())),1)


if __name__=='__main__':unittest.main()
