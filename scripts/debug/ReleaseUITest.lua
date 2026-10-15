-- Real release coordinator and widgets; only file/window adapters are isolated.
local U=require "core.StateUtil"
local R=require "debug.fixtures.ReleaseFixtures"
local E=require "debug.fixtures.ReleaseEndingFixtures"
local View=require "ui.PlayView"
local T={}
function T.Run()
    package.loaded["debug.DeveloperMode"]=false
    require("ui.landscape.tests.ZoomTestHost").New()
    local record,finish=R.Checks("ReleaseUI")
    local function check(name,fn)
        local filter=rawget(_G,"RELEASE_UI_FILTER")
        if not filter or name:find(filter,1,true) then record(name,fn) end
    end
    local function open(x)
        x.content.releaseEndings=U.Copy(require "data.release_endings")
        local v=View.New(x.session,x.content)
        local function widget(id) return assert(v.root:FindById(id),"missing "..id) end
        local function click(id)
            local w=widget(id);assert(not w.props.disabled,"disabled "..id)
            w.props.onClick();v.Update()
        end
        return v,widget,click
    end
    check("chair goes through schema4 ledger; cancellation and closing preserve brew draft",function()
        local x=R.New(1000);local request=R.Accept(x,1)
        R.Must(x.order.UpdateDraft({orderId=request.orderId,draft=require("systems.RecipeDraft").Project(request)}))
        local v,w,click=open(x);v.Navigate("brew");v.Update();v.Open("shop");v.Update()
        local before,writes=x.state.GetSnapshot(),x.writes
        click("shopTab_furniture");click("shop_select_decor_chair")
        v.Close();v.Update();assert(v.scene=="brew" and U.Equal(before,x.state.GetSnapshot()) and writes==x.writes)
        v.Open("shop");v.Update();click("shopTab_furniture");click("shop_select_decor_chair")
        -- Active nonempty draft must disable the purchase, never buy an ingredient instead.
        assert(w("buy_decor_chair").props.disabled)
        R.Must(x.order.UpdateDraft({orderId=request.orderId,draft={equipmentId=request.equipmentId,mainTokenId=false,auxTokenIds={},ingredients={},specialItemIds={}}}))
        v.Refresh();v.Update();click("buy_decor_chair")
        local data=x.state.GetSnapshot();assert(data.live.economy.currency==900 and #data.live.economy.itemPurchases==1)
        assert(data.live.economy.itemPurchases[1].itemId=="decor_chair" and w("buy_decor_chair").props.disabled)
    end)
    check("D14 opens preparation, actual receive/read/cut reaches selection without D15",function()
        local x=R.New();E.Day14(x);local v,w,click=open(x)
        v.Open("day");v.Update();click("confirmNextDay")
        assert(x.state.GetSnapshot().live.gameFlow.day==14 and v.panel=="closing")
        click("prepareWishLetter")
        assert(v.panel=="reader" and next(x.state.GetSnapshot().live.letters.byId))
        local span=R.Must(x.modules.letters.ParseDefinition(x.content.release.requiredOrderIds[1])).spans[1]
        R.Must(v.model.Cut(span.spanId));v.Update()
        assert(v.panel=="closing" and not w("chooseWish").props.disabled)
        assert(w("chooseApprentice").props.disabled and w("apprenticeMissing"):GetText():find("11",1,true))
        v.Open("shop");v.Update();assert(v.panel=="closing","closing blocks ordinary UI navigation")
    end)
    check("wish uses consumed sources, persists reorder/remove, preview cancel and failed save",function()
        local x=R.New();R.Ship(x,1);E.Day14(x);R.Must(x.state.BeginClosing(E.Request(x)))
        local v,w,click=open(x);click("chooseWish")
        local samples=R.Must(x.session.queries.GetWishView()).samples
        assert(#samples>=2)
        local a
        for _,sample in ipairs(samples) do if not sample.available then a=sample;break end end
        assert(a,"shipping must leave a consumed source for the wish")
        local b;for _,sample in ipairs(samples) do if sample.sourceTokenId~=a.sourceTokenId then b=sample;break end end
        local available=x.state.GetSnapshot().live.wordTokens.byId[a.sourceTokenId].available
        click("wish_add_"..a.sourceTokenId);click("wish_add_"..b.sourceTokenId);click("wish_previous_2")
        local draft=R.Must(x.session.queries.GetWishView())
        assert(draft.draftSourceIds[1]==b.sourceTokenId and draft.draftSourceIds[2]==a.sourceTokenId)
        assert(draft.draftText=="我想"..b.text..a.text)
        assert(x.state.GetSnapshot().live.wordTokens.byId[a.sourceTokenId].available==available)
        click("wish_remove_2");local before=x.state.GetSnapshot();x.fault="write";click("wish_add_"..a.sourceTokenId);x.fault=false
        assert(U.Equal(before,x.state.GetSnapshot()) and v.model.message:find("保存失败",1,true))
        click("previewWish");local writes=x.writes;click("cancelWishPreview")
        assert(v.panel=="wish" and writes==x.writes)
        assert(x.state.ReloadCurrent());v.Refresh();v.Update()
        assert(v.panel=="wish" and w("wishDraftText"):GetText()=="我想"..b.text)
        click("previewWish");click("confirmWish")
        assert(v.panel=="ending" and w("releaseEndingText"):GetText():find("我想"..b.text,1,true))
        assert(x.state.GetSnapshot().chapter.ending.wishText=="我想"..b.text)
    end)
    check("ticket cancel, departure reload, restoration and explicit new-game confirmation",function()
        local x=R.New(1000);local v,w,click=open(x);v.Open("shop");v.Update()
        click("shopTab_tickets");click("shop_select_travel_ticket");click("buy_travel_ticket")
        local before,writes=x.state.GetSnapshot(),x.writes
        click("cancelTravelTicket");assert(U.Equal(before,x.state.GetSnapshot()) and writes==x.writes)
        click("buy_travel_ticket");click("confirmTravelTicket")
        assert(v.panel=="ending" and x.state.GetSnapshot().live.economy.currency==334)
        local reloaded=E.Clone(x);v,w,click=open(reloaded)
        assert(v.panel=="ending" and w("releaseEndingText"):GetText()==reloaded.state.GetSnapshot().chapter.ending.text)
        click("restoreBeforeEnding");assert(reloaded.state.GetSnapshot().live.economy.currency==1000 and v.panel==false)
        v.Open("shop");v.Update();click("shopTab_tickets");click("shop_select_travel_ticket");click("buy_travel_ticket");click("confirmTravelTicket")
        before,writes=reloaded.state.GetSnapshot(),reloaded.writes
        click("startNewPlaythrough");assert(U.Equal(before,reloaded.state.GetSnapshot()) and writes==reloaded.writes)
        click("cancelNewPlaythrough");assert(U.Equal(before,reloaded.state.GetSnapshot()) and writes==reloaded.writes)
        click("startNewPlaythrough");reloaded.fault="write";click("confirmNewPlaythrough");reloaded.fault=false
        assert(U.Equal(before,reloaded.state.GetSnapshot()) and v.panel=="ending")
        click("confirmNewPlaythrough");assert(reloaded.state.GetSnapshot().chapter.phase=="operating" and v.panel==false)
    end)
    check("qualified apprentice remains a choice alongside wish and preserves full-stars notice",function()
        local x=E.Route(11);E.Homes(x);local v,w,click=open(x)
        assert(w("finishJourney"));click("finishJourney")
        assert(not w("chooseApprentice").props.disabled and not w("chooseWish").props.disabled)
        click("chooseWish");click("backToClosing");click("chooseApprentice")
        assert(x.state.GetSnapshot().chapter.ending.kind=="apprentice" and v.panel=="ending")
        assert(w("releaseEndingText"):GetText():find(require("data.release_endings").apprentice.allThreeStarText,1,true))
    end)
    check("release player has no case entry; ended route cannot leak back to operations",function()
        local x=R.New(1000);local v,w,click=open(x)
        assert(not v.root:FindById("home.caseFile") and not v.root:FindById("hint_home.caseFile"))
        v.Open("case");v.Update();assert(v.panel==false)
        v.Open("shop");v.Update();click("shopTab_tickets");click("shop_select_travel_ticket");click("buy_travel_ticket");click("confirmTravelTicket")
        v.Navigate("brew");v.Open("shop");v.Close();v.Update()
        assert(v.panel=="ending" and not w("homeHud").props.visible)
        assert(w("releaseBodyScroll").props.scrollY and w("restoreBeforeEnding").props.minHeight>=44)
    end)
    check("uncertain wish save offers same-slot recovery and rebuilds the committed draft",function()
        local x=E.WishSeed();local v,w,click=open(x)
        local samples=R.Must(x.session.queries.GetWishView()).samples
        -- Seed has one cut word; removing it commits an empty draft before acknowledgement fails.
        local id=samples[1].sourceTokenId
        x.commitWritten=false;x.fault="uncertain";click("wish_remove_1");x.fault=false
        assert(not x.state.CanMutate() and v.model.message:find("重新读取",1,true))
        click("reloadReleaseSave")
        assert(x.state.CanMutate() and v.panel=="wish")
        assert(#R.Must(x.session.queries.GetWishView()).draftSourceIds==0)
        assert(not w("wish_add_"..id).props.disabled)
    end)
    check("release modal intercepts room input; safe insets and capsule move the paper",function()
        local x=E.WishSeed();local v,w=open(x)
        local host=require("ui.landscape.tests.ZoomTestHost").New();host.Bind(v.root)
        MOUSEB_LEFT,MOUSEB_MIDDLE,MOUSEB_RIGHT=0,1,2
        local EngineUI=require "urhox-libs/UI/Core/UI"
        EngineUI.SetRoot(v.root)
        local hit=EngineUI.FindWidgetAt(1,719)
        assert(hit and hit.props.id=="modalBlocker","corner input must stop at the modal, above room hotspots")
        local before,writes=x.state.GetSnapshot(),x.writes
        local UI=require "urhox-libs/UI"
        local oldSize,oldInsets=UI.GetViewportSize,UI.GetSafeAreaInsets
        UI.GetViewportSize=function() return 640,360 end
        UI.GetSafeAreaInsets=function() return {left=32,right=14,top=0,bottom=16} end
        local platform=rawget(_G,"GetPlatform");GetPlatform=function() return "iOS" end
        v.Update();host.Bind(v.root);v.Update()
        assert(w("activePanel").props.left>=44 and w("activePanel").props.bottom>=28)
        assert(w("activePanel").props.top>=80 and w("releaseFooter").props.flexShrink==0)
        UI.GetViewportSize,UI.GetSafeAreaInsets=oldSize,oldInsets;GetPlatform=platform
        assert(U.Equal(before,x.state.GetSnapshot()) and writes==x.writes)
    end)
    check("old wish buttons cannot overwrite a newer draft or seal an unseen sentence",function()
        local x=R.New();R.Ship(x,1);E.Day14(x);R.Must(x.state.BeginClosing(E.Request(x)))
        local v,w,click=open(x);click("chooseWish")
        local samples=R.Must(x.session.queries.GetWishView()).samples
        local first=w("wish_add_"..samples[1].sourceTokenId).props.onClick
        local second=w("wish_add_"..samples[2].sourceTokenId).props.onClick
        first();local writes=x.writes;second()
        local draft=R.Must(x.session.queries.GetWishView()).draftSourceIds
        assert(#draft==1 and draft[1]==samples[1].sourceTokenId and x.writes==writes,"stale button must reject instead of dropping the first word")
        v.Update();click("previewWish")
        local seal=w("confirmWish").props.onClick
        R.Must(x.state.UpdateWishDraft(E.Request(x,{sourceTokenIds={samples[2].sourceTokenId}})))
        writes=x.writes;seal();v.Update()
        assert(x.state.GetSnapshot().chapter.phase=="wish" and x.writes==writes,"stale preview must not seal changed text")
        assert(v.model.message:find("重新确认",1,true))
    end)
    return finish()
end
return T
