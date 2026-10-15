-- Native, calibrated lighting approximation. Blender wattage is not copied as engine brightness.
local H={}
function H.Apply(scene,opts)
 opts=opts or {}
 local z=scene:GetChild('FullSceneAmbient'):GetComponent('Zone')
 z.ambientSource=AMBIENT_COLOR;z.ambientColor=opts.ambient or Color(.035,.03,.025)
 z:SetFogDensity(0);z:SetHeightFog(false);z:SetVolumetricFogEnabled(false)
 z:SetAttribute('Env Spec Texture',Variant(ResourceRef('TextureCube','Cube/Dusk/DuskSpecularHDR_QualityLow.xml')))
 z:SetAttribute('Env texture spec intensity',Variant(VAR_FLOAT,'0.6'))
 local n=scene:GetChild('FullSceneSun');n.direction=Vector3(.4682927,-.4682927,.7492687)
 local l=n:GetComponent('Light');l.brightness=1.25;l.color=Color(1,.76,.49);l.castShadows=true
 local root=scene:GetChild('v035.imported-scene')
 local clockGlassChunks=0
 for _,node in ipairs(root:GetChildren()) do
  -- Only the selected clock glass; opaque shadow pass otherwise darkens its dial.
  if node.name=='clock.01' or node.name:match('^clock%.01:%d+$') then
   node:GetComponent('CustomGeometry').castShadows=false;clockGlassChunks=clockGlassChunks+1
  end
  if node.name:find('full_group_056_',1,true)==1 or node.name:find('full_group_057_',1,true)==1 then node:GetComponent('CustomGeometry').castShadows=false end
  if node.name:find('full_group_020_',1,true)==1 then node:GetComponent('CustomGeometry'):GetMaterial(0):SetShaderParameter('MatEmissiveColor',Variant(Vector3(4,.8,.032))) end
 end
 local function point(name,pos,color,brightness,range,shadow)
  assert(not scene:GetChild(name),'lighting preset must be applied once')
  local node=scene:CreateChild(name);node.position=pos
  local light=node:CreateComponent('Light');light.lightType=LIGHT_POINT;light:SetUsePhysicalValues(false)
  light.brightness=brightness;light.range=range;light.color=color;light.castShadows=shadow
  return light
 end
 point('RestoredLanternPoint',Vector3(-.20078,3.67093,-2.9405),Color(1,.40,.10),1.3,2.8,true)
 point('SoftRoomFillApproximation',Vector3(1.3,4.2,2),Color(1,.95,.86),40,8,false)
 -- Small local shelf fill improves ingredient readability without lifting the whole room.
 point('IngredientShelfFill',Vector3(2.65,4.05,-1.7),Color(1,.95,.88),2,2.2,false)
 -- Independently calibrated weak local net fill; no global exposure or material changes.
 local netFill
 if opts.netFill~=false then
  netFill=point('RestoredNetLocalFill',Vector3(-3.12,2.75,-1.25),Color(1,.9,.78),.8,1.9,false)
 end
 local selectedLamp=require('v035.lab35.SelectedLampLighting').Apply(scene)
 return {zone=z,netFill=netFill,selectedLamp=selectedLamp,clockGlassChunks=clockGlassChunks}
end
return H
