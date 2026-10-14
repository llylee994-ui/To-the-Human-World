-- 真实信源→剪词→合成→独立结果→重置/确认→存档重放。只替换文件介质。
local U=require "core.StateUtil"
local Data=require "data.content"
local F=require "debug.fixtures.B5Fixtures"
local cases=require "debug.fixtures.NumericV02Cases"
local T={}
local function must(r) assert(r.ok,cjson.encode(r.error));return r.value end
local function advance(x,day)
    while x.state.GetSnapshot().live.gameFlow.day<day do must(x.state.NextDay()) end
end
local function collect(x,id,only)
    advance(x,Data.GetLetter(id).appearCondition.dayMin)
    if x.state.GetSnapshot().journal and not x.state.GetSnapshot().live.gameFlow.canSalvage then must(x.state.NextDay()) end
    local instance=must(x.state.ReceiveLetter({letterId=id})).letterInstanceId
    must(x.state.ReadLetter({letterInstanceId=instance}))
    x.tokens=x.tokens or {}
    for _,span in ipairs(must(x.modules.letters.ParseDefinition(id)).spans) do
        if not only or only[span.wordId] then
            local token=must(x.state.CutWord({letterInstanceId=instance,spanId=span.spanId})).tokenId
            assert(not x.tokens[span.wordId],"登记词应有独立位置")
            x.tokens[span.wordId]=token
        end
    end
    return instance
end
local function buyMissing(x,recipe)
    for _,ingredient in ipairs(recipe.ingredients) do
        local count=x.state.GetSnapshot().live.economy.ingredients[ingredient.ingredientId] or 0
        if count<ingredient.quantity then must(x.state.Shop({ingredientId=ingredient.ingredientId,quantity=ingredient.quantity-count})) end
    end
