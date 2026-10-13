"""Verify the staged full entry/resources without invoking Start or native APIs."""
from pathlib import Path
import datetime, hashlib, json, re, sys
sys.dont_write_bytecode=True
LAB=Path(__file__).resolve().parents[1]
E=LAB/'docs/evidence/v035-main-interface'
sys.path.insert(0,str(LAB/'tools/vendor'))
from lupa.lua54 import LuaRuntime

sha=lambda data:hashlib.sha256(data).hexdigest()
stage=json.loads((E/'native-stage-manifest.json').read_text(encoding='utf-8'))
assert stage['mode']=='complete-v035-scene'
for entry in stage['files']:
    p=LAB/entry['path']
    assert p.resolve().is_relative_to(LAB.resolve())
    assert sha(p.read_bytes())==entry['sha256'],entry['path']
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('package.path=... .. "/scripts/?.lua;" .. ... .. "/scripts/?/init.lua"',LAB.as_posix(),LAB.as_posix())
compiled=[]
for p in sorted((LAB/'scripts/v035').rglob('*.lua')):
    text=p.read_text(encoding='utf-8')
    lua.execute('assert(load(...))',text)
    assert not re.search(r'''require\s*(?:\(\s*)?["'](?:core|systems|data|ui|lab35|debug)[./]''',text),'Unnamespaced main require: '+str(p)
    compiled.append(p.relative_to(LAB).as_posix())

# Run the real generated entry's Install only. Any premature native access is an
# error; Start is registered, never called. This is not a runtime launch.
lua.execute('''
package.preload["urhox-libs/UI"]=function() return {} end
Scene=function() error("NATIVE START FORBIDDEN") end
File=function() error("DISK SAVE FORBIDDEN") end
cache=setmetatable({}, {__index=function() error("NATIVE RESOURCE READ FORBIDDEN") end})
''')
entry=(LAB/'scripts/main.lua').read_text(encoding='utf-8')
assert 'v035.lab35.FullSceneHost' in entry and 'resourcePrefix="v035-full"' in entry
lua.execute('assert(load(...))()',entry)
assert lua.eval('type(Start)=="function" and type(V035FullUpdate)=="function" and type(Stop)=="function"')

root=LAB/'assets/v035-full'
hashes=json.loads((root/'runtime-assets.sha256.json').read_text(encoding='utf-8'))
for name,expected in hashes.items():
    p=root/name
    assert p.resolve().is_relative_to(root.resolve()) and p.is_file()
    assert sha(p.read_bytes())==expected,name
manifest=json.loads((root/'manifest.json').read_text(encoding='utf-8'))
scene=json.loads((root/manifest['entry']).read_text(encoding='utf-8'))

def table(value):
    if isinstance(value,dict):return lua.table_from({k:table(v) for k,v in value.items()})
    if isinstance(value,list):return lua.table_from([table(v) for v in value])
    return value

catalog=lua.eval('require("v035.lab35.ScenePackage").Catalog')(table({'meshFiles':scene['meshFiles']}))
header=lua.eval('require("v035.lab35.ProbeAdapter").Convert')(table(scene),lua.table_from({'meshCatalog':catalog}))
prepared=lua.eval('require("v035.lab35.MeshContract").Prepare')(header,lua.table_from({'meshCatalog':catalog}))
ids=lua.eval('(require("v035.lab35.Ids"))')
mapping=[]
for a in scene['interactionProxies']:
    definition=ids[a['id']]
    assert definition.target==a['target'] and a['visibleMeshIds']
    mapping.append({'id':a['id'],'target':a['target'],'label':definition.label,'visibleMeshIds':a['visibleMeshIds']})
assert len(mapping)==8 and len(catalog)==90 and len(prepared.anchors)==8
source=LAB/'experiments/3d-lab/assets/import-v035-full'
for m in scene['meshFiles']:
    name=m.get('file') or m.get('path')
    assert sha((root/name).read_bytes())==m['sha256']==sha((source/name).read_bytes())
ship_ids=next(a['visibleMeshIds'] for a in scene['interactionProxies'] if a['id']=='home.merchantShip')
ship=[]
for mesh in scene['meshFiles']:
    if mesh['id'] in ship_ids:
        path=mesh.get('file') or mesh.get('path')
        payload=json.loads((root/path).read_text(encoding='utf-8'))
        assert len(payload['indices'])==mesh['triangles']*3 and len(payload['positions'])==mesh['vertices']*3
        ship.append({'id':mesh['id'],'triangles':mesh['triangles'],'vertices':mesh['vertices'],'sha256':mesh['sha256']})
assert len(ship)==len(ship_ids)==1
assert 'retainMeshIds=keep' in (LAB/'scripts/v035/lab35/FullSceneHost.lua').read_text(encoding='utf-8')
audit=json.loads((E/'full-resource-audit.json').read_text(encoding='utf-8'))
assert sha((root/'_lab/default-white.png').read_bytes())==audit['whiteFallback']['sha256']
source_manifest=json.loads((E/'runtime-source-manifest.json').read_text(encoding='utf-8'))
for f in source_manifest['files']:
    assert sha((LAB/'v035'/f['path']).read_bytes())==f['sha256']

report={'timestampUtc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'PASS',
    'nativeStarted':False,'actualEntryInstalledWithoutStart':True,'entry':str(LAB/'scripts/main.lua'),
    'stageManifestFiles':len(stage['files']),'compiledLuaFiles':len(compiled),'runtimeResourceFiles':len(hashes),
    'runtimeResourceBytes':sum((root/name).stat().st_size for name in hashes),'meshFiles':len(catalog),
    'completeShipGeometry':ship,'semanticMappings':mapping,'pinnedMainModulesUnchanged':len(source_manifest['files']),
    'availableCameraNames':['Home']+[c['id'] for c in scene.get('additionalCameras',[])],
    'limitations':['Install registration only; Start, native APIs, UI rendering and GPU not run','Full package supplies Home camera only; separate runtime evidence validates original Brew/Seaside pages','This offline checker does not run official prepare; see native session evidence for actual prepare results']}
(E/'full-staged-check.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2))
