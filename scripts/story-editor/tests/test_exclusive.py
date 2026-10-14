"""Current outline contracts; not a proof of natural-language route conditions."""
import json
import os
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[3]

class ExclusiveTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.p=json.loads(Path(os.environ.get('STORY_GRAPH', ROOT/'docs/文案/主线/主线故事图_v01.json')).read_text(encoding='utf-8'))
        cls.by={n['id']:n for n in cls.p['nodes']}

    def reachable(self,start):
        reached={start};queue=[start]
        while queue:
            at=queue.pop()
            for e in self.p['edges']:
                if e['from']==at and e['to'] not in reached:
                    reached.add(e['to']);queue.append(e['to'])
        return reached

    def test_every_choice_declares_the_unhelped_consequences(self):
        for n in self.p['nodes']:
            if n['kind']!='choice':continue
            self.assertIn('A 未获帮助：',n['unselected'],n['id'])
            self.assertIn('B 未获帮助：',n['unselected'],n['id'])
            self.assertNotEqual(n['wishAId'],n['wishBId'])
            exits=[e for e in self.p['edges'] if e['from']==n['id']]
            self.assertEqual({e['wish'] for e in exits},{'A','B'},n['id'])
            for e in exits:
                other='B' if e['wish']=='A' else 'A'
                self.assertTrue(self.by[e['to']]['unselected'].startswith('丢弃'+other+'：'))

    def test_failed_choices_never_reopen_the_successful_spine(self):
        spine={f'C{i:02}' for i in range(1,7)}
        self.assertEqual(len([n for n in self.p['nodes'] if n['kind']=='choice']),10)
        for start in ('F01','F02','F03','F04'):
            self.assertFalse(self.reachable(start)&spine,start)
            self.assertNotIn('E_TRUE',self.reachable(start),start)

    def test_star_independent_exits_and_only_one_successful_sequence(self):
        from collections import Counter
        cases={'E_TRUE','E_WRONG','E_ESCAPE','E_UNRESOLVED'}
        paths=[]
        def walk(at,choices):
            if at in cases:
                paths.append((choices,at));return
            for wish in ('A','B'):
                outcomes=[self.by[e['to']] for e in self.p['edges'] if e['from']==at and e.get('wish')==wish]
                self.assertEqual({n.get('stars') for n in outcomes},{1,2,3},(at,wish))
                targets={e['to'] for n in outcomes for e in self.p['edges'] if e['from']==n['id']}
                self.assertEqual(len(targets),1,(at,wish))
                walk(targets.pop(),choices+wish)
        self.assertIn('C01',self.by)
        walk('C01','')
        self.assertEqual(Counter(end for _,end in paths),{'E_TRUE':1,'E_WRONG':5,'E_ESCAPE':4,'E_UNRESOLVED':8})
        self.assertEqual([s for s,end in paths if end=='E_TRUE'],['ABAABA'])
        self.assertEqual(sum(n['kind']=='result' for n in self.p['nodes']),75)

    def test_fixed_case_endings_continue_to_one_ordinary_queue(self):
        doc=(ROOT/'docs/文案/主线/主线唯一抓凶路线与提前结局重构_v06.md').read_text(encoding='utf-8')
        for code in ('E_TRUE','E_WRONG','E_ESCAPE','E_UNRESOLVED'):
            self.assertIn(code,self.by)
            node=self.by[code]
            self.assertIn(node['summary'],doc)
            self.assertEqual([e['to'] for e in self.p['edges'] if e['from']==code],['ordinary_tail'])
        self.assertEqual({e['to'] for e in self.p['edges'] if e['from']=='ordinary_tail'}, {'apprentice','edmund','nameless','unreached'})
        self.assertTrue(all('全部必需普通订单完成并确认' in e['condition'] for e in self.p['edges'] if e['from']=='ordinary_tail'))

    def test_every_successful_spine_star_combination_reaches_true_ending(self):
        from itertools import product
        count=0
        for stars in product((1,2,3),repeat=6):
            at='C01'
            for wish,star in zip('ABAABA',stars):
                results=[self.by[e['to']] for e in self.p['edges'] if e['from']==at and e.get('wish')==wish]
                chosen=next(n for n in results if n['stars']==star)
                at=next(e['to'] for e in self.p['edges'] if e['from']==chosen['id'])
            self.assertEqual(at,'E_TRUE',stars);count+=1
        self.assertEqual(count,729)

    def test_early_orders_keep_one_next_scene(self):
        for i in range(1,6):
            results=[self.by[e['to']] for e in self.p['edges'] if e['from']==f'm{i:02}']
            self.assertEqual({n['stars'] for n in results},{1,2,3})
            targets={e['to'] for n in results for e in self.p['edges'] if e['from']==n['id']}
            self.assertEqual(targets,{f'm{i+1:02}'})

    def test_all_nodes_still_structurally_reachable_and_titles_follow_policy(self):
        self.assertEqual(self.reachable('root'),set(self.by))
        for n in self.p['nodes']:
            self.assertNotRegex(n['title'],r'别把|让|先|把|说清',n['id'])
        for e in self.p['edges']:
            a,b=self.by[e['from']],self.by[e['to']]
            self.assertLess((a['round'],a['step']),(b['round'],b['step']))
