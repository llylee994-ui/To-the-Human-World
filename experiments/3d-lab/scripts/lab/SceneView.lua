-- Engine-specific renderer derived from scaffold-3d-scene.lua lifecycle.
local V={}
local palette={
    wood={{0.34,0.17,0.08},0,0.82},woodLight={{0.58,0.35,0.16},0,0.78},darkWood={{0.17,0.085,0.045},0,0.85},
    plaster={{0.76,0.65,0.45},0,0.97},copper={{0.67,0.31,0.13},0.85,0.46},iron={{0.14,0.12,0.10},0.7,0.65},
    ceramic={{0.70,0.50,0.28},0,0.27},greenGlaze={{0.21,0.34,0.24},0,0.3},paper={{0.88,0.80,0.61},0,0.94},
    sail={{0.92,0.85,0.66},0,0.88},rope={{0.57,0.48,0.31},0,0.90},herbal={{0.20,0.35,0.18},0,0.22},
    flame={{1.0,0.42,0.08},0,0.5},sea={{0.19,0.38,0.42},0.2,0.25},coast={{0.30,0.40,0.35},0,0.94},
}
local function vector(v) return Vector3(v[1],v[2],v[3]) end
function V.New(world,rig)
    local scene=Scene(); local octree=scene:CreateComponent("Octree")
    local group=scene:CreateChild("LightGroup")
    local lighting=assert(cache:GetResource("XMLFile","LightGroup/Dusk.xml"),"Missing LightGroup/Dusk.xml")
    group:LoadXML(lighting:GetRoot())
    local zone=group:GetComponent("Zone",true)
    if zone then zone.fogStart=26; zone.fogEnd=85; zone.fogColor=Color(0.64,0.65,0.58) end
    local sun=group:GetComponent("Light",true)
    if sun then sun.color=Color(1.0,0.81,0.56); sun.brightness=2.6; sun.castShadows=true end
    renderer.hdrRendering=true
    local mats={}
    for name,p in pairs(palette) do
        local mat=Material:new()
        mat:SetTechnique(0,assert(cache:GetResource("Technique","Techniques/PBR/PBRNoTexture.xml")))
        mat:SetShaderParameter("MatDiffColor",Variant(Color(p[1][1],p[1][2],p[1][3],1)))
        mat:SetShaderParameter("Metallic",Variant(p[2])); mat:SetShaderParameter("Roughness",Variant(p[3]))
        if name=="flame" then mat:SetShaderParameter("MatEmissiveColor",Variant(Color(2,0.6,0.1))) end
        mats[name]=mat
    end
    local models={}
    local stats={meshes=#world.meshes,materials=0,uniqueModels=0,vertices=0,indices=0,textures=0}
    for _ in pairs(mats) do stats.materials=stats.materials+1 end
    for _,part in ipairs(world.meshes) do
        local key=part.shape..(part.params and ":"..part.id or "")
        local model=models[key]
        if not model then
            local geom
            if part.shape=="box" then geom=BoxGeometry(1,1,1)
            elseif part.shape=="sphere" then geom=SphereGeometry(0.5,16,12)
            elseif part.shape=="cylinder" then geom=CylinderGeometry(0.5,0.5,1,16)
            elseif part.shape=="torus" then geom=TorusGeometry(table.unpack(part.params))
            elseif part.shape=="lathe" or part.shape=="sail" then
                local points={}; for _,p in ipairs(part.params) do points[#points+1]=Vector2(p[1],p[2]) end
                geom=part.shape=="lathe" and LatheGeometry(points,32) or ExtrudeGeometry(points,0.025)
            elseif part.shape=="hull" then
                local points={}; for _,p in ipairs(part.params) do points[#points+1]=vector(p) end
                geom=ConvexGeometry(points)
            else error("Unknown lab geometry: "..part.shape) end
            stats.vertices=stats.vertices+geom:GetVertexCount(); stats.indices=stats.indices+geom:GetIndexCount()
            model=geom:ToModel(); models[key]=model; stats.uniqueModels=stats.uniqueModels+1
        end
        local node=scene:CreateChild(part.id); node.position=vector(part.position); node.scale=vector(part.size)
        node.rotation=Quaternion(part.rotation[1],part.rotation[2],part.rotation[3])
        local drawable=node:CreateComponent("StaticModel"); drawable.model=model; drawable.material=mats[part.material]
        drawable.castShadows=part.id~="sea"
    end
    local fire=scene:CreateChild("WarmStoveLight"); fire.position=Vector3(1.8,1.4,1.2)
    local light=fire:CreateComponent("Light"); light.lightType=LIGHT_POINT; light.color=Color(1,0.56,0.25); light.brightness=0.7; light.range=3
    local cameraNode=scene:CreateChild("LabCamera"); local camera=cameraNode:CreateComponent("Camera")
    camera.nearClip=rig.nearClip; camera.farClip=110
    renderer:SetViewport(0,Viewport:new(scene,camera))
    local view={scene=scene,camera=camera,stats=stats}
    function view.Update()
        cameraNode.position=vector(rig.position); cameraNode:LookAt(vector(rig.look))
        local aspect=graphics:GetWidth()/math.max(1,graphics:GetHeight())
        -- Preserve horizontal framing on 4:3 while keeping 16:9/21:9 natural.
        camera.fov=math.deg(2*math.atan(math.tan(math.rad(rig.fov)/2)*math.max(1,(16/9)/aspect)))
    end
    function view.Ray(nx,ny)
        local ray=camera:GetScreenRay(nx,ny)
        return {ray.origin.x,ray.origin.y,ray.origin.z},{ray.direction.x,ray.direction.y,ray.direction.z}
    end
    local function owner(name)
        if name:match("^stove%.") then return "home.stove" end
        if name:match("^net%.") then return "home.net" end
        if name:match("^ship%.") then return "home.merchantShip" end
        if name=="paper" then return "home.letterPaper" end
        if name:match("^drawer%.") then return "home.drawer" end
        return false
    end
    function world.IsOccluded(origin,direction,distance,id)
        local hit=octree:RaycastSingle(Ray(vector(origin),vector(direction)),RAY_TRIANGLE,distance+0.02,DRAWABLE_GEOMETRY)
        return hit and hit.node and hit.distance<distance-0.015 and owner(hit.node.name)~=id
    end
    view.Update()
    print("[D3-LAB scene] "..cjson.encode(stats))
    return view
end
return V
