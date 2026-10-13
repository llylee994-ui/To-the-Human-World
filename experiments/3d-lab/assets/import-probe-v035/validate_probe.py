import json,math,pathlib
from PIL import Image
P=pathlib.Path(__file__).resolve().parent;r=json.loads((P/'probe.json').read_text());errors=[];stats=[]
for m in r['meshes']+r.get('proxyMeshes',[]):
 n=len(m['positions'])//3
 if len(m['positions'])%3 or len(m['normals'])!=n*3 or len(m['uv0'])!=n*2 or len(m['indices'])%3:errors.append(m['id']+' invalid lengths')
 if not all(math.isfinite(x) for k in ['positions','normals','uv0'] for x in m[k]):errors.append(m['id']+' non-finite')
 if not all(isinstance(i,int) and 0<=i<n for i in m['indices']):errors.append(m['id']+' invalid index')
 lengths=[math.sqrt(sum(x*x for x in m['normals'][i:i+3])) for i in range(0,len(m['normals']),3)]
 if any(abs(x-1)>.001 for x in lengths):errors.append(m['id']+' non-unit normal')
 stats.append({'id':m['id'],'vertices':n,'triangles':len(m['indices'])//3,'normal_length_range':[min(lengths),max(lengths)],'uv_range':[min(m['uv0']),max(m['uv0'])]})
images=[]
for mat in r['materials']:
 if 'baseColorTexture' not in mat:continue
 p=P/mat['baseColorTexture'];im=Image.open(p);images.append({'path':p.name,'size':im.size,'mode':im.mode,'extrema':im.getextrema()})
 if max(e[1]-e[0] for e in im.getextrema())==0:errors.append(p.name+' uniform/blank')
report={'errors':errors,'meshes':stats,'textures':images,'engine_tested':False,'blender_reimport_is_not_engine_validation':True};(P/'validation.json').write_text(json.dumps(report,indent=2));print(json.dumps({'errors':errors,'mesh_count':len(stats),'triangles':sum(s['triangles'] for s in stats)},indent=2));assert not errors
