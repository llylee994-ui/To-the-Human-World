-- v3真实schema4连续经营；预算枚举仅调用公开Economy纯计划。
local U=require "core.StateUtil"
local Data=require "data.content"
local R=require "debug.fixtures.ReleaseFixtures"
local E=require "debug.fixtures.ReleaseEndingFixtures"
local T={}
local must=R.Must
local function change(x,q,main,aux,uses)
    q.mainTokenId=assert(x.tokens[main]);q.auxTokenIds={}
    for _,id in ipairs(aux) do q.auxTokenIds[#q.auxTokenIds+1]=assert(x.tokens[id]) end
    q.ingredients=uses or {}
end
local function play(kind)
    local x=R.New();local rows,three={},0
    local low={[1]="e01_result_song_faded",[2]="n01_result_stayed_for_promise",[3]="n02_candidate_care"}
    for day,id in ipairs(Data.release.requiredOrderIds) do
        local request=R.Accept(x,day)
        if kind=="mixed" and low[day] then
            for _,r in ipairs(Data.recipes) do if r.letterId==id and r.expect.facts[1]==low[day] then
                change(x,request,r.recipe.mainWordId,r.recipe.auxWordIds,U.Copy(r.recipe.ingredients));break
            end end
        elseif kind=="craft" then
            if day==1 then change(x,request,"word_candidate_elias_sleep",{"word_candidate_elias_dream"}) end
            if day==2 then change(x,request,"word_candidate_n01_brave",{"word_candidate_n01_curiosity"},{{ingredientId="ing_night_dew",quantity=1}}) end
            if day==3 then change(x,request,"word_candidate_n02_happy",{"word_candidate_n02_h2"},{{ingredientId="ing_sea_salt",quantity=2}}) end
            if day==5 then change(x,request,"word_candidate_n04_h1",{"word_candidate_n04_h2"},{{ingredientId="ing_sea_salt",quantity=2}}) end
            if day==9 then change(x,request,"word_candidate_n08_r1",{"word_candidate_elias_trust"},{{ingredientId="ing_night_dew",quantity=1}}) end
        elseif kind=="expensive" then request.ingredients={{ingredientId="ing_ashen_herb",quantity=2}} end
        local cash=x.state.GetSnapshot().live.economy.currency
        local pending=R.Preview(x,request)
        local before=x.state.GetSnapshot()
        local record=must(x.order.Confirm({orderId=request.orderId,transactionId=pending.transactionId})).record
        local stars=record.rating.stars;if stars==3 then three=three+1 end
        local wanted=kind=="expensive" and ({3,3,2,3,2,3,3,1,3,3,3})[day] or kind=="mixed" and day<=3 and ({2,1,2})[day] or 3
        assert(stars==wanted,kind.." actual stars "..id)
        local after=x.state.GetSnapshot()
        assert(after.live.economy.currency==before.live.economy.currency+100)
        assert(must(x.order.Confirm({orderId=request.orderId,transactionId=pending.transactionId})).alreadyConfirmed)
        assert(x.Reload() and U.Equal(after,x.state.GetSnapshot()))
        local words={}
        for _,token in ipairs(record.consumption.consumedTokenIds) do
            assert(not after.live.wordTokens.byId[token].available)
            words[#words+1]=Data.GetWord(after.live.wordTokens.byId[token].wordId).displayText
        end
        rows[#rows+1]={day=day,sourceLetterId=id,beforeShopping=cash,afterReward=after.live.economy.currency,
            stars=stars,fact=record.facts[1].id,recipe=record.recipe,usedWords=words,consumedTokenIds=record.consumption.consumedTokenIds}
        if day==(kind=="expensive" and 10 or 7) then
            local fork=E.Clone(x)
            must(fork.state.PurchaseTravelTicket(R.Quote(fork,"travel_ticket",666)))
            assert(fork.Reload() and fork.state.GetSnapshot().chapter.ending.kind=="departure")
            rows[#rows].departureVerified=true
        end
    end
    local final=x.state.GetSnapshot();local cost,used=0,0
    for _,p in ipairs(final.live.economy.shopPurchases) do cost=cost+p.unitPrice*p.quantity end
    for _,token in pairs(final.live.wordTokens.byId) do if not token.available then used=used+1 end end
    local expected={standard={cash=1106,cost=24,three=11},craft={cash=1113,cost=17,three=11},
        mixed={cash=1106,cost=24,three=8},expensive={cash=750,cost=380,three=8}}
    local want=assert(expected[kind])
    assert(final.live.economy.currency==want.cash and cost==want.cost and three==want.three,kind.." balance/stars")
    assert(final.live.gameFlow.deliveredOrders==11 and used>11)
    for _,item in ipairs(Data.furniture) do must(x.state.PurchaseHomeItem(R.Quote(x,item.id,item.price))) end
    assert(x.Reload() and x.state.GetSnapshot().live.economy.currency==want.cash-480)
    assert(must(x.session.queries.GetReleaseProgress()).canApprentice,"actual purchase route must unlock apprentice")
    return {kind=kind,balance=want.cash,materialCost=cost,threeStarCount=three,usedWordCards=used,
        afterHome=want.cash-480,days=rows,shopPurchases=final.live.economy.shopPurchases}
end
local function budget(expensive,miss1,miss2,homes)
    local api=require("systems.Economy").New(Data)
    local ledger=must(api.InitialSnapshot());local count=0
    for day=1,10 do if day~=miss1 and day~=miss2 then
        count=count+1
        local uses={}
        if expensive then uses={{ingredientId="ing_ashen_herb",quantity=2}}
        else
            for _,r in ipairs(Data.recipes) do if r.letterId==Data.release.requiredOrderIds[count] then uses=r.recipe.ingredients;break end end
        end
        for _,i in ipairs(uses) do
            local shortage=i.quantity-(ledger.ingredients[i.ingredientId] or 0)
            if shortage>0 then ledger=must(api.PlanPurchase(ledger,{ingredientId=i.ingredientId,quantity=shortage},{day=day,deliveredOrders=count-1})).state end
        end
        ledger=must(api.PlanSettlement(ledger,uses,{},{currency=100})).state
    end end
    if homes then for _,item in ipairs(Data.furniture) do ledger=must(api.PlanFurniturePurchase(ledger,{furnitureId=item.id},{day=10,deliveredOrders=count})).state end end
    return {balance=ledger.currency,completed=count,canAffordTicket=ledger.currency>=666,missedDays={miss1,miss2}}
end
function T.Run()
    local report={status="running",routes={},missedPairs={},scope="real schema4 transactions and reload; miss-two enumeration is pure Economy only"}
    local publish=rawget(_G,"RELEASE_ECONOMY_REPORT")
    for _,kind in ipairs({"standard","craft","mixed","expensive"}) do
        report.routes[#report.routes+1]=play(kind)
        if publish then publish(cjson.encode(report)) end
        print("[ReleaseEconomy] PASS real 11-order "..kind.." + departure fork + homes + apprentice eligibility")
    end
    local minimum=math.huge
    for a=1,9 do for b=a+1,10 do
        local result=budget(false,a,b,false);assert(result.completed==8 and result.canAffordTicket)
        minimum=math.min(minimum,result.balance);report.missedPairs[#report.missedPairs+1]=result
    end end
    assert(#report.missedPairs==45 and minimum==818)
    report.minimumMissTwoBalance=minimum;report.expensiveMissTwo=budget(true,1,2,false)
    report.homesBeforeTicket=budget(false,0,0,true)
    assert(report.expensiveMissTwo.balance==570 and not report.expensiveMissTwo.canAffordTicket)
    assert(report.homesBeforeTicket.balance==526 and not report.homesBeforeTicket.canAffordTicket)
    report.status="passed"
    if publish then publish(cjson.encode(report)) end
    print("[ReleaseEconomy] PASS 4 joint routes, 45 budget checks; standard1106/craft1113/mixed1106/expensive750")
    return true
end
return T
