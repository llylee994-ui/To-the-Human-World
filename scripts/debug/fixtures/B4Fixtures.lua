-- C3 真实内容副本；不从 sampleCases.expect 构造事实或评分。
local U=require "core.StateUtil"
local F={}
local B3=require "debug.fixtures.B3Fixtures"
F.Must=B3.Must
F.ById=B3.ById
function F.Content()
    local content=B3.Content()
    local data=require "data.content"
    for _,key in ipairs({"directRules","factExclusionGroups","followupTemplates","orderRatings"}) do content[key]=U.Copy(data[key]) end
    return content
end
function F.Setup(content)
    local x=B3.Setup(content or F.Content())
    x.world=require("systems.WorldState").New(x.content)
    x.narrative=require("systems.Narrative").New(x.content)
    x.initialWorld=F.Must(x.world.InitialSnapshot())
    F.Must(x.world.Restore(x.initialWorld)); F.Must(x.narrative.Restore(F.Must(x.narrative.InitialSnapshot())))
    x.definition=F.ById(x.content.letters,"letter_pa_01")
    x.context={letterId=x.definition.id,orderId="b3_order",day=1}
    function x.Simulate(id)
        local potion=x.Calculate(id)
        return x.world.Simulate(x.initialWorld,potion,x.context),potion
    end
    function x.Resolve(simulation,potion)
        local context=U.Copy(x.context); context.world=simulation.world; context.potion=potion
        return x.narrative.ResolveDirect(simulation.facts,context)
    end
    function x.Joint(id)
        local simulated,potion=x.Simulate(id)
        local result=F.Must(simulated)
        result.followup=F.Must(x.Resolve(result,potion))
        result.rating=F.Must(x.order.Rate(result.facts,x.definition.ratingSetId))
        return result,potion
    end
    return x
end
function F.Ids(facts)
    local ids={}
    for _,fact in ipairs(facts) do ids[#ids+1]=fact.id end
    table.sort(ids); return ids
end
function F.Sorted(ids) local copy=U.Copy(ids); table.sort(copy); return copy end
-- 只构造结构检查夹具，不调用/冒充尚未实现的 B5 Preview 或 Confirm。
function F.Envelope(x,id)
    local live=U.Copy(x.baseline.live)
    live.gameFlow={day=1,phase="day",canSalvage=true,mainStoryStage="intro",deliveredOrders=0}
    live.world=U.Copy(x.initialWorld); live.narrative=F.Must(x.narrative.InitialSnapshot())
    local base={contentVersion=x.content.contentVersion,revision=0,nextOrderSerial=2,live=live,currentOrder=false}
    local data=require("debug.fixtures.B2Fixtures").Pending(base,"letter:" .. x.context.letterId,x.byWord.word_sleep[1])
    local order=data.currentOrder
    local request=x.Request(x.Sample(id).recipe)
    request.orderId,request.baselineId=order.orderId,order.baseline.id
    order.recipe=U.Copy(request)
    local resolved=F.Must(x.order.ResolveRecipe(request,order.baseline))
    local potion=F.Must(require("systems.Potion").Calculate(resolved,x.content))
    local context=U.Copy(x.context); context.orderId=order.orderId
    local result=F.Must(x.world.Simulate(order.baseline.live.world,potion,context))
    context.world=result.world; context.potion=potion
    local p=order.pending
    p.potion=potion; p.requirementResult=F.Must(x.order.Evaluate(x.definition.requirement,potion))
    p.facts=result.facts; p.worldChanges=result.worldChanges
    p.followup=F.Must(x.narrative.ResolveDirect(result.facts,context))
    p.rating=F.Must(x.order.Rate(result.facts,x.definition.ratingSetId))
    p.reward=U.Copy(x.definition.reward); p.consumption.ingredients=U.Copy(request.ingredients)
    p.candidateLive.world=U.Copy(result.world)
    p.candidateLive.economy=F.Must(x.economy.PlanSettlement(base.live.economy,request.ingredients,{},p.reward)).state
    local record=U.Copy(p); record.candidateLive=nil; record.status=nil
    record.recipe=U.Copy(request); record.letterInstanceId=order.letterInstanceId
    p.candidateLive.orders.confirmedById[order.orderId]=record
    p.candidateLive.letters.directArchive[order.orderId]={transactionId=p.transactionId,letterId=p.followup.letterId,
        renderedText=p.followup.renderedText,fragmentIds=U.Copy(p.followup.fragmentIds),rating=U.Copy(p.rating)}
    return data
end
function F.Checks()
    local total,failed=0,0
    local function check(name,actual,expected)
        total=total+1
        local ok=U.Equal(actual,expected)
        if not ok then failed=failed+1 end
        print("[B4] " .. (ok and "PASS " or "FAIL ") .. name .. (ok and "" or " actual=" .. tostring(actual) .. " expected=" .. tostring(expected)))
    end
    return check,function() print("[B4] checks=" .. total .. " failed=" .. failed); return failed==0 end
end
return F
