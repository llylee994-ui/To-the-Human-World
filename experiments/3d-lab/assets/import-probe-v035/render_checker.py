import bpy,os
P=os.path.dirname(os.path.abspath(__file__));bpy.ops.wm.open_mainfile(filepath=P+'/probe_reimport.blend',use_scripts=False);s=bpy.context.scene;im=bpy.data.images.load(P+'/uv_checker.png',check_existing=False)
for m in bpy.data.materials:
 if m.name.startswith('mat_'):
  for n in m.node_tree.nodes:
   if n.type=='TEX_IMAGE' and n.image and n.image.name not in ['sea-calm.png','merchant-ship-muted.png']:n.image=im
s.cycles.samples=8;s.render.filepath=P+'/uv_checker_preview.png';bpy.ops.render.render(write_still=True)
