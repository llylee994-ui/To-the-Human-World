local U=require "core.StateUtil"
local R=require "debug.fixtures.ReleaseFixtures"
local E=require "debug.fixtures.ReleaseEndingFixtures"
local must=E.Must
local T={}
function T.Run()
    local check,done=R.Checks("ReleaseEndingSave")
    local base,token=E.WishSeed();local wish=E.Clone(base)
    must(wish.state.ConfirmEnding(E.Request(wish,{kind="wish"})))
    local opening=E.New();E.Day14(opening);assert(opening.state.Save("b5_flow"))
    local ticket=E.New(666);assert(ticket.state.Save("b5_flow"))
    local cases={
        {name="PurchaseTravelTicket",seed=ticket,call=function(x)return x.state.PurchaseTravelTicket(R.Quote(x,"travel_ticket",666))end,phase="ended"},
        {name="BeginClosing",seed=opening,call=function(x)return x.state.BeginClosing(E.Request(x))end,phase="closing_prepare"},
        {name="UpdateWishDraft",seed=base,call=function(x)return x.state.UpdateWishDraft(E.Request(x,{sourceTokenIds={}}))end,phase="wish"},
        {name="ConfirmEnding",seed=base,call=function(x)return x.state.ConfirmEnding(E.Request(x,{kind="wish"}))end,phase="ended"},
        {name="RestoreEndingCheckpoint",seed=wish,call=function(x)return x.state.RestoreEndingCheckpoint(E.Request(x))end,phase="operating"},
        {name="StartNewPlaythrough",seed=wish,call=function(x)return x.state.StartNewPlaythrough(E.Request(x))end,phase="operating"},
    }
    for _,case in ipairs(cases) do for _,fault in ipairs({"write","uncertain"}) do
        check(case.name.." "..fault,function()
            local x=E.Clone(case.seed);local before=x.state.GetSnapshot();x.fault=fault
            assert(not case.call(x).ok and U.Equal(before,x.state.GetSnapshot()))
            if fault=="uncertain" then assert(not x.state.CanMutate() and not x.state.Load("wrong_slot")) end
            x.fault=false;assert(x.state.ReloadCurrent())
            if fault=="write" then assert(U.Equal(before,x.state.GetSnapshot()))
            else assert(x.state.GetSnapshot().chapter.phase==case.phase)
                if case.name=="UpdateWishDraft" then assert(#x.state.GetSnapshot().chapter.wishDraftSourceIds==0) end
                if case.name=="PurchaseTravelTicket" then assert(x.state.GetSnapshot().live.economy.currency==0) end
            end
        end)
    end end
    for _,kind in ipairs({"checkpoint_cash","checkpoint_nested","checkpoint_version","current_cash","wish_source","duplicate_source","ending_id","fake_apprentice","ticket_without_departure"}) do
        check("reject bad saved ending "..kind,function()
            local x=E.Clone(wish);local d=x.state.GetSnapshot()
            if kind=="checkpoint_cash" then d.chapter.checkpoint.live.economy.currency=999
            elseif kind=="checkpoint_nested" then d.chapter.checkpoint.chapter.checkpoint=U.Copy(d.chapter.checkpoint)
            elseif kind=="checkpoint_version" then d.chapter.checkpoint.contentVersion="foreign-version"
            elseif kind=="current_cash" then d.live.economy.currency=d.live.economy.currency+1
            elseif kind=="wish_source" then d.chapter.wishDraftSourceIds={"not-obtained"}
            elseif kind=="duplicate_source" then d.chapter.wishDraftSourceIds={token,token}
            elseif kind=="ending_id" then d.chapter.endingTransactionId="forged-ending"
            elseif kind=="fake_apprentice" then d.chapter.ending.kind="apprentice"
            elseif kind=="ticket_without_departure" then d.live.economy.itemPurchases={{itemId="travel_ticket",unitPrice=666,day=1,afterDeliveredOrders=0,transactionId="purchase:travel_ticket"}} end
            assert(x.save.Save("b5_flow",d,4));assert(not x.Reload(),"bad ended state accepted")
        end)
    end
    check("committed ending with failed install locks and reloads frozen outcome",function()
        local x=E.Clone(base);local original=x.modules.economy.Restore;local calls=0
        x.modules.economy.Restore=function(value)
            local result=original(value);calls=calls+1;if calls==1 then error("install after mutation") end;return result
        end
        local request=E.Request(x,{kind="wish"});local r=x.state.ConfirmEnding(request)
        assert(not r.ok and r.error.code=="COMMIT_RECOVERY_REQUIRED" and not x.state.CanMutate())
        x.modules.economy.Restore=original;assert(x.state.ReloadCurrent() and x.state.GetSnapshot().chapter.phase=="ended")
        local writes=x.writes;assert(must(x.state.ConfirmEnding(request)).alreadyEnded and x.writes==writes)
    end)
    check("ending query and wishes are pure copies; notification failure is committed",function()
        local x=E.Clone(base);local before=x.state.GetSnapshot();local writes=x.writes
        local view=must(x.session.queries.GetWishView());view.draftSourceIds[1]="invalid"
        must(x.session.queries.GetEndingView());assert(U.Equal(before,x.state.GetSnapshot()) and x.writes==writes)
        x.onEvent=function(name)if name=="EndingConfirmed" then error("observer failure")end end
        local result=must(x.state.ConfirmEnding(E.Request(x,{kind="wish"})))
        assert(result.notificationErrors and x.Reload() and x.state.GetSnapshot().chapter.phase=="ended")
    end)
    check("pure ending retry cannot accept unknown or duplicate source selections",function()
        local x=E.Clone(wish);local api=require("systems.ReleaseEndings").New(x.content);local d=x.state.GetSnapshot()
        for _,ids in ipairs({{"not-obtained"},{token,token}}) do
            local r=api.PlanEnding(d,{kind="wish",expectedRevision=0,sourceTokenIds=ids})
            assert(not r.ok and r.error.code=="SOURCE_INVALID","invalid selection cannot be treated as an idempotent retry")
        end
        assert(must(api.PlanEnding(d,{kind="wish",expectedRevision=0,sourceTokenIds={token}})).alreadyEnded)
    end)
    return done()
end
return T
