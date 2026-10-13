"""Preserve explicitly authorized local originals without changing PNG pixels/metadata."""
from pathlib import Path
import datetime,hashlib,json,struct
ROOT=Path(__file__).resolve().parents[1]
E=ROOT/'docs/evidence/3d-lab-r3'
candidates=json.loads((E/'reference-local-candidates.json').read_text(encoding='utf-8-sig'))['files']
remote=json.loads((E/'reference-map.json').read_text(encoding='utf-8-sig'))['files'][1:]
items=[]
uses=[
 'Home composition: large open left doorway and sea; close right-hand desk with rear shelving; warm sunset on aged wood, plaster panels, abundant herbs. Full frame is composition reference, never a flat scene backdrop.',
 'Stove: rounded hammered dark-copper body, flared rolled lip, two hanging ring handles, three slender splayed curved brass supports and a separate small burner beneath. Visible herbal surface. Backside remains an adjustable default.',
 'Ship: one small European sailing boat, cream triangular sails and white timber hull, warm rigging. Same scene vessel across cameras; do not add multiple boats.',
 'Net candidate: long turned wooden handle, oval hoop, hanging rope pocket. Local candidate has a visible brown backdrop; version identity remains unresolved and does not authorize replacing the net appearance.'
]
for i,(candidate,attachment) in enumerate(zip(candidates,remote)):
 source=Path(candidate['source']); data=source.read_bytes()
 assert hashlib.sha256(data).hexdigest()==candidate['sha256'],'Source changed since inspection'
 pos=8; auxiliary_bytes=0; chunks=[]
 while pos<len(data):
  size=struct.unpack('>I',data[pos:pos+4])[0]; kind=data[pos+4:pos+8].decode('ascii')
  chunks.append({'type':kind,'payload_bytes':size})
  if kind=='caBX': auxiliary_bytes+=size+12
  pos+=size+12
 explained=(len(data)-auxiliary_bytes==attachment['size_bytes']) and candidate['dimensions_match_attachment']
 folder='references/local-originals' if explained else 'references/unconfirmed-candidates'
 destination=ROOT/folder/source.name
 destination.parent.mkdir(parents=True,exist_ok=True)
 if destination.exists(): assert destination.read_bytes()==data,'Do not overwrite different reference'
 else: destination.write_bytes(data)
 assert source.read_bytes()==destination.read_bytes()==data
 items.append({**candidate,'library_file_id':attachment['library_file_id'],'library_file_name':attachment['file_name'],'library_bytes':attachment['size_bytes'],'local_path':str(destination),'caBX_total_bytes':auxiliary_bytes,'bytes_excluding_caBX':len(data)-auxiliary_bytes,'png_chunks':chunks,'pixels_viewed':True,'viewed_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'use':uses[i],'status':'LOCAL_ORIGINAL_METADATA_CORRESPONDENCE' if explained else 'LOCAL_CANDIDATE_VERSION_UNCONFIRMED','appearance_reference_usable':explained,'provenance_limit':'Exact filename/dimensions and auxiliary-chunk-adjusted size match is correspondence evidence, not a remote cryptographic pixel comparison. Official Library materialization remains failed. Original local bytes are preserved.'})
result={'task':'01a12c24-a725-712b-ba7d-df58430f5098','scope':'Explicitly authorized exact local originals read from formal material directory; all outputs in Lab.','files':items}
(E/'reference-local-map.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps([{'name':x['file_name'],'status':x['status'],'bytes':x['size'],'caBX_bytes':x['caBX_total_bytes']} for x in items],ensure_ascii=True))
