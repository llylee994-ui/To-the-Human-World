-- Call once from HarborLighting.Apply after importing the selected lamp.
-- Geometry-derived relocated bulb position and letter-paper target; no global light changes.
local M={}
local active=setmetatable({}, {__mode="k"})
function M.Apply(scene,bulbPosition,bulbMeshId)
 if active[scene] then return active[scene] end
 assert(not scene:GetChild('SelectedDeskLampSpot'),'lamp light already exists')
 local root=assert(scene:GetChild('v035.imported-scene'),'lamp import root missing')
 -- MeshLoader names each drawable <catalog mesh id>:<first expanded index>.
 -- The default catalog id is pinned by the selected bulb's exported sourceObjects.
 local meshId=bulbMeshId or 'selected-lamp.01';local geometries={}
 for _,child in ipairs(root:GetChildren()) do
  local catalogId,first=child.name:match('^(.*):(%d+)$')
  if child.name==meshId or (catalogId==meshId and tonumber(first)>=1) then
   local geometry=assert(child:GetComponent('CustomGeometry'),'bulb drawable lacks CustomGeometry')
   geometries[#geometries+1]={geometry=geometry,previousShadow=geometry.castShadows,name=child.name}
  end
 end
 assert(#geometries>0,'lamp bulb drawable chunks missing for catalog mesh '..meshId)
 local bulb=bulbPosition or Vector3(2.627664,2.331373574979,-1.803250)
 local target=Vector3(2.36,1.854,-0.65)
 local n=scene:CreateChild('SelectedDeskLampSpot')
 local handle={node=n,bulbMeshId=meshId,glassChunks=geometries};local stopped=false
 function handle.Stop()
  if stopped then return end
  stopped=true;local errors={}
  for _,row in ipairs(geometries) do
   local ok,err=pcall(function() row.geometry.castShadows=row.previousShadow end)
   if not ok then errors[#errors+1]='restore '..row.name..': '..tostring(err) end
  end
  local ok,err=pcall(function() n:Remove() end);if not ok then errors[#errors+1]='remove lamp: '..tostring(err) end
  active[scene]=nil
  if #errors>0 then error('lamp cleanup incomplete: '..table.concat(errors,'; ')) end
 end
 active[scene]=handle;for _,row in ipairs(geometries) do row.geometry.castShadows=false end
 n.position=bulb;n.direction=(target-bulb):Normalized()
 local l=n:CreateComponent('Light');handle.light=l;l.lightType=LIGHT_SPOT;l:SetUsePhysicalValues(false)
 l.fov=100;l:SetAttribute('Outer Cone Angle',Variant(VAR_FLOAT,'50'));l:SetAttribute('Inner Cone Angle',Variant(VAR_FLOAT,'35'))
 l.brightness=2.4;l.range=1.5;l.color=Color(1,.67,.32);l.castShadows=false
 return handle
end
function M.Stop(scene) if active[scene] then active[scene].Stop() end end
return M
