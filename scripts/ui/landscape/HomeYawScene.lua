-- Separate scene -> render target -> NanoVG. Never changes the game's viewport.
local C=require "ui.landscape.HomeYawMotion"
local S={}
function S.New()
    local a={objects={},materials={},closed=false --[[@as boolean]],image=0 --[[@as integer]],frame=0,
        scene=nil --[[@as Scene?]],cameraNode=nil --[[@as Node?]],camera=nil --[[@as Camera?]],
        viewport=nil --[[@as Viewport?]],texture=nil --[[@as Texture2D?]],surface=nil --[[@as RenderSurface?]],
        imageContext=nil --[[@as NVGContextWrapper?]]}
    local function releaseImage()
        if a.image~=0 and a.imageContext then nvgDeleteVideo(a.imageContext,a.image) end
        a.image=0;a.imageContext=nil
    end
    local function releaseTarget()
        releaseImage()
        if a.surface then a.surface:SetNumViewports(0) end
        if a.texture then a.texture:Dispose() end
        a.surface=nil;a.texture=nil
    end
    function a.Close()
        if a.closed then return end
        a.closed=true;releaseTarget();a.viewport=nil
        if a.scene then a.scene:Dispose();a.scene=nil end
        -- These materials belong only to this scene; cached models/techniques stay alive.
        for _,m in ipairs(a.materials) do m:Dispose() end
        a.materials={};a.objects={};a.camera=nil;a.cameraNode=nil
    end
    local function material(r,g,b)
        local m=Material:new();a.materials[#a.materials+1]=m
        m:SetTechnique(0,assert(cache:GetResource("Technique","Techniques/NoTextureUnlit.xml")))
        m:SetShaderParameter("MatDiffColor",Variant(Color(r,g,b,1)));return m
    end
    local function object(id,model,p,scale,mat)
        local n=assert(a.scene):CreateChild(id);n.position=Vector3(p[1],p[2],p[3]);n.scale=Vector3(scale[1],scale[2],scale[3])
        local d=n:CreateComponent("StaticModel")
        d.model=assert(cache:GetResource("Model","Models/"..model..".mdl"));d.material=mat
        a.objects[#a.objects+1]={node=n,id=id,position=n.worldPosition,scale=n.scale,rotation=n.rotation}
        return n
    end
    function a.Resize(width,height)
        if a.closed then return end
        -- Fixed 16:9 projection with integer-size targets; UI letterboxes other ratios.
        local unit=math.max(1,math.min(100,math.floor(math.min(width/16,height/9))))
        local w,h=unit*16,unit*9
        if a.width==w and a.height==h then return end
        releaseTarget();a.width=w;a.height=h
        a.texture=Texture2D:new();a.texture:SetNumLevels(1)
        assert(a.texture:SetSize(w,h,Graphics:GetRGBAFormat(),TEXTURE_RENDERTARGET),"yaw render target allocation failed")
        a.texture:SetFilterMode(FILTER_BILINEAR)
        a.surface=a.texture:GetRenderSurface();a.surface:SetViewport(0,assert(a.viewport))
        a.surface:SetUpdateMode(SURFACE_MANUALUPDATE);a.surface:QueueUpdate()
        print(string.format("[HomeYawTarget] size=%dx%d aspect=%.6f",w,h,assert(a.camera).aspectRatio))
    end
    function a.SetYaw(yaw)
        if a.closed then return end
        assert(a.cameraNode).rotation=Quaternion(C.pitch,yaw,C.roll)
        if a.surface then a.surface:QueueUpdate() end
    end
    function a.Sample(elapsed,reason)
        local node=assert(a.cameraNode);local camera=assert(a.camera)
        local p=node.worldPosition;local r=node.rotation.eulerAngles
        local unchanged=true
        for _,o in ipairs(a.objects) do
            if o.node.worldPosition~=o.position or o.node.scale~=o.scale or o.node.rotation~=o.rotation then unchanged=false end
        end
        local q=camera:WorldToScreenPoint(Vector3(C.pot[1],C.pot[2],C.pot[3]))
        a.frame=a.frame+1
        local line=string.format('[HomeYawFrame] {"frame":%d,"wall":%.6f,"t":%.6f,"position":[%.6f,%.6f,%.6f],"rotation":[%.6f,%.6f,%.6f],"fov":%.6f,"aspect":%.6f,"potScreen":[%.6f,%.6f],"objectsUnchanged":%s,"state":"%s"}',
            a.frame,GetTime():GetElapsedTime(),elapsed,p.x,p.y,p.z,r.x,r.y,r.z,camera.fov,camera.aspectRatio,q.x,q.y,tostring(unchanged),reason)
        print(line)
        return unchanged
    end
    function a.Draw(vg,x,y,w,h)
        if a.closed or not a.texture then return end
        if a.imageContext and a.imageContext~=vg then releaseImage() end
        if a.image==0 then
            a.image=nvgCreateVideo(vg,a.texture);a.imageContext=vg
            assert(a.image~=0,"nvgCreateVideo failed")
        end
        nvgSave(vg);nvgIntersectScissor(vg,x,y,w,h)
        nvgBeginPath(vg);nvgRect(vg,x,y,w,h)
        -- nvgCreateVideo already corrects render-target orientation. No extra flip.
        nvgFillPaint(vg,nvgImagePattern(vg,x,y,w,h,0,a.image,1));nvgFill(vg);nvgRestore(vg)
    end
    local ok,err=pcall(function()
        a.scene=Scene();a.scene:CreateComponent("Octree")
        local blue=material(.18,.34,.53);local orange=material(.64,.32,.13)
        local floor=material(.12,.16,.20);local grid=material(.66,.76,.76)
        local desk=material(.18,.39,.30);local dark=material(.12,.13,.14)
        local gold=material(.78,.57,.14);local liquid=material(.38,.82,.25)
        local red=material(.9,.22,.16)
        object("front-wall","Box",{0,1.75,6},{10,3.5,.12},blue)
        object("right-wall","Box",{5,1.75,2},{.12,3.5,8},orange)
        object("floor","Box",{0,-.08,2},{10,.12,8},floor)
        for i=-4,4 do object("front-column-"..i,"Box",{i,1.75,5.92},{.025,3.5,.025},grid) end
        for i=-1,5 do object("right-column-"..i,"Box",{4.92,1.75,i},{.025,3.5,.025},grid) end
        for _,y in ipairs({.5,1.5,2.5,3.4}) do
            object("front-row-"..y,"Box",{0,y,5.92},{10,.025,.025},grid)
            object("right-row-"..y,"Box",{4.92,y,2},{.025,.025,8},grid)
        end
        object("front-top-marker","Box",{0,2.8,5.8},{.7,.35,.12},red)
        object("right-top-marker","Box",{4.8,2.8,2.8},{.12,.35,.7},red)
        object("table","Box",{2.9,.75,2.9},{3.6,.16,2.8},desk)
        for _,x in ipairs({1.2,4.6}) do for _,z in ipairs({1.6,4.2}) do object("leg-"..x.."-"..z,"Box",{x,.35,z},{.12,.7,.12},dark) end end
        for _,x in ipairs({1.2,2,3,4,4.6}) do object("table-x-"..x,"Box",{x,.838,2.9},{.02,.01,2.8},grid) end
        for _,z in ipairs({1.6,2,3,4.2}) do object("table-z-"..z,"Box",{2.9,.838,z},{3.6,.01,.02},grid) end
        object("pot-body","Sphere",C.pot,{.85,.62,.85},gold)
        object("pot-mouth","Cylinder",{3.2,1.43,2.8},{.69,.09,.69},dark)
        object("pot-liquid","Cylinder",{3.2,1.481,2.8},{.57,.015,.57},liquid)
        object("pot-left-handle","Box",{2.71,1.24,2.8},{.18,.13,.16},dark)
        object("pot-right-handle","Box",{3.69,1.24,2.8},{.18,.13,.16},dark)
        a.cameraNode=a.scene:CreateChild("fixed-eye")
        a.cameraNode.position=Vector3(C.position[1],C.position[2],C.position[3])
        a.camera=a.cameraNode:CreateComponent("Camera");a.camera.orthographic=false
        a.camera.fov=C.fov;a.camera.nearClip=.05;a.camera.farClip=30
        a.camera.autoAspectRatio=false;a.camera.aspectRatio=C.aspect;a.SetYaw(C.startYaw)
        a.viewport=Viewport:new(a.scene,a.camera)
        -- Clone/load also avoids the duplicate SetRenderPath overload in EmmyLua metadata.
        local renderPath=a.viewport:GetRenderPath():Clone()
        assert(renderPath:Load(cache:GetResource("XMLFile","RenderPaths/Forward.xml")),"Forward render path load failed")
        a.viewport:SetRenderPath(renderPath)
        local path=a.viewport:GetRenderPath()
        for i=0,path:GetNumCommands()-1 do local command=path:GetCommand(i)
            if command.type==CMD_CLEAR then command.useFogColor=false;command.clearColor=Color(.07,.09,.12,1) end
        end
        a.Resize(1280,720)
        print("[HomeYawProbe] created objects="..#a.objects.." camera=(0,1.65,0), only yaw changes")
    end)
    if not ok then a.Close();return nil,tostring(err) end
    return a
end
return S
