import sys
from pathlib import Path as _Path
sys.path.insert(0, str(_Path(__file__).resolve().parent))
from paths import output_dir, source_blend, mapping
import bpy,os,json,math
P=str(output_dir());bpy.ops.wm.open_mainfile(filepath=P+'/baked_staging.blend',use_scripts=False);old=bpy.context.scene;data=json.load(open(P+'/scene.json'));
for mr in data['materials']:
 if 'glass' in mr.get('sourceMaterial','').lower():
  mat=bpy.data.materials.get(mr['id'])
  if mat:
   for node in mat.node_tree.nodes:
    if node.type=='MIX_SHADER':node.inputs[0].default_value=mr['baseColorFactor'][3]
s=bpy.data.scenes.new('Reconstructed exported full JSON');bpy.context.window.scene=s;s.render.engine='CYCLES';s.cycles.samples=24;s.cycles.use_denoising=False;s.cycles.adaptive_min_samples=8;s.cycles.adaptive_threshold=.055;s.world=old.world;s.camera=old.camera.copy();s.collection.objects.link(s.camera)
s.view_settings.view_transform=old.view_settings.view_transform;s.view_settings.look=old.view_settings.look;s.view_settings.exposure=old.view_settings.exposure
lights=[]
for o in old.objects:
 if o.type=='LIGHT' and not o.hide_render:
  s.collection.objects.link(o.copy());lights.append({'name':o.name,'type':o.data.type,'position':list(o.matrix_world.translation),'matrixWorld':[list(row) for row in o.matrix_world],'colorLinear':list(o.data.color),'energyBlenderUnits':o.data.energy,'note':'Blender light energy is not assumed numerically equivalent to UrhoX brightness'})
open(P+'/lighting_reference.json','w').write(json.dumps(lights,indent=2))
for j,item in enumerate(data['meshFiles']):
 part=json.load(open(P+'/'+item['file']));v=part['positions'];ix=part['indices'];me=bpy.data.meshes.new(part['id']);me.from_pydata([v[i:i+3] for i in range(0,len(v),3)],[],[ix[i:i+3] for i in range(0,len(ix),3)]);me.uv_layers.new();uv=part['uv0'];norm=part['normals']
 for loop in me.loops:me.uv_layers.active.data[loop.index].uv=uv[loop.vertex_index*2:loop.vertex_index*2+2]
 for poly in me.polygons:poly.use_smooth=True
 me.normals_split_custom_set_from_vertices([norm[k:k+3] for k in range(0,len(norm),3)]);ob=bpy.data.objects.new(part['id'],me);s.collection.objects.link(ob);ob.data.materials.append(bpy.data.materials[part['materialId']])
 if j%20==0:print('REBUILT',j,len(data['meshFiles']),flush=True)

for other in list(bpy.data.scenes):
 if other!=s:bpy.data.scenes.remove(other)
bpy.ops.outliner.orphans_purge(do_recursive=True)
s.render.resolution_x=1672;s.render.resolution_y=941;s.render.resolution_percentage=70;s.render.filepath=P+'/full_json_reconstruction.png';bpy.ops.render.render(write_still=True)
print('FULL_JSON_REFERENCE_DONE',flush=True)
