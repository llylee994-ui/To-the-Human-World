import bpy,os,json,math,shutil,hashlib
from mathutils import Vector
P=os.path.dirname(os.path.abspath(__file__));ROOT=os.path.dirname(P)
bpy.ops.wm.open_mainfile(filepath=ROOT+'/scene/hybrid_scene.blend',use_scripts=False);old=bpy.context.scene;camera=old.camera
cam={'position':list(camera.matrix_world.translation),'forward':list(camera.matrix_world.to_quaternion()@Vector((0,0,-1))),'up':list(camera.matrix_world.to_quaternion()@Vector((0,1,0))),'projection':'perspective','resolution':[1672,941]}
f=camera.data.view_frame(scene=old);cam['verticalFovDegrees']=math.degrees(2*math.atan(max(v.y/-v.z for v in f)));cam['horizontalFovDegrees']=math.degrees(2*math.atan(max(v.x/-v.z for v in f)))
prefixes=('Massive timber post','Open door board','Overdoor plaster','Left interior plaster wall','Plaster infill','Right plaster wall','Hammered copper cauldron','Cauldron drop handle','Cauldron ornate foot','Sculpted brass cauldron leg','Hybrid misty harbor','Hybrid independent merchant')
source=[o for o in old.objects if not o.hide_render and o.name.startswith(prefixes)];dg=bpy.context.evaluated_depsgraph_get();scene=bpy.data.scenes.new('Import probe only');bpy.context.window.scene=scene;scene.render.engine='CYCLES';scene.cycles.samples=8;scene.cycles.use_denoising=False
objects=[]
for o in source:
 ev=o.evaluated_get(dg);me=bpy.data.meshes.new_from_object(ev,preserve_all_data_layers=True,depsgraph=dg);ob=bpy.data.objects.new(o.name,me);scene.collection.objects.link(ob);ob.matrix_world=o.matrix_world.copy();objects.append(ob)
groups={}
for o in objects:
 mats=[m for m in o.data.materials if m];assert len(mats)==1,(o.name,len(mats));groups.setdefault(mats[0].name,[]).append(o)
materials=[]; meshes=[];group_notes=[]
def select(obs):
 bpy.ops.object.select_all(action='DESELECT')
 for o in obs:o.select_set(True)
 bpy.context.view_layer.objects.active=obs[0]
def texmat(name,image,metal,rough,alpha=False,unlit=False):
 m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;n.clear();l=m.node_tree.links;out=n.new('ShaderNodeOutputMaterial');t=n.new('ShaderNodeTexImage');t.image=image
 if unlit:
  sh=n.new('ShaderNodeEmission');l.new(t.outputs['Color'],sh.inputs['Color'])
 else:
  sh=n.new('ShaderNodeBsdfPrincipled');l.new(t.outputs['Color'],sh.inputs['Base Color']);sh.inputs['Metallic'].default_value=metal;sh.inputs['Roughness'].default_value=rough
 if alpha:
  mix=n.new('ShaderNodeMixShader');tr=n.new('ShaderNodeBsdfTransparent');l.new(t.outputs['Alpha'],mix.inputs[0]);l.new(tr.outputs[0],mix.inputs[1]);l.new(sh.outputs[0],mix.inputs[2]);l.new(mix.outputs[0],out.inputs['Surface'])
 else:l.new(sh.outputs[0],out.inputs['Surface'])
 return m
