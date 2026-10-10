"""Reversible local Maker 0.0.36 preview-copy fix. No preview launch or account changes.

Apply/check/rollback require an explicit installed dist/maker.js and backup directory.
Package upgrades are deliberately rejected; review the new upstream version first.
"""
import argparse
import hashlib
import json
from pathlib import Path

ORIGINAL_SHA = '62deb6cd7adc3975d23ce5750be53116f02ef7b9b5b9d49e5ace44fbbc144652'
EDITS = (
    ('async function copyTree(source, target, signal) {',
     'async function copyTree(source, target, signal, editorLocal) {'),
    ('  const stat = await fs27.promises.lstat(source);',
     '  // Human World: editor working data is not a game preview input.\n'
     '  if (editorLocal && path28.relative(editorLocal, path28.resolve(source)) === "") return;\n'
     '  const stat = await fs27.promises.lstat(source);'),
    ('await copyTree(path28.join(source, name), path28.join(target, name), signal);',
     'await copyTree(path28.join(source, name), path28.join(target, name), signal, editorLocal);'),
    ('await copyTree(original, path28.join(source, name), signal);',
     'await copyTree(original, path28.join(source, name), signal,\n'
     '      path28.resolve(project, "scripts", "layout-editor", ".local"));'),
)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def patched(original):
    if digest(original) != ORIGINAL_SHA:
        raise ValueError('Unknown Maker bundle; refusing to patch a changed version')
    source = original.decode('utf-8')
    for old, new in EDITS:
        if source.count(old) != 1:
            raise ValueError('Preview copy seam changed; no files modified')
        source = source.replace(old, new)
    return source.encode('utf-8')


def operate(bundle, backup_dir, mode):
    bundle = bundle.resolve(strict=True)
    if bundle.name != 'maker.js' or bundle.parent.name != 'dist':
        raise ValueError('Expected an installed dist/maker.js')
    package = json.loads((bundle.parent.parent / 'package.json').read_text(encoding='utf-8'))
    if package.get('version') != '0.0.36':
        raise ValueError('Only the verified Maker 0.0.36 is supported')
    current = bundle.read_bytes()
    key = digest(str(bundle).encode())[:16]
    backup = backup_dir / (key + '.original.js')
    if digest(current) == ORIGINAL_SHA:
        expected = patched(current)
        if mode == 'check':
            return {'status': 'unpatched', 'sha256': digest(current)}
        if mode == 'rollback':
            return {'status': 'already_original', 'sha256': digest(current)}
        backup_dir.mkdir(parents=True, exist_ok=True)
        if backup.exists() and backup.read_bytes() != current:
            raise ValueError('Backup mismatch; refusing overwrite')
        if not backup.exists():
            with backup.open('xb') as stream:
                stream.write(current)
        bundle.write_bytes(expected)
        if bundle.read_bytes() != expected:
            raise ValueError('Install readback failed; original backup retained')
        return {'status': 'patched', 'sha256': digest(expected), 'backup': str(backup)}
    # A modified installation can only be checked or rolled back with its exact original.
    original = backup.read_bytes()
    if current != patched(original):
        raise ValueError('Installed bundle has other changes; refusing overwrite')
    if mode == 'rollback':
        bundle.write_bytes(original)
        if bundle.read_bytes() != original:
            raise ValueError('Rollback readback failed')
        return {'status': 'restored', 'sha256': digest(original)}
    return {'status': 'already_patched', 'sha256': digest(current), 'backup': str(backup)}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bundle', type=Path, required=True)
    parser.add_argument('--backup-dir', type=Path, required=True)
    parser.add_argument('--mode', choices=['check', 'apply', 'rollback'], default='check')
    args = parser.parse_args()
    print(json.dumps(operate(args.bundle, args.backup_dir, args.mode), ensure_ascii=False))
