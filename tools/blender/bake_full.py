import sys
from pathlib import Path as _Path
sys.path.insert(0, str(_Path(__file__).resolve().parent))
from paths import output_dir, source_blend, mapping
import bpy,os,json,time,shutil
P=str(output_dir());ROOT=os.path.dirname(P);bpy.ops.wm.open_mainfile(filepath=P+'/staging.blend',use_scripts=False);s=bpy.context.scene;s.cycles.samples=4;s.render.bake.margin=6;s.render.bake.use_clear=True;groups=json.load(open(P+'/groups.json'));materials=[];start=time.time()
for gi,g in enumerate(groups):
 ob=bpy.data.objects[g['id']];old=ob.data.materials[0];mid='full_mat_%03d'%gi;card=g['id'] and g['sourceMaterial'].startswith('Hybrid ');n0=old.node_tree.nodes if old.use_nodes else [];p0=next((n for n in n0 if n.type=='BSDF_PRINCIPLED'),None);em0=next((n for n in n0 if n.type=='EMISSION'),None)
 base=list(p0.inputs['Base Color'].default_value) if p0 else list(em0.inputs['Color'].default_value) if em0 else [0.7,0.7,0.7,1];rough=float(p0.inputs['Roughness'].default_value) if p0 else .6;metal=float(p0.inputs['Metallic'].default_value) if p0 else 0
 glass=bool(p0 and p0.inputs['Transmission Weight'].default_value>.1) or 'glass' in old.name.lower();unlit=card or bool(em0 and not p0);alpha=card and 'merchant' in old.name or glass
 record={'id':mid,'sourceMaterial':old.name,'baseColorFactor':base,'metallic':metal,'roughness':rough,'alphaMode':'BLEND' if alpha else 'OPAQUE','unlit':unlit,'doubleSided':card or glass,'notes':[]}
 if glass:record['baseColorFactor'][3]=.07;record['notes'].append('Approximate tinted alpha glass; no Blender refraction or Fresnel equivalence')
 if card:
  im=next(n.image for n in n0 if n.type=='TEX_IMAGE');filename='merchant-ship-muted.png' if 'merchant' in old.name else 'sea-calm.png';shutil.copy2(ROOT+'/scene/textures/'+filename,P+'/'+filename);record['baseColorTexture']=filename;record['baseColorFactor']=[1,1,1,1]
 else:
  bake=old.copy();ob.data.materials.clear();ob.data.materials.append(bake);n=bake.node_tree.nodes;l=bake.node_tree.links;p=next((x for x in n if x.type=='BSDF_PRINCIPLED'),None)
  # Preserve per-source generated coordinates after mesh joins.
  for tc in [x for x in n if x.type=='TEX_COORD']:
   for socket,attr in [('Generated','OriginalGenerated'),('Object','OriginalObject')]:
    links=list(tc.outputs[socket].links)
    if links:
     at=n.new('ShaderNodeAttribute');at.attribute_name=attr
     for li in links:l.new(at.outputs['Vector'],li.to_socket)
  passes=[]
  if p and p.inputs['Base Color'].is_linked:passes.append(('basecolor','EMIT',p.inputs['Base Color'],'sRGB'))
  if p and p.inputs['Roughness'].is_linked:passes.append(('roughness','EMIT',p.inputs['Roughness'],'Non-Color'))
  if p and p.inputs['Normal'].is_linked and not glass:passes.append(('normal','NORMAL',None,'Non-Color'))
  if passes:
   bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob;bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.1519,island_margin=.012);bpy.ops.object.mode_set(mode='OBJECT')
   out=next(x for x in n if x.type=='OUTPUT_MATERIAL');orig=out.inputs['Surface'].links[0].from_socket;emit=n.new('ShaderNodeEmission');target=n.new('ShaderNodeTexImage');n.active=target
   size=2048 if len(ob.data.polygons)>12000 else 1024
   for kind,typ,socket,cs in passes:
    im=bpy.data.images.new(mid+'_'+kind,width=size,height=size,alpha=False);im.colorspace_settings.name=cs;target.image=im;n.active=target
    if typ=='EMIT':
     for li in list(emit.inputs['Color'].links):l.remove(li)
     l.new(socket.links[0].from_socket,emit.inputs['Color']);l.new(emit.outputs[0],out.inputs['Surface'])
    else:l.new(orig,out.inputs['Surface'])
    bpy.ops.object.bake(type=typ,use_clear=True);filename=mid+'_'+kind+'.png';im.filepath_raw=P+'/'+filename;im.file_format='PNG';im.save();record[{'basecolor':'baseColorTexture','roughness':'roughnessTexture','normal':'normalTexture'}[kind]]=filename
    if kind=='basecolor':record['baseColorFactor']=[1,1,1,record['baseColorFactor'][3]]
   l.new(orig,out.inputs['Surface'])
  if not ob.data.uv_layers:ob.data.uv_layers.new(name='UVMap')
  if any(x.type=='MIX_SHADER' for x in n0):record['notes'].append('Original shader mix reduced to dominant surface for runtime')
 # Material for JSON-reimport reference: exactly exported maps and scalar channels.
 m=bpy.data.materials.new(mid);m.use_nodes=True;n=m.node_tree.nodes;n.clear();l=m.node_tree.links;out=n.new('ShaderNodeOutputMaterial');sh=n.new('ShaderNodeEmission') if unlit else n.new('ShaderNodeBsdfPrincipled');color=sh.inputs['Color'] if unlit else sh.inputs['Base Color'];color.default_value=record['baseColorFactor'];alphaout=None
 if 'baseColorTexture' in record:
  tex=n.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(P+'/'+record['baseColorTexture'],check_existing=True);l.new(tex.outputs['Color'],color);alphaout=tex.outputs['Alpha']
 if not unlit:
  sh.inputs['Metallic'].default_value=metal;sh.inputs['Roughness'].default_value=rough
  for field,socket in [('roughnessTexture','Roughness'),('normalTexture','Normal')]:
   if field in record:
    t=n.new('ShaderNodeTexImage');t.image=bpy.data.images.load(P+'/'+record[field],check_existing=True);t.image.colorspace_settings.name='Non-Color'
    if field=='normalTexture':nm=n.new('ShaderNodeNormalMap');l.new(t.outputs['Color'],nm.inputs['Color']);l.new(nm.outputs['Normal'],sh.inputs[socket])
    else:l.new(t.outputs['Color'],sh.inputs[socket])
 if alpha:
  tr=n.new('ShaderNodeBsdfTransparent');mix=n.new('ShaderNodeMixShader');mix.inputs[0].default_value=record['baseColorFactor'][3]
  if alphaout and card:l.new(alphaout,mix.inputs[0])
  l.new(tr.outputs[0],mix.inputs[1]);l.new(sh.outputs[0],mix.inputs[2]);l.new(mix.outputs[0],out.inputs['Surface'])
 else:l.new(sh.outputs[0],out.inputs['Surface'])
 ob.data.materials.clear();ob.data.materials.append(m);g['materialId']=mid;materials.append(record);open(P+'/materials_progress.json','w').write(json.dumps(materials,indent=2));print('BAKED',gi+1,len(groups),old.name,'maps',[k for k in record if k.endswith('Texture')],round(time.time()-start,1),flush=True)
open(P+'/materials.json','w').write(json.dumps(materials,indent=2));open(P+'/groups.json','w').write(json.dumps(groups,ensure_ascii=False,indent=2));bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=P+'/baked_staging.blend');print('BAKE_COMPLETE',flush=True)
