import copy
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
spec = importlib.util.find_spec('store')
if spec:
    from store import Store, Problem


def fixture():
    return {'format': 'human-world-story', 'version': 1, 'title': '测试故事',
            'nodes': [{'id': 'root', 'parentId': None, 'kind': 'root', 'title': '故事'},
                      {'id': 'o', 'parentId': 'root', 'kind': 'ordinary', 'title': '普通', 'day': 1},
                      {'id': 'm', 'parentId': 'root', 'kind': 'main', 'title': '主线', 'day': 2}],
            'edges': [{'id': 'e', 'from': 'o', 'to': 'm', 'label': '次日'}]}


class StoreTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(spec, '持久保存服务尚未实现')
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name) / 'story.json'
        self.path.write_text(json.dumps(fixture(), ensure_ascii=False), encoding='utf-8')
        self.store = Store(self.path)

    def test_edit_survives_reload_and_previous_version_is_backed_up(self):
        state = self.store.read()
        state['project']['nodes'][2]['summary'] = '写过的梗概'
        result = self.store.save(state['project'], state['revision'])
        self.assertNotEqual(result['revision'], state['revision'])
        self.assertEqual(Store(self.path).read()['project']['nodes'][2]['summary'], '写过的梗概')
        backup = list((self.path.parent / '.story-backups').glob('*.json'))
        self.assertEqual(len(backup), 1)
        self.assertNotIn('summary', json.loads(backup[0].read_text(encoding='utf-8'))['nodes'][2])

    def test_stale_editor_does_not_overwrite_agent_change(self):
        first = self.store.read()
        other = Store(self.path).read()
        first['project']['title'] = '代理已修改'
        self.store.save(first['project'], first['revision'])
        other['project']['title'] = '过期窗口'
        with self.assertRaises(Problem) as error:
            self.store.save(other['project'], other['revision'])
        self.assertEqual(error.exception.status, 409)
        self.assertEqual(self.store.read()['project']['title'], '代理已修改')

    def test_invalid_parent_cycle_and_dangling_edges_are_rejected(self):
        for mutate in [lambda p: p['nodes'][0].update(parentId='m'),
                       lambda p: p['nodes'][2].update(parentId='missing'),
                       lambda p: p['edges'][0].update(to='missing')]:
            state = self.store.read()
            project = copy.deepcopy(state['project'])
            mutate(project)
            with self.assertRaises(Problem):
                self.store.save(project, state['revision'])
            self.assertEqual(self.store.read()['revision'], state['revision'])

    def test_alternating_days_enforced_on_bottle_nodes(self):
        for index, day in [(1, 2), (2, 3), (2, True)]:
            state = self.store.read()
            state['project']['nodes'][index]['day'] = day
            with self.assertRaises(Problem):
                self.store.save(state['project'], state['revision'])

    def test_duplicate_ids_and_excessive_text_do_not_replace_file(self):
        for mutate in [lambda p: p['nodes'][2].update(id='o'),
                       lambda p: p['nodes'][2].update(summary='x' * 60001)]:
            state = self.store.read()
            mutate(state['project'])
            with self.assertRaises(Problem):
                self.store.save(state['project'], state['revision'])

    def test_external_file_change_is_detected_without_restart(self):
        old = self.store.read()
        project = fixture()
        project['title'] = '来自文件的修改'
        self.path.write_text(json.dumps(project), encoding='utf-8')
        self.assertEqual(self.store.read()['project']['title'], '来自文件的修改')
        with self.assertRaises(Problem):
            self.store.save(old['project'], old['revision'])

    def test_route_templates_rounds_and_forward_edges_validated(self):
        state = self.store.read()
        project = state['project']
        project['layout'] = 'route'
        project['templates'] = [{'id': 'intro', 'title': '认识人物', 'summary': '冲突→念头→结果'}]
        for i, node in enumerate(project['nodes']):
            node.update(round=i, step=0, templateId='intro', context='实际前情', options='两封念头')
        self.store.save(project, state['revision'])
        for mutate in [lambda p: p['nodes'][2].update(round=-1),
                       lambda p: p['nodes'][2].update(templateId='missing'),
                       lambda p: p['edges'][0].update({'from': 'm', 'to': 'o'})]:
            state = self.store.read()
            mutate(state['project'])
            with self.assertRaises(Problem):
                self.store.save(state['project'], state['revision'])


if __name__ == '__main__':
    unittest.main()
