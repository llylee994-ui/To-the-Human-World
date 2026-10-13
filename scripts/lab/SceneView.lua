-- Engine-specific renderer derived from scaffold-3d-scene.lua lifecycle.
local V={}
local palette={
    wood={{1.0,0.97,0.92},0,0.62},woodLight={{1.13,1.10,1.02},0,0.56},darkWood={{0.67,0.64,0.60},0,0.68},
    plaster={{1,1,1},0,0.97},copper={{1,1,1},0.78,0.36},iron={{0.10,0.085,0.07},0.6,0.72},
    ceramic={{1,1,1},0,0.27},greenGlaze={{0.21,0.34,0.24},0,0.3},paper={{1,1,1},0,0.94},
    sail={{0.92,0.85,0.66},0,0.88},rope={{0.57,0.48,0.31},0,0.90},herbal={{0.20,0.35,0.18},0,0.22},
    flame={{1.0,0.42,0.08},0,0.5},sea={{1,1,1},0.16,0.22},coast={{0.37,0.46,0.53},0,0.94},
    clearGlass={{0.61,0.81,0.76},0.0,0.12},
    brass={{0.70,0.46,0.19},0.82,0.3},leaf={{1,1,1},0,0.72},stem={{0.24,0.23,0.10},0,0.9},
    lavender={{0.43,0.30,0.49},0,0.9},linen={{1,1,1},0,0.97},book={{1,1,1},0,0.70},
    rug={{1,1,1},0,0.99},botany={{1,1,1},0,0.99},petal={{0.94,0.84,0.60},0,0.8},flowerHeart={{0.76,0.45,0.10},0,0.75},
    paintedWood={{0.78,0.78,0.67},0,0.78},
    glassGreen={{0.23,0.39,0.30},0.1,0.18},glassAmber={{0.42,0.24,0.09},0.12,0.21},
    lamp={{1.0,0.73,0.32},0,0.5},waterGlint={{0.38,0.60,0.66},0.15,0.38},sunlitWater={{0.83,0.66,0.32},0.2,0.4},
}
local function vector(v) return Vector3(v[1],v[2],v[3]) end
function V.New(world,rig)
    local scene=Scene(); local octree=scene:CreateComponent("Octree")
    local group=scene:CreateChild("LightGroup")
    local lighting=XMLFile()
    assert(lighting:FromString(require("lab.DuskPreset")),"Dusk preset copy could not parse")
    group:LoadXML(lighting:GetRoot())
    local zone=group:GetComponent("Zone",true)
    if zone then
        zone.fogStart=40; zone.fogEnd=100; zone.fogColor=Color(0.45,0.65,0.70)
        zone.ambientSource=AMBIENT_COLOR; zone.ambientColor=Color(0.29,0.29,0.29)
    end
    local sun=group:GetComponent("Light",true)
    if sun then
        sun.color=Color(1.0,0.79,0.49); sun.brightness=2.25; sun.castShadows=true
        sun.node.rotation=Quaternion(34,155,0)
    end
    require('lab.CloudSky').New(scene)
    renderer.hdrRendering=true
    local textures=require("lab.BakedTextures").New()
    local mats={}
    for name,p in pairs(palette) do
        local textureName=(name=="wood" or name=="woodLight" or name=="darkWood") and "wood" or name
        local mat=Material:new()
        if textures[textureName] then
            mat:SetTechnique(0,assert(cache:GetResource("Technique","Techniques/PBR/PBRDiffNormal.xml")))
            mat:SetTexture(TU_DIFFUSE,textures[textureName].diffuse)
            mat:SetTexture(TU_NORMAL,textures[textureName].normal)
        elseif name=="clearGlass" then
            mat:SetTechnique(0,assert(cache:GetResource("Technique","Techniques/PBR/PBRNoTextureAlpha.xml")))
        else
            mat:SetTechnique(0,assert(cache:GetResource("Technique","Techniques/PBR/PBRNoTexture.xml")))
        end
        mat:SetShaderParameter("MatDiffColor",Variant(Color(p[1][1],p[1][2],p[1][3],name=="clearGlass" and 0.35 or 1)))
        mat:SetShaderParameter("Metallic",Variant(p[2])); mat:SetShaderParameter("Roughness",Variant(p[3]))
        if name=="flame" then mat:SetShaderParameter("MatEmissiveColor",Variant(Color(1.5,0.48,0.08))) end
        if name=="lamp" then mat:SetShaderParameter("MatEmissiveColor",Variant(Color(1.2,0.62,0.16))) end
        mats[name]=mat
    end
    local models={}
    local stats={meshes=#world.meshes,materials=0,uniqueModels=0,vertices=0,indices=0,projectTextureFiles=21,generatedTextures=21,generatedTextureResolution=1024,proceduralSkyFaces=6}
    for _ in pairs(mats) do stats.materials=stats.materials+1 end
    for _,part in ipairs(world.meshes) do
        local rounded=part.shape=="box" and (part.material=="wood" or part.material=="woodLight" or part.material=="darkWood")
        local key=part.shape..(part.params and ":"..part.id or "")..(rounded and table.concat(part.size,":") or "")
        local model=models[key]
        if not model then
            local geom
            if rounded then geom=RoundedBoxGeometry(part.size[1],part.size[2],part.size[3],2,math.min(0.025,math.min(table.unpack(part.size))*0.24))
            elseif part.shape=="box" then geom=BoxGeometry(1,1,1)
            elseif part.shape=="sphere" then geom=SphereGeometry(0.5,16,12)
            elseif part.shape=="cylinder" then geom=CylinderGeometry(0.5,0.5,1,16)
            elseif part.shape=="torus" then geom=TorusGeometry(table.unpack(part.params))
            elseif part.shape=="lathe" or part.shape=="sail" then
                local points={}; for _,p in ipairs(part.params) do points[#points+1]=Vector2(p[1],p[2]) end
                geom=part.shape=="lathe" and LatheGeometry(points,64) or ExtrudeGeometry(points,0.025)
            elseif part.shape=="tube" then
                local points={}; for _,p in ipairs(part.params.points) do points[#points+1]=vector(p) end
                geom=TubeGeometry(points,part.params.segments,part.params.radius,8)
            elseif part.shape=="hull" then
                local points={}; for _,p in ipairs(part.params) do points[#points+1]=vector(p) end
                geom=ConvexGeometry(points)
            else error("Unknown lab geometry: "..part.shape) end
            stats.vertices=stats.vertices+geom:GetVertexCount(); stats.indices=stats.indices+geom:GetIndexCount()
            model=geom:ToModel(); models[key]=model; stats.uniqueModels=stats.uniqueModels+1
        end
        local node=scene:CreateChild(part.id); node.position=vector(part.position); node.scale=rounded and Vector3(1,1,1) or vector(part.size)
        node.rotation=Quaternion(part.rotation[1],part.rotation[2],part.rotation[3])
        local drawable=node:CreateComponent("StaticModel"); drawable.model=model; drawable.material=mats[part.material]
        drawable.castShadows=part.id~="sea"
    end
    local fire=scene:CreateChild("WarmStoveLight"); fire.position=Vector3(-1.15,1.34,0.65)
    local light=fire:CreateComponent("Light"); light.lightType=LIGHT_POINT; light.color=Color(1,0.56,0.25); light.brightness=0.3; light.range=1.7
    local lampNode=scene:CreateChild("LanternLight"); lampNode.position=Vector3(-0.94,2.94,2.90)
    local lampLight=lampNode:CreateComponent("Light"); lampLight.lightType=LIGHT_POINT; lampLight.color=Color(1,0.70,0.36); lampLight.brightness=0.7; lampLight.range=3.0
    local bounceNode=scene:CreateChild("WarmDoorBounce"); bounceNode.position=Vector3(-2.4,2.9,1.9)
    local bounce=bounceNode:CreateComponent("Light"); bounce.lightType=LIGHT_POINT; bounce.color=Color(1,0.79,0.51); bounce.brightness=1.4; bounce.range=8
    local fillNode=scene:CreateChild("SoftWorkbenchFill"); fillNode.position=Vector3(-2.3,3.3,-0.4)
    local fill=fillNode:CreateComponent("Light"); fill.lightType=LIGHT_POINT; fill.color=Color(1,0.88,0.71); fill.brightness=0.7; fill.range=6
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
