"""Pinned-main offline behavior and synthetic mesh checks; never starts UrhoX."""
from pathlib import Path
import sys, json, hashlib, datetime, traceback
sys.dont_write_bytecode = True
LAB = Path(__file__).resolve().parents[1]
ROOT = LAB / 'v035'
sys.path.insert(0, str(LAB / 'tools/vendor'))
from lupa.lua54 import LuaRuntime, lua_type

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path = ... .. '/scripts/?.lua;' .. ... .. '/scripts/?/init.lua'", ROOT.as_posix(), ROOT.as_posix())

def plain(v):
    if lua_type(v) != 'table':
        return v
    keys = list(v.keys())
    if keys and set(keys) == set(range(1, len(keys) + 1)):
        return [plain(v[i]) for i in range(1, len(keys) + 1)]
    return {str(k): plain(value) for k, value in v.items()}

def table(v):
    if isinstance(v, dict):
        return lua.table_from({k: table(value) for k, value in v.items()})
    if isinstance(v, list):
        return lua.table_from([table(value) for value in v])
    return v

logs = []
def log(*args):
    line = ' '.join(map(str, args))
    logs.append(line)
    print(line, flush=True)

lua.globals().print = log
lua.globals().cjson = lua.table_from({
    'encode': lambda v: json.dumps(plain(v), ensure_ascii=False, allow_nan=False),
    'decode': lambda text: table(json.loads(text)),
})
lua.execute('''
File=function() error("DISK STORAGE FORBIDDEN") end
fileSystem=setmetatable({}, {__index=function() error("FILESYSTEM ACCESS FORBIDDEN") end})
''')
failure = None
results = []
sources = {}
try:
    manifest = json.loads((LAB / 'docs/evidence/v035-main-interface/runtime-source-manifest.json').read_text(encoding='utf-8'))
    for entry in manifest['files']:
        digest = hashlib.sha256((ROOT / entry['path']).read_bytes()).hexdigest()
        assert digest == entry['sha256'], f"Pinned source changed: {entry['path']}"
    log('[source]', len(manifest['files']), 'pinned main Lua modules unchanged:', manifest['sha'])
    for path in sorted((ROOT / 'scripts').rglob('*.lua')):
        lua.execute('assert(load(...))', path.read_text(encoding='utf-8'))
        sources[str(path.relative_to(ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()
    log('[syntax]', len(sources), 'Lua files compiled under', lua.eval('_VERSION'))
    results = plain(lua.eval('require("lab35.tests.Checks").Run')())
    probe_path = LAB / 'experiments/3d-lab/assets/import-probe-v035/probe.json'
    if probe_path.exists():
        probe = table(json.loads(probe_path.read_text(encoding='utf-8')))
        normalized = lua.eval('require("lab35.ProbeAdapter").Convert')(probe)
        prepared = lua.eval('require("lab35.MeshContract").Prepare')(normalized)
        assert prepared.stats.meshes == 6 and prepared.stats.triangles == 8128 and len(prepared.anchors) == 8
        results.append({'name': 'actual delivered probe remains schema-compatible', 'status': 'PASS',
                        'detail': '6 meshes / 8128 triangles / 8 proxies; no GPU execution'})
        log('[PASS] actual delivered probe remains schema-compatible')
        frame = lua.eval('require("lab35.CameraMath").Frame')(probe.camera)
        project = lua.eval('function(frame,p,fov,aspect) return require("lab35.CameraMath").Project(frame,require("lab35.Math3").Convert(p),math.rad(fov),aspect) end')
        camera_rows = []
        for anchor in probe.interactionProxies.values():
            uv, depth = project(frame, anchor.position, probe.camera.horizontalFovDegrees,
                                probe.camera.resolution[1] / probe.camera.resolution[2])
            error = max(abs(uv[i] - anchor.screenAnchor[i]) for i in (1, 2))
            camera_rows.append({'id': anchor.id, 'projected': plain(uv), 'expected': plain(anchor.screenAnchor), 'error': error, 'depth': depth})
        assert max(r['error'] for r in camera_rows) < 1e-6
        (LAB / 'docs/evidence/v035-main-interface/camera-basis-offline.json').write_text(json.dumps({
            'status': 'PASS', 'nativeValidated': False, 'referenceBasis': plain(frame), 'anchors': camera_rows,
            'note': 'Proper RH node basis is right/up/backward. Native API mapping is still unverified.'
        }, indent=2), encoding='utf-8')
        results.append({'name': 'actual Blender camera basis reproduces all eight anchors offline', 'status': 'PASS'})
        log('[PASS] actual Blender camera basis reproduces all eight anchors offline')
except Exception:
    failure = traceback.format_exc()
    log(failure)

report = {
    'timestampUtc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'status': 'FAIL' if failure else 'PASS', 'failure': failure,
    'runtime': 'Lupa Lua 5.4 with widget/API substitutes; real pinned main business',
    'nativePreviewStarted': False, 'cloudV035AssetsLoaded': False,
    'limitations': ['No real GPU rendering or native input dispatch', 'Full-scene tests use synthetic batches; actual full package is separate',
                    'Layout updates do not prove visual composition', 'Memory reload is not cross-process persistence'],
    'mainSha': '1cd0cdbec06487a5c60f109d5fd477198cfc8846',
    'results': results, 'log': logs, 'sourceHashes': sources,
}
evidence = LAB / 'docs/evidence/v035-main-interface'
(evidence / 'offline-v035.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
(evidence / 'offline-v035.log').write_text('\n'.join(logs) + '\n', encoding='utf-8')
print('Evidence:', evidence / 'offline-v035.json')
if failure:
    raise SystemExit(1)
