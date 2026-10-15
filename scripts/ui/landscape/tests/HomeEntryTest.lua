-- Actual business/UI callbacks and engine Lua input dispatch, with explicit
-- File/widget geometry adapters. Does not claim native rendering or device input.
local U=require "core.StateUtil"
local Data=require "data.content"
local F=require "debug.fixtures.B5Fixtures"
local View=require "ui.PlayView"
local Manifest=require "ui.landscape.LayoutManifest"
local G=require "ui.landscape.LayoutGeometry"
local T={}
local count=0
local function check(ok,message) count=count+1; assert(ok,message) end
local function must(r) assert(r.ok,cjson.encode(r.error)); return r.value end
local function trace(value) print("[HomeEntry] "..value) end
function T.Run()
    -- Preserve the complete legacy room regression, including its case board.
    -- The release player entry is covered by debug.ReleaseUITest.
    local Data=U.Copy(Data);Data.release=nil
    package.loaded["debug.DeveloperMode"]=false
    local zoomHost=require("ui.landscape.tests.ZoomTestHost").New()
    local testUI=require "urhox-libs/UI"
    testUI.MeasureTextWidth=testUI.MeasureTextWidth or function(value,size) return utf8.len(value)*size end
    local x=F.New(Data,{targetSchema=3})
    local view=View.New(x.session,Data)
    local function control(id) return assert(view.root:FindById(id),"control missing: "..id) end
    local function click(id,force)
        -- The reader now unfolds before accepting cuts and collects one strip
        -- at a time. Advance only its simulated display clock, keeping every
        -- original business assertion below intact.
        for _=1,90 do
            local cache=view.readerCache
            if not cache or not cache.presentation or (not cache.presentation.motion.opening and not cache.presentation.motion.flight) then break end
            zoomHost.Step(view,1/60)
        end
        if id:match("^cut_") then
            local presentation=view.readerCache.presentation --[[@as table]]
            check(presentation.paper.enabled,"paper cut enabled")
            presentation.Cut(id:sub(5));view.Update();return
        end
        local b=control(id); check(force or not b:GetProps().disabled,"button disabled: "..id)
        if id=="home.net" or id=="home.stove" then zoomHost.Bind(view.root) end
        b:GetProps().onClick(); view.Update()
        if id=="startSalvage" then
            for _=1,150 do if view.salvage.active then zoomHost.Step(view,1/60) end end
        elseif id=="home.net" or id=="home.stove" then
            for _=1,(id=="home.stove" and 37 or 28) do if view.zoom.active then zoomHost.Step(view,1/60) end end
        end
    end
    local function capture(name)
        local export=rawget(_G,"HOME_EVIDENCE")
        if export then export(name,view.root,x.state.GetSnapshot()) end
    end
    check(not view.root:FindById("toggleHomeHotspots"),"normal player must not see dev controls")
    capture("home-initial")
    for _,o in ipairs(Manifest.objects) do
        view.Navigate("home"); view.Update()
        local before,writes=x.state.GetSnapshot(),x.writes
        click(o.id)
        check(U.Equal(before,x.state.GetSnapshot()) and writes==x.writes,"opening object mutated state: "..o.id)
        if o.target=="brew" or o.target=="seaside" then check(view.scene==o.target,"scene target")
        else check(view.panel==(o.target=="paper" and "letters" or o.target),"panel target") end
    end
    trace("eight object callbacks navigate without writes or consumption")
    view.Navigate("home");view.Update();click("home.letterPaper")
    check(control("lettersEmpty")~=nil,"paper empty state")
    click("closePanel");click("home.net")
    local day=x.state.GetSnapshot().live.gameFlow.day
    click("seasideShop"); click("closePanel");check(view.scene=="seaside","shop close returns seaside")
    click("startSalvage")
    local id=view.model.selectedLetter
    check(id and view.panel=="reader","capture opens actual received letter")
    check(x.state.GetSnapshot().live.gameFlow.salvageUsedToday==1,"only explicit capture spends one chance")
    local definition=assert(Data.GetLetter(x.state.GetSnapshot().live.letters.byId[id].letterId))
    check(control("readerTitle"):GetText()==definition.title,"real title")
    check(control("readerRequirement"):GetText()=="委托要求："..definition.requirement.desc,"formal requirement")
    check(control("readerReward"):GetText():find(tostring(definition.reward.currency),1,true),"formal reward")
    check(control("readerSender"):GetText():find(assert(Data.GetNpc(definition.senderId)).name,1,true),"real sender")
    local parsed=must(x.modules.letters.GetView(id)); local paper=control("letterPaper"); local scroll=control("playScroll")
    scroll.testScrollY=650
    local before=x.state.GetSnapshot();x.fault="write";click("cut_"..parsed.spans[1].spanId);x.fault=false
    check(U.Equal(before,x.state.GetSnapshot()),"failed cut cannot mutate")
    check(control("letterPaper")==paper and scroll.testScrollY==650,"failed cut retains node and scroll")
    check(view.model.message:find("失败",1,true),"failed cut is not reported successful")
    check(control("panelMessage"):GetText()==view.model.message,"failed cut visible inside reader overlay")
    for _,span in ipairs(parsed.spans) do
        click("cut_"..span.spanId)
        check(control("letterPaper")==paper and scroll.testScrollY==650,"successful cut retains nodes/scroll")
        local saved=must(x.modules.letters.GetView(id))
        local cut=false;for _,s in ipairs(saved.spans) do if s.spanId==span.spanId then cut=s.cut end end
        check(cut,"span cut once")
    end
    check(not paper:GetText():find("缺口",1,true),"cut slots leave whitespace")
    before=x.state.GetSnapshot();click("closePanel")
    check(U.Equal(before,x.state.GetSnapshot()) and not before.currentOrder,"closing does not accept")
    check(view.scene=="seaside","reader close returns scene")
    click("returnHome");click("home.letterPaper")
    check(must(x.modules.letters.GetView(id)).spans[1].cut,"reopen preserves cuts")
    capture("reader-cut")
    click("acceptOrder");check(view.scene=="brew","accept explicit command opens workspace")
    local order=x.state.GetSnapshot().currentOrder
    view.model.selectedLetter=false;view.Navigate("home");view.Update();click("home.letterPaper")
    check(view.model.selectedLetter==order.letterInstanceId,"paper falls back to current order")
    click("closePanel");click("home.drawer");click("read_"..id)
    check(view.panel=="reader" and control("letterPaper"),"drawer and paper use same reader")
    click("closePanel");check(view.panel=="letters","reader from drawer returns to list")
    click("closePanel");click("home.stove");click("brewWords")
    local cards=must(x.session.queries.GetWordTray()).cards
    local tokens={}; for _,c in ipairs(cards) do tokens[c.wordId]=c.tokenId end
    local sample=assert(require("debug.fixtures.NumericV02Cases")[1]).recipe
    local main=assert(tokens[sample.mainWordId]);local extra=false
    for _,card in ipairs(cards) do if card.tokenId~=main then extra=card.tokenId;break end end
    local mainCard=false --[[@as table|false]]
    for _,card in ipairs(cards) do if card.tokenId==main then mainCard=card end end
    assert(mainCard,"fixture main word appears in the tray query")
    click("wordTrayTab_"..mainCard.categoryId)
    check(view.root:FindById("wordTrayCard_"..main),"collected word is browsable in the tray")
    must(view.model.Drop("word",main));must(view.model.Drop("word",extra))
    local draft=view.model.GetDraft()
    check(draft.mainTokenId==main and draft.auxTokenIds[1]==extra,"real source IDs in draft")
    must(view.model.TakeOut("word",main));check(view.model.GetDraft().mainTokenId==false and view.model.GetDraft().auxTokenIds[1]==extra,"main removal does not promote aux")
    must(view.model.Drop("word",main));must(view.model.TakeOut("word",extra));click("closePanel")
    for _=1,20 do zoomHost.Step(view,1/60) end
    for _,line in ipairs(sample.ingredients) do for _=1,line.quantity do click("add_"..line.ingredientId) end end
    draft=view.model.GetDraft();click("returnHome")
    check(U.Equal(draft,view.model.GetDraft()),"return home preserves saved draft")
    click("nextDay");before=x.state.GetSnapshot();click("confirmNextDay",true)
    check(U.Equal(before,x.state.GetSnapshot()) and view.panel=="day","nonempty draft denies day and remains confirm")
    check(view.model.message~="已进入新的一天。","day failure is not success")
    click("cancelNextDay")
    click("home.merchantShip");before=x.state.GetSnapshot();x.fault="write";click("buy_ing_sea_salt");x.fault=false
    check(U.Equal(before,x.state.GetSnapshot()),"purchase write failure cannot consume currency")
    check(view.model.message:find("失败",1,true),"purchase failure honest")
    check(control("panelMessage"):GetText()==view.model.message,"failed purchase visible inside shop overlay")
    click("buy_ing_sea_salt")
    check(x.state.GetSnapshot().live.economy.currency<before.live.economy.currency,"explicit purchase settles")
    click("closePanel");click("home.stove")
    before=x.state.GetSnapshot();x.fault="write";click("previewOrder");x.fault=false
    check(U.Equal(before,x.state.GetSnapshot()),"preview write failure cannot create result")
    click("previewOrder");check(view.panel=="result","preview saves actual result")
    local pending=x.state.GetSnapshot();local tid=pending.currentOrder.pending.transactionId
    capture("pending")
    click("closePanel");click("returnHome")
    check(U.Equal(pending,x.state.GetSnapshot()),"return home preserves pending")
    click("home.journal")
    local pendingPage=must(x.session.queries.GetJournalPage(definition.id))
    local pendingBranch=assert(pendingPage.outcomes[1],"pending attempt keeps its branch")
    click("bookEntry_"..pendingBranch.branchFragmentId)
    check(control("bookEntryText"):GetText()==pending.journal.byAttemptId[tid].followup.renderedText,"history renders stored text")
    check(not view.root:FindById("confirmOrder") and not view.root:FindById("resetOrder"),"history has no resolution commands")
    check(U.Equal(pending,x.state.GetSnapshot()),"history never recomputes or settles")
    click("closePanel");click("nextDay");click("confirmNextDay",true)
    check(U.Equal(pending,x.state.GetSnapshot()),"pending blocks cross day")
    click("cancelNextDay");click("resumePending");click("resetOrder")
    check(must(x.session.queries.GetAttempt(tid)).status=="reset","reset attempt retained")
    click("returnHome");click("home.journal")
    local journalPage=must(x.session.queries.GetJournalPage(definition.id))
    local branch=assert(journalPage.outcomes[1],"reset attempt keeps its branch")
    click("bookEntry_"..branch.branchFragmentId)
    check(control("bookEntryText"):GetText()==pending.journal.byAttemptId[tid].followup.renderedText,"reset history still readable")
    capture("history-reset");click("closePanel")
    click("nextDay");before=x.state.GetSnapshot();x.fault="write";click("confirmNextDay");x.fault=false
    check(U.Equal(before,x.state.GetSnapshot()),"cross day write failure not installed")
    click("confirmNextDay");check(x.state.GetSnapshot().live.gameFlow.day==day+1,"empty draft allows explicit day")
    check(view.panel==false,"successful day closes confirmation")
    click("home.caseFile");check(control("caseEmpty"),"true unopened case state");click("closePanel")
    -- Recreate the view/session from saved state, never a production slot.
    assert(x.Reload());view=View.New(x.session,Data);view.Open("brew");view.Update();click("brewWords");must(view.model.Drop("word",main));click("closePanel")
    for _,line in ipairs(sample.ingredients) do for _=1,line.quantity do click("add_"..line.ingredientId) end end
    click("previewOrder");local second=x.state.GetSnapshot();x.fault="write";click("confirmOrder");x.fault=false
    check(U.Equal(second,x.state.GetSnapshot()),"shipping failure preserves pending")
    click("confirmOrder");check(not x.state.GetSnapshot().currentOrder,"shipping closes real order")
    check(x.state.GetSnapshot().live.gameFlow.deliveredOrders==1,"one delivered order")
    trace("letter binding/read/cut/faults, source cards, draft/pending preservation, shop, history, reset, day and shipping callbacks passed")
    T.Geometry()
    T.Input()
    trace("PASS assertions="..count.."; Lua input dispatch + File/widget adapters; native/mobile separate")
    return true
