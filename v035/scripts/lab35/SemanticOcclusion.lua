-- Shared material batches are not semantic objects. Recognize only the parcel
-- cord inside the measured paper-stack bounds; never whitelist the shared mesh.
local S={}
function S.Owns(anchor,meshId,point)
    for _,id in ipairs(anchor.visibleMeshIds) do if id==meshId then return true end end
    if anchor.id~="home.caseFile" or meshId~="full_group_017_000" or not point then return false end
    -- Full v035 source full_group_044_000 bounds, converted (x,z,-y), plus 3.5 cm.
    local lo={3.7818199,1.8179999,-.1177720}
    local hi={4.5434324,2.0219999,.5500729}
    for i=1,3 do if point[i]<lo[i] or point[i]>hi[i] then return false end end
    return true
end
return S
