import sys
from pathlib import Path as _Path
sys.path.insert(0, str(_Path(__file__).resolve().parent))
from paths import output_dir, source_blend, mapping
import json,pathlib,math,hashlib
P=output_dir();r=json.loads((P/'scene.json').read_text());base=json.loads((P/'coverage.json').read_text());mapping=json.loads((P/'object_mesh_coverage.json').read_text());expected={x['name'] for x in base['source_objects'] if x['status']=='covered'};errors=[];stats=[]
if set(mapping)!=expected:errors.append('Object coverage mismatch')
ids=set()
for item in r['meshFiles']:
 path=pathlib.PurePosixPath(item['file']);assert not path.is_absolute() and '..' not in path.parts
 m=json.loads((P/path).read_text());ids.add(m['id']);n=len(m['positions'])//3
 if n>60000:errors.append(m['id']+' exceeds vertex budget')
 if len(m['positions'])%3 or len(m['normals'])!=n*3 or len(m['uv0'])!=n*2 or len(m['indices'])%3:errors.append(m['id']+' bad array lengths')
 if not all(math.isfinite(x) for k in ['positions','normals','uv0'] for x in m[k]):errors.append(m['id']+' non-finite')
 if not all(isinstance(i,int) and 0<=i<n for i in m['indices']):errors.append(m['id']+' invalid index')
 maxerr=max(abs(math.sqrt(sum(x*x for x in m['normals'][i:i+3]))-1) for i in range(0,len(m['normals']),3))
 if maxerr>.001:errors.append(m['id']+' non-unit normals')
 stats.append({'id':m['id'],'vertices':n,'triangles':len(m['indices'])//3,'maxNormalError':maxerr,'bytes':(P/path).stat().st_size})
for name,meshids in mapping.items():
 if not meshids or not all(x in ids for x in meshids):errors.append(name+' missing output meshes')
for mat in r['materials']:
 for k,v in mat.items():
  if k.endswith('Texture') and not (P/v).is_file():errors.append(v+' missing texture')
report={'errors':errors,'coveredObjects':len(mapping),'expectedObjects':len(expected),'meshCount':len(stats),'triangles':sum(x['triangles'] for x in stats),'vertices':sum(x['vertices'] for x in stats),'removedZeroAreaTriangles':r['removedZeroAreaTriangles'],'chunks':stats,'engineValidated':False};(P/'validation.json').write_text(json.dumps(report,indent=2));print({k:v for k,v in report.items() if k!='chunks'});assert not errors
