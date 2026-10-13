-- Metadata-only checks; all payloads stay package-relative and load separately.
local P={}
function P.Path(path,suffix)
    assert(type(path)=="string" and path~="" and not path:find("[\\:%z]") and path:sub(1,1)~="/","unsafe package path")
    for segment in (path.."/"):gmatch("(.-)/") do assert(segment~="" and segment~="." and segment~="..","unsafe package segment") end
    if suffix then assert(path:lower():sub(-#suffix)==suffix,"wrong package file extension") end
    return path
end
function P.Catalog(manifest)
    assert(type(manifest)=="table" and type(manifest.meshFiles)=="table" and #manifest.meshFiles>0,"manifest.meshFiles required")
    local rows,ids,paths={}, {},{}
    local count=0
    for k in pairs(manifest.meshFiles) do
        assert(type(k)=="number" and k%1==0 and k>=1 and k<=#manifest.meshFiles,"meshFiles must be a dense array");count=count+1
    end
    assert(count==#manifest.meshFiles,"meshFiles has missing entries")
    for _,m in ipairs(manifest.meshFiles) do
        assert(type(m)=="table","meshFiles entries require path, id, materialId and counts")
        local path=P.Path(m.path or m.file,".json")
        assert(type(m.id)=="string" and m.id~="" and not ids[m.id],"duplicate/missing mesh ID")
        assert(not paths[path:lower()],"duplicate mesh path on Windows");paths[path:lower()]=true;ids[m.id]=true
        assert(type(m.materialId)=="string" and m.materialId~="","catalog materialId required")
        local vertices=m.vertices or m.vertexCount;local triangles=m.triangles or m.triangleCount
        assert(type(vertices)=="number" and vertices%1==0 and vertices>=3 and vertices<=60000,"each mesh file must contain 3..60000 source vertices")
        assert(type(triangles)=="number" and triangles%1==0 and triangles>0,"positive triangle count required")
        rows[#rows+1]={path=path,id=m.id,materialId=m.materialId,vertices=vertices,triangles=triangles,sha256=m.sha256}
    end
    return rows
end
return P