end
function T.Geometry()
    for _,size in ipairs({{1920,1080},{1560,720},{1600,720},{1024,768},{812,375},{800,360}}) do
        local bounds={x=28,y=60,w=size[1]-56,h=size[2]-100};local fit=G.Fit(bounds,Manifest)
        check(fit.w<=bounds.w+.001 and fit.h<=bounds.h+.001,"complete contain")
        for _,o in ipairs(Manifest.objects) do
            local layer=assert(Manifest.layers[o.layer]);local r=assert(o.regions[1])
            local x,y=G.ToScreen(layer,fit,r.cx,r.cy)
            check(G.Pick(Manifest,fit,x,y).id==o.id,"subject hit at aspect "..size[1].." / "..o.id)
            local lx,ly=G.ToLocal(layer,fit,x,y)
            check(math.abs(lx-(r.cx-.5)*layer.width)<1e-8 and math.abs(ly-(r.cy-.5)*layer.height)<1e-8,"rotation inverse")
        end
        for _,probe in ipairs({{6,.9,.92},{8,.5,.05},{3,.90,.90},{4,.90,.12}}) do
            local o=assert(Manifest.objects[math.floor(probe[1])]);local px,py=G.ToScreen(assert(Manifest.layers[o.layer]),fit,probe[2],probe[3])
            check(not G.HitObject(Manifest,o,fit,px,py),"transparent margin/water/decoration excluded")
        end
        local overlaps=0
        for y=fit.y,fit.y+fit.h,4 do for x=fit.x,fit.x+fit.w,4 do
            local hits=0;for _,o in ipairs(Manifest.objects) do if G.HitObject(Manifest,o,fit,x,y) then hits=hits+1 end end
            if hits>1 then overlaps=overlaps+1 end
        end end
        check(overlaps==0,"neighbor regions overlap at "..size[1]..": "..overlaps)
    end
    trace("six aspect/size/safe-margin projections: subjects, transparent margins, inverse rotation and no intersecting targets")
