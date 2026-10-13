"""Copy the required UI library closure and engine declarations, with source hashes."""
from pathlib import Path
import hashlib,json,datetime,re
SRC=Path(r'D:\taptap\To-the-Human-World')
ROOT=Path(__file__).resolve().parents[1]
pending=['urhox-libs/UI']; seen=set(); files=[]
while pending:
    name=pending.pop()
    if name in seen: continue
    seen.add(name)
    choices=[SRC/(name+'.lua'),SRC/name/'init.lua']
    src=next((p for p in choices if p.is_file()),None)
    assert src, name
    files.append(src)
    text=src.read_text(encoding='utf-8-sig')
    for dep in re.findall(r'require\s*\(?\s*[\"\']([^\"\']+)',text):
        if dep.startswith('urhox-libs/'): pending.append(dep)
files.extend((SRC/'.emmylua').rglob('*.lua'))
files.append(SRC/'urhox-libs/LICENSE')
manifest=[]
for src in sorted(set(files)):
    assert not src.is_symlink(),src
    data=src.read_bytes(); dest=ROOT/src.relative_to(SRC)
    if dest.exists(): assert dest.read_bytes()==data,f'Existing different file {dest}'
    else:
        dest.parent.mkdir(parents=True,exist_ok=True); dest.write_bytes(data)
    assert src.read_bytes()==data,src
    manifest.append(dict(source=str(src),destination=str(dest),sha256=hashlib.sha256(data).hexdigest(),size=len(data),copied_at=datetime.datetime.now(datetime.timezone.utc).isoformat()))
(ROOT/'docs/evidence/3d-lab-r3/library-snapshot.json').write_text(json.dumps({'files':manifest,'required_modules':sorted(seen)},ensure_ascii=False,indent=2),encoding='utf-8')
print(f'Copied {len(manifest)} library/declaration files, {sum(x["size"] for x in manifest)} bytes')
