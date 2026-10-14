import sys
from pathlib import Path as _Path
sys.path.insert(0, str(_Path(__file__).resolve().parent))
from paths import output_dir, source_blend, mapping
import json,pathlib,hashlib,collections
P=output_dir();r=json.loads((P/'scene.json').read_text());coverage=json.loads((P/'object_mesh_coverage.json').read_text());by_mesh=collections.defaultdict(list)
for name,ids in coverage.items():
 for mid in ids:by_mesh[mid].append(name)
ids={d['id'] for d in r['meshFiles']};assert set(by_mesh)==ids
checks=[]
for d in r['meshFiles']:
 p=P/d['file'];m=json.loads(p.read_text());keys=['positions','normals','uv0','indices'];before=hashlib.sha256(json.dumps({k:m[k] for k in keys},separators=(',',':')).encode()).hexdigest();m['sourceObjects']=sorted(set(by_mesh[m['id']]));m['sourceObjectsScope']='Provenance of merged semantic/material group; repeated across its split chunks, not per-triangle attribution';p.write_text(json.dumps(m,separators=(',',':')));after=hashlib.sha256(json.dumps({k:m[k] for k in keys},separators=(',',':')).encode()).hexdigest();assert before==after;d['sha256']=hashlib.sha256(p.read_bytes()).hexdigest();checks.append({'id':m['id'],'geometryUnchanged':True,'geometrySha256':before,'sourceObjects':len(m['sourceObjects'])})
for a in r['interactionProxies']:
 a['visibleMeshIds']=sorted(set(d['id'] for d in r['meshFiles'] if d['semantic']==a['id']));assert a['visibleMeshIds'] and all(mid in ids for mid in a['visibleMeshIds'])
assert len(r['interactionProxies'])==8
r['format']='dot-customgeometry-scene-v1';r['sourceObjectMappingScope']='Merged-group provenance repeated across chunk files; all original visible objects accounted for, not a triangle ownership map';(P/'scene.json').write_text(json.dumps(r,ensure_ascii=False,indent=2));manifest={'entry':'scene.json','completeVisibleScene':True,'meshCount':len(r['meshFiles']),'triangles':r['triangles'],'vertices':r['vertices'],'visibleSourceObjects':r['sourceVisibleObjects'],'proxyCount':len(r['interactionProxies']),'materials':len(r['materials']),'engineValidated':False,'cameraReference':'camera_projection_reference.json','coverage':'object_mesh_coverage.json','validation':'validation.json'};manifest['format']=r['format'];manifest['schemaVersion']=1;(P/'manifest.json').write_text(json.dumps(manifest,indent=2));(P/'metadata_compatibility_check.json').write_text(json.dumps({'meshGeometryUnchanged':checks,'allEightOwnershipListsNonempty':True,'format':r['format'],'contractLibraryId':'libfile_2ce51c6065b48191a892d35f0ed2fc6f'},indent=2));print('METADATA_OK',len(checks))
