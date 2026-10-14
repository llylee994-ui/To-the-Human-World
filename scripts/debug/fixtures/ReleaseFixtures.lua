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
    local aux={};for _,wid in ipairs(recipe.auxWordIds) do aux[#aux+1]=assert(x.tokens[wid]) end
    return {orderId=oid,equipmentId=recipe.equipmentId,mainTokenId=assert(x.tokens[recipe.mainWordId]),auxTokenIds=aux,ingredients={},specialItemIds={}}
end
function R.Preview(x,request)
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