end
function T.Input()
    MOUSEB_LEFT,MOUSEB_MIDDLE,MOUSEB_RIGHT=0,1,2 -- Explicit enum adapters, matching PointerEvent documentation.
    local EngineUI=require "urhox-libs/UI/Core/UI"
    local Widget=require "urhox-libs/UI/Core/Widget"
    local Event=require "urhox-libs/UI/Core/PointerEvent"
    local UI=require "urhox-libs/UI"
    local n=0;local home=require("ui.landscape.HomeView").New(function() n=n+1 end,true)
    local bounds={x=0,y=0,w=960,h=540}
    local function bind(w,l)
        w.renderProps_={};w.testLayout=l or bounds
        function w:IsVisible() return self.props.visible~=false end
        function w:GetRenderChildren() return self.children end
        function w:GetAbsoluteLayout() return self.testLayout end
        w.GetAbsoluteLayoutForHitTest=w.GetAbsoluteLayout
        w.HitTest=w.HitTest or Widget.HitTest
        w.OnClick=Widget.OnClick;w.OnPointerDown=Widget.OnPointerDown;w.OnPointerUp=Widget.OnPointerUp
        w.OnMouseDown=function() end;w.OnMouseUp=function() end;w.OnBlur=function() end;w.OnFocus=function() end
        for _,child in ipairs(w.children) do bind(child,l) end
    end
    bind(home.root);EngineUI.SetRoot(home.root)
    local function hit(x,y) return EngineUI.FindWidgetAt(x,y) end
    local function tap(x,y)
        EngineUI.HandlePointerDown(Event.new("PointerDown",{x=x,y=y,button=0,pointerType="mouse"}))
        EngineUI.HandlePointerUp(Event.new("PointerUp",{x=x,y=y,button=0,pointerType="mouse"}))
    end
    local o=assert(Manifest.objects[6]);local r=assert(o.regions[1]);local x,y=G.ToScreen(Manifest.layers[o.layer],home.Fit(),r.cx,r.cy)
    check(assert(hit(x,y)).props.id==o.id,"actual engine Lua findWidgetAt hits subject through decorative visual")
    tap(x,y);check(n==1,"one pointer up fires once")
    check(not hit(950,50),"box-none layout ignores empty background")
    local blocker=UI.Panel {id="testModal",position="absolute",width="100%",height="100%",onClick=function() end}
    home.root:AddChild(blocker);bind(blocker);tap(x,y);check(n==1,"modal blocks actual dispatch")
    blocker:Destroy()
    local side=UI.Panel {id="testSide",position="absolute",onClick=function() end}
    home.root:AddChild(side);bind(side,{x=700,y=0,w=260,h=540})
    tap(x,y);check(n==2,"side panel only intercepts its own rect")
    check(hit(750,200)==side,"side blocks inside")
    -- Closing on release does not cause the same up to hit a lower object.
    side:Destroy();blocker=UI.Panel {position="absolute",onClick=function(w) w:Destroy() end}
    home.root:AddChild(blocker);bind(blocker);tap(x,y);check(n==2,"closing a blocker cannot click through")
    trace("actual urhox-libs/UI/Core/UI pointer dispatch: decoration, modal, side panel and closing no click-through")
end
return T
