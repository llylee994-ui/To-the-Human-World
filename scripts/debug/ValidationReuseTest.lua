local U=require "core.StateUtil"
local R=require "debug.fixtures.ReleaseFixtures"
local E=require "debug.fixtures.ReleaseEndingFixtures"
local T={}
function T.Run()
    local check,done=R.Checks("ValidationReuse")
    local x=E.SmallComplete();local valid=x.state.GetSnapshot()
    check("identical validated state avoids repeating potion/history replay",function()
        R.Must(x.order.ValidateEnvelope(valid))
        local potion=require "systems.Potion";local calculate=potion.Calculate;local calls=0
        potion.Calculate=function(...) calls=calls+1;return calculate(...) end
        local result=x.order.ValidateEnvelope(U.Copy(valid));potion.Calculate=calculate
        assert(result.ok and calls==0,"unchanged history replayed "..calls.." times")
        result.value.live.economy.currency=999999
        assert(R.Must(x.order.ValidateEnvelope(valid)).live.economy.currency==valid.live.economy.currency)
    end)
    check("changed values with the same revision still receive full audit",function()
        for _,part in ipairs({"cash","potion","letter","journal","extra","meta"}) do
            local bad=U.Copy(valid)
            if part=="cash" then bad.live.economy.currency=bad.live.economy.currency+1
            elseif part=="potion" then bad.live.orders.confirmedById["order:1"].reward.currency=999
            elseif part=="letter" then local _,l=next(bad.live.letters.byId);l.read=false
            elseif part=="journal" then bad.journal.byAttemptId[bad.journal.attemptIds[1]].followup.renderedText="forged"
            elseif part=="extra" then bad.extra=true
            else setmetatable(bad,{}) end
            assert(not x.order.ValidateEnvelope(bad).ok,part)
        end
    end)
    check("configuration edits invalidate previous validation",function()
        local old=x.content.stage1.initialEconomy.currency
        x.content.stage1.initialEconomy.currency=old+1
        local result=x.order.ValidateEnvelope(valid)
        x.content.stage1.initialEconomy.currency=old
        assert(not result.ok);R.Must(x.order.ValidateEnvelope(valid))
    end)
    check("checkpoint reuse rejects tampering even when its revision is unchanged",function()
        R.Must(x.state.NextDay());local closed=x.state.GetSnapshot()
        R.Must(x.order.ValidateEnvelope(closed))
        for _,part in ipairs({"cash","history","world","new-field"}) do
            local bad=U.Copy(closed);local cp=bad.chapter.checkpoint
            if part=="cash" then cp.live.economy.currency=cp.live.economy.currency+1
            elseif part=="history" then cp.live.orders.confirmedById["order:1"].reward.currency=999
            elseif part=="world" then cp.live.world.injected=true
            else cp.extra=true end
            assert(not x.order.ValidateEnvelope(bad).ok,part)
        end
    end)
    return done()
end
return T
