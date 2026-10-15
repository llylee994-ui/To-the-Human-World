-- Semantic ownership comes from each entry's explicit visible meshes.
-- The old parcel and its shared cord geometry have been removed.
local S={}
function S.Owns(anchor,meshId,point)
    for _,id in ipairs(anchor.visibleMeshIds) do if id==meshId then return true end end
    return false
end
return S
