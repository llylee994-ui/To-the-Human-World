-- Pure validation/conversion. No native API or source-table mutation.
local V=require "v035.lab35.Math3"
local IDs=require "v035.lab35.Ids"
local C={format="d3-v035-mesh-v1"}
local function expect(value,message) assert(value,"mesh contract: "..message) end
local function array(a,name)
    expect(type(a)=="table",name.." must be an array")
    local n,count=#a,0
    for k in pairs(a) do
        expect(type(k)=="number" and k%1==0 and k>=1 and k<=n,name.." must be dense");count=count+1
    end
    expect(count==n,name.." has missing entries")
    return n
end
local function number(n,name,lo,hi)
    expect(V.Finite(n),name.." must be finite")
    if lo then expect(n>=lo and n<=hi,name.." out of range") end
    return n
end
local function vec(a,name,n)
    expect(array(a,name)==n,name.." size")
    for _,x in ipairs(a) do number(x,name) end
    return a
end
local function id(value,seen,name)
    expect(type(value)=="string" and #value>0,name.." missing id")
    expect(not seen[value],name.." duplicate id "..value);seen[value]=true
    return value
end
function C.ResourcePath(path)
    expect(type(path)=="string" and #path>0,"texture path missing")
    expect(not path:find("[\\:%z]") and path:sub(1,1)~="/","texture must be package-relative")
    for segment in (path.."/"):gmatch("(.-)/") do
        expect(segment~="" and segment~="." and segment~="..","unsafe texture path")
    end
    expect(path:lower():sub(-4)==".png","texture must be PNG")
    return path
end
local function geometry(m,scale,needsAttributes,progress)
    expect(not m.transform and not m.matrix and not m.matrixWorld,"world transforms must be baked")
    local count=array(m.positions,"positions");expect(count>=9 and count%3==0,"positions xyz count")
    local n=count/3;local positions,normals,uvs={},{},{}
    if needsAttributes then
        expect(array(m.normals,"normals")==count,"normal count mismatch")
        expect(array(m.uv0,"uv0")==n*2,"UV count mismatch")
    end
    for i=1,n do
        local k=(i-1)*3;local a={m.positions[k+1],m.positions[k+2],m.positions[k+3]}
        vec(a,"position",3);positions[i]=V.Convert(a,scale)
        if needsAttributes then
            local normal={m.normals[k+1],m.normals[k+2],m.normals[k+3]};vec(normal,"normal",3)
            expect(math.abs(V.Dot(normal,normal)-1)<.1,"normal must be normalized")
            normals[i]=V.Unit(V.Convert(normal))
            uvs[i]={number(m.uv0[i*2-1],"u"),number(m.uv0[i*2],"v")}
        end
        if progress and i%1024==0 then progress("validateVertices",i,n,m.id) end
    end
    local ic=array(m.indices,"indices");expect(ic>=3 and ic%3==0,"triangle index count")
    local indices={}
    for i,x in ipairs(m.indices) do
        expect(V.Finite(x) and x%1==0 and x>=0 and x<n,"zero-based index outside vertex range")
        indices[i]=x+1
        if progress and i%3072==0 then progress("validateIndices",i,ic,m.id) end
    end
    for i=1,ic,3 do
        local a,b,c=positions[indices[i]],positions[indices[i+1]],positions[indices[i+2]]
        local cross=V.Cross(V.Sub(b,a),V.Sub(c,a))
        -- A world-space epsilon rejects valid tiny letter strokes. Test the
        -- cross components directly, avoiding squared-area under/overflow.
        expect(V.Finite(cross[1]) and V.Finite(cross[2]) and V.Finite(cross[3]),"nonfinite triangle cross product")
        expect(cross[1]~=0 or cross[2]~=0 or cross[3]~=0,"degenerate triangle")
        if progress and i%3072==1 then progress("validateTriangles",i,ic,m.id) end
    end
    return {positions=positions,normals=normals,uv0=uvs,indices=indices}
end
function C.Prepare(data,limits)
    limits=limits or {};expect(type(data)=="table","package object required")
    expect(data.format==C.format,"unsupported format")
    expect(data.axis=="BLENDER_Z_UP","source must be Blender Z-up; refuse double conversion")
    local scale=number(data.unitScale,"unitScale",1e-8,1e8)
    local out={format=data.format,axis="URHO_Y_UP",meshes={},materials={},cameras={},anchors={},
        stats={meshes=0,triangles=0,sourceVertices=0,expandedVertices=0},warnings={}}
    local progress=limits.onProgress
    local seen={};array(data.materials,"materials")
    for _,m in ipairs(data.materials) do
        local key=id(m.id,seen,"material");vec(m.baseColor,"baseColor",4)
        local color={};for i,x in ipairs(m.baseColor) do color[i]=number(x,"baseColor",0,1) end
        expect(m.alphaMode=="OPAQUE" or m.alphaMode=="BLEND" or m.alphaMode=="MASK","alphaMode")
        expect(type(m.doubleSided)=="boolean","doubleSided must be boolean")
        expect(m.cullMode==nil or m.cullMode=="CW" or m.cullMode=="CCW" or m.cullMode=="NONE","invalid explicit cullMode")
        if m.alphaMode=="MASK" then number(m.alphaCutoff,"alphaCutoff",0,1) end
        out.materials[key]={id=key,baseColor=color,roughness=number(m.roughness,"roughness",0,1),
            metallic=number(m.metallic,"metallic",0,1),alphaMode=m.alphaMode,alphaCutoff=m.alphaCutoff,
            doubleSided=m.doubleSided,cullMode=m.cullMode,unlit=m.unlit==true,baseColorTexture=m.baseColorTexture and C.ResourcePath(m.baseColorTexture)}
        if m.normalTexture then
            expect(not m.unlit,"normal texture on unlit material is unsupported")
            expect(m.normalMapConvention=="tangent-space OpenGL +Y; requires tangent basis derived from uv0","normal map convention must explicitly declare tangent-space OpenGL +Y")
            expect(type(m.textureColorSpaces)=="table" and m.textureColorSpaces.normalTexture=="linear","normal texture must be linear")
            out.materials[key].normalTexture=C.ResourcePath(m.normalTexture)
            out.materials[key].normalMapConvention=m.normalMapConvention
        end
        if m.roughMetalOcclusionTexture then
            expect(not m.unlit and (m.alphaMode=="OPAQUE" or m.alphaMode=="BLEND") and m.normalTexture,"packed PBR texture requires opaque or blended normal-mapped material")
            expect(type(m.textureColorSpaces)=="table" and m.textureColorSpaces.roughMetalOcclusionTexture=="linear","packed PBR texture must be linear")
            out.materials[key].roughMetalOcclusionTexture=C.ResourcePath(m.roughMetalOcclusionTexture)
        end
        expect(m.emissiveStrength==nil or m.emissiveFactor,"emissive strength requires factor")
        if m.emissiveFactor then
            vec(m.emissiveFactor,"emissiveFactor",3)
            local e={};for i,x in ipairs(m.emissiveFactor) do e[i]=number(x,"emissiveFactor",0,1) end
            out.materials[key].emissiveFactor=e
            out.materials[key].emissiveStrength=number(m.emissiveStrength or 1,"emissiveStrength",0,100000)
        end
        if m.emissiveTexture then
            expect(m.emissiveFactor,"emissive texture requires factor")
            expect(not m.unlit and m.normalTexture and m.roughMetalOcclusionTexture,"emissive texture requires lit normal and RMA maps")
            expect(type(m.textureColorSpaces)=="table" and m.textureColorSpaces.emissiveTexture=="sRGB","emissive texture must be sRGB")
            out.materials[key].emissiveTexture=C.ResourcePath(m.emissiveTexture)
        end
        if progress then progress("validateMaterials",0,#data.materials,key) end
    end
    seen={}
    local meshCount=array(data.meshes,"meshes")
    if limits.meshCatalog then
        expect(meshCount==0,"stream header cannot include inline meshes")
        expect(array(limits.meshCatalog,"meshCatalog")>0,"empty mesh catalog")
        for _,m in ipairs(limits.meshCatalog) do
            id(m.id,seen,"mesh catalog");expect(out.materials[m.materialId],"catalog material does not exist")
        end
    else expect(meshCount>0,"empty scene") end
    for _,m in ipairs(data.meshes) do
        local key=id(m.id,seen,"mesh");expect(out.materials[m.materialId],"unknown materialId")
        expect(out.stats.expandedVertices+array(m.indices,"indices")<=(limits.maxExpandedVertices or 6000000),"expanded vertex budget exceeded")
        local g=geometry(m,scale,true,progress);g.id=key;g.materialId=m.materialId;g.sourceObjects=m.sourceObjects
        out.meshes[#out.meshes+1]=g
        out.stats.sourceVertices=out.stats.sourceVertices+#g.positions
        out.stats.expandedVertices=out.stats.expandedVertices+#g.indices
        out.stats.triangles=out.stats.triangles+#g.indices/3
        expect(out.stats.expandedVertices<=(limits.maxExpandedVertices or 6000000),"expanded vertex budget exceeded")
        if progress then progress("validateMeshes",#out.meshes,#data.meshes,key) end
    end
    local meshIds=seen
    out.stats.meshes=#out.meshes
    seen={};array(data.anchors,"anchors")
    for _,a in ipairs(data.anchors) do
        local key=id(a.id,seen,"anchor");expect(IDs[key],"unknown semantic anchor")
        local entry={id=key,position=V.Convert(vec(a.position,"anchor",3),scale)}
        if a.visibleMeshIds then
            entry.visibleMeshIds={};local members={}
            expect(array(a.visibleMeshIds,"visibleMeshIds")>0,"empty visibleMeshIds")
            for _,meshId in ipairs(a.visibleMeshIds) do
                expect(meshIds[meshId],"anchor references missing visible mesh "..tostring(meshId))
                expect(not members[meshId],"duplicate anchor visible mesh");members[meshId]=true
                entry.visibleMeshIds[#entry.visibleMeshIds+1]=meshId
            end
        end
        if a.proxy then
            expect(type(a.proxy)=="table","proxy object")
            if a.proxy.kind=="sphere" then
                expect(key~="home.merchantShip","ship requires semantic triangle silhouette, not a whole-card proxy")
                entry.proxy={kind="sphere",center=V.Convert(vec(a.proxy.center or a.position,"proxy center",3),scale),
                    radius=number(a.proxy.radius,"radius",1e-8,1e8)*scale}
            elseif a.proxy.kind=="triangles" then
                entry.proxy=geometry(a.proxy,scale,false);entry.proxy.kind="triangles"
            else error("mesh contract: unsupported proxy kind") end
        else out.warnings[#out.warnings+1]=key..": no semantic proxy; picking disabled" end
        out.anchors[#out.anchors+1]=entry
    end
    seen={};array(data.cameras,"cameras")
    for _,c in ipairs(data.cameras) do
        local key=id(c.id or c.name,seen,"camera")
        expect(key=="Home" or key=="Brew" or key=="Seaside","camera name")
        local f,u=vec(c.forward,"camera forward",3),vec(c.up,"camera up",3)
        expect(math.abs(V.Dot(f,f)-1)<.01 and math.abs(V.Dot(u,u)-1)<.01,"camera vectors must be normalized")
        expect(math.abs(V.Dot(f,u))<.01,"camera vectors must be orthogonal")
        expect(c.projection=="perspective" or c.projection=="orthographic","camera projection")
        local entry={id=key,position=V.Convert(vec(c.position,"camera position",3),scale),forward=V.Convert(f),up=V.Convert(u),projection=c.projection}
        if c.projection=="perspective" then
            expect(c.fovAxis=="vertical" or c.fovAxis=="horizontal","fovAxis")
            expect(c.fovUnit=="degrees" or c.fovUnit=="radians","fovUnit")
            local radians=number(c.fov,"fov")*(c.fovUnit=="degrees" and math.pi/180 or 1)
            expect(radians>0 and radians<math.pi,"fov range");entry.fovRadians=radians;entry.fovAxis=c.fovAxis
        else entry.orthoHeight=number(c.orthoScale,"orthoScale",1e-8,1e8)*scale end
        entry.nearClip=number(c.nearClip or .05,"nearClip",1e-8,1e8)*scale
        entry.farClip=number(c.farClip or 500,"farClip",1e-8,1e10)*scale
        expect(entry.farClip>entry.nearClip,"camera clip range")
        out.cameras[key]=entry
    end
    expect(out.cameras.Home,"Home camera required")
    return out
end
return C
