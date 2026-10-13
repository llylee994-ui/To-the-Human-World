"""Read-only verification of source snapshots, input availability and tested source hashes."""
from pathlib import Path
import json,hashlib,datetime,sys
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]; E=ROOT/'docs/evidence/3d-lab-r3'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
changes=[]; local_changes=[]; count=0
for name in ('source-snapshot.json','library-snapshot.json'):
    for row in json.loads((E/name).read_text(encoding='utf-8'))['files']:
        count+=1; src=Path(row['source']); dst=Path(row['destination'])
        if sha(src)!=row['sha256']: changes.append(str(src))
        if sha(dst)!=row['sha256']: local_changes.append(str(dst.relative_to(ROOT)))
test=json.loads((E/'offline-checks.json').read_text(encoding='utf-8'))
stale=[name for name,digest in test['tested_sources'].items() if sha(ROOT/name)!=digest]
integrity={'time':now,'source_files_checked':count,'source_changed_since_copy':changes,'intentional_local_changes':local_changes,'offline_test_source_mismatches':stale,'offline_test_count':len(test['results']),'scope':'Only the explicitly copied source/dependency files; does not assert that other workers stopped editing unrelated formal files.'}
(E/'integrity.json').write_text(json.dumps(integrity,ensure_ascii=False,indent=2),encoding='utf-8')
raw=json.loads((ROOT/'tools/library-current/transfers.json').read_text(encoding='utf-8')) if (ROOT/'tools/library-current/transfers.json').exists() else None
if raw:
    safe=[]
    uses=['完整任务原文','空间、构图、配色和光照（必须看像素）','药炉造型（必须看像素）','同一商船造型（必须看像素）','捞网造型（必须看像素）']
    for n,t in enumerate(raw['transfers']):
        dest=ROOT/'references/incoming'/t['file_name']
        row={k:v for k,v in t.items() if k not in ('download_url','headers','required_headers')}
        row.update(intended_local_path=str(dest),exists=dest.is_file(),readable=dest.is_file() and len(dest.read_bytes())>0,pixels_viewed=False,use=uses[n],status='FAILED_OFFICIAL_HELPER_XATTR')
        safe.append(row)
    (E/'reference-map.json').write_text(json.dumps({'time':now,'destination':str(ROOT/'references/incoming'),'files':safe,'remaining_directory_entries':[p.name for p in (ROOT/'references/incoming').iterdir()],'note':'No readable destination or residual temporary file remained after official helper failures. This is a post-call directory inspection, not an inference from xattr failure alone. Signed transfer URLs deliberately excluded.'},ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(integrity,ensure_ascii=False))
