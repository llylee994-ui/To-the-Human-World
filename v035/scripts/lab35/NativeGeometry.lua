-- Documented UrhoX API only; native execution is pending explicit preview permission.
local V=require "lab35.Math3"
local N={}
local function vector(v) return Vector3(v[1],v[2],v[3]) end
function N.New(scene,resourcePrefix,options)
    options=options or {}
    assert(scene and type(resourcePrefix)=="string" and resourcePrefix~="","explicit scene/resource prefix required")
    assert(not resourcePrefix:find("[\\:%z]") and resourcePrefix:sub(1,1)~="/" and not resourcePrefix:find("..",1,true),"relative package resource prefix required")
    if resourcePrefix:sub(-1)~="/" then resourcePrefix=resourcePrefix.."/" end
    local api={}
    local normalMaterials,normalGeometry={},{}
    function api.Material(m)
        -- MASK is parsed but cannot be silently replaced by alpha blending.
        assert(m.alphaMode~="MASK","MASK technique/cutoff transfer not yet verified; material "..m.id)
        local name=m.normalTexture and "PBRDiffNormal" or (m.baseColorTexture and "PBRDiff" or "PBRNoTexture")
        local directory="Techniques/PBR/"
        if m.unlit then name=m.baseColorTexture and "DiffUnlit" or "NoTextureUnlit";directory="Techniques/" end
        if m.alphaMode=="BLEND" then name=name.."Alpha" end
        local tech=assert(cache:GetResource("Technique",directory..name..".xml"),"missing technique "..name)
        local texturePath=(options.checker and not m.unlit) and "uv_checker.png" or m.baseColorTexture
        if m.normalTexture and not texturePath then texturePath="_lab/default-white.png" end
        local texture=texturePath and assert(cache:GetResource("Texture2D",resourcePrefix..texturePath),"missing package texture "..texturePath)
        local normal=m.normalTexture and assert(cache:GetResource("Texture2D",resourcePrefix..m.normalTexture),"missing normal texture "..m.normalTexture)
        local mat=Material:new();mat:SetTechnique(0,tech)
        if texture then texture.sRGB=true;mat:SetTexture(TU_DIFFUSE,texture) end
        if normal then
            assert(TU_NORMAL~=nil,"runtime lacks TU_NORMAL")
            normal.sRGB=false;mat:SetTexture(TU_NORMAL,normal);normalMaterials[mat]=true
        end
        local c=m.baseColor;mat:SetShaderParameter("MatDiffColor",Variant(Color(c[1],c[2],c[3],c[4])))
        mat:SetShaderParameter("Roughness",Variant(m.roughness));mat:SetShaderParameter("Metallic",Variant(m.metallic))
        if m.doubleSided then mat:SetCullMode(CULL_NONE) end
        return mat
    end
    function api.Begin()
        local root=scene:CreateChild("v035.imported-scene")
        if options.deferPublish then root.enabled=false end
        return root
    end
    function api.Publish(root) root.enabled=true end
    function api.Geometry(root,id,material)
        local node=root:CreateChild(id)
        local geometry=node:CreateComponent("CustomGeometry")
        geometry:BeginGeometry(0,TRIANGLE_LIST);geometry:SetMaterial(material)
        if normalMaterials[material] then normalGeometry[geometry]=true end
        geometry.castShadows=true
        return geometry
    end
    function api.Vertex(geometry,p,n,uv)
        geometry:DefineVertex(vector(p));geometry:DefineNormal(vector(n));geometry:DefineTexCoord(Vector2(uv[1],options.flipV and 1-uv[2] or uv[2]))
    end
    function api.Commit(geometry)
        if normalGeometry[geometry] then
            assert(type(geometry.GenerateTangents)=="function","runtime lacks CustomGeometry.GenerateTangents; normal map cannot be accepted")
            assert(geometry:GenerateTangents(),"CustomGeometry.GenerateTangents failed")
            normalGeometry[geometry]=nil
        end
        geometry:Commit()
    end
    function api.Remove(root) root:Remove();normalGeometry={} end
    return api
end
function N.ApplyCamera(camera,node,pose,aspect)
    assert(aspect>0,"camera aspect must be positive")
    camera.autoAspectRatio=false;camera.aspectRatio=aspect
    if pose.handedness~=nil then camera.handedness=pose.handedness end
    node.position=vector(pose.position);node:LookAt(vector(V.Add(pose.position,V.Mul(pose.forward,pose.lookSign or 1))),vector(pose.up))
    camera.nearClip=pose.nearClip;camera.farClip=pose.farClip
    camera.orthographic=pose.projection=="orthographic"
    if camera.orthographic then camera.orthoSize=pose.orthoHeight
    else
        local fov=pose.fovRadians
        if pose.fovAxis=="horizontal" then fov=2*math.atan(math.tan(fov/2)/aspect) end
        camera.fov=math.deg(fov)
    end
end
function N.ScreenUV(camera,node,point)
    local p=vector(point)
    -- WorldToScreenPoint alone mirrors points behind the camera; reject first.
    local delta=p-node.worldPosition
    local direction=camera:GetScreenRay(.5,.5).direction
    local depth=delta:DotProduct(direction)
    if depth<=camera.nearClip or depth>=camera.farClip then return end
    -- Runtime WorldToScreenPoint assumes positive view Z and clamps RH points.
    -- Use the actual camera matrices and signed homogeneous W for both hands.
    local q=camera.view*p
    local m=camera.projection
    local w=m.m30*q.x+m.m31*q.y+m.m32*q.z+m.m33
    if math.abs(w)<1e-8 then return end
    return {x=.5+.5*(m.m00*q.x+m.m01*q.y+m.m02*q.z+m.m03)/w,
        y=.5-.5*(m.m10*q.x+m.m11*q.y+m.m12*q.z+m.m13)/w}
end
function N.Project(camera,node,point,rect)
    local uv=N.ScreenUV(camera,node,point)
    if not uv then return end
    if uv.x<0 or uv.x>1 or uv.y<0 or uv.y>1 then return end
    return {x=rect.x+uv.x*rect.w,y=rect.y+uv.y*rect.h}
end
return N
