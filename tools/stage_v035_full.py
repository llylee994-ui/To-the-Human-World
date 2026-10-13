"""Stage the complete validated v035 scene in the isolated Lab. Never run native."""
from pathlib import Path
import argparse, datetime, hashlib, json, re

parser=argparse.ArgumentParser()
parser.add_argument('--observe-entries',action='store_true',help='Explicitly enable bounded native UI callback evidence; no business commands')
args=parser.parse_args()

LAB=Path(__file__).resolve().parents[1]
E=LAB/'docs/evidence/v035-main-interface'
ROOT=LAB/'experiments/3d-lab/assets/import-v035-full'
manifest_path=E/'native-stage-manifest.json'
previous=json.loads(manifest_path.read_text(encoding='utf-8'))
known={x['path']:x['sha256'] for x in previous['files']}
digest=lambda raw:hashlib.sha256(raw).hexdigest()
check=json.loads((E/'full-package-check.json').read_text(encoding='utf-8'))
audit=json.loads((E/'full-resource-audit.json').read_text(encoding='utf-8'))
assert check['status']=='PASS' and not check['synthetic']
assert check['stats']['meshes']==90 and check['stats']['triangles']==3209455
assert check['stats']['retainedGeometryMeshes']==1 and len(check['semanticEntries'])==8
assert audit['status']=='PASS' and audit['normalMaterials']==26
scene=json.loads((ROOT/'scene.json').read_text(encoding='utf-8'))
hashes=json.loads((ROOT/'SHA256.json').read_text(encoding='utf-8'))
planned=[]

def plan(path,raw,source):
    assert path.resolve().is_relative_to(LAB.resolve())
    key=path.relative_to(LAB).as_posix()
    if path.exists() and path.read_bytes()!=raw:
        assert digest(path.read_bytes())==known.get(key),'Refuse unknown overwrite: '+key
    planned.append((path,raw,{'path':key,'source':source,'bytes':len(raw),'sha256':digest(raw)}))

# Check every previously generated file, including retained historical probe.
for key,expected in known.items():
    path=LAB/key
    assert path.is_file() and digest(path.read_bytes())==expected,'Existing generated file changed: '+key

source=LAB/'v035/scripts'
for p in sorted(source.rglob('*.lua')):
    if 'tests' in p.parts: continue
    text=p.read_text(encoding='utf-8')
    text=re.sub(r'''(require\s*(?:\(\s*)?["'])(core|systems|data|ui|lab35|debug)([./])''',r'\1v035.\2\3',text)
    text=re.sub(r'''(["'])image/''',r'\1v035-main-image/',text)
    plan(LAB/'scripts/v035'/p.relative_to(source),text.encode('utf-8'),p.relative_to(LAB).as_posix())

resources={'manifest.json','scene.json','uv_checker.png','camera_projection_reference.json','object_mesh_coverage.json','validation.json'}
resources.update(m.get('file') or m.get('path') for m in scene['meshFiles'])
used={m['materialId'] for m in scene['meshFiles']}
for material in scene['materials']:
    if material['id'] in used:
        resources.update(material[k] for k in ('baseColorTexture','normalTexture') if material.get(k))
resource_hashes={}
for name in sorted(resources):
    p=ROOT/name
    assert p.resolve().is_relative_to(ROOT.resolve())
    raw=p.read_bytes();assert digest(raw)==hashes[name],'Source payload hash mismatch: '+name
    resource_hashes[name]=digest(raw)
    plan(LAB/'assets/v035-full'/name,raw,p.relative_to(LAB).as_posix())
white=LAB/'v035/assets/engine-support/default-white.png'
raw=white.read_bytes();assert digest(raw)==audit['whiteFallback']['sha256']
resource_hashes['_lab/default-white.png']=digest(raw)
plan(LAB/'assets/v035-full/_lab/default-white.png',raw,white.relative_to(LAB).as_posix())
plan(LAB/'assets/v035-full/runtime-assets.sha256.json',json.dumps(resource_hashes,indent=2).encode('utf-8'),'hashes of exactly the staged runtime resources')
for p in sorted((LAB/'v035/assets/image').rglob('*')):
    if p.is_file(): plan(LAB/'assets/v035-main-image'/p.relative_to(LAB/'v035/assets/image'),p.read_bytes(),p.relative_to(LAB).as_posix())
entry=LAB/'scripts/main.lua'
new=b'-- Isolated Lab: complete cloud v03.5 scene; native launch requires explicit user intent.\nrequire("v035.lab35.FullSceneHost").Install({resourcePrefix="v035-full",manifestPath="manifest.json",flipV=true,maxLoadingSeconds=300})\n'
if args.observe_entries: new=new.replace(b'maxLoadingSeconds=300}',b'maxLoadingSeconds=300,observeEntries=true}')
plan(entry,new,'explicit full scene entry; historical probe entry preserved')

# Preflight is complete. Preserve previous state before the first full staging.
for name,raw in [('native-stage-before-full.json',manifest_path.read_bytes()),('probe-main-before-full.lua',entry.read_bytes())]:
    p=E/name
    if not p.exists(): p.write_bytes(raw)

records={x['path']:x for x in previous['files']}
for p,raw,record in planned:
    p.parent.mkdir(parents=True,exist_ok=True)
    if not p.exists() or p.read_bytes()!=raw: p.write_bytes(raw)
    records[record['path']]=record
report={'timestampUtc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'mode':'complete-v035-scene',
    'files':list(records.values()),'bindingChanged':False,'nativeStarted':False,
    'oldEntrySha256':previous['oldEntrySha256'],'runtimeResourceFiles':len(resource_hashes),
    'preservedProbeEntry':'docs/evidence/v035-main-interface/probe-main-before-full.lua'}
manifest_path.write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps({'status':'STAGED_OFFLINE','files':len(records),'runtimeResourceFiles':len(resource_hashes),
    'entry':str(entry),'nativeStarted':False},indent=2))
