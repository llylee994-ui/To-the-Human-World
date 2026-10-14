"""Focused storage and HTTP tests; all data stays in temporary test directories."""
import copy
import io
import json
import struct
import subprocess
import sys
import tempfile
import shutil
import threading
import time
import unittest
import urllib.error
import urllib.request
import zipfile
import zlib
from http.server import ThreadingHTTPServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from store import Store, Problem, uid
from server import handler_class, lock_directory

TEST_ROOT = Path(__file__).resolve().parents[1] / '.local' / 'test-runs'


class LocalTemporaryDirectory:
    """Use normal inherited Windows ACLs; Python 3.13's 0700 temp ACL excludes sandbox identities."""
    def __init__(self):
        TEST_ROOT.mkdir(parents=True, exist_ok=True)
        self.path = (TEST_ROOT / uid()).resolve()
        self.path.mkdir()
        self.name = str(self.path)

    def cleanup(self):
        assert self.path.is_relative_to(TEST_ROOT.resolve()) and self.path != TEST_ROOT.resolve()
        shutil.rmtree(self.path)

    def __enter__(self):
        return self.name

    def __exit__(self, *args):
        self.cleanup()


def png(width=16, height=12):
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    pixels = b''.join(b'\0' + b'\x60\xa0\x80\x90' * width for _ in range(height))
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(pixels)) + chunk(b'IEND', b'')


class StoreTests(unittest.TestCase):
    def setUp(self):
        self.temp = LocalTemporaryDirectory()
        self.store = Store(self.temp.name)
        self.doc = self.store.state()
        self.page = self.doc['pages'][0]
        self.request = {'clientId': 'window-a', 'epoch': self.doc['epoch'], 'pageId': self.page['id']}
        self.asset = self.store.upload(self.request, png(), '透明小样.png')
        self.request['token'] = self.store.lease(self.request)['token']

    def tearDown(self):
        self.store.db.close()
        self.temp.cleanup()

    def populated(self):
        page = copy.deepcopy(self.page)
        page['layers'] = [{'id': uid(), 'assetId': self.asset['id'], 'name': '物件', 'x': 400, 'y': 600,
                           'width': 160, 'height': 120, 'rotation': 25, 'visible': True, 'locked': False, 'groupId': None}]
        return page

    def save(self, page, revision=0, request=None):
        return self.store.save_page({**(request or self.request), 'page': page, 'revision': revision})

    def assert_problem(self, status, operation):
        with self.assertRaises(Problem) as caught:
            operation()
        self.assertEqual(caught.exception.status, status)

    def test_persist_restart_transforms_and_asset_reuse(self):
        page = self.populated()
        self.save(page)
        second = self.store.create_page({**self.request, 'name': '读信'})
        request = {**self.request, 'pageId': second['id'], 'token': None}
        request['token'] = self.store.lease(request)['token']
        second['layers'] = copy.deepcopy(page['layers'])
        second['layers'][0]['id'] = uid()
        self.save(second, request=request)
        self.store.db.close()
        self.store = Store(self.temp.name)
        doc = self.store.state()
        self.assertEqual(len(doc['pages']), 2)
        self.assertEqual(len(doc['assets']), 1)
        self.assertEqual(doc['pages'][0]['layers'][0]['rotation'], 25)
        self.assertEqual(doc['pages'][1]['layers'][0]['assetId'], self.asset['id'])

    def test_delete_instance_preserves_original_and_restore(self):
        page = self.populated()
        self.save(page)
        empty = copy.deepcopy(page); empty['layers'] = []
        self.save(empty, 1)
        self.assertEqual(self.store.asset(self.asset['id'])[1], png())
        self.save(page, 2)
        self.assertEqual(len(self.store.state()['pages'][0]['layers']), 1)

    def test_same_page_lock_and_stale_version_rejected(self):
        other = {**self.request, 'clientId': 'window-b'}
        self.assert_problem(423, lambda: self.store.lease(other))
        self.assert_problem(423, lambda: self.save(self.populated(), request=other))
        self.save(self.populated())
        self.assert_problem(409, lambda: self.save(self.page, 0))

    def test_expired_lease_reacquisition_gets_new_token(self):
        old_token = self.request['token']
        self.store.leases[self.page['id']]['until'] = time.monotonic() - 1
        self.assert_problem(423, lambda: self.store.lease(self.request))
        result = self.store.lease({**self.request, 'token': None})
        self.assertNotEqual(result['token'], old_token)
        self.assert_problem(423, lambda: self.save(self.populated()))

    def test_parallel_pages_do_not_overwrite_each_other(self):
        second = self.store.create_page({**self.request, 'name': '另一页'})
        other = {**self.request, 'clientId': 'window-b', 'pageId': second['id'], 'token': None}
        other['token'] = self.store.lease(other)['token']
        second['name'] = '另一页改名'
        self.save(second, request=other)
        first = self.populated(); first['name'] = '主页改名'
        self.save(first)
        doc = self.store.state()
        self.assertEqual([p['name'] for p in doc['pages']], ['主页改名', '另一页改名'])
        self.assertEqual([p['id'] for p in doc['pages']], [self.page['id'], second['id']])

    def test_atomic_zip_roundtrip_backup_and_old_epoch_rejected(self):
        page = self.populated(); self.save(page)
        archive = self.store.export()
        with zipfile.ZipFile(io.BytesIO(archive)) as zipped:
            manifest = json.loads(zipped.read('project.json'))
            self.assertEqual(zipped.read(manifest['assets'][0]['file']), png())
        empty = copy.deepcopy(page); empty['layers'] = []; self.save(empty, 1)
        current = self.store.state()
        result = self.store.import_project({**self.request, 'revision': current['revision']}, archive)
        self.assertTrue((Path(self.temp.name) / 'backups' / result['backup']).is_file())
        restored = self.store.state()
        self.assertEqual(restored['pages'][0]['layers'], page['layers'])
        self.assertNotEqual(restored['epoch'], current['epoch'])
        self.assert_problem(409, lambda: self.save(page, 2))

    def test_import_blocked_by_other_window_and_stale_project_revision(self):
        archive = self.store.export()
        second = self.store.create_page({**self.request, 'name': '其他窗口'})
        other = {**self.request, 'pageId': second['id'], 'clientId': 'window-b', 'token': None}
        self.store.lease(other)
        req = {**self.request, 'revision': self.store.state()['revision']}
        self.assert_problem(423, lambda: self.store.import_project(req, archive))
        req['revision'] = -1
        self.assert_problem(409, lambda: self.store.import_project(req, archive))

    def test_bad_zip_and_missing_assets_do_not_modify_project(self):
        before = self.store.state()
        self.assert_problem(400, lambda: self.store.import_project(self.request, b'bad zip'))
        output = io.BytesIO()
        with zipfile.ZipFile(output, 'w') as archive:
            doc = copy.deepcopy(before); doc['format'] = 'to-human-world-layout'; doc['assets'] = []
            doc['pages'][0] = self.populated()
            archive.writestr('project.json', json.dumps(doc))
        self.assert_problem(400, lambda: self.store.import_project(self.request, output.getvalue()))
        self.assertEqual(before, self.store.state())

    def test_group_integrity_and_nonfinite_coordinates(self):
        page = self.populated(); page['layers'][0]['x'] = float('nan')
        self.assert_problem(400, lambda: self.save(page))
        page = self.populated(); page['layers'][0]['groupId'] = uid()
        self.assert_problem(400, lambda: self.save(page))

    def test_identical_asset_upload_deduplicates_bytes(self):
        item = self.store.upload(self.request, png(), '重复图片.png')
        self.assertEqual(item['id'], self.asset['id'])
        self.assertEqual(len(self.store.assets()), 1)


