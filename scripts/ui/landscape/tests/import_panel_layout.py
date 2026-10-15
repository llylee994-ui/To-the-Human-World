"""Freeze an exported material-editor project as a runtime-only art manifest."""
import hashlib
import json
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[4]
def lua(value, level=0):
    pad = '    ' * level
    if isinstance(value, dict):
        return '{\n' + ',\n'.join(pad + '    [' + json.dumps(k, ensure_ascii=False) + ']=' + lua(v, level + 1) for k, v in value.items()) + '\n' + pad + '}'
    if isinstance(value, list):
        return '{\n' + ',\n'.join(pad + '    ' + lua(v, level + 1) for v in value) + '\n' + pad + '}'
    if isinstance(value, bool):
        return 'true' if value else 'false'
    return json.dumps(value, ensure_ascii=False)
def main(source):
    raw = Path(source).read_bytes()
    project = json.loads(raw)
    paths = project['referenceProfile']['sourceAssets']
    pages = {}
    for page in project['pages']:
        layers = []
        for layer in page['layers']:
            if not layer['visible']:
                continue
            row = {k: layer[k] for k in ('id', 'assetId', 'x', 'y', 'width', 'height', 'rotation')}
            row['path'] = paths[layer['assetId']].removeprefix('assets/')
            assert (ROOT / 'assets' / row['path']).is_file(), row['path']
            layers.append(row)
        pages[page['id']] = dict(width=page['width'], height=page['height'], revision=page['revision'], layers=layers)
    result = dict(sourceRevision=project.get('revision', 292), sourceSha256=hashlib.sha256(raw).hexdigest(), pages=pages)
    target = ROOT / 'scripts/ui/landscape/PanelLayoutManifest.lua'
    target.write_text('-- Frozen designer reference; original PNGs and transforms.\nreturn ' + lua(result) + '\n', encoding='utf-8')
if __name__ == '__main__':
    main(sys.argv[1])
