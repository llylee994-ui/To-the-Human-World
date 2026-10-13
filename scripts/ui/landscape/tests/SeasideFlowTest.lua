-- Real GameSession/transactions, explicit File/UI/time/layout adapters.
local U=require "core.StateUtil"
local Data=require "data.content"
local F=require "debug.fixtures.B5Fixtures"
local View=require "ui.PlayView"
local T={}
function T.Run()
    package.loaded["debug.DeveloperMode"]=false
    package.loaded["ui.landscape.DevChecks"]={hotspots=false,nativeProbe=false,hitFeedback=false}
    local n=0
    local function check(value,message) n=n+1;assert(value,message) end
    local function new()
        local host=require("ui.landscape.tests.ZoomTestHost").New()
        local x=F.New(Data,{targetSchema=3})
        local view=View.New(x.session,Data)
        host.Bind(view.root);view.Navigate("seaside");view.Update();host.Bind(view.root)
        return x,view,host
    end
    local function button(view,id)
        return assert(view.root:FindById(id),"missing "..id)
    end
    local function click(view,id)
        button(view,id):GetProps().onClick();view.Update()
    end
    local function finish(view,host)
        for _=1,160 do host.Step(view,1/60) end
    end
    local x,view,host=new()
    check(view.seaside~=nil,"formal seaside must replace functional text scene")
    local initial=x.state.GetSnapshot();local writes=x.writes
    view.Navigate("home");view.Update();view.Navigate("seaside");view.Update()
    check(U.Equal(initial,x.state.GetSnapshot()) and writes==x.writes,"navigation never receives")
    check(view.seaside.bottleVisible,"only real available letter has a floating bottle")
    click(view,"seasideShop");check(view.panel=="shop","shop opens")
    view.StartSalvage();check(U.Equal(initial,x.state.GetSnapshot()),"modal blocks direct capture callback")
    click(view,"closePanel");check(view.scene=="seaside","shop close returns to sea")
    check(view.StartSalvage().ok,"real capture succeeds");view.Update()
    local id=view.salvage.letterInstanceId
    check(view.salvage.active and id,"saved capture starts net performance")
    check(view.panel==false,"reader waits until performance completes")
    local saved=x.state.GetSnapshot();writes=x.writes
    check(saved.live.gameFlow.salvageUsedToday==1 and saved.live.letters.byId[id],"one actual letter and daily use saved")
    check(not saved.live.letters.byId[id].read,"performance does not prematurely mark letter read")
    view.StartSalvage();view.Open("shop");view.Open("day");view.Navigate("home")
    check(view.scene=="seaside" and not view.panel,"performance rejects navigation/HUD/modal reentry")
    check(U.Equal(saved,x.state.GetSnapshot()) and writes==x.writes,"repeat actions never receive or write")
    host.Step(view,.1);check(view.salvage.active,"animation progresses even with model dirty false")
    finish(view,host)
    check(view.panel=="reader" and view.model.selectedLetter==id,"completion opens actual saved letter")
    check(not view.salvage.active and not view.salvage.letterInstanceId,"read acknowledgement releases capture")
    check(x.state.GetSnapshot().live.letters.byId[id].read,"actual reader marks saved letter read")
    click(view,"closePanel")
    check(not view.seaside.bottleVisible and button(view,"startSalvage"):GetProps().disabled,"daily exhaustion hides bottle and disables capture")
    local before=x.state.GetSnapshot();writes=x.writes;view.StartSalvage();finish(view,host)
    check(U.Equal(before,x.state.GetSnapshot()) and writes==x.writes,"exhausted callback cannot receive")
    local empty=x.session.queries.GetSalvageView()
    check(empty.ok and empty.value.remaining==0,"daily gate remains real")
    x,view,host=new();before=x.state.GetSnapshot();x.fault="write"
    check(not view.StartSalvage().ok,"save failure reports failure");view.Update();x.fault=false
    check(not view.salvage.active and not view.salvage.letterInstanceId,"failed save never shows a caught bottle")
    check(U.Equal(before,x.state.GetSnapshot()) and view.seaside.bottleVisible,"failed receive preserves state and floating bottle")
    check(view.model.message~="" and not button(view,"startSalvage"):GetProps().disabled,"failure remains visible and retry allowed")
    check(view.StartSalvage().ok,"capture retry succeeds");view.Update();id=view.salvage.letterInstanceId
    x.fault="write";finish(view,host);x.fault=false
    check(not view.panel and not view.salvage.active and view.salvage.letterInstanceId==id,"read save failure retains received letter for retry")
    check(button(view,"readCapturedLetter"):GetProps().visible,"failed reader exposes retry button")
    before=x.state.GetSnapshot();writes=x.writes;view.StartSalvage()
    check(U.Equal(before,x.state.GetSnapshot()) and x.writes==writes,"unacknowledged catch blocks recapture")
    click(view,"readCapturedLetter");check(view.panel=="reader" and not view.salvage.letterInstanceId,"retry reads same captured letter")
    for _,mode in ipairs({"focus","resize","gap","skip","destroy"}) do
        x,view,host=new();check(view.StartSalvage().ok,"capture before "..mode);view.Update()
        id=view.salvage.letterInstanceId;before=x.state.GetSnapshot();writes=x.writes
        if mode=="focus" then host.focused=false;host.Step(view,.02);host.focused=true
        elseif mode=="resize" then host.width=1600;host.Bind(view.root);host.Step(view,.02)
        elseif mode=="gap" then host.Step(view,.4)
        elseif mode=="skip" then view.SkipSalvage();view.Update()
        else view.root:Destroy();finish(view,host) end
        check(not view.salvage.active,"performance stops on "..mode)
        if mode=="skip" then
            check(view.panel=="reader" and x.state.GetSnapshot().live.gameFlow.salvageUsedToday==1,"skip reads without second receive")
        else
            check(U.Equal(before,x.state.GetSnapshot()) and x.writes==writes,"interruption does not rewrite saved capture "..mode)
            check(view.salvage.letterInstanceId==id,"interruption keeps caught id "..mode)
            if mode~="destroy" then
                view.Update();check(not view.root:FindById("salvageBlocker"):GetProps().visible,"interruption frees blocker")
                view.Navigate("home");view.Update();view.Open("letters");view.Update()
                check(view.root:FindById("read_"..id)~=nil,"captured letter recoverable through drawer "..mode)
                click(view,"read_"..id)
                check(view.panel=="reader" and not view.salvage.letterInstanceId,"drawer reading acknowledges interrupted receipt "..mode)
            end
        end
    end
    x,view,host=new();check(view.StartSalvage().ok,"capture before reload");view.Update()
    id=view.salvage.letterInstanceId;assert(x.Reload())
    check(x.state.GetSnapshot().live.letters.byId[id]~=nil,"window exit has saved catch independent of animation")
    -- Real engine Lua pointer dispatch with explicit layout adapter.
    MOUSEB_LEFT,MOUSEB_MIDDLE,MOUSEB_RIGHT=0,1,2
    local Engine=require "urhox-libs/UI/Core/UI"
    local Event=require "urhox-libs/UI/Core/PointerEvent"
    local G=require "ui.landscape.LayoutGeometry"
    local function bind() host.Bind(view.root);Engine.SetRoot(view.root) end
    local function tap(px,py)
        Engine.HandlePointerDown(Event.new("PointerDown",{x=px,y=py,button=MOUSEB_LEFT,pointerType="touch",pointerId=3}))
        Engine.HandlePointerUp(Event.new("PointerUp",{x=px,y=py,button=MOUSEB_LEFT,pointerType="touch",pointerId=3}))
    end
    x,view,host=new();bind()
    for _,size in ipairs({{1280,720},{1560,720},{1600,720},{1024,768},{800,360}}) do
        host.width,host.height=size[1],size[2];bind()
        local fit=view.seaside.Fit();local layer=view.seaside.ShipLayer()
        local px,py=G.ToScreen(layer,fit,.47,.34)
        local rootBounds=view.seaside.root:GetAbsoluteLayout()
        check(fit.w>=rootBounds.w-.001 and fit.scale>0,"seaside full-width projection "..size[1])
        check(Engine.FindWidgetAt(px,py).props.id=="seaside.merchantShip","ship hit follows art "..size[1])
        tap(px,py);view.Update();bind();check(view.panel=="shop","real pointer opens shop")
        tap(px,py);view.Update();check(not view.salvage.active,"modal never captures through art")
        click(view,"closePanel");bind()
        local waterX=fit.x+1500*fit.scale;local waterY=fit.y+600*fit.scale
        check(not Engine.FindWidgetAt(waterX,waterY),"sea blank is not an invisible input target")
    end
    local capture=button(view,"startSalvage"):GetAbsoluteLayout()
    tap(capture.x+capture.w/2,capture.y+capture.h/2);view.Update();bind()
    check(view.salvage.active,"real pointer starts performance")
    before=x.state.GetSnapshot();writes=x.writes
    local hud=button(view,"nextDay"):GetAbsoluteLayout()
    tap(hud.x+20,hud.y+20);view.Update()
    check(not view.panel and view.salvage.active,"topmost input blocker covers HUD")
    check(U.Equal(before,x.state.GetSnapshot()) and writes==x.writes,"blocked pointer has no business effects")
    local skip=button(view,"skipSalvage"):GetAbsoluteLayout()
    tap(skip.x+skip.w/2,skip.y+skip.h/2);view.Update()
    check(view.panel=="reader" and not view.salvage.active,"pointer skip opens saved reader once")
    check(x.state.GetSnapshot().live.gameFlow.salvageUsedToday==1,"skip pointer does not recapture")
    print("[SeasideFlow] PASS assertions="..n.."; saved capture, once-only, reader retry, modal, failure, skip/interruption, drawer/reload; NOT native/mobile")
    return {passed=n,failed=0}
end
return T
