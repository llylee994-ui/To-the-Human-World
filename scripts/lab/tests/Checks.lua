local T={}
function T.Run()
    local U=require "core.StateUtil"
    local checks={}
    local function check(name,condition,details)
        assert(condition,name..": "..tostring(details))
        checks[#checks+1]={name=name,status="PASS",details=details or ""}
        print("[PASS] "..name.." "..tostring(details or ""))
    end
    local ctx=require("lab.Bootstrap").New()
    local session,model=ctx.session,ctx.model
    check("single real schema 3 session",session.state.GetStatus().schema==3)
    local before=session.state.GetSnapshot()
    model.Navigate("home"); model.Navigate("seaside"); model.ReturnHome()
    session.queries.GetLetters(); session.queries.GetShopView(); session.queries.GetSalvageView()
    check("navigation and projections never mutate",U.Equal(before,session.state.GetSnapshot()) and ctx.storage.GetWriteCount()==0)
    local shop=session.queries.GetShopView().value
    local item=shop.items[1]
    check("real shop products and balance",#shop.items>0 and type(shop.currency)=="number",cjson.encode(shop))
    local buy=model.Buy(item.ingredientId)
    local after=session.queries.GetShopView().value
    check("real purchase charges configured price",buy.ok and after.currency==shop.currency-item.price and after.items[1].ownedQuantity==item.ownedQuantity+1,cjson.encode(buy))
    local snapshot=session.state.GetSnapshot(); local writes=ctx.storage.GetWriteCount()
    local bad=model.Buy("unknown_lab_ingredient")
    check("failed unknown purchase changes nothing",not bad.ok and U.Equal(snapshot,session.state.GetSnapshot()) and writes==ctx.storage.GetWriteCount(),bad.error.code)
    local fail
    for _=1,100 do
        snapshot=session.state.GetSnapshot(); writes=ctx.storage.GetWriteCount()
        local attempt=model.Buy(item.ingredientId)
        if not attempt.ok then fail=attempt; break end
    end
    check("real stock or affordability rejection is atomic",fail and U.Equal(snapshot,session.state.GetSnapshot()) and writes==ctx.storage.GetWriteCount(),fail and fail.error.code)
    local poor=model.Buy(shop.items[2].ingredientId)
    check("insufficient funds failure is atomic",not poor.ok and U.Equal(snapshot,session.state.GetSnapshot()) and writes==ctx.storage.GetWriteCount(),poor.error and poor.error.code)
    local salvage=session.queries.GetSalvageView().value
    local received=model.Receive(salvage.availableLetterIds[1])
    check("test setup via real Receive only",received.ok,cjson.encode(received))
    local id=received.value.letterInstanceId
    check("receive spends exactly one salvage",session.queries.GetSalvageView().value.remaining==salvage.remaining-1)
    check("real Read",model.Read(id).ok)
    local letter=session.modules.letters.GetView(id).value
    check("real body and requirement available",#letter.segments>0 and ctx.content.GetLetter(letter.letterId).requirement~=nil)
    local span=letter.spans[1]; local cardsBefore=session.modules.wordTokens.GetInventoryView().value.availableCount
    local cut=model.Cut(span.spanId)
    local count=session.modules.wordTokens.GetInventoryView().value.availableCount
    check("real Cut creates one card",cut.ok and count==cardsBefore+1,cjson.encode(cut))
    snapshot=session.state.GetSnapshot(); writes=ctx.storage.GetWriteCount()
    local repeated=model.Cut(span.spanId)
    check("repeat cut same span never duplicates",session.modules.wordTokens.GetInventoryView().value.availableCount==count and U.Equal(snapshot,session.state.GetSnapshot()) and writes==ctx.storage.GetWriteCount(),cjson.encode(repeated))
    model.ReturnHome(); model.Read(id)
    local reopened=session.modules.letters.GetView(id).value
    check("reopen retains exact cut gap",reopened.spans[1].cut)
    check("same-session SaveSystem reload",model.Reload().ok)
    check("memory commit retains cut after reload",session.modules.letters.GetView(id).value.spans[1].cut)
    local pathOk=pcall(ctx.storage.read,"save_numeric_v02_trial_a.json")
    check("formal slot rejected",not pathOk)
    for _,entry in ipairs(ctx.storage.GetAudit()) do assert(entry.path:find("save_d3_lab_r3",1,true)==1) end
    check("all storage operations restricted to lab memory",true,#ctx.storage.GetAudit())
    local S=require "lab.Spatial"
    local world=require("lab.World").Build()
    local rig=require("lab.CameraRig").New()
    local adapter=require("lab.Interaction").New(ctx,rig,world)
    local manifest=require "ui.landscape.LayoutManifest"
    local known={}; for _,object in ipairs(manifest.objects) do known[object.id]=true end
    for _,proxy in ipairs(world.proxies) do check("stable manifest ID: "..proxy.id,known[proxy.id]) end
    local function rayTo(id)
        for _,p in ipairs(world.proxies) do if p.id==id then return rig.position,S.Unit(S.Sub(S.Mul(S.Add(p.min,p.max),0.5),rig.position)) end end
        error("Unknown proxy "..id)
    end
    for _,id2 in ipairs({"home.net","home.stove","home.merchantShip","home.letterPaper","home.drawer"}) do
        local origin,direction=rayTo(id2)
        check("Home unobstructed ray: "..id2,adapter.Pick(origin,direction)==id2)
    end
    local origin,direction=rayTo("home.net")
    snapshot=session.state.GetSnapshot(); writes=ctx.storage.GetWriteCount()
    check("UI consumed input rejected",not adapter.Pointer(origin,direction,true) and not rig.busy)
    world.IsOccluded=function() return true end
    check("native mesh occlusion hook vetoes proxy",adapter.Pick(origin,direction)==nil)
    world.IsOccluded=nil
    adapter.Open("shop")
    check("modal blocks world input",not adapter.Pointer(origin,direction,false) and not rig.busy)
    adapter.Close(); adapter.dragging=true
    check("drag blocks world input",not adapter.Pointer(origin,direction,false) and not rig.busy)
    adapter.dragging=false
    check("net picking starts route",adapter.Pointer(origin,direction,false) and rig.busy)
    check("duplicate transition input rejected",not adapter.Activate("home.net"))
    local samples=0
    local function finish()
        local crossed=false
        local previousForward=S.Unit(S.Sub(rig.look,rig.position))
        for _=1,1200 do
            rig.Update(1/120); samples=samples+1
            for _,box in ipairs(world.occluders) do assert(not S.InBox(rig.position,box,rig.nearClip+0.05),"camera clips "..box.id) end
            local forward=S.Unit(S.Sub(rig.look,rig.position))
            assert(S.Dot(forward,previousForward)>0.99,"camera changes direction abruptly")
            previousForward=forward
            if rig.position[3]>3.3 and rig.position[3]<3.7 then
                assert(rig.position[1]>-3.6 and rig.position[1]<-1.7,"must pass door opening"); crossed=true
            end
            if not rig.busy then return crossed end
        end
        error("camera route did not complete")
    end
    check("Home to Seaside passes actual door",finish() and rig.mode=="Seaside")
    origin,direction=rayTo("home.merchantShip")
    check("same ship pick opens real shop",adapter.Pointer(origin,direction,false) and adapter.panel=="shop")
    adapter.Close(); adapter.Navigate("Home")
    check("Seaside return through same door",finish() and rig.mode=="Home")
    origin,direction=rayTo("home.stove")
    check("stove pick starts Brew route",adapter.Pointer(origin,direction,false))
    finish(); check("Brew reached",rig.mode=="Brew")
    local rimOrigin=S.Add(world.rim.center,{0,2,0})
    check("independent pot rim accepts interior",adapter.CanDropAt(rimOrigin,{0,-1,0}))
    check("pot body is not drop zone",not adapter.CanDropAt(S.Add(rimOrigin,{0.6,0,0}),{0,-1,0}))
    adapter.Navigate("Home"); finish()
    check("Brew return reached",rig.mode=="Home")
    check("camera clearance sampled with near-clip margin",true,samples)
    check("all camera/panel operations preserve business",U.Equal(snapshot,session.state.GetSnapshot()) and writes==ctx.storage.GetWriteCount())
    check("occluded object cannot be picked through wall",adapter.Pick({-6,1.16,2.75},{1,0,0})==nil)
    local projectionRows={}
    for _,aspect in ipairs({16/9,21/9,4/3}) do
        local fov=math.deg(2*math.atan(math.tan(math.rad(rig.fov)/2)*math.max(1,(16/9)/aspect)))
        for _,p in ipairs(world.proxies) do
            local center=S.Mul(S.Add(p.min,p.max),0.5)
            local screen=assert(S.Project(rig.position,rig.look,center,fov,aspect))
            check(string.format("Home projection %.3f %s",aspect,p.id),screen and screen[1]>0.03 and screen[1]<0.97 and screen[2]>0.10 and screen[2]<0.9)
            projectionRows[#projectionRows+1]={aspect=aspect,id=p.id,x=screen[1],y=screen[2]}
        end
    end
    check("aspect test is mathematical, not rendered acceptance",true,cjson.encode(projectionRows))
    package.preload["urhox-libs/UI"]=function() return require "lab.tests.HeadlessUI" end
    local UI=require "urhox-libs/UI"
    local hud=require("lab.Hud").New(ctx,rig,adapter,{Ray=function() error("UI test never synthesizes engine rays") end})
    adapter.Open("letters"); hud.Update()
    local read=assert(hud.root:FindById("read_"..id))
    check("real letter list callback wired",read~=nil)
    read:GetProps().onClick(); hud.Update()
    check("reader body requirement and gap rendered as text",hud.root:FindById("readerRequirement")~=nil and assert(hud.root:FindById("letterPaper")):GetText():find("〔",1,true)~=nil)
    check("later brewing UI excluded from minimal reader",hud.root:FindById("acceptOrder")==nil)
    local cutButton=hud.root:FindById("cut_"..span.spanId)
    check("already cut UI disabled",cutButton and cutButton:GetProps().disabled)
    local second=letter.spans[2]
    if second then
        local paper=hud.root:FindById("letterPaper")
        local secondButton=assert(hud.root:FindById("cut_"..second.spanId))
        secondButton:GetProps().onClick(); hud.Update()
        check("cut updates existing reader without rebuilding scroll",hud.root:FindById("letterPaper")==paper and secondButton:GetProps().disabled)
    end
    snapshot=session.state.GetSnapshot(); writes=ctx.storage.GetWriteCount()
    assert(hud.root:FindById("closePanel")):GetProps().onClick()
    check("close changes state, blocker survives event until Update",adapter.panel==false and hud.root:FindById("modalBlocker")~=nil)
    hud.Update(); adapter.Open("shop"); hud.Update()
    check("shop panel uses real sold-out balance",assert(hud.root:FindById("buy_"..item.ingredientId)):GetProps().disabled)
    check("panel open/close does not settle or receive",U.Equal(snapshot,session.state.GetSnapshot()) and writes==ctx.storage.GetWriteCount())
    check("scene geometry count",#world.meshes>60,#world.meshes)
    return checks
end
return T
