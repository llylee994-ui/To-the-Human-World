-- 新手引导状态、开场便签、跳过与旧档边界；无头布局适配器，不宣称原生画面。
local U=require "core.StateUtil"
local T={}
local function must(r) assert(r.ok,cjson.encode(r.error));return r.value end
function T.Run()
    local Sizing=require "ui.landscape.OnboardingLayout"
    local short=Sizing.Tooltip("先去海边看看。",1200,false)
    assert(short.width<220 and short.height<70,"short hint hugs its text without a fixed empty box")
    local long="剪下的词条收在左边。调配时，可以把词条拖进锅里。"
    assert(Sizing.Tooltip(long,180,true).height>Sizing.Tooltip(long,340,true).height,
        "narrow hints grow vertically with real wrapping")
    local fontUI=require("urhox-libs/UI") --[[@as table]]
    local oldFit=fontUI.MeasureTextFit
    fontUI.MeasureTextFit=function() return {height=100} end
    assert(Sizing.Text("字",100,15,1.45).height>=100,"actual glyph bounds override nominal line height")
    fontUI.MeasureTextFit=oldFit
    local Data=require "data.content"
    local F=require "debug.fixtures.B5Fixtures"
    local View=require "ui.PlayView"
    local Host=require "ui.landscape.tests.ZoomTestHost"
    local Session=require "core.GameSession"
    local base=F.New(Data,{targetSchema=4})
    base.files={}
    local session=Session.New(Data,{saveSystem=base.save,eventBus=base.bus,targetSchema=4,onboarding=true})
    local loaded,status=session.state.Load("b5_flow")
    assert(loaded,cjson.encode(status))
    local state=session.state.GetSnapshot().onboarding
    assert(state and state.step=="intro.paper" and state.completed==false and state.skipped==false and state.noteRead==false,
        "new journey starts at the desk note")
    assert(not session.state.SetOnboarding({version=1,step="unknown",completed=false,skipped=false,noteRead=false}).ok,
        "unknown step is rejected")

    local host=Host.New()
    local view=View.New(session,Data)
    host.Bind(view.root)
    view.Update()
    local root=assert(view.root:FindById("onboardingRoot"))
    assert(root.props.visible==true,"note step shows the tutorial overlay")
    assert(view.root:FindById("onboardingTooltip"):GetProps().visible==true,"intro tooltip is visible")
    assert(view.root:FindById("onboardingSkip").props.visible==true,"skip is available")
    assert(view.root:FindById("onboardingTarget").props.visible==true,"desk note is the only intercepted target")

    view.root:FindById("onboardingTarget").props.onClick()
    view.Update()
    assert(session.state.GetSnapshot().onboarding.step=="intro.note","paper click advances to the note")
    assert(view.root:FindById("onboardingNoteLayer").props.visible==true,"note expands")
    view.root:FindById("onboardingNoteDone").props.onClick()
    view.Update()
    local after=session.state.GetSnapshot().onboarding
    assert(after.step=="home.net" and after.noteRead==true,"closing the note records noteRead and moves to the net")

    view.root:FindById("onboardingSkip").props.onClick()
    view.Update()
    assert(session.state.GetSnapshot().onboarding.skipped==true,"skip persists")
    assert(view.root:FindById("onboardingRoot").props.visible==false,"skip removes the overlay")
    assert(session.state.GetSnapshot().live.gameFlow.deliveredOrders==0,"skip grants no business progress")
    view.onboarding:ShowNote();view.Update()
    assert(view.root:FindById("onboardingNoteLayer").props.visible==true,"help can reopen the note")
    view.root:FindById("onboardingNoteDone").props.onClick();view.Update()
    assert(view.root:FindById("onboardingRoot").props.visible==false,"help note closes without changing progress")

    -- 旧存档没有 onboarding 字段时不强制播开场。
    local old=F.New(Data,{targetSchema=4})
    local oldView=View.New(old.session,old.content)
    oldView.Update()
    assert(oldView.root:FindById("onboardingRoot")==nil,"old saves do not get an onboarding overlay")

    -- 新旅程初态重新启用；已完成/跳过的旧状态不阻塞 StartNewPlaythrough 初态。
    local fresh=Session.New(Data,{saveSystem=base.save,eventBus=base.bus,targetSchema=4,onboarding=true})
    assert(fresh.state.Load("fresh_slot"))
    assert(fresh.state.GetSnapshot().onboarding.step=="intro.paper","a new journey starts the tutorial again")
    fresh.state.SetOnboarding({version=1,step="complete",completed=true,skipped=false,noteRead=true})
    local saved=fresh.state.GetSnapshot().onboarding
    assert(saved.completed==true and saved.step=="complete","completion persists")
    view.root:Destroy()
    oldView.root:Destroy()
    fresh.state.SetOnboarding({version=1,step="complete",completed=true,skipped=true,noteRead=true})
    print("[Onboarding] PASS new journey, note read, skip, persistence, old-save guard")
    assert(flowChecks(Data,F,View,Session,Host))
    pauseChecks(Data,F,View,Session,Host)
    readingChecks(Data,F,View,Session,Host)
    return true
