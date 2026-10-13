-- Separate full-scene entry. Not staged/launched while native preview is paused.
local H={}
function H.Install(config)
    assert(config and config.resourcePrefix,"explicit full-scene resource prefix required")
    local UI=require "urhox-libs/UI"
    local Package=require "v035.lab35.ScenePackage"
    local Native=require "v035.lab35.NativeGeometry"
    local V=require "v035.lab35.Math3"
    local U=require "v035.core.StateUtil"
    local prefix=Package.Path(config.resourcePrefix).."/"
    local app,scene,camera,node,octree,job,display,header,raw,home,pose,nav,observation
    local stage,waitFrames,elapsed,reportAt,lastPhase="waiting",0,0,0,nil
    local startedMs,lastStepMs,worstStepMs=0,0,0
    -- Use the same monotonic instance API as the shipped UI input clock.
    local function nowMs() return time:GetElapsedTime()*1000 end
    local frames=require("v035.lab35.FrameStats").New()
    local options={deferPublish=true,flipV=config.flipV==true}
    local function vector(v) return Vector3(v[1],v[2],v[3]) end
    local function log(label,data) print("[V035 FULL "..label.."] "..cjson.encode(data)) end
    local function fail(err)
        local failedPhase=stage;stage="failed"
        if job then
            if not job.Cancel() and job.Result() then job.Result().root:Remove() end
        end
        if app then app.view.root:Destroy();app=nil end
        local row=job and job.Snapshot() or {phase=failedPhase}
        row.status="failed";row.error=tostring(err)
        if display then display.Update(row) end
        log("FAIL",row)
    end
    local function readText(path,limit)
        return require("v035.lab35.ResourceReader").Read(function(name) return cache:GetFile(name) end,
            prefix..Package.Path(path),limit or 33554432)
    end
    local function alphaOpaque(origin,direction,a)
        if a.id~="home.merchantShip" then return true end
        for _,id in ipairs(a.visibleMeshIds) do
            local mesh=app.imported.meshById[id]
            local material=app.imported.prepared.materials[mesh.materialId]
            assert(mesh.positions,"ship mesh was not retained for alpha picking")
            for i=1,#mesh.indices,3 do
                local ia,ib,ic=mesh.indices[i],mesh.indices[i+1],mesh.indices[i+2]
                local t,u,v=V.Triangle(origin,direction,mesh.positions[ia],mesh.positions[ib],mesh.positions[ic])
                if t then
                    if not material.baseColorTexture then return material.baseColor[4]>.1 end
                    local aUV,bUV,cUV=mesh.uv0[ia],mesh.uv0[ib],mesh.uv0[ic]
                    local x=aUV[1]*(1-u-v)+bUV[1]*u+cUV[1]*v
                    local y=aUV[2]*(1-u-v)+bUV[2]*u+cUV[2]*v
                    if options.flipV then y=1-y end
                    local im=cache:GetResource("Image",prefix..material.baseColorTexture)
                    if im and im.width>0 and im.height>0 then
                        local px=math.max(0,math.min(im.width-1,math.floor(x*im.width)))
                        local py=math.max(0,math.min(im.height-1,math.floor(y*im.height)))
                        if im:GetPixel(px,py).a*material.baseColor[4]>.1 then return true end
                    end
                end
            end
        end
        return false
    end
    local anchorById={}
    local function occluded(origin,direction,distance,id)
        local a=anchorById[id]
        if not a or not alphaOpaque(origin,direction,a) then return true end
        local hit=octree:RaycastSingle(Ray(vector(origin),vector(direction)),RAY_TRIANGLE,distance+.02,DRAWABLE_GEOMETRY)
        if not hit or not hit.node or hit.distance>=distance-.02 then return false end
        local owner=hit.node.name:match("^(.*):%d+$")
        local hitPoint=V.Add(origin,V.Mul(direction,hit.distance))
        if require("v035.lab35.SemanticOcclusion").Owns(a,owner,hitPoint) then return false end
        return true
    end
    local function prepare()
        local manifest=cjson.decode(readText(config.manifestPath or "manifest.json",4194304))
        raw=cjson.decode(readText(Package.Path(manifest.entry,".json"),4194304))
        local catalog=Package.Catalog({meshFiles=manifest.meshFiles or raw.meshFiles})
        assert(raw.format=="dot-customgeometry-scene-v1","full entry refuses probe/old-scene fallback")
        header=require("v035.lab35.ProbeAdapter").Convert(raw,{meshCatalog=catalog})
        assert(#header.meshes==0,"full scene must be split across manifest.meshFiles")
        local keep={}
        for _,a in ipairs(header.anchors) do
            if a.id=="home.merchantShip" then for _,id in ipairs(a.visibleMeshIds) do keep[id]=true end end
        end
        job=require("v035.lab35.MeshLoader").Stream(header,catalog,function(entry) return readText(entry.path) end,
            Native.New(scene,config.resourcePrefix,options),{chunkVertices=12000,retainMeshIds=keep,maxExpandedVertices=12000000})
        stage="loading"
    end
    local function finish()
        local imported=assert(job.Result())
        if config.deferLoadingViewport then renderer:SetViewport(0,Viewport:new(scene,camera)) end
        home=U.Copy(imported.prepared.cameras.Home)
        local calibration
        home,calibration=require("v035.lab35.CameraCalibration").Run(camera,node,home,raw,graphics:GetWidth()/graphics:GetHeight())
        pose=U.Copy(home);imported.prepared.cameras.Home=home
        log("CAMERA",calibration)
        for _,a in ipairs(imported.prepared.anchors) do anchorById[a.id]=a end
        nav=require("v035.lab35.Navigation").New(imported.prepared.cameras,function() return pose end,function(value) pose=value end,home,
            function(target,mode,hasPose) log("ROUTE",{target=target,mode=mode,exportedPose=hasPose}) end)
        app=require("v035.lab35.Integration").New({scene=scene,sceneData=header,imported=imported,camera=camera,cameraNode=node,
            resourcePrefix=config.resourcePrefix,navigation=nav,occluded=occluded,
            hintOccluded=function(point,id) local d=V.Sub(point,pose.position);return occluded(pose.position,V.Unit(d),math.sqrt(V.Dot(d,d)),id) end})
        UI.GetRoot():AddChild(app.view.root)
        raw=nil;header=nil
        stage="ready"
        if calibration.ok then display.Update({status="complete"})
        else
            app.controller.SetDragging(true)
            display.Update({status="warning",error="原生投影校准未通过。画面仅供排查，交互保持暂停。"})
        end
        log("READY",{stats=imported.stats,loadWallSeconds=(nowMs()-startedMs)/1000,calibrationPassed=calibration.ok,
            warnings=imported.prepared.warnings,storage="one in-memory GameSession/PlayModel",businessQa="no automatic commands",fullSceneRendered="requires pixel verification"})
        if config.observeEntries and calibration.ok then
            observation=require("v035.lab35.NativeObservation").New(app,camera,node,log)
        end
    end
    function Start()
        startedMs=nowMs()
        graphics.windowTitle="寄往人间 · 独立 3D · v03.5 完整场景"
        UI.Init({scale=UI.Scale.DEFAULT,fonts={{family="sans",weights={normal="Fonts/MiSans-Regular.ttf"}}}})
        local root=UI.Panel {width="100%",height="100%",backgroundColor={0,0,0,0},pointerEvents="box-none"};UI.SetRoot(root)
        display=require("v035.lab35.LoadStatus").New(UI,function() if job then job.Cancel() end;stage="cancelled";display.Update({status="cancelled"}) end)
        root:AddChild(display.root)
        local ok,err=pcall(function()
            scene=Scene();octree=scene:CreateComponent("Octree")
            node=scene:CreateChild("FullSceneCamera");camera=node:CreateComponent("Camera")
            if not config.deferLoadingViewport then renderer:SetViewport(0,Viewport:new(scene,camera)) end
            local lightNode=scene:CreateChild("FullSceneSun");lightNode.rotation=Quaternion(35,140,0)
            local light=lightNode:CreateComponent("Light");light.lightType=LIGHT_DIRECTIONAL;light.color=Color(1,.87,.7);light.brightness=1.6;light.castShadows=true
            local zone=scene:CreateChild("FullSceneAmbient"):CreateComponent("Zone")
            zone.boundingBox=BoundingBox(Vector3(-1000,-1000,-1000),Vector3(1000,1000,1000));zone.ambientSource=AMBIENT_COLOR;zone.ambientColor=Color(.45,.43,.4);zone.fogStart=400;zone.fogEnd=500
        end)
        SubscribeToEvent("Update","V035FullUpdate")
        if not ok then fail(err) end
    end
    function V035FullUpdate(_,eventData)
        local dt=eventData["TimeStep"]:GetFloat();elapsed=elapsed+dt;frames.Add(dt)
        local stepStart=nowMs()
        local ok,err=pcall(function()
            if (stage=="loading" or stage=="waiting") and stepStart-startedMs>(config.maxLoadingSeconds or 300)*1000 then
                error("full-scene loading exceeded the explicit wall-time limit; no automatic retry")
            end
            if stage=="waiting" then waitFrames=waitFrames+1;if waitFrames>=2 then prepare() end
            elseif stage=="loading" then
                -- Bound cooperative work by wall time as well as resume count;
                -- a full package should not spend thousands of idle frames.
                local state
                for _=1,(config.loadingMaxSteps or 8) do
                    state=job.Step(1)
                    if state=="complete" or state=="failed" or nowMs()-stepStart>=(config.loadingBudgetMs or 8) then break end
                end
                local status=job.Snapshot();display.Update(status)
                if status.phase~=lastPhase then log("PROGRESS",status);lastPhase=status.phase end
                if state=="complete" then finish() elseif state=="failed" then fail(status.error) end
            elseif stage=="ready" then
                nav.Update(dt);Native.ApplyCamera(camera,node,pose,graphics:GetWidth()/math.max(1,graphics:GetHeight()));app.view.Update()
                if observation then observation.Update(dt) end
            end
        end)
        lastStepMs=nowMs()-stepStart;worstStepMs=math.max(worstStepMs,lastStepMs)
        if lastStepMs>1000 then log("SLOW_STEP",{milliseconds=lastStepMs,stage=stage,load=job and job.Snapshot()}) end
        if not ok then fail(err) end
        if elapsed-reportAt>=5 then
            reportAt=elapsed;local r=frames.Report(true);r.stage=stage;r.width=graphics:GetWidth();r.height=graphics:GetHeight()
            r.wallSeconds=(nowMs()-startedMs)/1000;r.lastHostStepMs=lastStepMs;r.worstHostStepMs=worstStepMs
            local memOk,mem=pcall(collectgarbage,"count");if memOk then r.luaMemoryKiB=mem end
            if job then r.load=job.Snapshot() end
            if app then r.memoryWrites=app.bundle.storage.WriteCount() end
            log("FRAME",r)
        end
    end
    function Stop()
        if job then job.Cancel() end
        if app then app.view.root:Destroy() end
        UI.Shutdown();if scene then scene:Dispose() end
        app=nil
    end
end
return H
