"""Read current working-tree bytes once; detect concurrent changes; never copy bindings/saves."""
from pathlib import Path
import hashlib, json, datetime, subprocess
SRC=Path(r'D:\taptap\To-the-Human-World')
DST=Path(__file__).resolve().parents[1]
def digest(data): return hashlib.sha256(data).hexdigest()
files=[]
for folder in ('scripts/core','scripts/systems','scripts/data'):
    files.extend(SRC.joinpath(folder).rglob('*.lua'))
files.extend(SRC/p for p in ('scripts/ui/PlayModel.lua','scripts/ui/landscape/Panels.lua','scripts/ui/landscape/LayoutManifest.lua','templates/scaffold-3d-scene.lua','scripts/debug/fixtures/HeadlessUI.lua'))
files.extend(p for p in (SRC/'.tmp/b1-python/lupa').iterdir() if p.name in ('__init__.py','version.py') or p.name.startswith('lua54.') and p.suffix=='.pyd')
manifest=[]
for src in sorted(files):
    assert not src.is_symlink(), src
    rel=src.relative_to(SRC)
    dest=DST/rel
    if str(rel).startswith('.tmp'): dest=DST/'tools/vendor/lupa'/src.name
    if str(rel).startswith('templates'): dest=DST/'references/engine'/src.name
    if src.name=='HeadlessUI.lua': dest=DST/'scripts/lab/tests/HeadlessUI.lua'
    data=src.read_bytes()
    if dest.exists(): assert dest.read_bytes()==data, f'Unknown/different destination: {dest}'
    else:
        dest.parent.mkdir(parents=True,exist_ok=True)
        dest.write_bytes(data)
    assert src.read_bytes()==data, f'Changed during copy: {src}'
    manifest.append(dict(source=str(src),destination=str(dest),sha256=digest(data),size=len(data),copied_at=datetime.datetime.now(datetime.timezone.utc).isoformat()))
status=subprocess.check_output(['git','-C',str(SRC),'status','--porcelain'],encoding='utf-8')
head=subprocess.check_output(['git','-C',str(SRC),'rev-parse','HEAD'],encoding='utf-8').strip()
e=DST/'docs/evidence/3d-lab-r3'
(e/'source-snapshot.json').write_text(json.dumps(dict(head=head,files=manifest),ensure_ascii=False,indent=2),encoding='utf-8')
(e/'source-status-initial.txt').write_text(status,encoding='utf-8')
print(f'Copied {len(manifest)} files; {sum(x["size"] for x in manifest)} bytes; all before/after hashes equal')
