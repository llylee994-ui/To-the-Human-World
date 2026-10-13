-- Real AppView/Probe/UI dispatch; only the GPU renderer and layout/clock are adapters.
local T={}
function T.Run()
    package.loaded["debug.DeveloperMode"]=false
    MOUSEB_LEFT,MOUSEB_MIDDLE,MOUSEB_RIGHT=0,1,2 -- Headless enum adapters.
    local Engine=require "urhox-libs/UI/Core/UI"
    local Event=require "urhox-libs/UI/Core/PointerEvent"
    local G=require "ui.landscape.LayoutGeometry"
    local U=require "core.StateUtil"
    local Data=require "data.content"
    local host=require("ui.landscape.tests.ZoomTestHost").New()
    local fixture=require("debug.fixtures.B5Fixtures").New(Data,{targetSchema=3})
    local creates,releases,checks,nav=0,0,0,0
    local failure=false
    local original=package.loaded["ui.landscape.HomeYawScene"]
    package.loaded["ui.landscape.HomeYawScene"]={New=function()
        if failure then return nil,"test renderer failure" end
        creates=creates+1
        return {SetYaw=function() end,Sample=function() return true end,Resize=function() end,
            Draw=function() end,Close=function() releases=releases+1 end}
    end}
    package.loaded["ui.landscape.HomeYawProbe"]=nil
    local view=require("ui.landscape.AppView").New(fixture.session,Data)
    local navigate=view.Navigate
    view.Navigate=function(target) nav=nav+1;navigate(target) end
    local function check(ok,why) checks=checks+1;assert(ok,why) end
    local function bind()
        host.Bind(view.root);Engine.SetRoot(view.root)
        local close=view.root:FindById("homeYawClose")
        if close then close.testLayout={x=view.root:GetAbsoluteLayout().w-80,y=0,w=76,h=48} end
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
    local function tap(x,y) pointer("PointerDown",x,y);pointer("PointerUp",x,y);bind() end
    local function start()
        tap(point("home.stove"));check(view.yawProbe and view.scene=="home","stove opens yaw before brew")
        check(not view.root:FindById("homeYawPlay"),"normal entry needs no Play button")
        step(.01)
        view.root:FindById("homeYawCanvas"):Render({})
        step(.01);check(view.yawProbe.motion.active and view.yawProbe.motion.elapsed==0,"automatic start after initial draw")
    end
    bind()
    check(not view.root:FindById("openHomeYawProbe") and not view.OpenYawProbe(),"developer switch stays off")
    local before,writes=fixture.state.GetSnapshot(),fixture.writes
    for _,size in ipairs({{1280,720},{1560,720},{1024,768},{640,360}}) do
        host.width,host.height=size[1],size[2];bind();local previous=nav
        start();local probe=view.yawProbe;local tree=view.root:GetNumChildren()
        tap(point("home.stove"));tap(point("home.merchantShip"));tap(30,20)
        view.Open("day");view.Open("shop");view.Read("missing");view.Push("words");view.Close()
        check(not view.BeginStoveYaw() and not view.BeginHomeZoom() and not view.panel,"repeat and other actions blocked")
        for _=1,72 do
            step(1/60)
            check(view.yawProbe==probe and view.root:GetNumChildren()==tree,"same view advances before dirty guard")
        end
        step(.000001);step(.01)
        check(not view.yawProbe and view.scene=="brew" and nav==previous+1,"one completion navigates to brew")
        check(not view.home.blocked and creates==releases,"complete releases input and renderer")
        step(.1);check(nav==previous+1,"no repeated completion")
        view.Navigate("home");step(0)
        check(view.home.zoom==1 and not view.home.blocked and view.scene=="home","return restores homepage")
    end
    for _,reason in ipairs({"cancel","resize","hidden","minimized","frame-gap","elapsed-gap","navigate"}) do
        start();step(.1);local previous=nav
        if reason=="cancel" then
            local r=view.root:FindById("homeYawClose"):GetAbsoluteLayout()
            tap(r.x+20,r.y+20);check(view.yawProbe~=false,"close deferred through pointer up")
        elseif reason=="resize" then host.width=host.width+10;bind()
        elseif reason=="hidden" then view.root:FindById("homeYawCanvas").testLayout.w=0
        elseif reason=="minimized" then host.minimized=true
        elseif reason=="elapsed-gap" then host.now=host.now+1
        elseif reason=="navigate" then view.Navigate("home");previous=nav end
        host.Step(view,reason=="frame-gap" and .3 or .01);step(.01)
        check(not view.yawProbe and not view.home.blocked and view.scene=="home" and nav==previous,"interrupt "..reason)
        check(creates==releases,"resource release "..reason)
        host.minimized=false;bind()
    end
    failure=true;tap(point("home.stove"));step(.01)
    check(not view.yawProbe and not view.home.blocked and view.scene=="home","failed renderer unlocks without navigation")
    check(view.model.message:find("未能加载"),"failure is visible")
    failure=false
    view.Open("shop");step(0);tap(point("home.stove"))
    check(not view.yawProbe and view.panel=="shop","modal blocks stove")
    view.Close();step(0);start();local previous=nav
    pointer("PointerDown",100,100);view.yawProbe.Close();pointer("PointerUp",100,100)
    check(not view.panel and view.scene=="home" and nav==previous,"late release cannot trigger underlying entry")
    bind();start();view.root:Destroy();step(.1)
    check(not view.yawProbe and not view.BeginStoveYaw() and nav==previous,"destroy has no deferred navigation")
    check(creates==releases,"all renderers released")
    check(U.Equal(before,fixture.state.GetSnapshot()) and fixture.writes==writes,"no business or save writes")
    package.loaded["ui.landscape.HomeYawScene"]=original
    package.loaded["ui.landscape.HomeYawProbe"]=nil
    print("[StoveYawEntryTest] PASS assertions="..checks.."; real UI dispatch, renderer/layout/clock adapters; not native visual evidence")
    return true
end
return T
