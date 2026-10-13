-- Exercises the actual NativeGeometry functions against recorded API substitutes.
-- Native/GPU behavior still requires the real runtime.
local T={}
function T.Run(check)
    local calls={};local missing=false
    local vec={};vec.__index=vec
    function vec:DotProduct(v) return self.x*v.x+self.y*v.y+self.z*v.z end
    function vec.__sub(a,b) return Vector3(a.x-b.x,a.y-b.y,a.z-b.z) end
    Vector3=function(x,y,z) return setmetatable({x=x,y=y,z=z},vec) end
    Vector2=function(x,y) return {x=x,y=y} end
    Color=function(r,g,b,a) return {r,g,b,a} end
    Variant=function(v) return v end
    TU_DIFFUSE=0;TU_NORMAL=1;CULL_NONE=0;TRIANGLE_LIST=0
    cache={GetResource=function(_,kind,path)
        calls[#calls+1]={kind=kind,path=path}
        if missing and kind=="Texture2D" then return nil end
        return {kind=kind,path=path}
    end}
    Material={new=function()
        local m={parameters={},textures={}}
        function m:SetTechnique(_,t) self.technique=t end
        function m:SetTexture(unit,t) self.textures[unit]=t;if unit==TU_DIFFUSE then self.texture=t end end
        function m:SetShaderParameter(k,v) self.parameters[k]=v end
        function m:SetCullMode(v) self.cull=v end
        return m
    end}
    local rootCount,vertices,commits,removed=0,{},0,false
    local tangentMode,tangentCalls="ok",0
    local function node()
        local n={}
        function n:CreateChild() return node() end
        function n:CreateComponent(kind)
            assert(kind=="CustomGeometry")
            local g={}
            function g:BeginGeometry(index,mode) assert(index==0 and mode==TRIANGLE_LIST) end
            function g:SetMaterial(m) self.material=m end
            function g:DefineVertex(v) vertices[#vertices+1]={position=v} end
            function g:DefineNormal(v) vertices[#vertices].normal=v end
            function g:DefineTexCoord(v) vertices[#vertices].uv=v end
            if tangentMode~="absent" then
                function g:GenerateTangents()
                    assert(not self.committed and vertices[#vertices].normal and vertices[#vertices].uv)
                    tangentCalls=tangentCalls+1;self.tangents=true;return tangentMode~="failure"
                end
            end
            function g:Commit() self.committed=true;commits=commits+1 end
            return g
        end
        function n:Remove() removed=true end
        return n
    end
    local scene={CreateChild=function() rootCount=rootCount+1;return node() end}
    local native=require "lab35.NativeGeometry"
    local data=require("lab35.tests.Fixture").New()
    data.materials[1].baseColorTexture="textures/rgba.png"
    data.materials[1].alphaMode="BLEND";data.materials[1].doubleSided=true
    local loaded=require("lab35.MeshLoader").Load(data,native.New(scene,"probe"))
    local m=loaded.materials.test
    check("native adapter selects existing PBR alpha texture technique",m.technique.path=="Techniques/PBR/PBRDiffAlpha.xml" and m.texture.path=="probe/textures/rgba.png")
    check("native adapter emits normals/UV before commit",commits==1 and #vertices==3 and vertices[3].position.z==-1 and vertices[3].normal.y==1 and vertices[3].uv.y==1)
    check("native adapter preserves metallic/roughness and double-sided flag",m.parameters.Metallic==0 and m.parameters.Roughness==.7 and m.cull==CULL_NONE)
    missing=true;local before=rootCount
    check("missing texture fails before scene creation",not pcall(require("lab35.MeshLoader").Load,data,native.New(scene,"probe")) and rootCount==before)
    missing=false;data.materials[1].alphaMode="MASK";data.materials[1].alphaCutoff=.5
    check("unsupported MASK fails explicitly before scene creation",not pcall(require("lab35.MeshLoader").Load,data,native.New(scene,"probe")) and rootCount==before)
    local normal=data.materials[1];normal.alphaMode="BLEND";normal.normalTexture="textures/normal.png"
    normal.normalMapConvention="tangent-space OpenGL +Y; requires tangent basis derived from uv0";normal.textureColorSpaces={normalTexture="linear"}
    local normalLoaded=require("lab35.MeshLoader").Load(data,native.New(scene,"full"))
    m=normalLoaded.materials.test
    check("normal alpha uses verified technique and correct texture units",m.technique.path=="Techniques/PBR/PBRDiffNormalAlpha.xml" and m.textures[TU_NORMAL].path=="full/textures/normal.png" and m.texture.sRGB and not m.textures[TU_NORMAL].sRGB)
    check("normal geometry generates tangents after attributes before Commit",tangentCalls==1 and commits==2)
    normal.baseColorTexture=nil;normal.alphaMode="OPAQUE"
    m=require("lab35.MeshLoader").Load(data,native.New(scene,"full")).materials.test
    check("constant-color normal material binds white diffuse fallback",m.technique.path=="Techniques/PBR/PBRDiffNormal.xml" and m.texture.path=="full/_lab/default-white.png" and m.parameters.MatDiffColor[2]==.5)
    for _,mode in ipairs({"failure","absent"}) do
        tangentMode=mode;removed=false;local committed=commits
        check("tangent API "..mode.." rolls back without Commit",not pcall(require("lab35.MeshLoader").Load,data,native.New(scene,"full")) and removed and commits==committed)
    end
    tangentMode="ok"
    local c={};local n={worldPosition=Vector3(0,0,0),worldDirection=Vector3(0,0,1),LookAt=function(self,target,up) self.target=target;self.up=up end}
    local pose=loaded.prepared.cameras.Home
    native.ApplyCamera(c,n,pose,16/9)
    local expected=math.deg(2*math.atan(math.tan(pose.fovRadians/2)/(16/9)))
    check("horizontal FOV converted to native vertical FOV",math.abs(c.fov-expected)<1e-8 and n.target.z==4 and n.up.y==1)
    c.WorldToScreenPoint=function() return {x=.25,y=.75} end
    c.GetScreenRay=function() return {direction=n.worldDirection} end
    c.view=setmetatable({}, {__mul=function(_,v) return v end})
    c.projection={m00=.5,m01=0,m02=0,m03=0,m10=0,m11=.5,m12=0,m13=0,m30=0,m31=0,m32=1,m33=0}
    local rect={x=10,y=20,w=1000,h=600}
    local p=native.Project(c,n,{-10,-10,10},rect)
    check("native projection maps to active screen rectangle",p.x==260 and p.y==470)
    check("native projection suppresses behind-camera and far-clipped anchors",not native.Project(c,n,{0,0,-10},rect) and not native.Project(c,n,{0,0,1000},rect))
    c.view=setmetatable({}, {__mul=function(_,v) return Vector3(v.x,v.y,-v.z) end})
    c.projection.m32=-1
    c.WorldToScreenPoint=function() return {x=0,y=1} end -- observed RH clamp
    local rh=native.Project(c,n,{-10,-10,10},rect)
    check("RH camera projects through signed native clip W despite WorldToScreen clamp",rh and rh.x==260 and rh.y==470)
    local semantic=require "lab35.SemanticOcclusion"
    local parcel={id="home.caseFile",visibleMeshIds={"full_group_044_000"}}
    check("measured parcel cord hit belongs to the tied paper stack",semantic.Owns(parcel,"full_group_017_000",{4.1273475,1.9647179,.4837088}))
    check("shared rope mesh outside parcel bounds remains an occluder",not semantic.Owns(parcel,"full_group_017_000",{4.1273475,1.9647179,1.5}))
    check("foreign mesh inside parcel bounds remains an occluder",not semantic.Owns(parcel,"full_group_012_003",{4.1273475,1.9647179,.4837088}))
end
return T
