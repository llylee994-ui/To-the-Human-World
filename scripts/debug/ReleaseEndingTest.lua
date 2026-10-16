local U=require "core.StateUtil"
local R=require "debug.fixtures.ReleaseFixtures"
local E=require "debug.fixtures.ReleaseEndingFixtures"
local must=E.Must
local T={}
function T.Run()
    local record,done=R.Checks("ReleaseEnding")
    local function check(name,fn)
        local filter=rawget(_G,"RELEASE_ENDING_FILTER")
        if not filter or name:find(filter,1,true) then record(name,fn) end
    end
    check("D14 cannot close an unfinished story",function()
        local x=E.New();R.LegacyDay(x,14);local before=x.state.GetSnapshot()
        assert(not x.state.NextDay().ok and not x.state.BeginClosing(E.Request(x)).ok)
        assert(not must(x.session.queries.GetReleaseProgress()).canClose)
        assert(U.Equal(before,x.state.GetSnapshot()))
    end)
    check("departure D10 666, stale quote, idempotency and full checkpoint restore",function()
        local poor=E.New(665)
        local r=poor.state.PurchaseTravelTicket(R.Quote(poor,"travel_ticket",666));assert(not r.ok and r.error.code=="CURRENCY_SHORT")
        local x=E.New(666);R.LegacyDay(x,10)
        local q=R.Quote(x,"travel_ticket",666);local before=x.state.GetSnapshot()
        local result=must(x.state.PurchaseTravelTicket(q));assert(result.departed and result.ending.kind=="departure")
        assert(x.state.GetSnapshot().live.economy.currency==0)
        local writes=x.writes;assert(must(x.state.PurchaseTravelTicket(q)).alreadyEnded and writes==x.writes)
        assert(x.Reload() and x.state.GetSnapshot().chapter.ending.text==result.ending.text)
        must(x.state.RestoreEndingCheckpoint(E.Request(x)));local restored=x.state.GetSnapshot()
        assert(U.Equal(restored.live,before.live) and U.Equal(restored.currentOrder,before.currentOrder) and restored.chapter.phase=="operating")
        q=R.Quote(x,"travel_ticket",666);R.LegacyDay(x,11)
        r=x.state.PurchaseTravelTicket(q);assert(not r.ok and r.error.code=="STALE_DAY")
        r=x.state.PurchaseTravelTicket(R.Quote(x,"travel_ticket",666));assert(not r.ok and r.error.code=="OFFER_EXPIRED")
        local rev=E.New(700);q=R.Quote(rev,"travel_ticket",666);must(rev.state.Shop({ingredientId="ing_sea_salt",quantity=1}))
        r=rev.state.PurchaseTravelTicket(q);assert(not r.ok and r.error.code=="STALE_REVISION")
    end)
    check("seven actual paid orders finance departure without future income",function()
        local x=E.Route(11,7);local before=x.state.GetSnapshot()
        assert(before.live.gameFlow.day==7 and before.live.economy.currency==718)
        local result=must(x.state.PurchaseTravelTicket(R.Quote(x,"travel_ticket",666)))
        assert(result.departed and x.state.GetSnapshot().live.economy.currency==52)
        assert(x.Reload() and x.state.GetSnapshot().live.gameFlow.deliveredOrders==7)
        must(x.state.RestoreEndingCheckpoint(E.Request(x)))
        assert(U.Equal(before.live,x.state.GetSnapshot().live))
    end)
    check("consumed sample remains unusable; order, selection, frozen text and new playthrough",function()
        local x=E.SmallComplete()
        local first=x.state.GetSnapshot().live.orders.confirmedById["order:1"].consumption.consumedTokenIds[1]
        local before=x.state.GetSnapshot();must(x.state.BeginClosing(E.Request(x)));E.OpenWish(x)
        local samples=must(x.session.queries.GetWishView()).samples;local second
        for _,sample in ipairs(samples) do if sample.sourceTokenId~=first then second=sample.sourceTokenId;break end end
        assert(second);local saved=x.state.GetSnapshot()
        assert(not x.state.UpdateWishDraft(E.Request(x,{sourceTokenIds={first,first}})).ok)
        assert(not x.state.UpdateWishDraft(E.Request(x,{sourceTokenIds={"unknown-source"}})).ok)
        assert(U.Equal(saved,x.state.GetSnapshot()))
        must(x.state.UpdateWishDraft(E.Request(x,{sourceTokenIds={second,first}})));assert(x.Reload())
        local req=E.Request(x,{kind="wish"});local ended=must(x.state.ConfirmEnding(req)).ending
        assert(ended.sourceTokenIds[1]==second and ended.sourceTokenIds[2]==first)
        assert(not x.state.GetSnapshot().live.wordTokens.byId[first].available)
        x.content.releaseEndings.wish.text="[验收]更改后的正文"
        assert(x.Reload() and must(x.session.queries.GetEndingView()).ending.text==ended.text)
        local writes=x.writes;assert(must(x.state.ConfirmEnding(req)).alreadyEnded and writes==x.writes)
        for _,call in ipairs({function()return x.state.NextDay()end,function()return x.state.Shop({ingredientId="ing_sea_salt",quantity=1})end,
            function()return x.state.ReceiveLetter({letterId="letter_n01"})end,function()return x.state.ReadLetter({letterInstanceId="letter:letter_pa_01"})end,
            function()return x.state.CutWord({letterInstanceId="letter:letter_pa_01",spanId="body:2"})end,
            function()return x.order.Accept({letterInstanceId="letter:letter_pa_01"})end,function()return x.order.Preview({})end,
            function()return x.order.Confirm({orderId="order:1",transactionId="order:1:attempt:1"})end}) do
            local d=x.state.GetSnapshot();assert(not call().ok and U.Equal(d,x.state.GetSnapshot()),"ended business must not mutate")
        end
        must(x.state.RestoreEndingCheckpoint(E.Request(x)));assert(U.Equal(before.live,x.state.GetSnapshot().live))
        must(x.state.BeginClosing(E.Request(x)));E.OpenWish(x)
        must(x.state.UpdateWishDraft(E.Request(x,{sourceTokenIds={first}})));must(x.state.ConfirmEnding(E.Request(x,{kind="wish"})))
        must(x.state.StartNewPlaythrough(E.Request(x)));local fresh=x.state.GetSnapshot()
        assert(fresh.live.gameFlow.day==1 and fresh.live.economy.currency==30 and next(fresh.live.wordTokens.byId)==nil and fresh.chapter.phase=="operating")
    end)
    check("empty accepted order cannot close; departure preserves reset journal",function()
        local x=E.New(700);local request=R.Accept(x,1)
        local pending=R.Preview(x,request)
        assert(not x.state.NextDay().ok and not x.state.PurchaseTravelTicket(R.Quote(x,"travel_ticket",666)).ok)
        local order=x.state.GetSnapshot().currentOrder
        must(x.order.Reset({orderId=request.orderId,transactionId=pending.transactionId,baselineId=order.baseline.id}))
        must(x.order.UpdateDraft({orderId=request.orderId,draft=require("systems.RecipeDraft").Project(request)}))
        assert(not x.state.BeginClosing(E.Request(x)).ok)
        must(x.order.UpdateDraft({orderId=request.orderId,draft=require("systems.RecipeDraft").Empty(request.equipmentId)}))
        local before=x.state.GetSnapshot();assert(not x.state.NextDay().ok and not x.state.BeginClosing(E.Request(x)).ok)
        must(x.state.PurchaseTravelTicket(R.Quote(x,"travel_ticket",666)))
        assert(U.Equal(before.currentOrder,x.state.GetSnapshot().currentOrder))
        assert(must(x.session.queries.GetReleaseProgress()).completedCount==0)
        must(x.state.RestoreEndingCheckpoint(E.Request(x)))
        assert(U.Equal(before.currentOrder,x.state.GetSnapshot().currentOrder) and U.Equal(before.journal,x.state.GetSnapshot().journal))
    end)
    check("real 7/8/11 three-star routes, missing home, ten orders and automatic route",function()
        local x=E.New();assert(type(x.session.queries.GetReleaseProgress)=="function","missing progress query")
        local eight=E.Route(8,10);local p=must(eight.session.queries.GetReleaseProgress())
        assert(p.completedCount==10 and p.threeStarCount==7 and not p.canApprentice)
        local request=R.Accept(eight,11);local pending=R.Preview(eight,request)
        assert(must(eight.session.queries.GetReleaseProgress()).completedCount==10,"trial is not completion")
        must(eight.order.Confirm({orderId=request.orderId,transactionId=pending.transactionId}));p=must(eight.session.queries.GetReleaseProgress())
        assert(p.completedCount==11 and p.threeStarCount==8 and not p.canApprentice)
        for _,item in ipairs({{"decor_tablecloth",60},{"decor_chair",100},{"decor_lamp",140}}) do must(eight.state.PurchaseHomeItem(R.Quote(eight,item[1],item[2]))) end
        p=must(eight.session.queries.GetReleaseProgress());assert(not p.canApprentice and #p.missingHomeItemIds==1 and p.missingHomeItemIds[1]=="decor_bookshelf")
        E.Homes(eight);assert(must(eight.session.queries.GetReleaseProgress()).canApprentice)
        local alternative=E.Clone(eight)
        must(eight.state.BeginClosing(E.Request(eight)));local before=eight.state.GetSnapshot()
        assert(before.chapter.ending==false and before.chapter.epilogue.route=="apprentice","letter precedes ending")
        must(eight.state.AdvanceEpilogue(E.Request(eight,{expectedStep="dawn"})))
        local ending=must(eight.state.ConfirmEnding(E.Request(eight,{kind="apprentice"}))).ending
        assert(ending.kind=="apprentice" and not ending.allThreeStar and eight.state.GetSnapshot().live.economy.currency==650)
        must(alternative.state.BeginClosing(E.Request(alternative)))
        assert(not alternative.state.BeginWish(E.Request(alternative)).ok,"qualified apprentice cannot switch routes")
        local seven=E.Route(7);E.Homes(seven);p=must(seven.session.queries.GetReleaseProgress())
        assert(p.completedCount==11 and p.threeStarCount==7 and not p.canApprentice)
        must(seven.state.BeginClosing(E.Request(seven)));assert(not seven.state.ConfirmEnding(E.Request(seven,{kind="apprentice"})).ok)
        local all=E.Route(11);E.Homes(all);assert(must(all.session.queries.GetReleaseProgress()).threeStarCount==11)
        must(all.state.BeginClosing(E.Request(all)));must(all.state.AdvanceEpilogue(E.Request(all,{expectedStep="dawn"})))
        assert(must(all.state.ConfirmEnding(E.Request(all,{kind="apprentice"}))).ending.allThreeStar)
    end)
    check("formal text remains unavailable without approved definitions",function()
        local x=E.New(666);x.content.releaseEndings={}
        local before=x.state.GetSnapshot();local r=x.state.PurchaseTravelTicket(R.Quote(x,"travel_ticket",666))
        assert(not r.ok and r.error.code=="ENDING_TEXT_UNAVAILABLE" and U.Equal(before,x.state.GetSnapshot()))
        assert(not must(x.session.queries.GetTravelTicketView()).canDepart)
    end)
    return done()
end
return T
