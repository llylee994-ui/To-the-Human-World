-- Native renderer diagnostic using official bundled Sphere/Box models.
function Start()
    local scene=Scene();scene:CreateComponent("Octree")
    local zone=scene:CreateChild("Zone"):CreateComponent("Zone")
    zone.boundingBox=BoundingBox(Vector3(-100,-100,-100),Vector3(100,100,100))
    zone.ambientSource=AMBIENT_COLOR;zone.ambientColor=Color(.03,.03,.03)
    local n=scene:CreateChild("Sun");n.direction=Vector3(.4,-1,.6)
    local light=n:CreateComponent("Light");light.lightType=LIGHT_DIRECTIONAL
    light.brightness=2;light.castShadows=true
    local function object(name,model,pos,scale,color)
        local node=scene:CreateChild(name);node.position=pos;node.scale=scale
        local sm=node:CreateComponent("StaticModel")
        sm:SetModel(assert(cache:GetResource("Model",model)))
        local m=Material:new();m:SetTechnique(0,assert(cache:GetResource("Technique","Techniques/PBR/PBRNoTexture.xml")))
        m:SetShaderParameter("MatDiffColor",Variant(color))
        m:SetShaderParameter("MatSpecColor",Variant(Color(.5,.5,.5)))
        m:SetShaderParameter("Metallic",Variant(.1));m:SetShaderParameter("Roughness",Variant(.3))
        sm:SetMaterial(m);sm.castShadows=true
    end
    object("Ground","Models/Box.mdl",Vector3(0,-1,0),Vector3(8,.2,8),Color(.5,.5,.5))
    object("Sphere","Models/Sphere.mdl",Vector3(-1,0,0),Vector3(2,2,2),Color(.7,.2,.1))
    object("Box","Models/Box.mdl",Vector3(1.5,-.3,0),Vector3(1.4,1.4,1.4),Color(.1,.3,.7))
    local cn=scene:CreateChild("Camera");cn.position=Vector3(0,3,-7);cn:LookAt(Vector3(0,0,0))
    local cam=cn:CreateComponent("Camera");cam.nearClip=.1;cam.farClip=100
    renderer:SetViewport(0,Viewport:new(scene,cam));renderer.hdrRendering=true
    zone:SetAutoExposureEnabled(false);zone:SetTonemapMode(TONEMAP_MODE_NONE)
    print("[PBR SMOKE] official Sphere/Box, directional light and shadows requested")
end
