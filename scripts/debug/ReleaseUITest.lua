-- Real release coordinator and widgets; only file/window adapters are isolated.
local U=require "core.StateUtil"
local R=require "debug.fixtures.ReleaseFixtures"
local E=require "debug.fixtures.ReleaseEndingFixtures"
local View=require "ui.PlayView"
local T={}
local Input=require "ui.landscape.tests.WishTestInput"
function T.Run()
    package.loaded["debug.DeveloperMode"]=false
    local host=require("ui.landscape.tests.ZoomTestHost").New()
    local function finishDeparture(v)
        local event={IsPrimaryAction=function() return true end,StopPropagation=function() end}
        local function step(seconds) for _=1,math.ceil(seconds/.02) do host.Step(v,.02) end end
        step(1.2)
        for _=1,#v.journeyView.pages do
            local node=assert(v.root:FindById("departureAdvance"))
            node.props.onPointerDown(event);node.props.onClick(node,event);step(.8)
        end
        step(3);assert(v.journeyView.sequence.done)
    end
    local record,finish=R.Checks("ReleaseUI")
    local function check(name,fn)
        local filter=rawget(_G,"RELEASE_UI_FILTER")
        if not filter or name:find(filter,1,true) then record(name,fn) end
    end
    local function open(x)
        x.content.releaseEndings=U.Copy(require "data.release_endings")
        local v=View.New(x.session,x.content)
        local function widget(id)
            local node=v.root:FindById(id)
            -- The reused drawer mounts only the currently selected category.
            if not node and id:match("^wish_add_") then
                local token=id:sub(#"wish_add_"+1)
                for _,card in ipairs(R.Must(x.session.queries.GetWordTray()).cards) do if card.tokenId==token then
                    local tab=assert(v.root:FindById("wordTrayTab_"..card.categoryId))
                    tab.props.onClick();v.Update();node=v.root:FindById(id);break
                end end
            end
            return assert(node,"missing "..id)
        end
        local function click(id)
            local w=widget(id);assert(not w.props.disabled,"disabled "..id)
            if id:match("^wish_add_") then Input.Source(v,w) else w.props.onClick() end
            v.Update()
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
    check("day confirmation stays disabled until shipment and does not close early",function()
        local x=R.New();local v,w,click=open(x)
        v.Open("day");v.Update();assert(w("confirmNextDay").props.disabled)
        local callback=w("confirmNextDay").props.onClick;local before=x.state.GetSnapshot()
        callback();assert(U.Equal(before,x.state.GetSnapshot()),"disabled UI must also reject direct callback")
        R.Ship(x,1);v.Refresh();v.Update();assert(not w("confirmNextDay").props.disabled)
        click("confirmNextDay")
        assert(v.panel=="day" and v.calendar.motion.active)
        host.Step(v,1.6)
        assert(x.state.GetSnapshot().live.gameFlow.day==2 and v.panel==false)
        assert(not v.root:FindById("finishJourney"))
    end)
    check("legacy unfinished closing and wish show restoration instead of new endings",function()
        for _,phase in ipairs({"closing_prepare","closing","wish"}) do
            local x=E.LegacyClosing(phase);local v,w,click=open(x)
            assert(w("restoreBeforeClosing"))
            assert(not v.root:FindById("chooseWish") and not v.root:FindById("confirmWish"))
            click("restoreBeforeClosing");assert(x.state.GetSnapshot().chapter.phase=="operating" and v.panel==false)
            v.Open("day");v.Update();assert(w("confirmNextDay").props.disabled)
        end
    end)
    check("completed story day confirmation enters closing without incrementing day",function()
        local x=E.SmallComplete();local day=x.state.GetSnapshot().live.gameFlow.day
        local v,w,click=open(x);v.Open("day");v.Update()
        assert(w("confirmNextDay").props.text=="结束今天" and not w("confirmNextDay").props.disabled)
        click("confirmNextDay")
        assert(x.state.GetSnapshot().live.gameFlow.day==day and x.state.GetSnapshot().chapter.phase=="closing")
        assert(v.panel=="day" and v.calendar.motion.active)
        host.Step(v,1.2)
        assert(w("continueEpilogue") and not v.root:FindById("chooseWish"))
    end)
    check("wish uses consumed sources, persists rotation/remove, preview cancel and failed save",function()
        local x=E.SmallComplete();R.Must(x.state.BeginClosing(E.Request(x)))
        E.OpenWish(x);local v,w,click=open(x)
        local samples=R.Must(x.session.queries.GetWishView()).samples
        assert(#samples>=2)
        local a
        for _,sample in ipairs(samples) do if not sample.available then a=sample;break end end
        assert(a,"shipping must leave a consumed source for the wish")
        local b;for _,sample in ipairs(samples) do if sample.sourceTokenId~=a.sourceTokenId then b=sample;break end end
        local available=x.state.GetSnapshot().live.wordTokens.byId[a.sourceTokenId].available
        click("wish_add_"..a.sourceTokenId);click("wish_add_"..b.sourceTokenId)
        Input.Transform(v,b.sourceTokenId,"rotate",-45);v.Update()
        local draft=R.Must(x.session.queries.GetWishView())
        assert(#draft.draftSourceIds==2 and math.abs(draft.placements[2].angle+45)<.001)
        assert(x.state.GetSnapshot().live.wordTokens.byId[a.sourceTokenId].available==available)
        v.wishSelected=a.sourceTokenId;v.Refresh();v.Update();click("wishRemove")
        local before=x.state.GetSnapshot();x.fault="write";click("wish_add_"..a.sourceTokenId);x.fault=false
        assert(U.Equal(before,x.state.GetSnapshot()) and v.model.message:find("保存失败",1,true))
        click("previewWish");local writes=x.writes;click("cancelWishPreview")
        assert(v.panel=="wish" and writes==x.writes)
        assert(x.state.ReloadCurrent());v.Refresh();v.Update()
        assert(v.panel=="wish" and w("wish_piece_"..b.sourceTokenId) and R.Must(x.session.queries.GetWishView()).draftText=="我想"..b.text)
        click("previewWish");click("confirmWish")
        assert(v.panel=="ending" and table.concat(v.journeyView.pages,"\n\n")==x.content.releaseEndings.wish.text)
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
        assert(v.panel=="ending" and table.concat(v.journeyView.pages,"\n\n")==reloaded.state.GetSnapshot().chapter.ending.text)
        finishDeparture(v)
        click("endGame");click("restoreBeforeEnding");assert(reloaded.state.GetSnapshot().live.economy.currency==1000 and v.panel==false)
        v.Open("shop");v.Update();click("shopTab_tickets");click("shop_select_travel_ticket");click("buy_travel_ticket");click("confirmTravelTicket")
        finishDeparture(v);click("endGame");before,writes=reloaded.state.GetSnapshot(),reloaded.writes
        click("startNewPlaythrough");assert(U.Equal(before,reloaded.state.GetSnapshot()) and writes==reloaded.writes)
        click("cancelNewPlaythrough");assert(U.Equal(before,reloaded.state.GetSnapshot()) and writes==reloaded.writes)
        click("startNewPlaythrough");reloaded.fault="write";click("confirmNewPlaythrough");reloaded.fault=false
        assert(U.Equal(before,reloaded.state.GetSnapshot()) and v.panel=="title")
        click("confirmNewPlaythrough");assert(reloaded.state.GetSnapshot().chapter.phase=="operating" and v.panel==false)
    end)
    check("qualified apprentice opens its letter directly and preserves approved ending text",function()
        local x=E.SmallComplete(1000);E.Homes(x);local v,w,click=open(x)
        R.Must(x.state.NextDay());v.Refresh();v.Update()
        assert(not v.root:FindById("chooseApprentice") and not v.root:FindById("chooseWish"))
        local function step(t) for _=1,math.ceil(t/.02) do host.Step(v,.02) end end
        step(1.2)
        local intro=w("continueEpilogue");intro.props.onPointerDown();click("continueEpilogue");step(1)
        local allThree=require("data.release_endings").apprentice.allThreeStarText:match("“(.-)”")
        assert(w("merchantLetterText"):GetText():find(allThree,1,true))
        w("finishMerchantLetter").props.onPointerDown();click("finishMerchantLetter");step(.6)
        assert(x.state.GetSnapshot().chapter.ending.kind=="apprentice" and v.panel=="ending")
        assert(not w("releaseEndingText"):GetText():find(allThree,1,true))
        assert(x.state.GetSnapshot().chapter.ending.text:find(require("data.release_endings").apprentice.allThreeStarText,1,true))
    end)
    check("release player has no case entry; ended route cannot leak back to operations",function()
        local x=R.New(1000);local v,w,click=open(x)
        assert(not v.root:FindById("home.caseFile") and not v.root:FindById("hint_home.caseFile"))
        v.Open("case");v.Update();assert(v.panel==false)
        v.Open("shop");v.Update();click("shopTab_tickets");click("shop_select_travel_ticket");click("buy_travel_ticket");click("confirmTravelTicket")
        v.Navigate("brew");v.Open("shop");v.Close();v.Update()
        assert(v.panel=="ending" and not w("homeHud").props.visible)
        assert(w("departureNarrationScroll").props.scrollY and w("endGame").props.minHeight>=44)
    end)
    check("uncertain wish save offers same-slot recovery and rebuilds the committed draft",function()
        local x=E.WishSeed();local v,w,click=open(x)
        local samples=R.Must(x.session.queries.GetWishView()).samples
        -- Seed has one cut word; removing it commits an empty draft before acknowledgement fails.
        local id=samples[1].sourceTokenId
        v.wishSelected=id;v.Refresh();v.Update()
        x.commitWritten=false;x.fault="uncertain";click("wishRemove");x.fault=false
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
        assert(w("modalBlocker") and w("wishEditor"),"full-screen epilogue owns room input")
        local before,writes=x.state.GetSnapshot(),x.writes
        local UI=require "urhox-libs/UI"
        local oldSize,oldInsets=UI.GetViewportSize,UI.GetSafeAreaInsets
        UI.GetViewportSize=function() return 640,360 end
        UI.GetSafeAreaInsets=function() return {left=32,right=14,top=0,bottom=16} end
        local platform=rawget(_G,"GetPlatform");GetPlatform=function() return "iOS" end
        v.Update();host.Bind(v.root);v.Update()
        local rect=v.journeyView.paper.rect
        assert(rect.x>=44 and rect.y>=80 and rect.y+rect.h<=v.viewport.h-16)
        local actions=w("wishHeaderActions").props
        assert(actions.top+actions.height<=rect.y and not v.root:FindById("wishFooter"))
        UI.GetViewportSize,UI.GetSafeAreaInsets=oldSize,oldInsets;GetPlatform=platform
        assert(U.Equal(before,x.state.GetSnapshot()) and writes==x.writes)
    end)
    check("old wish buttons cannot overwrite a newer draft or seal an unseen sentence",function()
        local x=E.SmallComplete();R.Must(x.state.BeginClosing(E.Request(x)))
        E.OpenWish(x);local v,w,click=open(x)
        local samples,groups={},{}
        for _,card in ipairs(R.Must(x.session.queries.GetWordTray()).cards) do
            local group=groups[card.categoryId] or {};groups[card.categoryId]=group
            group[#group+1]={sourceTokenId=card.tokenId}
            if #group>=2 then samples=group;break end
        end
        assert(#samples>=2,"need two sources in one drawer category")
        local first=w("wish_add_"..samples[1].sourceTokenId)
        local second=w("wish_add_"..samples[2].sourceTokenId)
        Input.Source(v,first);local writes=x.writes;Input.Source(v,second)
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
