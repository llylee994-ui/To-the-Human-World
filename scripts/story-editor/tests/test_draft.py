"""Authoring graph integrity, not narrative-condition execution or game balance."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from draft_routes import build


class DraftTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.project = build()
        cls.by = {n['id']: n for n in cls.project['nodes']}

    def test_choice_scene_has_two_named_bottles_and_each_result_has_exit(self):
        outgoing = {}
        for e in self.project['edges']:
            outgoing.setdefault(e['from'], []).append(e)
        for n in self.project['nodes']:
            if n['kind'] == 'choice':
                self.assertIn('A · ', n['options'], n['id'])
                self.assertIn('B · ', n['options'], n['id'])
                self.assertGreaterEqual(len(outgoing[n['id']]), 6)
            if n['kind'] == 'result':
                self.assertTrue(n['summary'] and n['effects'], n['id'])
                self.assertTrue(outgoing.get(n['id']), n['id'])

    def test_warehouse_results_reach_different_next_scenes(self):
        dest = {e['from']: e['to'] for e in self.project['edges'] if e['from'].startswith('p01_r')}
        self.assertEqual(dest['p01_r1'], 'witness_safe')
        self.assertEqual(dest['p01_r2'], 'witness_hidden')
        self.assertEqual(dest['p01_r3'], 'witness_blurred')
        self.assertEqual(dest['p01_r4'], 'witness_silenced')

    def test_invitation_does_not_skip_actual_meeting(self):
        for e in self.project['edges']:
            if e['from'] in ('land_wait_r1', 'land_wait_r4'):
                self.assertEqual(e['to'], 'land_pending')

    def test_case_axis_stays_separate_from_identity(self):
        for case in ('captured', 'escaped', 'wrong', 'unresolved'):
            following = [e['to'] for e in self.project['edges'] if e['from'] == case]
            self.assertTrue(following)
            self.assertTrue(all(self.by[n]['round'] == 16 for n in following))
        identities = {e['to'] for e in self.project['edges'] if e['from'] == 'closing'}
        self.assertEqual(identities, {'apprentice', 'edmund', 'nameless', 'unreached'})
        self.assertTrue(any(e['to'] == 'traveler' and e['condition'] for e in self.project['edges']))
