-- 仅用于复用 schema 2 审计/计算的临时副本。原档先经 schema 3 严格关联验证。
-- 从不持久化此投影，也不把新事务 ID 的合法性委托给旧版审计。
local U=require "core.StateUtil"
local P={}
function P.Live(live)
    local out=U.Copy(live)
    out.gameFlow.salvageUsedToday=nil
    for id,record in pairs(out.orders.confirmedById) do record.recipe.baselineId=id..":baseline" end
    return out
end
function P.V2(data)
    local out=U.Copy(data); out.journal=nil; out.live=P.Live(data.live)
    local order=out.currentOrder
    if order then
        order.draft=nil
        if order.baseline then order.baseline.id=order.orderId..":baseline"; order.baseline.live=P.Live(order.baseline.live) end
        if order.recipe then order.recipe.baselineId=order.orderId..":baseline" end
        if order.pending then order.pending.candidateLive=P.Live(order.pending.candidateLive) end
    end
    return out
end
return P
