-- Compatibility filename: this suite now verifies removal of the stove yaw.
-- Real AppView/business/UI dispatch; clock and Yoga layout are headless adapters.
local T={}
function T.Run()
    package.loaded["debug.DeveloperMode"]=false
    MOUSEB_LEFT,MOUSEB_MIDDLE,MOUSEB_RIGHT=0,1,2
    local Engine=require "urhox-libs/UI/Core/UI"
    local Event=require "urhox-libs/UI/Core/PointerEvent"
    local G=require "ui.landscape.LayoutGeometry"
    local U=require "core.StateUtil"
    local Data=require "data.content"
    local host=require("ui.landscape.tests.ZoomTestHost").New()
    local fixture=require("debug.fixtures.B5Fixtures").New(Data,{targetSchema=3})
    local creates,checks,nav=0,0,0
    local original=package.loaded["ui.landscape.HomeYawProbe"]
    -- Detect any attempt to create the removed transition, without requiring a GPU.
    package.loaded["ui.landscape.HomeYawProbe"]={New=function(_,closed)
        creates=creates+1
        return {Update=function() end,Close=function(reason) closed(reason or "cancel") end}
    end}
    local view=require("ui.landscape.AppView").New(fixture.session,Data)
    local navigate=view.Navigate
    view.Navigate=function(target) nav=nav+1;navigate(target) end
    local function check(ok,why) checks=checks+1;assert(ok,why) end
    local function bind()
        host.Bind(view.root);Engine.SetRoot(view.root)
        -- The shared layout adapter predates the pending-result HUD button.
        local pending=view.root:FindById("resumePending")
        if pending then pending.testLayout={x=view.root:GetAbsoluteLayout().w-356,y=0,w=114,h=48} end
    end
    local function step(dt) host.Step(view,dt);bind() end
    local function point(id)
        for _,o in ipairs(view.home.manifest.objects) do if o.id==id then
            local r=o.regions[1];return G.ToScreen(view.home.manifest.layers[o.layer],view.home.Fit(),r.cx,r.cy)
        end end
        error(id)
    end
    local function pointer(kind,x,y)
        Engine["Handle"..kind](Event.new(kind,{x=x,y=y,button=MOUSEB_LEFT,pointerType="mouse"}))
    end
    local function tap(x,y) pointer("PointerDown",x,y);pointer("PointerUp",x,y) end
    local function returnHome()
        local b=assert(view.root:FindById("returnHome"));local r=b:GetAbsoluteLayout()
        tap(r.x+r.w/2,r.y+r.h/2);step(0)
        check(view.scene=="home" and view.home.zoom==1 and not view.home.blocked,"return restores home and input")
    end
    bind()
    check(not view.root:FindById("openHomeYawProbe") and not view.OpenYawProbe(),"normal entry hides developer probe")
    local before,writes=fixture.state.GetSnapshot(),fixture.writes
    for _,entry in ipairs({{"home.merchantShip","shop"},{"home.tray","words"},{"home.letterPaper","letters"},
        {"home.caseFile","case"},{"home.journal","journal"},{"home.drawer","letters"}}) do
        view.Navigate("home");step(0);tap(point(entry[1]));step(0)
        check(view.panel==entry[2],"unchanged entrance "..entry[1])
        check(U.Equal(before,fixture.state.GetSnapshot()) and fixture.writes==writes,"navigation is read only "..entry[1])
    end
    view.Navigate("home");step(0);tap(point("home.merchantShip"));step(0)
    local x,y=point("home.stove");tap(x,y)
    check(view.panel=="shop" and view.scene=="home" and creates==0,"modal blocks underlying stove")
    pointer("PointerDown",x,y);view.Close();step(0);pointer("PointerUp",x,y)
    check(view.scene=="home" and not view.panel and creates==0,"closing modal cannot release through to stove")
    -- Prepare real isolated state, then establish the navigation-preservation baseline.
    local function must(result) assert(result.ok,result.error and result.error.message);return result.value end
    local received=must(fixture.state.ReceiveLetter({letterId="letter_pa_01"}))
    must(fixture.state.ReadLetter({letterInstanceId=received.letterInstanceId}))
    local tokens={}
    for _,span in ipairs(must(fixture.modules.letters.ParseDefinition("letter_pa_01")).spans) do
        tokens[span.wordId]=must(fixture.state.CutWord({letterInstanceId=received.letterInstanceId,spanId=span.spanId})).tokenId
    end
    must(fixture.order.Accept({letterInstanceId=received.letterInstanceId}))
    view.Refresh();step(0)
    local recipe=require("debug.fixtures.NumericV02Cases")[1].recipe
    local mainToken=assert(tokens[recipe.mainWordId])
    local edited=view.model.Edit("main",mainToken);check(edited.ok,"prepare nonempty saved draft")
    for _,line in ipairs(recipe.ingredients) do
        for _=1,line.quantity do must(view.model.Edit("ingredient",line.ingredientId,1)) end
    end
    before,writes=fixture.state.GetSnapshot(),fixture.writes
    check(before.currentOrder.draft.mainTokenId==mainToken,"fixture has saved input")
    view.Open("brew");step(0);returnHome()
    check(U.Equal(before,fixture.state.GetSnapshot()) and fixture.writes==writes,"existing navigation preserves saved draft")
    must(view.model.Preview());view.Refresh();step(0)
    before,writes=fixture.state.GetSnapshot(),fixture.writes
    check(before.currentOrder.pending~=false,"fixture has pending result")
    view.Open("brew");step(0);returnHome()
    check(U.Equal(before,fixture.state.GetSnapshot()) and fixture.writes==writes,"existing navigation preserves pending result")
    print("[StoveDirectEntryTest] P_TO_P PASS assertions="..checks.."; six other entries/modal/draft/pending/state")
    local pChecks=checks
    for _,size in ipairs({{1280,720},{1560,720},{1600,720},{1024,768},{640,360}}) do
        host.width,host.height=size[1],size[2];bind()
        for cycle=1,3 do
            local previous=nav;local sx,sy=point("home.stove")
            check(assert(Engine.FindWidgetAt(sx,sy)).props.id=="home.stove","stove subject hit")
            tap(sx,sy)
            check(view.scene=="brew" and nav==previous+1,"F1: stove must navigate immediately, without waiting for yaw")
            check(creates==0 and not view.yawProbe and not view.zoom.active and not view.home.blocked,"F2: no transition creation or input lock")
            step(0)
            check(view.root:FindById("brewStage") and view.root:FindById("openPending"),"existing pending-result brew controls visible")
            check(not view.root:FindById("homeYawCanvas") and not view.root:FindById("homeYawClose"),"no geometry test UI")
            for _=1,80 do step(1/60) end
            check(nav==previous+1 and not view.yawProbe and creates==0,"F3: no late completion or duplicate navigation")
            returnHome()
            check(U.Equal(before,fixture.state.GetSnapshot()) and fixture.writes==writes,"stove and return do not consume pending or mutate saves")
        end
    end
    -- Real engine sorting (the shared headless layout adapter normally bypasses it).
    view.Open("shop");step(0)
    view.root.GetRenderChildren=require("urhox-libs/UI/Core/Widget").GetRenderChildren
    view.root.needsZSort_=true -- Native AddChild sets this when adding the zIndex=1000 blocker.
    local sx,sy=point("home.stove")
    check(Engine.FindWidgetAt(sx,sy)~=view.root:FindById("home.stove"),"F4: real z-order must keep modal above home")
    view.Close();step(0)
    view.root:Destroy();step(.1)
    check(creates==0,"no transition during destruction")
    package.loaded["ui.landscape.HomeYawProbe"]=original
    print("[StoveDirectEntryTest] F_TO_P PASS assertions="..(checks-pChecks).."; 5 sizes, 15 visits; transition creations=0")
    print("[StoveDirectEntryTest] PASS assertions="..checks.."; headless, not native/mobile evidence")
    return true
end
return T
