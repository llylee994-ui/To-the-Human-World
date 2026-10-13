local T={}
function T.Run()
    local U=require "core.StateUtil"
    local V=require "lab35.Math3"
    local Contract=require "lab35.MeshContract"
    local Fixture=require "lab35.tests.Fixture"
    local results={}
    local function check(name,value,detail)
        assert(value,name..": "..tostring(detail))
        results[#results+1]={name=name,status="PASS",detail=detail or ""};print("[PASS] "..name)
    end
    local original=Fixture.New();local before=U.Copy(original)
    local prepared=Contract.Prepare(original)
    check("source data not mutated or double-converted",U.Equal(original,before) and prepared.axis=="URHO_Y_UP")
    check("zero based indices convert exactly once",prepared.meshes[1].indices[1]==1 and prepared.meshes[1].indices[3]==3)
    check("Blender Z-up maps to engine Y-up",U.Equal(V.Convert({2,3,4}),{2,4,-3}))
    local g=prepared.meshes[1]
    check("rotation preserves triangle winding and normal",V.Dot(V.Cross(V.Sub(g.positions[2],g.positions[1]),V.Sub(g.positions[3],g.positions[1])),g.normals[1])>0)
    check("UV orientation preserved pending checker",g.uv0[3][1]==0 and g.uv0[3][2]==1)
    local scale=Fixture.New();scale.unitScale=2;local scaled=Contract.Prepare(scale)
    check("unit conversion scales geometry/camera/clips but not normals",scaled.meshes[1].positions[2][1]==2 and scaled.cameras.Home.position[3]==10 and scaled.cameras.Home.nearClip==.1 and scaled.meshes[1].normals[1][2]==1)
    local function invalid(name,edit)
        local data=Fixture.New();edit(data);check(name,not pcall(Contract.Prepare,data))
    end
    invalid("reject negative indices",function(d) d.meshes[1].indices[1]=-1 end)
    invalid("reject out-of-range zero based indices",function(d) d.meshes[1].indices[3]=3 end)
    invalid("reject fractional indices",function(d) d.meshes[1].indices[1]=.5 end)
    invalid("reject incomplete triangles",function(d) d.meshes[1].indices[3]=nil end)
    invalid("reject sparse mesh arrays",function(d) d.meshes[3]=U.Copy(d.meshes[1]);d.meshes[3].id="sparse" end)
    invalid("reject NaN positions",function(d) d.meshes[1].positions[1]=0/0 end)
    invalid("reject coordinate conversion overflow",function(d) d.unitScale=1e8;d.meshes[1].positions[1]=1e308 end)
    invalid("reject missing normals",function(d) d.meshes[1].normals={} end)
    invalid("reject zero normals",function(d) d.meshes[1].normals[3]=0 end)
    invalid("reject mismatched UV count",function(d) d.meshes[1].uv0[6]=nil end)
    invalid("reject degenerate triangles",function(d) d.meshes[1].indices[3]=1 end)
    invalid("reject collinear distinct vertices",function(d) d.meshes[1].positions={0,0,0,1,1,1,2,2,2} end)
    invalid("reject nonfinite triangle cross product",function(d) d.meshes[1].positions={0,0,0,1e200,0,0,0,1e200,0} end)
    local tiny=Fixture.New()
    -- Exact source values: full_group_002_000, zero-based triangle 600.
    tiny.meshes[1].positions={2.6593804,.9017305,1.8521092,2.6608348,.90169,1.8521059,2.6589026,.9017438,1.8521103}
    local tinyResult=Contract.Prepare(tiny)
    check("preserve actual nonzero letter-ink triangle below old area threshold",tinyResult.stats.triangles==1 and #tinyResult.meshes[1].indices==3)
    invalid("reject unbaked transform",function(d) d.meshes[1].transform={} end)
    invalid("reject foreign axis and double conversion",function(d) d.axis="URHO_Y_UP" end)
    invalid("reject material reference mismatch",function(d) d.meshes[1].materialId="missing" end)
    invalid("reject duplicate semantic ID",function(d) d.anchors[#d.anchors+1]=U.Copy(d.anchors[1]) end)
    invalid("reject independent scissors target",function(d) d.anchors[1].id="home.scissors" end)
    invalid("reject package path traversal",function(d) d.materials[1].baseColorTexture="../formal.png" end)
    invalid("reject absolute texture path",function(d) d.materials[1].baseColorTexture="D:/formal.png" end)
    invalid("reject ambiguous camera FOV",function(d) d.cameras[1].fovAxis=nil end)
    invalid("reject sphere for transparent ship",function(d) for _,a in ipairs(d.anchors) do if a.id=="home.merchantShip" then a.proxy={kind="sphere",radius=50} end end end)
    local absent=Fixture.New();absent.anchors[1].proxy=nil
    check("missing proxy disables picking rather than inventing bounds",#Contract.Prepare(absent).warnings==1)
    local ship
    for _,a in ipairs(prepared.anchors) do if a.id=="home.merchantShip" then ship=a end end
    local picker=require("lab35.Picking").New({anchors={ship}},function() return false end)
    check("semantic ship triangle is selectable",picker.Pick({0,0,0},{0,0,-1})=="home.merchantShip")
    check("transparent card corner is not a ship hit",picker.Pick({.9,.8,0},{0,0,-1})==nil)
    local hidden=require("lab35.Picking").New({anchors={ship}},function() return true end)
    check("occluder veto prevents through-wall hit",hidden.Pick({0,0,0},{0,0,-1})==nil)
    local events={};local failCommit=false
    local backend={Material=function(m) return m.id end,Begin=function() events[#events+1]="begin";return {} end,
        Geometry=function(_,id,mat) return {id=id,mat=mat,vertices={}} end,
        Vertex=function(mesh,p,n,uv) mesh.vertices[#mesh.vertices+1]={p,n,uv} end,
        Commit=function(mesh) if failCommit then error("injected commit failure") end;events[#events+1]=mesh end,
        Remove=function() events[#events+1]="rollback" end}
    local loader=require "lab35.MeshLoader"
    local loaded=loader.Load(Fixture.New(),backend,{chunkVertices=3})
    check("loader emits complete synthetic geometry",loaded.stats.drawables==1 and #events[2].vertices==3 and events[2].vertices[3][1][3]==-1)
    local bad=Fixture.New();bad.meshes[1].indices[1]=99;local eventCount=#events
    check("invalid data causes zero native scene mutations",not pcall(loader.Load,bad,backend) and #events==eventCount)
    failCommit=true
    check("native emission failure removes partial root",not pcall(loader.Load,Fixture.New(),backend) and events[#events]=="rollback")

    local UI=require "lab35.tests.FakeUI";UI.Install()
    local bundle=require("lab35.Bootstrap").New()
    local model,session,storage=bundle.model,bundle.session,bundle.storage
    local calls=0;local completion
    local navigation={Start=function(from,target,done) calls=calls+1;completion=done;return true end,Cancel=function() end}
    local controller=require("lab35.Controller").New(bundle,navigation);controller.SetAnchors(prepared.anchors)
    local ctx=require("lab35.AppView").New(session,bundle.content,nil,{model=model,bind=controller.Bind,
        homeFactory=function() return require("lab35.HomeView").New(controller,{picker=picker,ray=function() return {0,0,0},{0,0,-1} end,
            project=function() return {x=800,y=500} end,hintOccluded=function() return false end}) end})
    check("AppView uses the one injected real session/model",ctx.session==session and ctx.model==model and session.state.GetStatus().schema==3)
    local manifest=require "ui.landscape.LayoutManifest";local map=require "lab35.Ids";local count=0
    for _,obj in ipairs(manifest.objects) do
        check("main semantic mapping and exact visible label "..obj.id,map[obj.id] and map[obj.id].target==obj.target and map[obj.id].label==obj.label)
        check("rendered hint uses main label "..obj.id,UI.registry['v035Hint.'..obj.id].props.text==obj.label)
        count=count+1
    end
    check("exactly eight Home business entries",count==8 and map['home.scissors']==nil)
    local snapshot=session.state.GetSnapshot();local writes=storage.WriteCount()
    controller.ShowHints(true)
    check("Home hint anchors visible",#controller.ProjectHints(function() return {x=100,y=200} end,{x=0,y=0,w=1920,h=1080},function() return false end)==8)
    check("offscreen hints omitted",#controller.ProjectHints(function() return nil end,{x=0,y=0,w=1920,h=1080},function() return false end)==0)
    check("occluded hints omitted",#controller.ProjectHints(function() return {x=100,y=200} end,{x=0,y=0,w=1920,h=1080},function() return true end)==0)
    check("UI-consumed pointer cannot reach scene",not controller.Activate("home.net",1,true) and calls==0)
    controller.SetDragging(true);check("drag blocks navigation and hints",not controller.Activate("home.net",2) and not controller.HintsVisible());controller.SetDragging(false)
    check("net starts navigation only",controller.Activate("home.net",3) and controller.busy and ctx.scene=="home")
    check("navigation blocks repeated clicks and hints",not controller.Activate("home.net",4) and not controller.Activate("home.stove",5) and not controller.EndDay() and not controller.HintsVisible() and calls==1)
    local oldDone=completion;completion(true);ctx.Update()
    check("net completion opens existing SeasideView",ctx.scene=="seaside" and ctx.seaside.root.props.visible and not controller.busy)
    check("navigation completion replay has no effect",oldDone(true)==false)
    check("navigation never receives or saves",U.Equal(snapshot,session.state.GetSnapshot()) and storage.WriteCount()==writes)
    check("return Home starts guarded navigation",controller.Back() and controller.busy);completion(true);ctx.Update()
    check("Home return restores hint display",ctx.scene=="home" and controller.HintsVisible())
    check("duplicate gesture rejected after completion",not controller.Activate("home.net",3))
    check("new gesture begins a fresh transition",controller.Activate("home.net",6))
    oldDone=completion;ctx.CancelHomeZoom("portrait")
    check("cancel invalidates stale camera completion",not controller.busy and oldDone(true)==false and ctx.scene=="home")
    local gesture=10
    for _,id in ipairs({"home.drawer","home.journal","home.tray","home.caseFile","home.merchantShip","home.letterPaper","home.stove"}) do
        gesture=gesture+1;check("dispatch "..id,controller.Activate(id,gesture));if controller.busy then completion(true) end;ctx.Update()
        if id=="home.stove" then check("stove reaches brew without automatic Preview",ctx.scene=="brew");controller.Back();completion(true)
        else check("panel blocks scene and hints "..id,ctx.panel and not controller.Activate("home.net",99) and not controller.HintsVisible());ctx.Close() end
        ctx.Update()
    end
    check("all eight routes preserve business state",U.Equal(snapshot,session.state.GetSnapshot()) and writes==storage.WriteCount())
    check("End Day opens confirmation only",controller.EndDay());ctx.Update()
    check("opening confirmation does not advance day",U.Equal(snapshot,session.state.GetSnapshot()))
    local stale=UI.registry.confirmNextDay.props.onClick
    UI.Click("cancelNextDay");ctx.Update();stale()
    check("cancelled confirmation cannot advance day",U.Equal(snapshot,session.state.GetSnapshot()))
    controller.EndDay();ctx.Update();local confirm=UI.registry.confirmNextDay.props.onClick
    local day=controller.Hud().day;confirm();confirm();ctx.Update()
    check("double confirmation advances exactly one day",controller.Hud().day==day+1)
    check("HUD ledger binds real day and currency",UI.registry.playLedger.props.text:find(tostring(controller.Hud().day),1,true) and UI.registry.playLedger.props.text:find(tostring(controller.Hud().currency),1,true))
    controller.Activate("home.merchantShip",30);ctx.Update()
    local shop=session.queries.GetShopView().value;local item=shop.items[1]
    UI.Click("buy_"..item.ingredientId);ctx.Update();local after=session.queries.GetShopView().value
    check("existing Shop panel performs real purchase",after.currency==shop.currency-item.price and after.items[1].ownedQuantity==item.ownedQuantity+1)
    check("HUD follows committed purchase",controller.Hud().currency==after.currency)
    snapshot=session.state.GetSnapshot();writes=storage.WriteCount();local failure=model.Buy("not-an-ingredient")
    check("failed purchase does not debit or save",not failure.ok and U.Equal(snapshot,session.state.GetSnapshot()) and writes==storage.WriteCount())
    ctx.Close();ctx.Update();controller.Activate("home.net",31);completion(true);ctx.Update()
    local salvage=session.queries.GetSalvageView().value;local receive=ctx.StartSalvage();local received=session.state.GetSnapshot()
    check("existing salvage command runs once before animation",receive.ok and ctx.salvage.active and session.queries.GetSalvageView().value.remaining==salvage.remaining-1)
    writes=storage.WriteCount();check("repeat salvage and return blocked during animation",ctx.StartSalvage()==false and not controller.Back() and writes==storage.WriteCount())
    ctx.SkipSalvage();ctx.Update()
    check("skip preserves receipt and opens real Reader",ctx.panel=="reader" and UI.registry.readerRequirement and UI.registry.letterPaper)
    local letter=session.modules.letters.GetView(model.selectedLetter).value;local span=letter.spans[1]
    local cards=session.queries.GetWordTray().value.cards
    UI.Click("cut_"..span.spanId);ctx.Update()
    local cut=session.state.GetSnapshot();writes=storage.WriteCount();model.Cut(span.spanId)
    check("repeat real Cut cannot duplicate cards",#session.queries.GetWordTray().value.cards==#cards+1 and U.Equal(cut,session.state.GetSnapshot()) and storage.WriteCount()==writes)
    ctx.Close();ctx.Update();controller.Back();completion(true);ctx.Update();controller.Activate("home.letterPaper",32);ctx.Update()
    check("reopen paper retains the real cut gap",ctx.panel=="reader" and session.modules.letters.GetView(model.selectedLetter).value.spans[1].cut)
    check("formal save slot is rejected",not pcall(storage.read,"save_numeric_v02_trial_a.json"))
    local audit=storage.Audit();for _,a in ipairs(audit) do assert(a.path:match('^save_d3_lab_v035')) end
    check("all real storage operations remain memory scoped",#audit>0)
    check("separate memory instances do not share player data",not require("lab35.MemoryStorage").New().exists("save_d3_lab_v035_a.json"))
    ctx.Close();ctx.Update()
    for _,resolution in ipairs({{1920,1080},{2560,1080},{1440,1080}}) do
        UI.width,UI.height=resolution[1],resolution[2];ctx.Update();ctx.home.Update()
        check("offline HUD/hint layout update "..resolution[1].."x"..resolution[2],UI.registry.playLedger.props.text~=nil and UI.registry['v035Hint.home.net'].props.visible)
    end
    controller.ShowHints(false);ctx.home.Update();check("hint toggle hides all bubbles",not UI.registry['v035Hint.home.net'].props.visible)
    check("destroy blocks all future navigation",(function() ctx.root:Destroy();return not controller.Activate("home.net",100) end)())
    local fallbackBundle=require("lab35.Bootstrap").New()
    local home=prepared.cameras.Home;local pose=U.Copy(home);local routeModes={}
    local realNav=require("lab35.Navigation").New({Home=home},function() return pose end,function(p) pose=p end,home,
        function(target,mode) routeModes[target]=mode end)
    local fallbackController=require("lab35.Controller").New(fallbackBundle,realNav)
    local fallbackView=require("lab35.AppView").New(fallbackBundle.session,fallbackBundle.content,nil,{model=fallbackBundle.model,bind=fallbackController.Bind,
        homeFactory=function() return require("lab35.HomeView").New(fallbackController,{picker=picker,ray=function() return {0,0,0},{0,0,-1} end,
            project=function() return {x=800,y=500} end,hintOccluded=function() return false end}) end})
    local fallbackSnapshot=fallbackBundle.session.state.GetSnapshot();local fallbackWrites=fallbackBundle.storage.WriteCount()
    check("missing Seaside camera still opens original salvage page",fallbackController.Activate("home.net",1) and fallbackView.scene=="seaside" and not fallbackController.busy)
    fallbackView.Update()
    check("existing Seaside UI is actually visible on fallback route",fallbackView.seaside.root.props.visible and routeModes.seaside=="existing-main-ui")
    fallbackController.Back();for _=1,16 do realNav.Update(.1) end;fallbackView.Update()
    check("fallback page can return to calibrated Home",fallbackView.scene=="home" and not fallbackController.busy and U.Equal(pose,home))
    check("missing Brew camera still opens existing brewing page",fallbackController.Activate("home.stove",2) and fallbackView.scene=="brew" and routeModes.brew=="existing-main-ui")
    fallbackView.Update()
    check("fallback routes never receive brew or write storage",U.Equal(fallbackSnapshot,fallbackBundle.session.state.GetSnapshot()) and fallbackWrites==fallbackBundle.storage.WriteCount())
    fallbackView.root:Destroy()
    require("lab35.tests.FullImport").Run(check)
    require("lab35.tests.NativeCalls").Run(check)
    return results
end
return T