class HTTPTests(unittest.TestCase):
    def test_startup_reuses_service_and_blocks_second_process_on_same_data(self):
        with LocalTemporaryDirectory() as directory:
            store = Store(directory)
            lock = lock_directory(Path(directory))
            server = ThreadingHTTPServer(('127.0.0.1', 0), handler_class(store, 'test-secret'))
            thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
            command = [sys.executable, '-B', str(Path(__file__).resolve().parents[1] / 'server.py'), '--no-browser', '--data-dir', directory]
            try:
                reused = subprocess.run(command + ['--port', str(server.server_port)], capture_output=True, text=True, timeout=10)
                self.assertEqual(reused.returncode, 0, reused.stderr)
                self.assertIn('already running', reused.stdout)
                rejected = subprocess.run(command + ['--port', '0'], capture_output=True, text=True, timeout=10)
                self.assertNotEqual(rejected.returncode, 0)
                self.assertIn('already open', rejected.stderr)
            finally:
                server.shutdown(); server.server_close(); store.db.close(); lock.close()

    def test_origin_protection_request_validation_and_asset_stream(self):
        with LocalTemporaryDirectory() as directory:
            store = Store(directory)
            server = ThreadingHTTPServer(('127.0.0.1', 0), handler_class(store, 'test-secret'))
            thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
            url = f'http://127.0.0.1:{server.server_port}'
            try:
                with urllib.request.urlopen(url + '/api/state') as response:
                    doc = json.load(response)
                self.assertEqual(doc['csrf'], 'test-secret')
                request = urllib.request.Request(url + '/api/pages', data=b'{}', headers={'Content-Type': 'application/json'})
                with self.assertRaises(urllib.error.HTTPError) as caught:
                    urllib.request.urlopen(request)
                self.assertEqual(caught.exception.code, 403)
                request.add_header('X-Editor-Token', 'test-secret'); request.add_header('Origin', 'https://example.com')
                with self.assertRaises(urllib.error.HTTPError) as caught:
                    urllib.request.urlopen(request)
                self.assertEqual(caught.exception.code, 403)
                request.remove_header('Origin')
                request.data = b'[]'
                with self.assertRaises(urllib.error.HTTPError) as caught:
                    urllib.request.urlopen(request)
                self.assertEqual(caught.exception.code, 400)
                asset = store.upload({'epoch': doc['epoch']}, png(), 'image.png')
                with urllib.request.urlopen(url + '/api/asset/' + asset['id']) as response:
                    self.assertEqual(response.headers['Content-Type'], 'image/png')
                    self.assertEqual(response.read(), png())
            finally:
                server.shutdown(); server.server_close(); store.db.close()


if __name__ == '__main__':
    unittest.main(verbosity=2)
