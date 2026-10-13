-- Official Image/Texture2D API, equal-color test. No scene assets or player data.
local frame=0
function Start()
 local scene=Scene();scene:CreateComponent('Octree')
 local zone=scene:CreateChild('Zone'):CreateComponent('Zone')
 zone.boundingBox=BoundingBox(Vector3(-100,-100,-100),Vector3(100,100,100))
 zone:SetAutoExposureEnabled(false);zone:SetTonemapMode(TONEMAP_MODE_NONE)
 zone:SetFogDensity(0);zone:SetHeightFog(false);zone:SetVolumetricFogEnabled(false)
 local im=Image:new();assert(im:SetSize(4,4,4))
 for y=0,3 do for x=0,3 do im:SetPixel(x,y,Color(128/255,128/255,128/255,1)) end end
 local late=Texture2D:new();late:SetNumLevels(1);assert(late:SetData(im));late:SetSRGB(true)
 local early=Texture2D:new();early:SetNumLevels(1);early:SetSRGB(true);assert(early:SetData(im))
 for i=1,3 do
  local n=scene:CreateChild('Gray'..i);n.position=Vector3((i-2)*2,0,0);n.scale=Vector3(1.7,1.7,.2)
  local obj=n:CreateComponent('StaticModel');obj:SetModel(cache:GetResource('Model','Models/Box.mdl'))
  local mat=Material:new();mat:SetTechnique(0,cache:GetResource('Technique',i==1 and 'Techniques/NoTextureUnlit.xml' or 'Techniques/DiffUnlit.xml'))
  local c=i==1 and .2158605 or 1;mat:SetShaderParameter('MatDiffColor',Variant(Color(c,c,c,1)))
  if i>1 then mat:SetTexture(TU_DIFFUSE,i==2 and late or early) end
  obj:SetMaterial(mat)
 end
 local cn=scene:CreateChild('Camera');cn.position=Vector3(0,0,-6);cn:LookAt(Vector3(0,0,0))
 local cam=cn:CreateComponent('Camera');cam.orthographic=true;cam.orthoSize=4.5;cam.nearClip=.1;cam.farClip=100
 renderer.hdrRendering=true;renderer:SetViewport(0,Viewport:new(scene,cam))
 SubscribeToEvent('EndRendering','SrgbFrame')
 print('[SRGB ORDER] left=linear constant .2158605; middle=SetData then SRGB; right=SRGB then SetData')
end
function SrgbFrame()
 frame=frame+1
 if frame>=20 and frame%10==0 then
  local im=Image();local ok=graphics:TakeScreenShot(im);if ok then ok=im:SavePNG(os.getenv('D3_CLOUD_OUTPUT')..'/srgb-order.png') end
  print('[SRGB CAPTURE]',ok,frame)
  if ok or frame>=120 then engine:Exit() end
 end
end
