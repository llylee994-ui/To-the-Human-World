"""Content contract checks in Lua 5.4, plus an independent paper evaluator.

Run: python scripts/debug/check_story_content.py
Uses the same isolated lupa installation as run_b1.py. No engine/UI evidence.
"""
from pathlib import Path
import itertools
import math
import sys
import unittest
sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp' / 'b1-python'))
from lupa.lua54 import LuaRuntime, lua_type


def plain(value):
    if lua_type(value) != 'table':
        return value
    keys = list(value.keys())
    if keys and set(keys) == set(range(1, len(keys) + 1)):
        return [plain(value[i]) for i in range(1, len(keys) + 1)]
    return {k: plain(value[k]) for k in keys}


class ContentContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lua = LuaRuntime(unpack_returned_tuples=True)
        cls.lua.execute("package.path = ... .. '/scripts/?.lua;' .. package.path", ROOT.as_posix())
        cls.content = cls.lua.eval('require("data.content")')[0]
        ok, errors = cls.content.Load()
        assert ok, plain(errors)
        cls.words = {w['id']: w for w in plain(cls.content.words)}
        cls.ingredients = {i['id']: i for i in plain(cls.content.ingredients)}
        cls.profiles = {p['id']: p for p in plain(cls.content.attributeProfiles)}
        cls.rules = plain(cls.content.directRules)
        cls.fragments = plain(cls.content.fragments)
        cls.ratings = plain(cls.content.orderRatings)

    def brew(self, recipe):
        """Independent numeric reconstruction of the frozen eight-step design."""
        cfg = plain(self.content.synthesis)
        main = self.words[recipe['mainWordId']]
        effects = dict(main['effects'])
        mods = dict.fromkeys(['duration', 'speed', 'intensity', 'stability', 'sideEffect'], 0)
        def merge(tags):
            for tag, weight in tags.items():
                effects[tag] = effects.get(tag, 0) + weight * cfg['auxWeight'] + (cfg['sameTagBonus'] if tag in effects else 0)
        for aux in recipe['auxWordIds']:
            merge(self.words[aux]['effects'])
        for entry in recipe['ingredients']:
            ingredient = self.ingredients[entry['ingredientId']]
            for _ in range(entry['quantity']):
                merge(ingredient.get('addTags', {}))
                for key, value in ingredient['mods'].items():
                    mods[key] += value
        effects = {k: v * (1 + mods['intensity'] * cfg['intensityScale']) for k, v in effects.items()}
        effects = {k: v for k, v in effects.items() if v > 0}
        for side in cfg['sideEffectRules']:
            if mods['sideEffect'] >= side['minSideEffect']:
                for tag, value in side['addTags'].items():
                    effects[tag] = effects.get(tag, 0) + value
        profile = self.profiles[main['attributeProfileId']]
        delay = {p['speed']: p['delayHours'] for p in profile['speedToDelayHours']}[mods['speed']]
        return effects, profile['baseDurationHours'] + mods['duration'] * profile['durationHoursPerPoint'], delay, profile

    def complies(self, letter, brewed):
        effects, duration, delay, profile = brewed
        req = letter['requirement']
        if any(effects.get(tag, 0) < value for tag, value in req['tags'].items()): return False
        if any(effects.get(tag, 0) > 0 for tag in req['forbiddenEffects']): return False
        for c in req['conditions']:
            if c['kind'] == 'duration' and not c['minHours'] <= duration <= c['maxHours']: return False
            if c['kind'] == 'onset' and delay > c['maxDelayHours']: return False
            if c['kind'] == 'forbiddenEffect' and effects.get(c['effectId'], 0) > c['maxWeight']: return False
            if c['kind'] == 'workReady' and delay + duration + profile['recoveryAfterEndHours'] > c['workAfterDoseHours']: return False
            if c['kind'] == 'residualAt':
                points = next(r['points'] for r in profile['residualRules'] if r['effectId'] == c['effectId'])
                hours = math.floor(c['atAfterDoseHours'] - delay - duration)
                ratio = 1 if hours < 0 else next((p['ratio'] for p in points if p['hoursAfterEnd'] == hours), 0)
                if effects.get(c['effectId'], 0) * ratio > c['maxWeight']: return False
        return True

    def consequences(self, letter, effects):
        def matches(conditions):
            for c in conditions:
                self.assertEqual(c['source'], 'potion.effects')
                value, target = effects.get(c['path'], 0), c['value']
                if not {'eq': value == target, 'ne': value != target, 'gte': value >= target, 'lte': value <= target}[c['op']]: return False
            return True
        matched = [r for r in self.rules if r['ruleSetId'] == letter['directRuleSetId'] and matches(r['when']) and not (r.get('unless') and matches(r['unless']))]
        facts = {f['id'] for r in matched for f in r['facts']}
        important = {f['id'] for r in matched for f in r['facts'] if f['important']}
        def accepts(row):
            return set(row.get('requiresFacts', [])).issubset(facts) and not set(row.get('excludesFacts', [])).intersection(facts)
        fragments = [f for f in self.fragments if f['templateId'] == letter['followupTemplateId'] and accepts(f) and f['kind'] != 'generic']
        overridden = {i for f in fragments for i in f['overrides']}
        fragments = [f for f in fragments if f['id'] not in overridden]
        groups = {}
        for f in fragments:
            if f.get('exclusiveGroup'):
                groups.setdefault(f['exclusiveGroup'], []).append(f)
        for group in groups.values():
            winner = sorted(group, key=lambda f: (-f['priority'], f['id']))[0]
            fragments = [f for f in fragments if f not in group or f == winner]
        covered = {i for f in fragments for i in f['coversFacts']}
        self.assertTrue(important.issubset(covered), (letter['id'], effects, important - covered))
        ratings = [r for r in self.ratings if r['ratingSetId'] == letter['ratingSetId'] and accepts(r)]
        self.assertTrue(ratings, (letter['id'], effects, facts))
        rating = sorted(ratings, key=lambda r: (-r['stars'], -r['priority'], r['id']))[0]
        for group in plain(self.content.factExclusionGroups):
            self.assertLessEqual(len(set(group['factIds']) & facts), 1, (group['id'], facts))
        return facts, rating['stars'], {f['id'] for f in fragments}, rating['id']

    def test_original_first_order_golden_cases(self):
        letter = plain(self.content.GetLetter('letter_pa_01'))
        for case in plain(self.content.stage1.sampleCases):
            with self.subTest(case=case['id']):
                brewed = self.brew(case['recipe'])
                expected = case['expect']
                self.assertEqual(self.complies(letter, brewed), expected['canShip'])
                for tag, weight in expected['effects'].items():
                    self.assertAlmostEqual(brewed[0][tag], weight)
                self.assertEqual(brewed[1], expected['durationHours'])
                self.assertEqual(brewed[2], expected['onsetDelayHours'])
                if expected['canShip']:
                    facts, stars, fragments, rule_id = self.consequences(letter, brewed[0])
                    self.assertEqual(facts, set(expected['facts']))
                    self.assertEqual(stars, expected['rating']['stars'])
                    self.assertEqual(rule_id, expected['rating']['ruleId'])
                    self.assertEqual(fragments, set(expected['followupFragments']))

    def test_reference_recipes_and_available_sources(self):
        import re
        sources = {w for letter in plain(self.content.letters) if letter['kind'] == 'order' for w in re.findall(r'\{\{(.*?)\}\}', letter['body'])}
        self.assertEqual(len(sources), 14)
        self.assertTrue(self.content.recipes)
        for case in plain(self.content.recipes):
            with self.subTest(recipe=case['id']):
                letter = plain(self.content.GetLetter(case['letterId']))
                recipe = case['recipe']
                self.assertLessEqual(len(recipe['auxWordIds']), 2)
                self.assertEqual(len(set([recipe['mainWordId']] + list(recipe['auxWordIds']))), 1 + len(recipe['auxWordIds']))
                self.assertLessEqual(sum(x['quantity'] for x in recipe['ingredients']), 2)
                used = [self.words[i]['displayText'] for i in [recipe['mainWordId']] + list(recipe['auxWordIds'])]
                self.assertEqual(case['requiresFutureSources'], any(w not in sources for w in used))
                brewed = self.brew(recipe)
                self.assertTrue(self.complies(letter, brewed))
                facts, stars, _, _ = self.consequences(letter, brewed[0])
                self.assertEqual(stars, case['expect']['stars'])
                self.assertTrue(set(case['expect']['facts']).issubset(facts))
                self.assertEqual(brewed[1:3], (case['expect']['durationHours'], case['expect']['onsetDelayHours']))

    def test_all_orders_cover_all_legal_old_cauldron_combinations(self):
        count = 0
        for lid in ['letter_pa_01', 'letter_n01', 'letter_n02']:
            letter = plain(self.content.GetLetter(lid))
            for main in self.words:
                auxiliaries = [w for w in self.words if w != main]
                for size in range(3):
                    for aux in itertools.combinations(auxiliaries, size):
                        for quantity in (0, 1, 2):
                            for ingredients in itertools.combinations_with_replacement(self.ingredients, quantity):
                                recipe = dict(mainWordId=main, auxWordIds=list(aux), ingredients=[dict(ingredientId=i, quantity=1) for i in ingredients])
                                brewed = self.brew(recipe)
                                if self.complies(letter, brewed):
                                    self.consequences(letter, brewed[0])
                                    count += 1
        self.assertGreater(count, 1000)
        print(f'Paper combinations: {count} compliant results covered across 30 main words / 3 orders (NOT a Potion/Narrative runtime test)')

    def test_exact_threshold_partition_has_no_gap(self):
        for lid, axis in [('letter_n01', 'steady'), ('letter_n02', 'happy')]:
            letter = plain(self.content.GetLetter(lid))
            for calm in [math.nextafter(2.2, 0), 2.2, math.nextafter(2.2, 3)]:
                for brave in [math.nextafter(.6, 0), .6, math.nextafter(.6, 1)]:
                    for forget, recall in itertools.product([0, .6], repeat=2):
                        facts, _, _, _ = self.consequences(letter, {axis: 1, 'calm': calm, 'brave': brave, 'forget': forget, 'recall': recall})
                        if lid == 'letter_n01' and forget >= .6 and recall >= .6:
                            self.assertIn('n01_memory_contested', facts)
                        elif calm >= 2.2:
                            self.assertIn('n01_action_dulled' if lid == 'letter_n01' else 'n02_response_dulled', facts)
                        elif brave >= .6:
                            key = ('hurt_customer_noticed' if forget >= .6 else 'spoke_too_sharply') if lid == 'letter_n01' else ('forced_future_hurt' if forget >= .6 else 'overstepped_apologized')
                            self.assertIn(('n01_' if lid == 'letter_n01' else 'n02_') + key, facts)
                        else:
                            key = ('missed_promise_unaware' if forget >= .6 else 'kept_promise') if lid == 'letter_n01' else ('old_arrangement_repeated' if forget >= .6 else 'promise_kept')
                            self.assertIn(('n01_' if lid == 'letter_n01' else 'n02_') + key, facts)

    def test_new_words_have_distinct_meaning_and_explicit_time(self):
        words = plain(self.content.words)
        self.assertEqual(len(words), 30)
        by_text = {w['displayText']: w for w in words}
        for text, tag in [('生气', 'anger'), ('难过', 'sadness'), ('茫然', 'confusion'),
                          ('理性', 'reason'), ('放松', 'relax'), ('手稳', 'steady')]:
            self.assertEqual(by_text[text]['effects'], {tag: 1})
        profiles = {p['id'] for p in plain(self.content.attributeProfiles)}
        for word in words:
            self.assertIn(word.get('attributeProfileId'), profiles, word['displayText'])

    def test_named_sender_and_formal_orders(self):
        self.assertEqual(self.content.GetNpc('npc_passerby_a').name, '埃利亚斯·沃德')
        for letter_id in ['letter_n01', 'letter_n02']:
            letter = self.content.GetLetter(letter_id)
            self.assertIsNotNone(letter)
            self.assertEqual(letter.reward.currency, 80)
            self.assertEqual(letter.requirement.tags['sleep'], None)

    def test_real_content_validators(self):
        for method in [self.content.Load, self.content.ValidateStage1]:
            ok, errors = method()
            self.assertTrue(ok, plain(errors))


if __name__ == '__main__':
    unittest.main()