end

function flowChecks(Data,F,View,Session,Host)
    local x=F.New(Data,{targetSchema=4});x.files={}
    local session=Session.New(Data,{saveSystem=x.save,eventBus=x.bus,targetSchema=4,onboarding=true})
    assert(session.state.Load("onboarding_flow"))
    local host=Host.New()
    local view=View.New(session,Data)
    host.Bind(view.root);view.Update()
    local stepState={version=1,step="letter.cut",completed=false,skipped=false,noteRead=false}
    assert(session.state.SetOnboarding(stepState).ok)
    view.Update()
    local letterId=Data.release.requiredOrderIds[1]
    local instance=must(session.state.ReceiveLetter({letterId=letterId})).letterInstanceId
    must(session.state.ReadLetter({letterInstanceId=instance}))
    view.model.selectedLetter=instance
    view.Update()
    local span=must(session.modules.letters.ParseDefinition(letterId)).spans[1]
    local token=must(session.state.CutWord({letterInstanceId=instance,spanId=span.spanId})).tokenId
    view.Update();view.Update()
    assert(session.state.GetSnapshot().onboarding.step=="letter.accept","real cut advances to accept")
    view.Update()
    assert(view.root:FindById("onboardingBlocker_top").props.width==0
        or view.root:FindById("onboardingBlocker_top").props.height==0,"accept step leaves reading/cutting unblocked")
    local orderId=must(session.order.Accept({letterInstanceId=instance})).orderId
    view.Update();view.Update()
    assert(session.state.GetSnapshot().onboarding.step=="brew.word","real accept advances to the workbench")
    -- 炼药讲解只靠“知道了”，不写配方、不要求打开详情或开始熬制。
    view.Navigate("brew");view.Update()
    local before=session.state.GetSnapshot()
    local steps={"brew.word","brew.book","brew.ingredient","brew.conditions","brew.ready"}
    for i,name in ipairs(steps) do
        view.Update();view.Update()
        assert(session.state.GetSnapshot().onboarding.step==name,"acknowledgement visits "..name)
        local know=assert(view.root:FindById("onboardingKnow"))
        assert(know.props.visible and not know.props.disabled,"every brewing explanation has an enabled acknowledgement")
        for _,side in ipairs({"top","bottom","left","right"}) do
            local blocker=view.root:FindById("onboardingBlocker_"..side)
            assert(blocker.props.width==0 or blocker.props.height==0,"brewing never blocks player input")
        end
        if i==1 then
            view.Navigate("home");for _=1,80 do host.Step(view,.02) end
            assert(view.scene=="home","tutorial never forces a return to the workbench")
            assert(not view.root:FindById("onboardingRoot").props.visible,"workbench tips hide outside the workbench")
            view.Navigate("brew");view.Update()
        end
        know.props.onClick()
    end
    view.Update();view.Update()
    local after=session.state.GetSnapshot()
    assert(after.onboarding.completed,"last acknowledgement ends the tutorial immediately")
    assert(not view.root:FindById("onboardingRoot").props.visible,"no completion/shipping popup remains")
    assert(U.Equal(before.currentOrder.draft,after.currentOrder.draft),"tour leaves the recipe unchanged")
    assert(after.live.gameFlow.deliveredOrders==0 and not after.currentOrder.pending,"no brew or shipment is required")
    for _,legacy in ipairs({"result.explain","complete"}) do
        assert(session.state.SetOnboarding({version=1,step=legacy,completed=false,skipped=false,noteRead=true}).ok)
        view.Update();view.Update()
        assert(session.state.GetSnapshot().onboarding.completed,"legacy post-brew tutorials close quietly")
    end
    view.root:Destroy()
    print("[Onboarding] PASS passive workbench tour, free navigation, ends at brewing button, legacy migration")
    return true
end

