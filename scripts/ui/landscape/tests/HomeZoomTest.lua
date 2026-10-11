-- Real AppView/business + engine Lua pointer dispatch, simulated clock/focus/layout.
local Data=require "data.content"
local F=require "debug.fixtures.B5Fixtures"
local U=require "core.StateUtil"
local App=require "ui.landscape.AppView"
local G=require "ui.landscape.LayoutGeometry"
local Z=require "ui.landscape.HomeZoom"
local T={}
function T.Run()
    package.loaded["debug.DeveloperMode"]=false
    MOUSEB_LEFT,MOUSEB_MIDDLE,MOUSEB_RIGHT=0,1,2 -- Headless enum adapters.
    local Engine=require "urhox-libs/UI/Core/UI"
    local Event=require "urhox-libs/UI/Core/PointerEvent"
    local host=require("ui.landscape.tests.ZoomTestHost").New()
    local fixture=F.New(Data,{targetSchema=3})
    local view=App.New(fixture.session,Data)
    local checks,nav=0,0
    local function check(ok,why) checks=checks+1;assert(ok,why) end
    local navigate=view.Navigate
    view.Navigate=function(target) nav=nav+1;navigate(target) end
    local function bind() host.Bind(view.root);Engine.SetRoot(view.root) end
    local function point(id)
        for _,o in ipairs(view.home.manifest.objects) do if o.id==id then
            local layer=view.home.manifest.layers[o.layer];local r=assert(o.regions[1])
            return G.ToScreen(layer,view.home.Fit(),r.cx,r.cy)
        end end
        error("unknown object")
    end
    local function pointer(kind,x,y,pointerId)
        Engine["Handle"..kind](Event.new(kind,{x=x,y=y,button=MOUSEB_LEFT,pointerType="mouse",pointerId=pointerId or 0}))
    end
    local function tap(x,y) pointer("PointerDown",x,y);pointer("PointerUp",x,y) end
    local function step(dt) host.Step(view,dt) end
    local function control(id) return assert(view.root:FindById(id),id) end
    local function button(id) control(id):GetProps().onClick();step(0);bind() end
    local function export(name,t)
        local sink=rawget(_G,"HOME_ZOOM_EVIDENCE")
        if sink then sink(name,t,view,fixture.state.GetSnapshot()) end
    end
    bind()
    local before,writes=fixture.state.GetSnapshot(),fixture.writes
    for _,size in ipairs({{1280,720},{1560,720},{1600,720},{1024,768}}) do
        host.width,host.height=size[1],size[2];bind()
        local fit=view.home.Fit();local x,y=point("home.net")
        check(assert(Engine.FindWidgetAt(x,y)).props.id=="home.net","net hit")
        tap(x,y);check(view.zoom.active and view.scene=="home","start delayed navigation")
        check(view.home.zoom==1 and not view.model.dirty,"start without business dirty")
        local blocker=control("homeZoomBlocker");local tree=view.root:GetNumChildren()
        local room=view.home.art;local oldNav=nav
        export(size[1].."-start",0)
        for i=1,27 do
            local previous=view.home.zoom
            if i==3 then
                tap(x,y);tap(point("home.merchantShip"));tap(point("home.drawer"))
                local bounds=control("nextDay"):GetAbsoluteLayout();tap(bounds.x+10,bounds.y+10)
                view.Open("day");view.Open("shop");view.Close()
                check(not view.panel and view.zoom.active and nav==oldNav,"repeated input/HUD blocked")
                check(Engine.FindWidgetAt(x,y)==blocker,"full blocker owns input")
            end
            step(1/60)
            if i<27 then
                check(view.zoom.active and view.home.zoom>=previous and view.home.zoom<1.15,"continuous monotone zoom")
                check(view.home.art==room and view.root:GetNumChildren()==tree and not view.model.dirty,"no UI rebuild/dirty per frame")
                local s=view.home.zoom
                -- Outer scaling around interior anchor must cover the original fitted canvas.
                local left=fit.x+(1-s)*Z.anchor.x*fit.scale
                local top=fit.y+(1-s)*Z.anchor.y*fit.scale
                check(left<=fit.x and top<=fit.y and left+fit.w*s>=fit.x+fit.w and top+fit.h*s>=fit.y+fit.h,"no exposed canvas edges")
            end
            if i==13 or i==26 then export(size[1]..(i==13 and "-middle" or "-before-end"),i/60) end
        end
        -- Floating-point frame accumulation may need one zero-cost epsilon step.
        if view.zoom.active then step(.000001) end
        check(view.scene=="seaside" and nav==oldNav+1 and not view.zoom.active,"one completion to original seaside")
        check(control("startSalvage") and control("seasideShop"),"existing functional page")
        check(view.home.zoom==1 and not blocker.props.visible and not view.home.blocked,"completion releases all")
        export(size[1].."-seaside",.45)
        for _=1,3 do step(1/60) end
        check(nav==oldNav+1,"no repeated completion")
        bind();button("returnHome")
        check(view.home.zoom==1 and view.scene=="home" and not view.home.blocked,"return reset")
        export(size[1].."-returned",.50)
        check(U.Equal(before,fixture.state.GetSnapshot()) and fixture.writes==writes,"navigation never writes business state")
    end
    print("[HomeZoomTest] PASS simulated timeline start/middle/end/seaside/return at 4 aspect ratios; same UI tree; unchanged business")
    host.width,host.height=1280,720;bind()
    local x,y=point("home.merchantShip");tap(x,y);step(0);bind()
    check(view.panel=="shop" and not view.zoom.active,"ship still opens shop")
    x,y=point("home.net");tap(x,y);check(not view.zoom.active,"modal blocks net")
    button("closePanel")
    local fit=view.home.Fit();tap(fit.x+650*fit.scale,fit.y+550*fit.scale)
    check(not view.panel and not view.zoom.active,"doorway blank is not an entrance")
    -- A press started on blocker cannot turn into a click on the destination page.
    tap(point("home.net"));pointer("PointerDown",1200,20)
    for _=1,28 do step(1/60) end
    pointer("PointerUp",1200,20)
    check(not view.panel,"late release cannot open HUD action")
    view.Navigate("home");step(0);bind()
    for _,reason in ipairs({"resize","focus-lost","minimized","frame-gap","elapsed-gap"}) do
        local oldNav=nav;tap(point("home.net"));step(.1)
        if reason=="resize" then host.width=1290;bind()
        elseif reason=="focus-lost" then host.focused=false
        elseif reason=="minimized" then host.minimized=true
        elseif reason=="elapsed-gap" then host.now=host.now+1 end
        step(reason=="frame-gap" and .3 or .01)
        check(not view.zoom.active and view.scene=="home" and view.home.zoom==1 and not view.home.blocked,"cancel "..reason)
        check(not control("homeZoomBlocker").props.visible and nav==oldNav,"cancel releases without navigation")
        host.width=1280;host.focused=true;host.minimized=false;bind();step(.01)
        tap(point("home.net"));check(view.zoom.active,"can replay after "..reason)
        view.CancelHomeZoom("test-reset");check(nav==oldNav,"cancel does not defer callback")
    end
    tap(point("home.net"));step(.1);local oldNav=nav;view.root:Destroy();step(.1)
    check(view.destroyed and not view.zoom.active and view.home.zoom==1 and nav==oldNav,"destroy cancels without stale callback")
    check(not view.BeginHomeZoom(),"destroyed view cannot replay")
    check(U.Equal(before,fixture.state.GetSnapshot()) and fixture.writes==writes,"all inputs and interrupts leave state/writes unchanged")
    print("[HomeZoomTest] PASS assertions="..checks.."; repeat/HUD/modal/blank/ship/late-release; resize/focus/minimize/gap/destroy; OS and native rendering NOT tested")
    return true
end
return T
