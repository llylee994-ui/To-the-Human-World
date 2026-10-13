"""Stage a namespaced Lab-only preview; preserve old entry and unknown files."""
from pathlib import Path
import json, hashlib, re, datetime

LAB=Path(__file__).resolve().parents[1]
E=LAB/'docs/evidence/v035-main-interface'
manifest_path=E/'native-stage-manifest.json'
previous=json.loads(manifest_path.read_text(encoding='utf-8')) if manifest_path.exists() else {'files':[]}
known={x['path']:x['sha256'] for x in previous['files']}
records=[]
def put(path,raw,source):
    assert path.resolve().is_relative_to(LAB.resolve())
    key=path.relative_to(LAB).as_posix()
    if path.exists() and path.read_bytes()!=raw:
        assert hashlib.sha256(path.read_bytes()).hexdigest()==known.get(key),'Refuse unknown overwrite: '+key
    path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)
    records.append({'path':key,'source':source,'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()})

source=LAB/'v035/scripts'
for p in sorted(source.rglob('*.lua')):
    if 'tests' in p.parts:continue
    raw=p.read_text(encoding='utf-8')
    # Static require roots are namespaced so the old lab's core/ui cannot load.
    raw=re.sub(r'''(require\s*(?:\(\s*)?["'])(core|systems|data|ui|lab35|debug)([./])''',r'\1v035.\2\3',raw)
    raw=re.sub(r'''(["'])image/''',r'\1v035-main-image/',raw)
    put(LAB/'scripts/v035'/p.relative_to(source),raw.encode('utf-8'),p.relative_to(LAB).as_posix())
probe=LAB/'experiments/3d-lab/assets/import-probe-v035'
for name in ['probe.json','uv_checker.png','mat_00_basecolor.png','mat_01_basecolor.png','mat_02_basecolor.png','mat_03_basecolor.png','sea-calm.png','merchant-ship-muted.png']:
    put(LAB/'assets/v035-probe'/name,(probe/name).read_bytes(),str((probe/name).relative_to(LAB)))
for p in sorted((LAB/'v035/assets/image').rglob('*')):
    if p.is_file():put(LAB/'assets/v035-main-image'/p.relative_to(LAB/'v035/assets/image'),p.read_bytes(),str(p.relative_to(LAB)))
entry=LAB/'scripts/main.lua';backup=E/'legacy-main-before-v035.lua'
new=b'-- Lab-only v03.5 cloud probe. Original entry preserved in docs/evidence/v035-main-interface.\nrequire("v035.lab35.NativeHost").Install()\n'
if not backup.exists():
    assert b'lab.World' in entry.read_bytes(),'Unrecognized old entry; refuse overwrite'
    backup.write_bytes(entry.read_bytes())
if entry.read_bytes()!=new:
    assert entry.read_bytes()==backup.read_bytes(),'Entry has unknown edits; refuse overwrite'
entry.write_bytes(new)
records.append({'path':'scripts/main.lua','source':'explicit v035 probe entry; old entry preserved','bytes':len(new),'sha256':hashlib.sha256(new).hexdigest()})
(E/'native').mkdir(exist_ok=True)
manifest_path.write_text(json.dumps({'timestampUtc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'files':records,'oldEntrySha256':hashlib.sha256(backup.read_bytes()).hexdigest(),'bindingChanged':False},indent=2),encoding='utf-8')
print('Staged',len(records),'files; old entry preserved; no binding or formal changes.')
