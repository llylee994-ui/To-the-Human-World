import sys
from pathlib import Path as _Path
sys.path.insert(0, str(_Path(__file__).resolve().parent))
from paths import output_dir, source_blend, mapping
import bpy,os,json,collections,math,time
from mathutils import Vector
P=str(output_dir());ROOT=os.path.dirname(P);bpy.ops.wm.open_mainfile(filepath=source_blend(),use_scripts=False);old=bpy.context.scene;dg=bpy.context.evaluated_depsgraph_get();source=[o for o in old.objects if not o.hide_render and o.type in {'MESH','CURVE','FONT'}];anchors=json.load(open(mapping('baseline-65e640c/semantic_anchors.json')));defs=json.load(open(mapping('import_group_plan.json')));semantic={n:g['id'] for g in defs['groups'] if g['id'].startswith(('home.','decor.','backdrop')) for n in g['objects']};scene=bpy.data.scenes.new('Full export staging');bpy.context.window.scene=scene;scene.render.engine='CYCLES';scene.cycles.samples=4;scene.cycles.use_denoising=False;scene.world=old.world
cam=old.camera;scene.camera=cam.copy();scene.collection.objects.link(scene.camera)
for l in old.objects:
 if l.type=='LIGHT' and not l.hide_render:scene.collection.objects.link(l.copy())
scene.render.resolution_x=1672;scene.render.resolution_y=941;scene.view_settings.view_transform=old.view_settings.view_transform;scene.view_settings.look=old.view_settings.look;scene.view_settings.exposure=old.view_settings.exposure
coverage=[];groups=collections.defaultdict(list);start=time.time()
for j,o in enumerate(source):
 ev=o.evaluated_get(dg);me=bpy.data.meshes.new_from_object(ev,preserve_all_data_layers=True,depsgraph=dg)
 if not me or not me.polygons:coverage.append({'name':o.name,'type':o.type,'status':'empty_evaluated_geometry'});continue
 ob=bpy.data.objects.new(o.name,me);scene.collection.objects.link(ob);ob.matrix_world=o.matrix_world.copy()
 # Preserve original per-object generated/object coordinates before semantic joining.
 lo=Vector([min(v.co[k] for v in me.vertices) for k in range(3)]);hi=Vector([max(v.co[k] for v in me.vertices) for k in range(3)]);span=hi-lo
 gen=me.attributes.new('OriginalGenerated','FLOAT_VECTOR','POINT');local=me.attributes.new('OriginalObject','FLOAT_VECTOR','POINT')
 for v in me.vertices:
  gen.data[v.index].vector=Vector([(v.co[k]-lo[k])/span[k] if span[k]>1e-9 else 0 for k in range(3)]);local.data[v.index].vector=v.co
 mats=[m for m in me.materials if m]
 parts=[ob]
 if len(mats)>1:
  bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob;bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.separate(type='MATERIAL');bpy.ops.object.mode_set(mode='OBJECT');parts=list(bpy.context.selected_objects)
 for part in parts:
  pm=part.data;used=set(p.material_index for p in pm.polygons);assert len(used)==1,(o.name,used);mat=pm.materials[next(iter(used))];pm.materials.clear();pm.materials.append(mat)
  for face in pm.polygons:face.material_index=0
  sem=semantic.get(o.name,'static');key=sem+'__'+mat.name;groups[key].append(part);pm.calc_loop_triangles();coverage.append({'name':o.name,'part':part.name,'type':o.type,'status':'covered','group':key,'vertices':len(pm.vertices),'triangles':len(pm.loop_triangles)})
 if j%500==0:print('COVERAGE',j,len(source),round(time.time()-start,1),flush=True)
budget={'source_visible_geometry_objects':len(source),'covered':len(set(x['name'] for x in coverage if x['status']=='covered')),'empty_geometry':sum(x['status']!='covered' for x in coverage),'evaluated_triangles':sum(x.get('triangles',0) for x in coverage),'vertices':sum(x.get('vertices',0) for x in coverage),'candidate_groups':len(groups),'source_objects':coverage}
open(P+'/coverage.json','w').write(json.dumps(budget,ensure_ascii=False,indent=2));print('BUDGET', {k:v for k,v in budget.items() if k!='source_objects'},flush=True)
# Join only within semantic/material groups. Source scene is never modified or saved.
out=[]
for i,(key,obs) in enumerate(groups.items()):
 bpy.ops.object.select_all(action='DESELECT')
 for ob in obs:ob.select_set(True)
 bpy.context.view_layer.objects.active=obs[0]
 if len(obs)>1:bpy.ops.object.join()
 ob=bpy.context.view_layer.objects.active;ob.name='full_group_%03d'%i;ob['semantic']=key.split('__')[0];ob['source_material']=ob.data.materials[0].name
 # Resolve duplicate material slots of the same original material.
 mat=ob.data.materials[0];ob.data.materials.clear();ob.data.materials.append(mat)
 for poly in ob.data.polygons:poly.material_index=0
 out.append({'id':ob.name,'semantic':ob['semantic'],'sourceMaterial':mat.name,'sourceObjects':[x['name'] for x in coverage if x.get('group')==key]})
open(P+'/groups.json','w').write(json.dumps(out,ensure_ascii=False,indent=2));bpy.ops.wm.save_as_mainfile(filepath=P+'/staging.blend');print('PREPARED',len(out),flush=True)
