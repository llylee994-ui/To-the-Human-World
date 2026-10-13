"""Validate an already-delivered full package with the real Lua streaming importer.

No native preview, scene upload, extraction, source rewriting or player storage.
"""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import struct
import sys
import time
import traceback

sys.dont_write_bytecode = True
LAB = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(LAB / 'tools/vendor'))
from lupa.lua54 import LuaRuntime, lua_type

parser = argparse.ArgumentParser()
parser.add_argument('--root', type=Path, required=True)
parser.add_argument('--expected-triangles', type=int, required=True)
parser.add_argument('--expected-source-objects', type=int, required=True)
parser.add_argument('--synthetic', action='store_true')
args = parser.parse_args()
root = args.root.resolve()
assert root.is_relative_to(LAB.resolve()), 'Package must be inside the isolated Lab'
assert root.is_dir(), 'Package directory does not exist'
started = time.monotonic()
report = {'timestampUtc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'package': str(root), 'synthetic': args.synthetic, 'status': 'FAIL',
          'nativePreviewStarted': False, 'runtime': 'Lua 5.4, real validator/streamer with native backend substitute',
          'limitation': 'No GPU rendering, native performance, camera or human input acceptance'}

def file_path(name):
    assert isinstance(name, str) and name and '\\' not in name and ':' not in name
    assert all(p and p not in ('.', '..') for p in name.split('/'))
    p = (root / name).resolve()
    assert p.is_relative_to(root) and p.is_file(), 'Missing or out-of-package file: ' + name
    return p

def read_json(name, limit=None):
    p = file_path(name)
    if limit:
        assert p.stat().st_size <= limit, 'JSON exceeds bounded-read size: ' + name
    return json.loads(p.read_text(encoding='utf-8-sig'))

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('package.path = ... .. "/v035/scripts/?.lua;" .. ... .. "/v035/scripts/?/init.lua"', LAB.as_posix(), LAB.as_posix())

def table(value):
    if isinstance(value, dict):
        return lua.table_from({k: table(v) for k, v in value.items()})
    if isinstance(value, list):
        return lua.table_from([table(v) for v in value])
    return value

def plain(value):
    if lua_type(value) != 'table':
        return value
    keys = list(value.keys())
    if keys and set(keys) == set(range(1, len(keys) + 1)):
        return [plain(value[i]) for i in range(1, len(keys) + 1)]
    return {str(k): plain(v) for k, v in value.items()}

try:
    hashes = read_json('SHA256.json')
    assert isinstance(hashes, dict) and hashes
    seen = set()
    for name, expected in hashes.items():
        assert name.lower() not in seen, 'Windows case-colliding hash paths'
        seen.add(name.lower())
        actual = hashlib.sha256(file_path(name).read_bytes()).hexdigest()
        assert actual == expected, 'SHA256 mismatch: ' + name
    manifest = read_json('manifest.json', 4 * 1024 * 1024)
    assert 'manifest.json' in hashes and manifest['entry'] in hashes
    raw = read_json(manifest['entry'], 4 * 1024 * 1024)
    assert raw['format'] == 'dot-customgeometry-scene-v1'
    catalog = lua.eval('require("lab35.ScenePackage").Catalog')(table({'meshFiles': manifest.get('meshFiles') or raw.get('meshFiles')}))
    header = lua.eval('require("lab35.ProbeAdapter").Convert')(table(raw), lua.table_from({'meshCatalog': catalog}))
    textures = {}
    normal_bindings = []
    for material in plain(header.materials):
        assert material['alphaMode'] != 'MASK', 'Native MASK transfer is unverified'
        if material.get('normalTexture'):
            normal_name = material['normalTexture']
            assert normal_name in hashes and file_path(normal_name), 'Missing declared normal texture'
            assert material['normalMapConvention'] == 'tangent-space OpenGL +Y; requires tangent basis derived from uv0'
            assert material['textureColorSpaces']['normalTexture'] == 'linear'
            normal_bindings.append({'material': material['id'], 'file': normal_name, 'nativeStatus': 'binding implemented; actual runtime tangent API and visual TBN unverified'})
        name = material.get('baseColorTexture')
        if name and name not in textures:
            assert name in hashes, 'Texture absent from SHA256 manifest: ' + name
            with file_path(name).open('rb') as png:
                head = png.read(24)
            assert head[:8] == b'\x89PNG\r\n\x1a\n' and head[12:16] == b'IHDR', 'Invalid PNG: ' + name
            width, height = struct.unpack('>II', head[16:24])
            textures[name] = {'width': width, 'height': height, 'bytes': file_path(name).stat().st_size}
    visited = []
    def read_mesh(entry):
        name = entry.path
        assert name in hashes, 'Mesh absent from SHA256 manifest: ' + name
        p = file_path(name)
        assert p.stat().st_size <= 32 * 1024 * 1024, 'Mesh JSON exceeds bounded read size'
        if entry.sha256:
            assert entry.sha256 == hashes[name], 'Catalog digest disagrees with SHA256 manifest'
        visited.append(name)
        return p.read_text(encoding='utf-8-sig')
    lua.globals().cjson = lua.table_from({'decode': lambda text: table(json.loads(text))})
    lua.execute('File=function() error("DISK STORAGE FORBIDDEN") end; fileSystem=setmetatable({}, {__index=function() error("DISK STORAGE FORBIDDEN") end})')
    backend = lua.eval('''function() return {
        Material=function(m) return m.id end, Begin=function() return {} end,
        Geometry=function(_, id) return id end, Vertex=function() end,
        Commit=function() end, Remove=function() end, Publish=function() end
    } end''')()
    retain = {mesh_id:True for a in raw['interactionProxies'] if a['id']=='home.merchantShip' for mesh_id in a['visibleMeshIds']}
    job = lua.eval('require("lab35.MeshLoader").Stream')(header, catalog, read_mesh, backend, lua.table_from({'chunkVertices': 12000,'retainMeshIds':table(retain)}))
    while job.Snapshot().status not in ('complete', 'failed', 'cancelled'):
        job.Step(64)
    status = plain(job.Snapshot())
    assert status['status'] == 'complete', status
    stats = plain(job.Result().stats)
    assert stats['triangles'] == args.expected_triangles, 'Actual triangle total differs from expected full coverage'
    assert stats['sourceObjects'] == args.expected_source_objects, 'Source-object coverage differs from expected full scene'
    anchors=plain(job.Result().prepared.anchors)
    assert len(anchors)==8
    semantic=[{'id':a['id'],'visibleMeshIds':a['visibleMeshIds'],'proxyTriangles':len(a['proxy']['indices'])//3} for a in anchors]
    report.update(status='PASS', stats=stats, hashFiles=len(hashes), meshFiles=len(visited), textures=textures, normalTextureBindings=normal_bindings, semanticEntries=semantic,
                  expandedVertexPayloadBytes=stats['expandedVertices'] * 8 * 4,
                  memoryEstimateNote='Only position/normal/UV float payload; excludes engine buffers, overhead, textures and shadows')
except Exception:
    report['failure'] = traceback.format_exc()
finally:
    report['offlineSeconds'] = time.monotonic() - started
    evidence = LAB / 'docs/evidence/v035-main-interface'
    name = 'full-package-synthetic-check.json' if args.synthetic else 'full-package-check.json'
    (evidence / name).write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(report, ensure_ascii=False, indent=2))
    print('Evidence:', evidence / name)
if report['status'] != 'PASS':
    raise SystemExit(1)
