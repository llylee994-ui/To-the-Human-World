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
 for _,node in ipairs(root:GetChildren()) do
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
 point('RestoredLanternPoint',Vector3(-.2,3.6,-3),Color(1,.40,.10),1.3,2.8,true)
 point('SoftRoomFillApproximation',Vector3(1.3,4.2,2),Color(1,.95,.86),40,8,false)
 return {zone=z}
end
return H
