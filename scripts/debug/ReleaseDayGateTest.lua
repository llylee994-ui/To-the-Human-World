-- 真实 schema4 协调器和保存协议；只有文件介质隔离。完整 11 单另跑 RunFull。
local U=require "core.StateUtil"
local R=require "debug.fixtures.ReleaseFixtures"
local E=require "debug.fixtures.ReleaseEndingFixtures"
local D=require "systems.RecipeDraft"
local must=E.Must
local T={}
local function blocked(x,code)
    local before=x.state.GetSnapshot();local writes=x.writes
    local action=x.state.CheckAction("NextDay");local result=x.state.NextDay()
    assert(not action.enabled and action.reasonCode==code,cjson.encode(action))
    assert(not result.ok and result.error.code==code,cjson.encode(result))
    assert(U.Equal(before,x.state.GetSnapshot()) and x.writes==writes,"denied action must not save or mutate")
end
function T.Run()
    local check,done=R.Checks("ReleaseDayGate")
    check("unreceived unread read accepted draft pending and reset cannot skip shipment",function()
        local x=E.New();blocked(x,"DAY_LETTER_UNRECEIVED")
        local id=must(x.state.ReceiveLetter({letterId="letter_pa_01"})).letterInstanceId
        blocked(x,"DAY_ORDER_UNFINISHED")
        must(x.state.ReadLetter({letterInstanceId=id}));blocked(x,"DAY_ORDER_UNFINISHED")
        local request=R.Accept(x,1);blocked(x,"DAY_ORDER_UNFINISHED")
        must(x.order.UpdateDraft({orderId=request.orderId,draft=D.Project(request)}));blocked(x,"DRAFT_NOT_EMPTY")
        local pending=must(x.order.Preview(request));blocked(x,"ORDER_LOCKED")
        local order=x.state.GetSnapshot().currentOrder
        must(x.order.Reset({orderId=request.orderId,transactionId=pending.transactionId,baselineId=order.baseline.id}))
        blocked(x,"DAY_ORDER_UNFINISHED")
        pending=R.Preview(x,request)
        must(x.order.Confirm({orderId=request.orderId,transactionId=pending.transactionId}))
        assert(x.state.CheckAction("NextDay").enabled and x.state.ReloadCurrent())
        local writes=x.writes
        assert(must(x.order.Confirm({orderId=request.orderId,transactionId=pending.transactionId})).alreadyConfirmed and x.writes==writes)
        must(x.state.NextDay());assert(x.state.GetSnapshot().live.gameFlow.day==2)
        blocked(x,"DAY_LETTER_UNRECEIVED")
    end)
    check("one and two star shipments both unlock the day",function()
        local cases=require "debug.fixtures.NumericV02Cases"
        for _,index in ipairs({3,4}) do
            local x=E.New();local request=R.Accept(x,1);local recipe=cases[index].recipe
            request.mainTokenId=assert(x.tokens[recipe.mainWordId]);request.auxTokenIds={}
            for _,id in ipairs(recipe.auxWordIds) do request.auxTokenIds[#request.auxTokenIds+1]=assert(x.tokens[id]) end
            request.ingredients=U.Copy(recipe.ingredients)
            local pending=R.Preview(x,request)
            assert(x.state.GetSnapshot().currentOrder.pending.rating.stars==cases[index].expect.stars)
            must(x.order.Confirm({orderId=request.orderId,transactionId=pending.transactionId}))
            must(x.state.NextDay());assert(x.state.GetSnapshot().live.gameFlow.day==2)
        end
    end)
    for _,fault in ipairs({"write","uncertain"}) do
        check("shipment "..fault.." does not unlock day before commit recovery",function()
            local x=E.New();local request=R.Accept(x,1);local pending=R.Preview(x,request)
            local before=x.state.GetSnapshot();x.commitWritten=false;x.fault=fault
            assert(not x.order.Confirm({orderId=request.orderId,transactionId=pending.transactionId}).ok)
            assert(U.Equal(before,x.state.GetSnapshot()) and not x.state.CheckAction("NextDay").enabled)
            assert(not x.state.NextDay().ok)
            x.fault=false;assert(x.state.ReloadCurrent())
            if fault=="write" then
                blocked(x,"ORDER_LOCKED")
                must(x.order.Confirm({orderId=request.orderId,transactionId=pending.transactionId}))
            end
            assert(x.state.CheckAction("NextDay").enabled)
            local day=x.state.GetSnapshot().live.gameFlow.day;x.fault="write"
            assert(not x.state.NextDay().ok and x.state.GetSnapshot().live.gameFlow.day==day)
            x.fault=false;must(x.state.NextDay());assert(x.state.GetSnapshot().live.gameFlow.day==day+1)
        end)
    end
    check("legacy D14 backlog ships before D15 and later letters remain available",function()
        local x=E.New();R.LegacyDay(x,14);blocked(x,"DAY_LETTER_UNRECEIVED")
        assert(not must(x.session.queries.GetReleaseProgress()).canClose)
        assert(not x.state.BeginClosing(E.Request(x)).ok)
        R.Ship(x,1);must(x.state.NextDay())
        assert(x.state.GetSnapshot().live.gameFlow.day==15 and x.state.ReloadCurrent())
        blocked(x,"DAY_LETTER_UNRECEIVED")
        R.Ship(x,2);assert(not must(x.session.queries.GetReleaseProgress()).canClose)
        must(x.state.NextDay());assert(x.state.GetSnapshot().live.gameFlow.day==16)
    end)
    check("old incomplete closing phases must restore before continuing",function()
        for _,phase in ipairs({"closing_prepare","closing","wish"}) do
            local x=E.LegacyClosing(phase);local before=x.state.GetSnapshot();local writes=x.writes
            local w=must(x.session.queries.GetWishView());assert(w.needsStoryCompletion and not w.canConfirm)
            for _,kind in ipairs({"BeginClosing","BeginWish","UpdateWishDraft","ConfirmEnding"}) do
                local request=E.Request(x)
                if kind=="UpdateWishDraft" then request.sourceTokenIds={} end
                if kind=="ConfirmEnding" then request.kind="wish" end
                local result=x.state[kind](request)
                assert(not result.ok and not x.state.CheckAction(kind).enabled,kind)
            end
            assert(U.Equal(before,x.state.GetSnapshot()) and writes==x.writes)
            must(x.state.RestoreEndingCheckpoint(E.Request(x)))
            assert(x.state.GetSnapshot().chapter.phase=="operating" and x.state.ReloadCurrent())
            assert(U.Equal(before.chapter.checkpoint.live,x.state.GetSnapshot().live))
        end
    end)
    check("historical wish ending remains frozen and restorable",function()
        local x=E.LegacyClosing("ended");local before=x.state.GetSnapshot();local writes=x.writes
        assert(must(x.session.queries.GetEndingView()).ending.text==before.chapter.ending.text)
        assert(must(x.state.ConfirmEnding(E.Request(x,{kind="wish"}))).alreadyEnded and x.writes==writes)
        must(x.state.RestoreEndingCheckpoint(E.Request(x)))
        assert(not must(x.session.queries.GetReleaseProgress()).canClose)
        blocked(x,"DAY_ORDER_UNFINISHED")
    end)
    check("ticket can depart with an unfinished accepted letter and restore it",function()
        local x=E.New(666);R.Accept(x,1);blocked(x,"DAY_ORDER_UNFINISHED")
        local before=x.state.GetSnapshot();local quote=R.Quote(x,"travel_ticket",666)
        assert(must(x.session.queries.GetTravelTicketView()).canDepart)
        assert(must(x.state.PurchaseTravelTicket(quote)).departed)
        assert(x.state.GetSnapshot().live.economy.currency==0 and x.state.ReloadCurrent())
        must(x.state.RestoreEndingCheckpoint(E.Request(x)))
        assert(U.Equal(before.live,x.state.GetSnapshot().live) and U.Equal(before.currentOrder,x.state.GetSnapshot().currentOrder))
        blocked(x,"DAY_ORDER_UNFINISHED")
    end)
    return done()
end
function T.RunFull()
    local x=E.Route(8,11,function(index,route)
        local p=must(route.session.queries.GetReleaseProgress())
        assert(p.requiredCount==11 and p.completedCount==index and p.canClose==(index==11))
        assert(route.state.GetSnapshot().chapter.phase=="operating")
        if index<11 then assert(not route.state.BeginClosing(E.Request(route)).ok) end
        print("[ReleaseDayRoute] shipped "..index.."/11; day="..route.state.GetSnapshot().live.gameFlow.day)
    end)
    assert(x.state.GetSnapshot().live.gameFlow.day==11)
    assert(not must(x.session.queries.GetReleaseProgress()).canApprentice)
    local wishRoute=E.Clone(x)
    E.Homes(x);assert(must(x.session.queries.GetReleaseProgress()).canApprentice)
    local before=x.state.GetSnapshot();must(x.state.NextDay())
    assert(x.state.GetSnapshot().chapter.phase=="closing" and x.state.GetSnapshot().live.gameFlow.day==11)
    must(x.state.AdvanceEpilogue(E.Request(x,{expectedStep="dawn"})))
    assert(must(x.state.ConfirmEnding(E.Request(x,{kind="apprentice"}))).ending.kind=="apprentice")
    assert(x.state.ReloadCurrent());must(x.state.RestoreEndingCheckpoint(E.Request(x)))
    assert(U.Equal(before.live,x.state.GetSnapshot().live))
    x=wishRoute;must(x.state.BeginClosing(E.Request(x)));E.OpenWish(x)
    local sample=must(x.session.queries.GetWishView()).samples[1]
    must(x.state.UpdateWishDraft(E.Request(x,{sourceTokenIds={sample.sourceTokenId}})))
    assert(must(x.state.ConfirmEnding(E.Request(x,{kind="wish"}))).ending.kind=="wish")
    assert(x.state.ReloadCurrent())
    print("[ReleaseDayRoute] PASS actual 11 orders, 8 three-star, homes, D11 closure, both endings and restoration")
    return true
end
return T