for gi,(name,obs) in enumerate(groups.items()):
 mid='mat_%02d'%gi;original=obs[0].data.materials[0];pbr=next((n for n in original.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
 metal=float(pbr.inputs['Metallic'].default_value) if pbr else 0;rough=float(pbr.inputs['Roughness'].default_value) if pbr else 1
 iscard=obs[0].name.startswith('Hybrid');alpha='merchant boat' in obs[0].name
 if iscard:
  image=next(n.image for n in original.node_tree.nodes if n.type=='TEX_IMAGE');filename='merchant-ship-muted.png' if alpha else 'sea-calm.png';shutil.copy2(ROOT+'/scene/textures/'+filename,P+'/'+filename)
 else:
  select(obs);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.1519,island_margin=.025);bpy.ops.object.mode_set(mode='OBJECT')
  image=bpy.data.images.new(mid+'_basecolor',width=1024,height=1024,alpha=False);image.generated_color=(0,0,0,1);filename=mid+'_basecolor.png'
  bake=original.copy();n=bake.node_tree.nodes;l=bake.node_tree.links;out=next(x for x in n if x.type=='OUTPUT_MATERIAL');principled=next(x for x in n if x.type=='BSDF_PRINCIPLED');emit=n.new('ShaderNodeEmission');col=principled.inputs['Base Color']
  if col.is_linked:l.new(col.links[0].from_socket,emit.inputs['Color'])
  else:emit.inputs['Color'].default_value=col.default_value
  l.new(emit.outputs[0],out.inputs['Surface']);target=n.new('ShaderNodeTexImage');target.image=image;n.active=target
  for o in obs:o.data.materials.clear();o.data.materials.append(bake)
  scene.render.bake.margin=8;scene.render.bake.use_clear=False;bpy.ops.object.bake(type='EMIT',use_clear=False)
  image.filepath_raw=P+'/'+filename;image.file_format='PNG';image.save()
 material=texmat(mid,image,metal,rough,alpha,iscard)
 for o in obs:o.data.materials.clear();o.data.materials.append(material)
 materials.append({'id':mid,'sourceMaterial':name,'baseColorTexture':filename,'baseColorFactor':[1,1,1,1],'metallic':metal,'roughness':rough,'alphaMode':'BLEND' if alpha else 'OPAQUE','unlit':iscard,'doubleSided':iscard,'colorSpace':'sRGB','note':'Baked base color; original procedural bump/roughness variation not yet baked' if not iscard else 'Original unchanged PNG'})
 positions=[];normals=[];uv=[];indices=[]
 for o in obs:
  me=o.data;me.calc_loop_triangles();normalmat=o.matrix_world.to_3x3().inverted().transposed();flip=o.matrix_world.to_3x3().determinant()<0
  for tri in me.loop_triangles:
   loops=list(tri.loops)
   if flip:loops.reverse()
   for li in loops:
    loop=me.loops[li];pos=o.matrix_world@me.vertices[loop.vertex_index].co;norm=(normalmat@me.corner_normals[li].vector).normalized();t=me.uv_layers.active.data[li].uv
    indices.append(len(positions)//3);positions.extend(pos);normals.extend(norm);uv.extend(t)
 meshes.append({'id':'group_%02d'%gi,'materialId':mid,'positions':positions,'normals':normals,'uv0':uv,'indices':indices})
 group_notes.append({'meshId':'group_%02d'%gi,'sourceObjects':[o.name for o in obs],'sourceCount':len(obs),'triangles':len(indices)//3})
checker=bpy.data.images.new('UV_checker',width=512,height=512);checker.generated_type='COLOR_GRID';checker.filepath_raw=P+'/uv_checker.png';checker.file_format='PNG';checker.save()
anchors=json.load(open(ROOT+'/semantic_anchors.json'));proxies=[]
for a in anchors['interactions']:
 proxies.append({'id':a['id'],'target':a['target'],'position':a['world_blender_z_up'],'screenAnchor':a['screen_normalized_top_left'],'shape':'camera_facing_quad','renderVisible':False,'status':a['status'],'note':'Independent interaction proxy; target assets absent in probe except stove/ship. Case-file binding is only proposed.'})
result={'format':'dot-customgeometry-probe-v1','coordinateSystem':'Blender RH Z-up; consumer maps (x,y,z) to (x,z,-y)','indexBase':0,'primitive':'TRIANGLE_LIST','arrayLayout':'positions/normals flat xyz; uv0 flat uv','uvOrigin':'Blender bottom-left, no V flip applied; verify checker in engine','camera':cam,'materials':materials,'meshes':meshes,'interactionProxies':proxies,'mainContractSha':anchors['source_main_sha'],'groups':group_notes}
open(P+'/probe.json','w').write(json.dumps(result,separators=(',',':')))
# Isolated Blender display of the actual exported triangle arrays, not the original source objects.
for o in list(scene.objects):bpy.data.objects.remove(o,do_unlink=True)
for part in meshes:
 vals=part['positions'];vs=[vals[i:i+3] for i in range(0,len(vals),3)];ix=part['indices'];faces=[ix[i:i+3] for i in range(0,len(ix),3)];me=bpy.data.meshes.new(part['id']);me.from_pydata(vs,[],faces);me.uv_layers.new();
 for li in range(len(me.loops)):me.uv_layers.active.data[li].uv=part['uv0'][li*2:li*2+2]
 me.normals_split_custom_set([part['normals'][i:i+3] for i in range(0,len(part['normals']),3)]);ob=bpy.data.objects.new(part['id'],me);scene.collection.objects.link(ob);ob.data.materials.append(bpy.data.materials[part['materialId']])
scene.camera=camera.copy();scene.collection.objects.link(scene.camera);scene.world=old.world;scene.render.resolution_x=1003;scene.render.resolution_y=565;scene.render.resolution_percentage=100;scene.cycles.samples=16
for o in old.objects:
 if o.type=='LIGHT' and not o.hide_render:cp=o.copy();scene.collection.objects.link(cp)
scene.view_settings.view_transform=old.view_settings.view_transform;scene.view_settings.look=old.view_settings.look;scene.view_settings.exposure=old.view_settings.exposure
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=P+'/probe_reimport.blend');scene.render.filepath=P+'/probe_preview.png';bpy.ops.render.render(write_still=True)
print('EXPORT_DONE',len(meshes),sum(len(m['indices'])//3 for m in meshes))
