-- Actual six-mesh cloud probe. No old World model and no system input automation.
local H={}
local UI=require "urhox-libs/UI"
local V=require "lab35.Math3"
local Native=require "lab35.NativeGeometry"
local U=require "core.StateUtil"
local OUTPUT="D:/taptap/To-the-Human-World-3D-Lab/docs/evidence/v035-main-interface/native/"
local app,scene,camera,cameraNode,octree,data,pose,home,brew,nav
local settings={flipV=false,checker=false,businessQa=false}
local elapsed,qaIndex,shot,frames,total,worst=0,1,nil,0,0,0
local results={}
local function vector(v) return Vector3(v[1],v[2],v[3]) end
local function emit(name,ok,details)
    local row={name=name,ok=not not ok,seconds=elapsed,details=details}
    results[#results+1]=row;print("[V035 CHECK] "..cjson.encode(row))
end
local function screenshot(label) shot=label end
local function rebuild()
    local loaded=require("lab35.MeshLoader").Load(data,Native.New(scene,"v035-probe",settings))
    app.imported.root:Remove();app.imported=loaded
end
local function shipOpaque(origin,direction)
    local mesh=app.imported.prepared.meshes[6]
    for i=1,#mesh.indices,3 do
        local a,b,c=mesh.indices[i],mesh.indices[i+1],mesh.indices[i+2]
        local distance,u,v=V.Triangle(origin,direction,mesh.positions[a],mesh.positions[b],mesh.positions[c])
        if distance then
            local ua,ub,uc=mesh.uv0[a],mesh.uv0[b],mesh.uv0[c]
            local x=ua[1]*(1-u-v)+ub[1]*u+uc[1]*v
            local y=ua[2]*(1-u-v)+ub[2]*u+uc[2]*v
            local im=assert(cache:GetResource("Image","v035-probe/merchant-ship-muted.png"))
            local px=math.max(0,math.min(im.width-1,math.floor(x*im.width)))
            local py=math.max(0,math.min(im.height-1,math.floor((1-y)*im.height)))
            return im:GetPixel(px,py).a>.10
        end
    end
    return false
end
local function occluded(origin,direction,distance,id)
    if id=="home.merchantShip" and not shipOpaque(origin,direction) then return true end
    local hit=octree:RaycastSingle(Ray(vector(origin),vector(direction)),RAY_TRIANGLE,distance+.02,DRAWABLE_GEOMETRY)
    if not hit or not hit.node or hit.distance>=distance-.02 then return false end
    local name=hit.node.name
    if id=="home.stove" and (name:find("group_02",1,true) or name:find("group_03",1,true)) then return false end
    if id=="home.merchantShip" and name:find("group_05",1,true) then return false end
    return true
end
local function anchor(id)
    for _,a in ipairs(app.imported.prepared.anchors) do if a.id==id then return a end end
end
local function calibrateCamera(raw)
    local best,bestError
    local aspect=graphics:GetWidth()/graphics:GetHeight()
    local referenceAspect=raw.camera.resolution[1]/raw.camera.resolution[2]
    for _,handedness in ipairs({HANDEDNESS_LH,HANDEDNESS_RH}) do
        for _,sign in ipairs({1,-1}) do
            local candidate=U.Copy(home);candidate.handedness=handedness;candidate.lookSign=sign
            Native.ApplyCamera(camera,cameraNode,candidate,aspect)
            local ray=camera:GetScreenRay(.5,.5)
            local forward={ray.direction.x,ray.direction.y,ray.direction.z}
            if V.Dot(forward,home.forward)>.999 then
                local err=0
                for _,a in ipairs(raw.interactionProxies) do
                    local uv=camera:WorldToScreenPoint(vector(V.Convert(a.position)))
                    local expectedY=.5+(a.screenAnchor[2]-.5)*aspect/referenceAspect
                    err=err+(uv.x-a.screenAnchor[1])^2+(uv.y-expectedY)^2
                end
                print("[V035 CAMERA CANDIDATE] "..cjson.encode({handedness=handedness,lookSign=sign,error=err,aspect=aspect}))
                if not bestError or err<bestError then best,bestError=candidate,err end
            end
        end
    end
    assert(best,"native camera has no forward-facing calibrated candidate")
    home=best;pose=U.Copy(home)
    emit("native camera calibration",bestError<.00001,{handedness=home.handedness,lookSign=home.lookSign,anchorSquaredError=bestError})
end
local function pickId(id)
    local a=anchor(id);local ray=V.Unit(V.Sub(a.position,pose.position))
    return app.picker.Pick(pose.position,ray)
end
local function newNavigation()
    local n={active=false}
    function n.Start(from,target,done)
        if n.active then return false end
        -- The probe does not contain a dock route; Seaside keeps the real 2D page.
        n.active=true;n.elapsed=0;n.from=U.Copy(pose);n.to=target=="brew" and brew or home;n.done=done
        return true
    end
    function n.Cancel() n.active=false end
    function n.Update(dt)
        if not n.active then return end
        n.elapsed=math.min(1.5,n.elapsed+math.max(0,math.min(dt,.1)))
        local t=n.elapsed/1.5;t=t*t*(3-2*t)
        pose=U.Copy(n.to);pose.position=V.Add(V.Mul(n.from.position,1-t),V.Mul(n.to.position,t))
        pose.forward=V.Unit(V.Add(V.Mul(n.from.forward,1-t),V.Mul(n.to.forward,t)))
        local up=V.Add(V.Mul(n.from.up,1-t),V.Mul(n.to.up,t))
        pose.up=V.Unit(V.Sub(up,V.Mul(pose.forward,V.Dot(up,pose.forward))))
        if n.elapsed>=1.5 then n.active=false;n.done(true) end
    end
    return n
end
local actions={
    {4,function() screenshot("01-home-source-v");emit("visible cloud geometry only",app.imported.stats.meshes==6 and app.imported.stats.triangles==8128,app.imported.stats) end},
    {7,function() settings.checker=true;rebuild();screenshot("02-checker-source-v") end},
    {10,function() settings.flipV=true;rebuild();screenshot("03-checker-flipped-v") end},
    {13,function() settings.checker=false;rebuild();screenshot("04-home-flipped-v") end},
    {16,function()
        app.controller.ShowHints(true);screenshot("05-hints")
        emit("native ship semantic pick",pickId("home.merchantShip")=="home.merchantShip")
        emit("native stove semantic pick",pickId("home.stove")=="home.stove")
    end},
    {20,function() emit("native shop dispatch",app.controller.Activate("home.merchantShip","qa-ship"));screenshot("06-shop") end},
    {23,function()
        local before=app.bundle.session.queries.GetShopView().value;local item=before.items[1]
        local result=app.bundle.model.Buy(item.ingredientId);local after=app.bundle.session.queries.GetShopView().value
        emit("native real purchase",result.ok and after.currency==before.currency-item.price,{before=before.currency,after=after.currency})
        local snapshot=app.bundle.session.state.GetSnapshot();local writes=app.bundle.storage.WriteCount()
        local fail=app.bundle.model.Buy("unknown_probe_ingredient")
        emit("native failed purchase atomic",not fail.ok and U.Equal(snapshot,app.bundle.session.state.GetSnapshot()) and writes==app.bundle.storage.WriteCount())
        screenshot("07-purchase")
    end},
    {26,function() app.view.Close();app.controller.Activate("home.net","qa-net") end},
    {30,function()
        emit("native existing seaside page",app.view.scene=="seaside")
        screenshot("08-seaside")
    end},
    {33,function()
        local before=app.bundle.session.queries.GetSalvageView().value.remaining
        local r=app.view.StartSalvage()
        emit("native real salvage",r and r.ok and app.bundle.session.queries.GetSalvageView().value.remaining==before-1)
        emit("native repeat salvage blocked",app.view.StartSalvage()==false)
        screenshot("09-salvage")
    end},
    {37,function()
        if app.view.salvage.active then app.view.SkipSalvage() else app.view.OpenCapturedLetter() end
        emit("native real Reader",app.view.panel=="reader");screenshot("10-reader")
    end},
    {40,function()
        local view=app.bundle.session.modules.letters.GetView(app.bundle.model.selectedLetter).value
        local span=view.spans[1];local r=app.bundle.model.Cut(span.spanId)
        local snapshot=app.bundle.session.state.GetSnapshot();local writes=app.bundle.storage.WriteCount()
        app.bundle.model.Cut(span.spanId)
        emit("native cut and repeat protection",r.ok and U.Equal(snapshot,app.bundle.session.state.GetSnapshot()) and writes==app.bundle.storage.WriteCount())
        screenshot("11-cut")
    end},
    {43,function() app.view.Close();app.controller.Back() end},
    {46,function() emit("native home return",app.view.scene=="home");app.controller.Activate("home.stove","qa-stove") end},
    {50,function() emit("native Brew camera/sidebar",app.view.scene=="brew");screenshot("12-brew");app.controller.Back() end},
    {54,function()
        app.controller.EndDay();app.view.Update();local token=app.view.BeginDayConfirmation()
        local before=app.controller.Hud().day;local r=app.view.ConfirmDay(token);app.view.ConfirmDay(token)
        emit("native end day once",r and r.ok and app.controller.Hud().day==before+1);screenshot("13-home-final")
    end},
    {57,function() app.controller.Activate("home.drawer","qa-drawer");emit("native drawer entry",app.view.panel=="letters");screenshot("14-drawer") end},
    {60,function() app.view.Close();app.controller.Activate("home.journal","qa-journal");emit("native journal entry",app.view.panel=="journal");screenshot("15-journal") end},
    {63,function() app.view.Close();app.controller.Activate("home.tray","qa-tray");emit("native tray entry",app.view.panel=="words");screenshot("16-words") end},
    {66,function() app.view.Close();app.controller.Activate("home.caseFile","qa-case");emit("native case entry",app.view.panel=="case");screenshot("17-case") end},
    {69,function() app.view.Close();app.controller.Activate("home.letterPaper","qa-paper");emit("native paper entry",app.view.panel=="reader");screenshot("18-paper-reopened") end},
    {72,function() app.view.Close();app.controller.ShowHints(true);screenshot("19-home-done") end},
    {75,function()
        local ok=true;for _,r in ipairs(results) do if not r.ok then ok=false end end
        emit("native QA complete",ok,{checks=#results,storage="memory d3_lab_v035",input="programmatic scene IDs and real commands; no OS input",fullRoom=false})
        app.bundle.model.message="v03.5 导入小样 · 6 个可见网格；桌面、地板和其他器具未包含。";app.bundle.model.dirty=true
        local f=File(OUTPUT.."native-checks.json",FILE_WRITE);assert(f:IsOpen());f:WriteString(cjson.encode({checks=results,fullRoom=false,actualCloudProbe=true}));f:Close()
    end},
}
function H.Install()
    function Start()
        graphics.windowTitle="寄往人间 · 独立 3D 试验 · v03.5 小样"
        UI.Init({scale=UI.Scale.DEFAULT,fonts={{family="sans",weights={normal="Fonts/MiSans-Regular.ttf"}}}})
        UI.SetRoot(UI.Panel {id="v035Root",width="100%",height="100%",backgroundColor={0,0,0,0},pointerEvents="box-none"})
        local f=assert(cache:GetFile("v035-probe/probe.json"));local text=f:ReadString();f:Close()
        local raw=cjson.decode(text)
        data=require("lab35.ProbeAdapter").Convert(raw)
        scene=Scene();octree=scene:CreateComponent("Octree")
        local lightNode=scene:CreateChild("ProbeDirectional")
        lightNode.rotation=Quaternion(35,140,0)
        local light=lightNode:CreateComponent("Light");light.lightType=LIGHT_DIRECTIONAL;light.color=Color(1,.87,.7);light.brightness=1.6;light.castShadows=true
        local zoneNode=scene:CreateChild("ProbeAmbient");local zone=zoneNode:CreateComponent("Zone")
        zone.boundingBox=BoundingBox(Vector3(-1000,-1000,-1000),Vector3(1000,1000,1000));zone.ambientSource=AMBIENT_COLOR;zone.ambientColor=Color(.45,.43,.4)
        zone.fogStart=400;zone.fogEnd=500
        cameraNode=scene:CreateChild("ProbeCamera");camera=cameraNode:CreateComponent("Camera")
        home=require("lab35.MeshContract").Prepare(data).cameras.Home;pose=U.Copy(home)
        calibrateCamera(raw)
        brew=U.Copy(home);brew.position=V.Convert({2.7,-.4,3.05});brew.forward=V.Unit(V.Sub(V.Convert({2.0874,1.9289,2.3572}),brew.position))
        brew.up=V.Unit(V.Sub({0,1,0},V.Mul(brew.forward,V.Dot({0,1,0},brew.forward))))
        nav=newNavigation()
        app=require("lab35.Integration").New({scene=scene,sceneData=data,camera=camera,cameraNode=cameraNode,resourcePrefix="v035-probe",navigation=nav,
            occluded=occluded,hintOccluded=function(point,id) local delta=V.Sub(point,pose.position);return occluded(pose.position,V.Unit(delta),math.sqrt(V.Dot(delta,delta)),id) end})
        renderer:SetViewport(0,Viewport:new(scene,camera));UI.GetRoot():AddChild(app.view.root)
        Native.ApplyCamera(camera,cameraNode,pose,graphics:GetWidth()/graphics:GetHeight())
        app.bundle.model.message="v03.5 小样校准中 · 非完整房间 · 内存隔离";app.bundle.model.dirty=true
        SubscribeToEvent("Update","V035Update");SubscribeToEvent("EndRendering","V035Capture")
        print("[V035 START] actualCloudProbe=true fullRoom=false meshes=6 proxiesInvisible=8 main="..app.bundle.mainSha)
    end
    function V035Update(_,eventData)
        if not app then return end
        local dt=eventData["TimeStep"]:GetFloat();elapsed=elapsed+dt;frames=frames+1;total=total+dt;worst=math.max(worst,dt)
        nav.Update(dt);Native.ApplyCamera(camera,cameraNode,pose,graphics:GetWidth()/math.max(1,graphics:GetHeight()))
        if actions[qaIndex] and elapsed>=actions[qaIndex][1] and (settings.businessQa or actions[qaIndex][1]<20) then
            local fn=actions[qaIndex][2];qaIndex=qaIndex+1
            local ok,err=pcall(fn);if not ok then emit("QA action exception",false,tostring(err)) end
        end
        app.view.Update()
        if total>=5 then print(string.format("[V035 FRAME] resolution=%dx%d meanMs=%.2f worstMs=%.2f count=%d memoryWrites=%d",graphics:GetWidth(),graphics:GetHeight(),total*1000/frames,worst*1000,frames,app.bundle.storage.WriteCount()));frames,total,worst=0,0,0 end
    end
    function V035Capture()
        if shot then
            local label=shot;shot=nil
            local im=Image();local ok=graphics:TakeScreenShot(im)
            if ok then ok=im:SavePNG(OUTPUT..label..".png") end
            print("[V035 CAPTURE] "..cjson.encode({label=label,seconds=elapsed,ok=not not ok,flipV=settings.flipV,checker=settings.checker}))
        end
    end
    function Stop() UI.Shutdown();if scene then scene:Dispose() end;app=nil end
end
return H
