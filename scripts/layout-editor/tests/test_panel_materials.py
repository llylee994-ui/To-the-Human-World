"""Dedicated panel project: original images, durable edits, no unrelated replacements."""
import copy
import hashlib
import io
import json
import unittest
import shutil
from pathlib import Path
import zipfile

from test_store import LocalTemporaryDirectory
from store import Store
from panel_materials import ASSETS, PROJECT_ROOT, ensure_project
from server import lock_directory


class PanelMaterialsTests(unittest.TestCase):
    def setUp(self):
        self.temp = LocalTemporaryDirectory()
        self.store = Store(self.temp.name)

    def tearDown(self):
        self.store.db.close()
        self.temp.cleanup()

    def test_running_editor_can_be_copied_by_maker_without_releasing_its_lock(self):
        directory = Path(self.temp.name)
        lock = lock_directory(directory)
        try:
            (directory / 'preview-copy-sample.txt').write_text('saved layout', encoding='utf-8')
            with LocalTemporaryDirectory() as target:
                shutil.copytree(directory, Path(target) / 'managed-source')
                self.assertEqual((Path(target) / 'managed-source' / 'preview-copy-sample.txt').read_text(), 'saved layout')
            with self.assertRaises(SystemExit):
                lock_directory(directory)
        finally:
            lock.close()

    def test_first_open_contains_two_pages_and_original_asset_bytes(self):
        self.assertTrue(ensure_project(self.store))
        doc = self.store.state()
        self.assertEqual([p['name'] for p in doc['pages']], ['托盘界面', '记录书界面'])
        self.assertEqual(len(doc['assets']), len(ASSETS))
        for key, relative in ASSETS.items():
            info, raw = self.store.asset('panel-asset-' + key)
            self.assertEqual(raw, (PROJECT_ROOT / relative).read_bytes())
            self.assertEqual(info['sha256'], hashlib.sha256(raw).hexdigest())
        book = doc['pages'][1]
        self.assertIn('journal-flowers', [item['id'] for item in book['layers']])
        self.assertIn('journal-grass', [item['id'] for item in book['layers']])
        self.assertGreaterEqual(sum(item['assetId'] == 'panel-asset-tab' for item in book['layers']), 6)

    def test_reopening_never_resets_user_placement_or_imported_work(self):
        ensure_project(self.store)
        doc = self.store.state()
        page = copy.deepcopy(doc['pages'][1])
        request = {'clientId':'test-designer', 'epoch':doc['epoch'], 'pageId':page['id']}
        request['token'] = self.store.lease(request)['token']
        page['layers'][-1]['x'] = 123
        self.store.save_page({**request, 'revision':page['revision'], 'page':page})
        before = copy.deepcopy(self.store.state())
        self.assertFalse(ensure_project(self.store))
        self.assertEqual(self.store.state(), before)
        self.store.db.close()
        self.store = Store(self.temp.name)
        self.assertFalse(ensure_project(self.store))
        self.assertEqual(self.store.state()['pages'][1]['layers'][-1]['x'], 123)

    def test_export_is_a_complete_portable_project(self):
        ensure_project(self.store)
        with zipfile.ZipFile(io.BytesIO(self.store.export())) as bundle:
            doc = json.loads(bundle.read('project.json'))
            for asset in doc['assets']:
                self.assertEqual(hashlib.sha256(bundle.read(asset['file'])).hexdigest(), asset['sha256'])
            self.assertEqual(doc['referenceProfile']['kind'], 'tray-journal-v1')
            self.assertEqual(doc['coordinateSystem']['position'], 'center')

    def test_existing_unrelated_project_is_preserved(self):
        doc = self.store.state()
        self.store.create_page({'epoch':doc['epoch'], 'name':'用户原有构图'})
        before = copy.deepcopy(self.store.state())
        self.assertFalse(ensure_project(self.store))
        self.assertEqual(self.store.state(), before)


if __name__ == '__main__':
    unittest.main()
