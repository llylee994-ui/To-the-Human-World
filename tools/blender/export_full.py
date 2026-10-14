import sys
from pathlib import Path as _Path
sys.path.insert(0, str(_Path(__file__).resolve().parent))
from paths import output_dir, source_blend, mapping
import bpy,os,json,math,time
from mathutils import Vector
P=str(output_dir());bpy.ops.wm.open_mainfile(filepath=P+'/baked_staging.blend',use_scripts=False);s=bpy.context.scene;groups=json.load(open(P+'/groups.json'));materials=json.load(open(P+'/materials.json'));os.makedirs(P+'/meshes',exist_ok=True);parts=[];coverage={};removed=0;start=time.time()
for gi,g in enumerate(groups):
 ob=bpy.data.objects[g['id']];me=ob.data;me.calc_loop_triangles();nm=ob.matrix_world.to_3x3().inverted().transposed();flip=ob.matrix_world.to_3x3().determinant()<0;world=[ob.matrix_world@v.co for v in me.vertices];chunk=0;lookup={};pos=[];norm=[];uv=[];ix=[];groupids=[]
 def flush():
  global chunk,lookup,pos,norm,uv,ix
  if not ix:return
  mid=g['id']+'_%03d'%chunk;filename='meshes/'+mid+'.json';data={'id':mid,'materialId':g['materialId'],'positions':pos,'normals':norm,'uv0':uv,'indices':ix};open(P+'/'+filename,'w').write(json.dumps(data,separators=(',',':')));parts.append({'id':mid,'file':filename,'materialId':g['materialId'],'vertices':len(pos)//3,'triangles':len(ix)//3,'semantic':g['semantic']});groupids.append(mid);chunk+=1;lookup={};pos=[];norm=[];uv=[];ix=[]
 for tri in me.loop_triangles:
  lis=list(tri.loops)
  if flip:lis.reverse()
  ps=[world[me.loops[li].vertex_index] for li in lis]
  if (ps[1]-ps[0]).cross(ps[2]-ps[0]).length_squared<1e-24:removed+=1;continue
  if len(pos)//3+3>60000:flush()
  for li,p in zip(lis,ps):
   n=(nm@me.corner_normals[li].vector).normalized();t=me.uv_layers.active.data[li].uv if me.uv_layers else Vector((0,0));key=tuple(round(float(x),7) for x in (*p,*n,*t))
   if key not in lookup:
    lookup[key]=len(pos)//3;pos.extend(key[:3]);norm.extend(key[3:6]);uv.extend(key[6:8])
   ix.append(lookup[key])
 flush()
 for name in g['sourceObjects']:coverage.setdefault(name,[]).extend(groupids)
 print('EXPORTED',gi+1,len(groups),'parts',len(parts),'seconds',round(time.time()-start,1),flush=True)
cam=json.load(open(P+'/camera_projection_reference.json'));camera={'position':cam['position'],'forward':cam['forward'],'up':cam['up'],'right':cam['right'],'projection':'perspective','verticalFovDegrees':cam['fov_y_degrees'],'horizontalFovDegrees':cam['fov_x_degrees'],'resolution':cam['resolution'],'shift':[cam['shift_x'],cam['shift_y']],'nearClip':.1,'farClip':200}
proxy=json.load(open(mapping('interaction-contract.json')));materials.append(next(m for m in proxy['materials'] if m['id']=='interaction_proxy_invisible'))
scene={'format':'dot-customgeometry-fullscene-v2','coordinateSystem':'Blender world Z-up; consumer (x,y,z)->(x,z,-y)','indexBase':0,'primitive':'TRIANGLE_LIST','arrayLayout':'flat xyz / flat uv; each mesh file retains v1 mesh fields','uvOrigin':'Blender bottom-left','camera':camera,'materials':materials,'meshes':[],'meshFiles':parts,'proxyMeshes':proxy['proxyMeshes'],'interactionProxies':proxy['interactionProxies'],'mainContractSha':proxy['mainContractSha'],'sourceVisibleObjects':len(coverage),'removedZeroAreaTriangles':removed,'triangles':sum(p['triangles'] for p in parts),'vertices':sum(p['vertices'] for p in parts),'coverageFile':'object_mesh_coverage.json','projectionReference':'camera_projection_reference.json'}
open(P+'/scene.json','w').write(json.dumps(scene,ensure_ascii=False,indent=2));open(P+'/object_mesh_coverage.json','w').write(json.dumps(coverage,ensure_ascii=False,indent=2));print('EXPORT_COMPLETE',len(parts),scene['triangles'],scene['vertices'],removed,flush=True)
