from pathlib import Path
import json,zipfile,hashlib,zlib
P=Path(__file__).resolve().parent
base=['metadata_compatibility_check.json','transfer_plan.json','manifest.json','schema.json','scene.json','coverage.json','groups.json','object_mesh_coverage.json','materials.json','validation.json','camera_projection_reference.json','lighting_reference.json','semantic_anchors.json','main_constraints.json','README.txt']
files=[P/n for n in base]+sorted((P/'meshes').glob('*.json'))+sorted(P.glob('*.png'))+[P/n for n in ['prepare_full.py','bake_full.py','camera_reference.py','export_full.py','validate_full.py','rebuild_full_json.py','check_projection.py','complete_contract_metadata.py','package_full.py']]
sha={str(f.relative_to(P)):hashlib.sha256(f.read_bytes()).hexdigest() for f in files};(P/'SHA256.json').write_text(json.dumps(sha,indent=2));files.insert(0,P/'SHA256.json')
out=P.parent/'D3-v035-complete-CustomGeometry.zip'
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for f in files:z.write(f,str(f.relative_to(P)))
with zipfile.ZipFile(out) as z:assert z.testzip() is None
plan=[];batch=[];size=0
for f in files:
 b=f.read_bytes();estimated=len(zlib.compress(b,6))+len(str(f.relative_to(P)))*2+250
 if batch and size+estimated>18*1024*1024:plan.append(batch);batch=[];size=0
 batch.append(f);size+=estimated
if batch:plan.append(batch)
parts=[]
for i,batch in enumerate(plan):
 path=P.parent/('D3-v035-full-part-%02d-of-%02d.zip'%(i+1,len(plan)))
 with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  for f in batch:z.write(f,str(f.relative_to(P)))
 with zipfile.ZipFile(path) as z:assert z.testzip() is None
 assert path.stat().st_size<20*1024*1024
 parts.append({'file':path.name,'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
r={'complete':{'file':out.name,'bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest()},'split_parts':parts,'split_instructions':'All parts are independent ZIP archives. Extract ALL into the SAME directory, preserving meshes/. They are complementary files, not byte segments. No executable recombination needed.','file_count':len(files)};(P/'package_inventory.json').write_text(json.dumps(r,indent=2));print(json.dumps(r,indent=2))
