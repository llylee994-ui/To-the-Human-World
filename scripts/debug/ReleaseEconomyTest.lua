-- 新辅料的联合经营路线与有限采购账。整单使用真实 schema3，枚举预算使用真实 Economy 纯计划。
local U=require "core.StateUtil"
local Data=require "data.content"
local F=require "debug.fixtures.B5Fixtures"
local T={}
local function must(r) assert(r.ok,cjson.encode(r.error));return r.value end
local function ingredients(ids)
    local counts,rows={},{}
    for _,id in ipairs(ids) do counts[id]=(counts[id] or 0)+1 end
    for id,n in pairs(counts) do rows[#rows+1]={ingredientId=id,quantity=n} end
    table.sort(rows,function(a,b)return a.ingredientId<b.ingredientId end)
    return rows
end
local function materialUses(kind,day)
    if kind=="normal" then return ingredients(day==1 and {"ing_sea_salt"} or {"ing_sea_salt","ing_night_dew"}) end
    if kind=="expensive" then return ingredients({"ing_ashen_herb","ing_ashen_herb"}) end
    return {}
end
local function missing(economy,uses,shop)
    for _,row in ipairs(uses) do
        local n=row.quantity-(economy.ingredients[row.ingredientId] or 0)
        if n>0 then economy=shop(economy,row.ingredientId,n) end
    end
    return economy
end
local function recipeFor(id,kind)
    local mixed={letter_pa_01="e01_result_song_faded",letter_n01="n01_result_stayed_for_promise",letter_n02="n02_candidate_care"}
    for _,r in ipairs(Data.recipes) do
        if r.letterId==id and (kind~="mixed" or not mixed[id] or r.expect.facts[1]==mixed[id]) then return r.recipe end
    end
    error("missing source recipe "..id)
end
local function play(kind)
    local x=F.New(Data,{targetSchema=3});local tokens,rows,threeStars={}, {},0
    for day,id in ipairs(Data.release.requiredOrderIds) do
        while x.state.GetSnapshot().live.gameFlow.day<day do must(x.state.NextDay()) end
        local instance=must(x.state.ReceiveLetter({letterId=id})).letterInstanceId
        must(x.state.ReadLetter({letterInstanceId=instance}))
        for _,span in ipairs(must(x.modules.letters.ParseDefinition(id)).spans) do
            tokens[span.wordId]=must(x.state.CutWord({letterInstanceId=instance,spanId=span.spanId})).tokenId
        end
        local recipe=recipeFor(id,kind);local uses=materialUses(kind,day)
        local cash=x.state.GetSnapshot().live.economy.currency
        missing(x.state.GetSnapshot().live.economy,uses,function(_,ingredientId,n)
            must(x.state.Shop({ingredientId=ingredientId,quantity=n}))
            return x.state.GetSnapshot().live.economy
        end)
        local oid=must(x.order.Accept({letterInstanceId=instance})).orderId
        local aux={};for _,wid in ipairs(recipe.auxWordIds) do aux[#aux+1]=assert(tokens[wid]) end
        local request={orderId=oid,equipmentId=recipe.equipmentId,mainTokenId=assert(tokens[recipe.mainWordId]),
            auxTokenIds=aux,ingredients=uses,specialItemIds={}}
        must(x.order.UpdateDraft({orderId=oid,draft=require("systems.RecipeDraft").Project(request)}))
        local before=x.state.GetSnapshot()
        local pending=must(x.order.Preview(request))
        assert(U.Equal(before.live,x.state.GetSnapshot().live),"preview cannot consume")
        local record=must(x.order.Confirm({orderId=oid,transactionId=pending.transactionId})).record
        local stars=record.rating.stars
        if stars==3 then threeStars=threeStars+1 end
        if kind=="mixed" and day<=3 then assert(stars==({2,1,2})[day],"literal mixed-route stars")
        elseif kind=="expensive" then
            -- 独立源条件：N02/N04 happy2.0跨1.8，N07 anger2.0跨1.8；其余维持三星。
            assert(stars==({3,3,2,3,2,3,3,1,3,3,3})[day],"literal expensive-route stars "..id)
        else assert(stars==3,"route must remain three star "..kind.." "..id) end
        local after=x.state.GetSnapshot()
        assert(after.live.economy.currency==before.live.economy.currency+100)
        assert(must(x.order.Confirm({orderId=oid,transactionId=pending.transactionId})).alreadyConfirmed)
        assert(x.Reload())
        assert(U.Equal(after,x.state.GetSnapshot()))
        rows[#rows+1]={day=day,sourceLetterId=id,beforeShopping=cash,beforeReward=before.live.economy.currency,
            afterReward=after.live.economy.currency,stars=stars,recipe=record.recipe,consumedTokenIds=record.consumption.consumedTokenIds}
    end
    local final=x.state.GetSnapshot();local cost=0
    for _,p in ipairs(final.live.economy.shopPurchases) do cost=cost+p.unitPrice*p.quantity end
    local expected={free={cash=1130,cost=0,three=11},normal={cash=1006,cost=124,three=11},
        expensive={cash=750,cost=380,three=8},mixed={cash=1130,cost=0,three=8}}
    local want=assert(expected[kind])
    assert(final.live.economy.currency==want.cash and cost==want.cost and threeStars==want.three)
    assert(final.live.gameFlow.deliveredOrders==11)
    for _,item in ipairs(Data.furniture) do must(x.state.PurchaseFurniture({furnitureId=item.id})) end
    assert(x.state.GetSnapshot().live.economy.currency==want.cash-480)
    assert(x.Reload())
    assert(x.state.GetSnapshot().live.economy.currency==want.cash-480,"home purchases must replay with orders")
    return {kind=kind,balance=want.cash,materialCost=cost,threeStarCount=threeStars,
        afterHome=want.cash-480,days=rows,shopPurchases=final.live.economy.shopPurchases}
end
local function budget(kind,miss1,miss2,homes)
    local api=require("systems.Economy").New(Data)
    local ledger=must(api.InitialSnapshot());local count,rows=0,{}
    for day=1,10 do
        if day~=miss1 and day~=miss2 then
            local before=ledger.currency
            local uses=materialUses(kind,day)
            ledger=missing(ledger,uses,function(e,id,n)
                return must(api.PlanPurchase(e,{ingredientId=id,quantity=n},{day=day,deliveredOrders=count})).state
            end)
            ledger=must(api.PlanSettlement(ledger,uses,{},{currency=100})).state;count=count+1
            rows[#rows+1]={day=day,beforeShopping=before,afterReward=ledger.currency}
        end
    end
    if homes then for _,item in ipairs(Data.furniture) do
        ledger=must(api.PlanFurniturePurchase(ledger,{furnitureId=item.id},{day=10,deliveredOrders=count})).state
    end end
    return {kind=kind,missedDays={miss1,miss2},completed=count,balance=ledger.currency,
        canAffordTicket=ledger.currency>=666,days=rows,purchases=ledger.shopPurchases}
end
function T.Run()
    local report={status="passed",routes={},missedPairs={},scope="real schema3 route transactions; pure Economy cash enumeration"}
    for _,kind in ipairs({"expensive","mixed","free","normal"}) do
        report.routes[#report.routes+1]=play(kind)
        print("[ReleaseEconomy] PASS real 11-order "..kind.." route, homes and reload")
    end
    local minimum=math.huge
    for a=1,9 do for b=a+1,10 do
        local result=budget("normal",a,b,false)
        assert(result.completed==8 and result.canAffordTicket,"normal route misses two orders but must afford ticket")
        minimum=math.min(minimum,result.balance);report.missedPairs[#report.missedPairs+1]=result
    end end
    assert(#report.missedPairs==45 and minimum==745)
    report.minimumNormalMissTwoBalance=minimum
    report.expensiveMissTwo=budget("expensive",1,2,false)
    assert(report.expensiveMissTwo.balance==570 and not report.expensiveMissTwo.canAffordTicket)
    report.homesBeforeTicket=budget("normal",0,0,true)
    assert(report.homesBeforeTicket.balance==443 and not report.homesBeforeTicket.canAffordTicket)
    -- 单日最多两份同料的经营已通过；六份上限、未来收入与资金不足另作公共边界。
    local api=require("systems.Economy").New(Data);local initial=must(api.InitialSnapshot())
    assert(not api.PlanPurchase(initial,{ingredientId="ing_sea_salt",quantity=7},{day=1,deliveredOrders=0}).ok)
    assert(not api.PlanPurchase(initial,{ingredientId="ing_ashen_herb",quantity=2},{day=1,deliveredOrders=0}).ok)
    local publish=rawget(_G,"RELEASE_ECONOMY_REPORT");if publish then publish(cjson.encode(report)) end
    print("[ReleaseEconomy] PASS 4 joint routes, 45 miss-two budgets; minimum745; costly570; homes-first443")
    return true
end
return T
