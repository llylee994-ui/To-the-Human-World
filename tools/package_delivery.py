"""Build an A2 review bundle from explicit lab-only deliverables, excluding transfer secrets."""
from pathlib import Path
import json,hashlib,zipfile,datetime
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'deliverables'; OUT.mkdir(exist_ok=True)
required=['REPORT.md','LAB_STATUS.md','docs/actions/2026-10-12-3d-lab-r3.md','docs/3d-interface-map.md','docs/RUNBOOK.md','docs/evidence/3d-lab-r3/BLOCKERS.md']
for name in required: assert (ROOT/name).is_file(),name
e=ROOT/'docs/evidence/3d-lab-r3'
checks=json.loads((e/'offline-checks.json').read_text(encoding='utf-8'))
assert checks['status']=='PASS' and len(checks['results'])==70
integrity=json.loads((e/'integrity.json').read_text(encoding='utf-8'))
assert not integrity['source_changed_since_copy'] and not integrity['offline_test_source_mismatches']
device=json.loads((e/'device.json').read_text(encoding='utf-8-sig'))
device['hardware_query_status']='CPU CIM query unavailable. GPU/renderer and native dimensions are independently recorded from actual Runtime logs.'
(e/'device.json').write_text(json.dumps(device,ensure_ascii=False,indent=2),encoding='utf-8')
files=[]
for item in ('scripts','urhox-libs','.emmylua','docs','references/engine','tools/vendor'):
    files.extend(p for p in (ROOT/item).rglob('*') if p.is_file() and '__pycache__' not in p.parts and not (p.suffix=='.png' and 'native' in p.parts and 'selected' not in p.parts))
files.extend(ROOT/name for name in required[:2])
files.extend(p for p in (ROOT/'tools').iterdir() if p.is_file() and p.suffix in ('.py','.ps1'))
files=sorted(set(files))
for p in files:
    assert p.resolve().is_relative_to(ROOT.resolve()) and not p.is_symlink()
    assert '.git' not in p.parts and '.maker-mcp' not in p.parts
    if p.suffix in ('.json','.md','.txt','.log'):
        txt=p.read_text(encoding='utf-8-sig')
        assert not any(marker in txt for marker in ('X-Amz-Signature=','sig=','Bearer ')),p
manifest={'version':'D3-LAB-20261012-r3-v01','created_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'NATIVE_PARTIAL_ACCEPTANCE_REFERENCE_PENDING','excluded':'Runtime distribution, live .preview-home, app binding, .git, credentials, and redundant raw PNGs; selected unmodified native frame sequences included.','files':[{'path':p.relative_to(ROOT).as_posix(),'size':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in files]}
archive=OUT/'D3-LAB-20261012-r3-v01-review.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    for p in files: z.write(p,p.relative_to(ROOT).as_posix())
    z.writestr('DELIVERY_MANIFEST.json',json.dumps(manifest,ensure_ascii=False,indent=2))
with zipfile.ZipFile(archive) as z: assert z.testzip() is None
receipt={'path':str(archive),'size':archive.stat().st_size,'sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'files':len(files)+1,'report_path':str(ROOT/'REPORT.md'),'report_size':(ROOT/'REPORT.md').stat().st_size}
(OUT/'receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(receipt,ensure_ascii=False))
