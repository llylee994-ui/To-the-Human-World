-- 明确技术副本；不修改 data、不向库存注入 token。不代表正式内容已经切换。
local U=require "core.StateUtil"
local C=require "debug.fixtures.B4Fixtures"
local F={Must=C.Must,ById=C.ById}
function F.Content()
    local content=C.Content()
    content.contentVersion=content.contentVersion .. "+technical-single-use"
    for _,word in ipairs(content.words) do word.reusable=false end
    return content
end
function F.TwoSources()
    local content=F.Content()
    local letter=U.Copy(C.ById(content.letters,"letter_pa_01"))
    letter.id="letter_technical_second"
    letter.title="【技术副本】第二个独立来源"
    content.letters[#content.letters+1]=letter
    return content
end
function F.Receive(x,id)
    local instance=F.Must(x.state.ReceiveLetter({letterId=id})).letterInstanceId
    F.Must(x.state.ReadLetter({letterInstanceId=instance}))
    x.tokensByWord=x.tokensByWord or {}; x.instances=x.instances or {}; x.instances[id]=instance
    for _,span in ipairs(F.Must(x.modules.letters.ParseDefinition(id)).spans) do
        local token=F.Must(x.state.CutWord({letterInstanceId=instance,spanId=span.spanId})).tokenId
        local list=x.tokensByWord[span.wordId] or {}; x.tokensByWord[span.wordId]=list
        local seen=false; for _,old in ipairs(list) do if old==token then seen=true end end
        if not seen then list[#list+1]=token end
    end
    return instance
end
-- 测试明确选择排序首张可用来源，或指定信件；不是生产自动消耗优先级。
function F.Select(x,wordId,source)
    local state=x.state.GetSnapshot().live.wordTokens.byId
    local ids=U.Copy((x.tokensByWord or {})[wordId] or {}); table.sort(ids)
    for _,id in ipairs(ids) do
        local card=state[id]
        if card.available and (not source or card.sourceLetterInstanceId==source) then return id end
    end
    error("测试配方缺少可用来源: " .. wordId .. (source and " @ " .. source or ""),0)
end
function F.Begin(x,letterId)
    x.orderId=F.Must(x.order.Accept({letterInstanceId=assert(x.instances[letterId])})).orderId
    x.baselineId=F.Must(x.order.BeginBrew({orderId=x.orderId})).baselineId
end
function F.Request(x,recipe,source)
    local aux={}
    for _,id in ipairs(recipe.auxWordIds) do aux[#aux+1]=F.Select(x,id,source) end
    return {orderId=x.orderId,baselineId=x.baselineId,equipmentId=recipe.equipmentId,
        mainTokenId=F.Select(x,recipe.mainWordId,source),auxTokenIds=aux,
        ingredients=U.Copy(recipe.ingredients),specialItemIds=U.Copy(recipe.specialItemIds)}
end
function F.ExpectedConsumption(content,request,words)
    local expected={}
    local ids={request.mainTokenId}
    for _,id in ipairs(request.auxTokenIds) do ids[#ids+1]=id end
    for _,id in ipairs(ids) do
        if not content.GetWord(words.byId[id].wordId).reusable then expected[#expected+1]=id end
    end
    table.sort(expected); return expected
end
function F.CheckConsumption(check,content,before,after,request,consumed)
    local expected=F.ExpectedConsumption(content,request,before)
    check("consumed ids exactly main+aux by policy",C.Sorted(consumed),expected)
    local used={}; for _,id in ipairs(expected) do used[id]=true end
    local candidate=U.Copy(before)
    for id in pairs(used) do candidate.byId[id].available=false; candidate.byId[id].consumedByOrderId=request.orderId end
    check("only used cards changed; all sources retained",after,candidate)
end
return F
