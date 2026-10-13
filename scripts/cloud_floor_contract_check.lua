-- A bounded metadata/material test. It does not load the full geometry or write saves.
function Start()
 local R=require('v035.lab35.ResourceReader')
 local raw=cjson.decode(R.Read(function(n)return cache:GetFile(n)end,'v035-full/scene.json',4194304))
 local catalog=require('v035.lab35.ScenePackage').Catalog({meshFiles=raw.meshFiles})
 local header=require('v035.lab35.ProbeAdapter').Convert(raw,{meshCatalog=catalog})
 local prepared=require('v035.lab35.MeshContract').Prepare(header,{meshCatalog=catalog})
 local m=assert(prepared.materials.full_mat_018);assert(m.cullMode=='CW')
 local api=require('v035.lab35.NativeGeometry').New(Scene(),'v035-full',{flipV=true})
 local material=api.Material(m);assert(material:GetCullMode()==CULL_CW)
 print('[FLOOR CONTRACT PASS] metadata -> adapter -> contract -> native cull mode CW')
 engine:Exit()
end
