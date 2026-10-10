"""Executes the real installed copyTree in Node under a Windows byte lock; no UI."""
import argparse
import contextlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import maker_preview_lock_fix as fix


@contextlib.contextmanager
def locked(path):
    import msvcrt
    with path.open('r+b') as stream:
        msvcrt.locking(stream.fileno(), msvcrt.LK_NBLCK, 1)
        try:
            yield
        finally:
            stream.seek(0)
            msvcrt.locking(stream.fileno(), msvcrt.LK_UNLCK, 1)


class CopyRegression(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='maker-copy-lock-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.project = self.root / 'project'
        self.local = self.project / 'scripts/layout-editor/.local'
        self.local.mkdir(parents=True)
        (self.local / '.server.lock').write_bytes(b'1')
        (self.local / 'layout.sqlite3').write_bytes(b'editor-only')
        (self.project / 'scripts/main.lua').write_text('return 42')
        (self.project / 'scripts/layout-editor/server.py').write_text('# editor source')
        (self.project / 'assets/.local').mkdir(parents=True)
        (self.project / 'assets/.local/keep.txt').write_text('keep')

    def run_copy(self, source, patched=True, cancelled=False):
        bundle = fix.patched(ORIGINAL) if patched else ORIGINAL
        text = bundle.decode('utf-8')
        copy = text[text.index('async function copyTree('):text.index('function validateProjectVersion(')]
        script = ('import fs27 from "node:fs"; import path28 from "node:path";\n' + copy +
                  '\nconst [src,dst,excluded,cancelled]=process.argv.slice(1);'
                  '\ntry { await copyTree(src,dst,{aborted:cancelled==="true"},excluded);'
                  'console.log("OK"); } catch(e) {console.error(e.code || e.message);process.exitCode=1;}')
        return subprocess.run([NODE, '--input-type=module', '-e', script, str(source),
                               str(self.root / 'output'), str(self.local.resolve()),
                               str(cancelled).lower()], capture_output=True, text=True, timeout=20)

    def test_original_reproduces_busy_lock(self):
        with locked(self.local / '.server.lock'):
            result = self.run_copy(self.project / 'scripts', patched=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('EBUSY', result.stderr)
        print('Original copyTree: reproduced EBUSY on editor lock')

    def test_patch_copies_game_and_editor_source_without_working_data(self):
        with locked(self.local / '.server.lock'):
            result = self.run_copy(self.project / 'scripts')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / 'output/main.lua').read_text(), 'return 42')
        self.assertTrue((self.root / 'output/layout-editor/server.py').is_file())
        self.assertFalse((self.root / 'output/layout-editor/.local').exists())
        self.assertEqual((self.local / 'layout.sqlite3').read_bytes(), b'editor-only')

    def test_other_local_directory_preserved(self):
        result = self.run_copy(self.project / 'assets')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.root / 'output/.local/keep.txt').read_text(), 'keep')

    def test_other_locked_files_still_fail(self):
        with locked(self.project / 'scripts/main.lua'):
            result = self.run_copy(self.project / 'scripts')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('EBUSY', result.stderr)

    def test_cancel_not_swallowed(self):
        result = self.run_copy(self.local, cancelled=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('CANCELLED', result.stderr)

    def test_install_idempotence_rollback_and_version_guard(self):
        package = self.root / 'maker'
        (package / 'dist').mkdir(parents=True)
        (package / 'package.json').write_text(json.dumps({'version': '0.0.36'}))
        bundle = package / 'dist/maker.js'
        bundle.write_bytes(ORIGINAL)
        backup = self.root / 'backup'
        self.assertEqual(fix.operate(bundle, backup, 'apply')['status'], 'patched')
        self.assertEqual(fix.operate(bundle, backup, 'apply')['status'], 'already_patched')
        self.assertEqual(fix.operate(bundle, backup, 'rollback')['status'], 'restored')
        self.assertEqual(bundle.read_bytes(), ORIGINAL)
        bundle.write_bytes(ORIGINAL + b'\n// changed upstream')
        with self.assertRaises(ValueError):
            fix.operate(bundle, backup, 'apply')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--original-bundle', type=Path, required=True)
    parser.add_argument('--node', required=True)
    args = parser.parse_args()
    if os.name != 'nt':
        raise SystemExit('This regression requires a real Windows lock')
    ORIGINAL, NODE = args.original_bundle.read_bytes(), args.node
    unittest.main(argv=['copy-regression'])