end
local function attempt(x,case,instance,reset)
    buyMissing(x,case.recipe)
    local oid=must(x.order.Accept({letterInstanceId=instance})).orderId
    local v3=x.state.GetSnapshot().journal~=nil
    local baseline=false
    if not v3 then baseline=must(x.order.BeginBrew({orderId=oid})).baselineId end
    local recipe=case.recipe
    local aux={};for _,wid in ipairs(recipe.auxWordIds) do aux[#aux+1]=assert(x.tokens[wid],wid) end
    local req={orderId=oid,baselineId=baseline,equipmentId=recipe.equipmentId,mainTokenId=assert(x.tokens[recipe.mainWordId]),
        auxTokenIds=aux,ingredients=U.Copy(recipe.ingredients),specialItemIds={}}
    if v3 then
        req.baselineId=nil
        must(x.order.UpdateDraft({orderId=oid,draft=require("systems.RecipeDraft").Project(req)}))
    end
    local before=x.state.GetSnapshot()
    local function preview()
        local v=must(x.order.Preview(req));assert(v.phase=="pending")
        local pending=x.state.GetSnapshot().currentOrder.pending
        if v3 then baseline=x.state.GetSnapshot().currentOrder.baseline.id end
        assert(U.Equal(x.state.GetSnapshot().live,before.live),"试做不得消耗真实卡、金币和原料")
        assert(#pending.facts==1 and pending.facts[1].id==case.expect.facts[1],"只出现唯一正确结果事实")
        assert(#pending.followup.fragmentIds==1 and pending.followup.fragmentIds[1]=="frag_"..case.expect.facts[1])
        assert(pending.rating.stars==case.expect.stars)
        assert(pending.requirementResult.canShip)
        assert(pending.candidateLive.world.npcs[Data.GetLetter(case.letterId).senderId].lastResult==case.expect.facts[1])
        return v,pending
    end
    local value,pending=preview()
    local loaded,status=x.Reload();assert(loaded,cjson.encode(status))
    assert(U.Equal(x.state.GetSnapshot().currentOrder.pending,pending),"待确认重读保持相同结果")
    if reset then
        must(x.order.Reset({orderId=oid,baselineId=baseline,transactionId=value.transactionId}))
        assert(U.Equal(x.state.GetSnapshot().live,before.live),"重置完整回到原基准")
        local stale=value.transactionId
        if v3 then must(x.order.UpdateDraft({orderId=oid,draft=require("systems.RecipeDraft").Project(req)})) end
        value,pending=preview()
        assert(not x.order.Confirm({orderId=oid,transactionId=stale}).ok,"过期尝试不可确认")
    end
    local committed=must(x.order.Confirm({orderId=oid,transactionId=value.transactionId}))
    assert(U.Equal(x.state.GetSnapshot().live,pending.candidateLive),"确认安装完整候选")
    local after=x.state.GetSnapshot()
    local uses={req.mainTokenId};for _,id in ipairs(aux) do uses[#uses+1]=id end
    assert(#pending.consumption.consumedTokenIds==#uses)
    for _,id in ipairs(uses) do
        assert(before.live.wordTokens.byId[id].available)
        assert(after.live.wordTokens.byId[id].available==false and after.live.wordTokens.byId[id].consumedByOrderId==oid)
    end
    assert(after.live.economy.currency==before.live.economy.currency+pending.reward.currency)
    for _,i in ipairs(req.ingredients) do assert(after.live.economy.ingredients[i.ingredientId]==before.live.economy.ingredients[i.ingredientId]-i.quantity) end
    assert(committed.record.rating.stars==case.expect.stars)
    local writes=x.writes
    assert(must(x.order.Confirm({orderId=oid,transactionId=value.transactionId})).alreadyConfirmed)
    assert(x.writes==writes,"重复确认不再保存、消耗或发报酬")
    loaded,status=x.Reload();assert(loaded,cjson.encode(status))
    assert(U.Equal(x.state.GetSnapshot(),after),"确认后真实重放对账一致")
end
function T.RunSchema(schema)
    local count=0
    for _,case in ipairs(cases) do
        local x=F.New(Data,{targetSchema=schema})
        local letters,only={},{}
        for _,s in ipairs(case.sources) do letters[s.letterId]=true;only[s.wordId]=true end
        letters[case.letterId]=true
        local ids={};for id in pairs(letters) do ids[#ids+1]=id end
        table.sort(ids,function(a,b)return Data.GetLetter(a).appearCondition.dayMin<Data.GetLetter(b).appearCondition.dayMin end)
        local target
        for _,id in ipairs(ids) do local instance=collect(x,id,only);if id==case.letterId then target=instance end end
        attempt(x,case,assert(target),true)
        count=count+1
        print("[NumericV02Flow] PASS "..case.id.." → "..case.expect.facts[1])
    end
    -- 同一真实存档依次完成11单，58单见证各自独立，不能据此赠送副卡。
    local x=F.New(Data,{targetSchema=schema})
    local firstByLetter={}
    for _,case in ipairs(cases) do firstByLetter[case.letterId]=firstByLetter[case.letterId] or case end
    local ids={};for id in pairs(firstByLetter) do ids[#ids+1]=id end
    table.sort(ids,function(a,b)return Data.GetLetter(a).appearCondition.dayMin<Data.GetLetter(b).appearCondition.dayMin end)
    for _,id in ipairs(ids) do
        local instance=collect(x,id)
        attempt(x,firstByLetter[id],instance,false)
    end
    local final=x.state.GetSnapshot()
    assert(final.live.gameFlow.deliveredOrders==11)
    assert(final.live.economy.currency==1130,"首发无料基础路线30+1100=1130")
    local used,total=0,0
    for _,v in pairs(final.live.wordTokens.byId) do total=total+1;if not v.available then used=used+1 end end
    assert(total==61 and used==11)
    local cost=0;for _,p in ipairs(final.live.economy.shopPurchases) do cost=cost+p.unitPrice*p.quantity end
    assert(cost==0)
    -- 基础登记锅无料；单独真实采购再验证采购时间防伪，避免空循环失去覆盖。
    must(x.state.Shop({ingredientId="ing_sea_salt",quantity=1}))
    local forged=x.state.GetSnapshot()
    for _,p in ipairs(forged.live.economy.shopPurchases) do
        if p.afterDeliveredOrders>0 then p.day=1;break end
    end
    assert(not x.order.ValidateEnvelope(forged).ok,"已发货后的采购不能伪造为首日购买")
    print("[NumericV02Flow] schema="..schema.." PASS "..count.." registration flows; real 11-order chain, 61 cards, consumed11, purchases0, balance1130; separate purchase audit")
    return true
end
function T.Run() return T.RunSchema(2) end
return T
