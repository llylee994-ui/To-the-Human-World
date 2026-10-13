-- Compatibility filename: real-room pan/zoom replaces the retired geometric yaw.
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
        -- Keep the pending-result adapter separate from the current return button.
        -- These synthetic rectangles are only for headless input dispatch.
        local pending=view.root:FindById("resumePending")
        if pending then
            local back=assert(view.root:FindById("returnHome")):GetAbsoluteLayout()
            pending.testLayout={x=back.x-122,y=back.y,w=114,h=back.h}
        end
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
    print("[StovePanZoomTest] P_TO_P PASS assertions="..checks.."; six other entries/modal/draft/pending/state")
    local pChecks=checks
    for _,size in ipairs({{1280,720},{1560,720},{1600,720},{1024,768},{640,360}}) do
        host.width,host.height=size[1],size[2];bind()
        for cycle=1,3 do
            local previous=nav;local sx,sy=point("home.stove")
            check(assert(Engine.FindWidgetAt(sx,sy)).props.id=="home.stove","stove subject hit")
            tap(sx,sy)
            check(view.scene=="home" and nav==previous and view.zoom.active,"stove starts delayed real-room navigation")
            check(creates==0 and not view.yawProbe and view.home.blocked,"no geometric scene; room input blocked")
            local profile=view.zoom.profile
            local bounds=view.home.root:GetAbsoluteLayout();local fit=view.home.Fit()
            local room,tree=view.home.art,view.root:GetNumChildren()
            local previousScale=1 --[[@as number]]
            local previousPan=0 --[[@as number]]
            check(profile.target==1.5 and profile.duration==.6 and profile.panX<0,"scale/duration/left pan defaults")
            check(math.abs(profile.subjectX*1.5+profile.panX-bounds.w/2)<1,"stove ends horizontally centered")
            for frame=1,35 do
                if frame==4 then
                    tap(sx,sy);tap(point("home.net"));tap(point("home.merchantShip"));tap(point("home.drawer"))
                    local day=view.root:FindById("nextDay"):GetAbsoluteLayout();tap(day.x+5,day.y+5)
                    view.Open("day");view.Open("shop");view.Close()
                    check(view.zoom.profile==profile and not view.panel and nav==previous,"repeat/other/HUD input blocked")
                end
                step(1/60)
                local s,dx,dy=view.zoom.scale,view.zoom.panX,view.zoom.panY
                check(view.zoom.active and s>previousScale and dx<previousPan,"simultaneous monotone pan/zoom")
                check(view.home.art==room and view.root:GetNumChildren()==tree and not view.model.dirty,"same UI tree; animation advances without dirty")
                local left=bounds.x+(fit.x-bounds.x)*s+dx
                local top=bounds.y+(fit.y-bounds.y)*s+dy
                check(left<=math.max(fit.x,bounds.x)+.001 and top<=math.max(fit.y,bounds.y)+.001
                    and left+fit.w*s>=math.min(fit.x+fit.w,bounds.x+bounds.w)-.001
                    and top+fit.h*s>=math.min(fit.y+fit.h,bounds.y+bounds.h)-.001,"no newly exposed room edges")
                check(dx<=0 and dy<=0 and dx+bounds.w*s>=bounds.w and dy+bounds.h*s>=bounds.h,"cover backdrop remains full")
                previousScale,previousPan=s,dx
            end
            step(1/60+.000001)
            check(view.scene=="brew" and nav==previous+1 and not view.zoom.active and not view.home.blocked,"complete once to existing brew; unlocked")
            step(0)
            check(view.root:FindById("brewStage") and view.root:FindById("openPending"),"existing pending-result brew controls visible")
            check(not view.root:FindById("homeYawCanvas") and not view.root:FindById("homeYawClose"),"no geometry test UI")
            for _=1,80 do step(1/60) end
            check(nav==previous+1 and not view.yawProbe and creates==0,"F3: no late completion or duplicate navigation")
            returnHome()
            check(U.Equal(before,fixture.state.GetSnapshot()) and fixture.writes==writes,"stove and return do not consume pending or mutate saves")
        end
    end
    host.width,host.height=1280,720;bind()
    for _,reason in ipairs({"resize","focus-lost","minimized","frame-gap","elapsed-gap","portrait"}) do
        local previous=nav;tap(point("home.stove"));step(.1)
        if reason=="resize" then host.width=1290;bind()
        elseif reason=="focus-lost" then host.focused=false
        elseif reason=="minimized" then host.minimized=true
        elseif reason=="elapsed-gap" then host.now=host.now+1
        elseif reason=="portrait" then host.width=360;host.height=640;bind() end
        step(reason=="frame-gap" and .3 or .01)
        check(not view.zoom.active and view.home.zoom==1 and not view.home.blocked and nav==previous,"cancel/reset "..reason)
        check(not view.root:FindById("homeZoomBlocker").props.visible,"release input "..reason)
        host.width,host.height=1280,720;host.focused=true;host.minimized=false;bind();step(.01)
        tap(point("home.stove"));check(view.zoom.active,"replay after "..reason)
        view.CancelHomeZoom("test-reset")
    end
    -- A pointer held on the blocker cannot click the new page/HUD on release.
    tap(point("home.stove"));pointer("PointerDown",1200,20)
    for _=1,37 do step(1/60) end
    pointer("PointerUp",1200,20);check(view.scene=="brew" and not view.panel,"late release cannot penetrate")
    view.Navigate("home");step(0)
    -- Real engine sorting (the shared headless layout adapter normally bypasses it).
    view.Open("shop");step(0)
    view.root.GetRenderChildren=require("urhox-libs/UI/Core/Widget").GetRenderChildren
    view.root.needsZSort_=true -- Native AddChild sets this when adding the zIndex=1000 blocker.
    local sx,sy=point("home.stove")
    check(Engine.FindWidgetAt(sx,sy)~=view.root:FindById("home.stove"),"F4: real z-order must keep modal above home")
    view.Close();step(0)
    tap(point("home.stove"));step(.1);local previous=nav
    view.root:Destroy();step(.1)
    check(creates==0 and nav==previous and not view.zoom.active and not view.home.blocked,"destroy cancels without navigation or geometric scene")
    check(not view.BeginHomeZoom("stove"),"destroyed view cannot replay")
    check(U.Equal(before,fixture.state.GetSnapshot()) and fixture.writes==writes,"all interrupts and inputs preserve pending/draft/saves")
    package.loaded["ui.landscape.HomeYawProbe"]=original
    require("ui.landscape.tests.StovePanZoomRenderTest").Run()
    print("[StovePanZoomTest] PASS motion assertions="..(checks-pChecks).."; 5 sizes, 15 visits; geometry creations=0")
    print("[StovePanZoomTest] PASS assertions="..checks.."; headless, not native/mobile evidence")
    return true
end
return T