function pauseChecks(Data,F,View,Session,Host)
    local x=F.New(Data,{targetSchema=4});x.files={}
    local session=Session.New(Data,{saveSystem=x.save,eventBus=x.bus,targetSchema=4,onboarding=true})
    assert(session.state.Load("onboarding_pause"))
    local host=Host.New()
    local view=View.New(session,Data)
    host.Bind(view.root);view.Update()
    assert(session.state.SetOnboarding({version=1,step="sea.salvage",completed=false,skipped=false,noteRead=false}).ok)
    local function rootVisible() return view.root:FindById("onboardingRoot").props.visible==true end
    view.OpenSettings();view.Update()
    assert(view.settings.IsOpen(),"settings are open")
    assert(not rootVisible(),"settings hides the tutorial overlay")
    assert(view.scene=="home","paused tutorial does not navigate behind settings")
    view.root:FindById("closeMusicSettings").props.onClick()
    view.Update();view.Update()
    assert(not view.settings.IsOpen(),"settings closes")
    assert(rootVisible(),"closing settings shows the tutorial again")
    assert(view.scene=="seaside","resume repositions and syncs the scene")
    host.focused=false;view.Update()
    assert(not rootVisible(),"lost focus hides the tutorial overlay")
    host.focused=true;view.Update()
    assert(rootVisible(),"regained focus shows the tutorial again")
    host.minimized=true;view.Update()
    assert(not rootVisible(),"minimized app hides the tutorial overlay")
    host.minimized=false;view.Update()
    assert(rootVisible(),"restored app shows the tutorial again")
    view.portrait=true;view.Update()
    assert(not rootVisible(),"portrait hides the tutorial overlay")
    view.portrait=false;view.Update()
    assert(rootVisible(),"landscape shows the tutorial again")
    view.root:Destroy()
    print("[Onboarding] PASS settings/focus/minimized/portrait pause and resume")
end

function readingChecks(Data,F,View,Session,Host)
    local first=Data.release.requiredOrderIds[1]
    local x=F.New(Data,{targetSchema=4});x.files={}
    local session=Session.New(Data,{saveSystem=x.save,eventBus=x.bus,targetSchema=4,onboarding=true})
    assert(session.state.Load("onboarding_read"))
    local instance=must(session.state.ReceiveLetter({letterId=first})).letterInstanceId
    local host=Host.New()
    local view=View.New(session,Data)
    host.Bind(view.root);view.Update()
    assert(session.state.SetOnboarding({version=1,step="sea.read",completed=false,skipped=false,noteRead=false}).ok)
    for _=1,120 do host.Step(view,0.02) end
    assert(session.state.GetSnapshot().onboarding.step=="sea.read","tutorial never reads the letter by itself")
    assert(not session.state.GetSnapshot().live.letters.byId[instance].read,"captured letter stays unread without a click")
    assert(view.panel=="letters","resume opens the letter drawer instead of the reader")
    local card=assert(view.root:FindById("read_"..instance),"drawer exposes the received letter")
    assert(card.props.onClick,"received letter is clickable")
    card.props.onClick()
    for _=1,120 do host.Step(view,0.02) end
    assert(view.panel=="reader","the player's click opens the reader")
    assert(view.session.state.GetSnapshot().onboarding.step=="letter.cut","manual reading advances after the opening motion")
    view.root:Destroy()

    local y=F.New(Data,{targetSchema=4});y.files={}
    local live=Session.New(Data,{saveSystem=y.save,eventBus=y.bus,targetSchema=4,onboarding=true})
    assert(live.state.Load("onboarding_salvage_read"))
    local liveHost=Host.New()
    local liveView=View.New(live,Data)
    liveHost.Bind(liveView.root);liveView.Update()
    assert(live.state.SetOnboarding({version=1,step="sea.salvage",completed=false,skipped=false,noteRead=false}).ok)
    liveView.Update()
    assert(liveView.scene=="seaside","salvage step navigates to the sea")
    assert(liveView.StartSalvage().ok,"tutorial salvage receives a real letter")
    local caught=liveView.salvage.letterInstanceId
    for _=1,200 do liveHost.Step(liveView,1/60) end
    assert(not liveView.salvage.active,"salvage performance finishes")
    assert(liveView.panel==false,"finished salvage does not auto-open the reader during onboarding")
    assert(not live.state.GetSnapshot().live.letters.byId[caught].read,"salvage completion leaves the letter unread")
    assert(live.state.GetSnapshot().onboarding.step=="sea.read","salvage completion advances to the read step")
    local read=assert(liveView.root:FindById("readCapturedLetter"))
    assert(read.props.visible,"captured-letter read button is the real entrance")
    read.props.onClick()
    for _=1,200 do liveHost.Step(liveView,1/60) end
    assert(liveView.panel=="reader","clicking the sea read button opens the reader")
    assert(live.state.GetSnapshot().live.letters.byId[caught].read,"the click is the first read")
    assert(live.state.GetSnapshot().onboarding.step=="letter.cut","sea reading advances after the opening motion")
    liveView.root:Destroy()
    print("[Onboarding] PASS no auto-read; drawer/read-button entrances are manual")
end

return T
