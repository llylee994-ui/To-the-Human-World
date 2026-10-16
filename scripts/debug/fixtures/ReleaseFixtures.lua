-- 真实生产模块与隔离文件介质；不向存档注入卡片或采购结果。
local U=require "core.StateUtil"
local F=require "debug.fixtures.B5Fixtures"
local R={Must=F.Must}
function R.New(cash,schema)
    local content=U.Copy(require "data.content")
    if cash then content.stage1.initialEconomy.currency=cash end
    return F.New(content,{targetSchema=schema or 4})
end
function R.Quote(x,id,price)
    local d=x.state.GetSnapshot()
    return {itemId=id,expectedPrice=price,expectedDay=d.live.gameFlow.day,expectedRevision=d.revision}
end
-- 旧版允许未发货直接跨天；只构造这种历史经营快照，并走真实保存/完整审计。
-- 日期边界测试使用此入口，正常新周目必须调用 NextDay，不能绕过新门禁。
function R.LegacyDay(x,day)
    local data=x.state.GetSnapshot()
    assert(data.chapter.phase=="operating" and (not data.currentOrder or not data.currentOrder.pending))
    assert(day>data.live.gameFlow.day and day<=x.content.release.finalDay)
    data.live.gameFlow.day=day;data.live.gameFlow.salvageUsedToday=0;data.live.gameFlow.canSalvage=true
    data.revision=data.revision+1
    assert(x.save.Save("b5_flow",data,4));assert(x.state.ReloadCurrent())
end
function R.Accept(x,index)
    local id=x.content.release.requiredOrderIds[index]
    while x.state.GetSnapshot().live.gameFlow.day<index do R.Must(x.state.NextDay()) end
    local instance=R.Must(x.state.ReceiveLetter({letterId=id})).letterInstanceId
    R.Must(x.state.ReadLetter({letterInstanceId=instance}))
    x.tokens=x.tokens or {}
    for _,span in ipairs(R.Must(x.modules.letters.ParseDefinition(id)).spans) do
        x.tokens[span.wordId]=R.Must(x.state.CutWord({letterInstanceId=instance,spanId=span.spanId})).tokenId
    end
    local oid=R.Must(x.order.Accept({letterInstanceId=instance})).orderId
    ---@type table|nil
    local recipe
    for _,case in ipairs(x.content.recipes) do if case.letterId==id then recipe=case.recipe;break end end
    assert(recipe)
    recipe=require("core.StateUtil").Copy(recipe)
    local function available(wid)
        local token=x.tokens[wid]
        return token and x.state.GetSnapshot().live.wordTokens.byId[token].available
    end
    -- 低星经营也消耗词卡；后面的成功见证不能重复使用已发货的来源。
    if index==6 and not available(recipe.auxWordIds[1]) then recipe.auxWordIds={"word_candidate_elias_happy"} end
    if index==9 and not available(recipe.auxWordIds[1]) then recipe.auxWordIds={"word_candidate_elias_trust"} end
    if index==11 and not available(recipe.auxWordIds[1]) then
        recipe.mainWordId="word_candidate_n01_curiosity"
        recipe.auxWordIds={"word_candidate_n10_recall"}
        recipe.ingredients={{ingredientId="ing_night_dew",quantity=1}}
    end
    local aux={};for _,wid in ipairs(recipe.auxWordIds) do aux[#aux+1]=assert(x.tokens[wid]) end
    return {orderId=oid,equipmentId=recipe.equipmentId,mainTokenId=assert(x.tokens[recipe.mainWordId]),auxTokenIds=aux,ingredients=recipe.ingredients,specialItemIds={}}
end
function R.Preview(x,request)
    for _,i in ipairs(request.ingredients) do
        local shortage=i.quantity-(x.state.GetSnapshot().live.economy.ingredients[i.ingredientId] or 0)
        if shortage>0 then R.Must(x.state.Shop({ingredientId=i.ingredientId,quantity=shortage})) end
    end
    R.Must(x.order.UpdateDraft({orderId=request.orderId,draft=require("systems.RecipeDraft").Project(request)}))
    return R.Must(x.order.Preview(request))
end
function R.Ship(x,index)
    local request=R.Accept(x,index);local pending=R.Preview(x,request)
    R.Must(x.order.Confirm({orderId=request.orderId,transactionId=pending.transactionId}))
end
function R.Checks(label)
    local passed,failed=0,0
    return function(name,fn)
        local ok,err=pcall(fn)
        if ok then passed=passed+1 else failed=failed+1 end
        print("["..label.."] "..(ok and "PASS " or "FAIL ")..name..(ok and "" or " "..tostring(err)))
    end,function()
        print("["..label.."] "..passed.." passed; "..failed.." failed")
        return failed==0
    end
end
return R
