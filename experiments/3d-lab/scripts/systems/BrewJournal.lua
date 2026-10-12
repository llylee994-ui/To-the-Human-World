-- 永久记录位于 live 外；只复制已算出的结果，不重演历史、不解锁案件。
local U=require "core.StateUtil"
local G=require "systems.CalculationGuard"
local J={}
function J.Empty() return {byAttemptId={},attemptIds={}} end
function J.OutcomeKey(followup)
    local pieces={followup.letterId}
    for _,id in ipairs(followup.fragmentIds) do pieces[#pieces+1]=id end
    for i,s in ipairs(pieces) do pieces[i]=#s..":"..s end
    return table.concat(pieces)
end
function J.Display(recipe,live,content)
    local function card(id)
        if not id then return false end
        local t=live.wordTokens.byId[id]
        G.Need(t~=nil,"STATE_INVALID","journal.tokenId","历史卡片来源不存在")
        return {tokenId=id,wordId=t.wordId,text=content.GetWord(t.wordId).displayText,sourceLetterInstanceId=t.sourceLetterInstanceId}
    end
    local aux,ingredients={},{}
    for _,id in ipairs(recipe.auxTokenIds) do aux[#aux+1]=card(id) end
    for _,row in ipairs(recipe.ingredients) do ingredients[#ingredients+1]={ingredientId=row.ingredientId,name=G.Known(content,"ingredients",row.ingredientId,"ingredientId").name,quantity=row.quantity} end
    return {main=card(recipe.mainTokenId),aux=aux,ingredients=ingredients}
end
function J.Record(data,orderId,result,recipe,status,origin,content)
    local accepted=data.live.orders.acceptedById[orderId]
    return {transactionId=result.transactionId,orderId=orderId,sourceLetterId=accepted.letterId,letterInstanceId=accepted.letterInstanceId,
        attemptDay=result.deliveryDay or data.live.gameFlow.day,status=status,originSchema=origin,contentVersion=result.contentVersion,
        synthesisVersion=result.synthesisVersion,recipe=U.Copy(recipe),recipeDisplay=J.Display(recipe,data.live,content),
        followup=U.Copy(result.followup),rating=U.Copy(result.rating),outcomeKey=J.OutcomeKey(result.followup)}
end
function J.Insert(journal,record)
    G.Need(journal.byAttemptId[record.transactionId]==nil,"STATE_INVALID","journal","试做 ID 重复")
    journal.byAttemptId[record.transactionId]=U.Copy(record)
    journal.attemptIds[#journal.attemptIds+1]=record.transactionId
end
function J.Validate(data,content)
    return G.Run(function()
        local j=data.journal
        G.Keys(j,{byAttemptId=true,attemptIds=true},"journal","STATE_INVALID")
        G.Need(type(j.byAttemptId)=="table","STATE_INVALID","journal.byAttemptId","缺少历史集合")
        G.Array(j.attemptIds,"journal.attemptIds","STATE_INVALID")
        local seen,pending,max={},0,{}
        for _,id in ipairs(j.attemptIds) do
            G.Need(U.String(id) and not seen[id],"STATE_INVALID","journal.attemptIds","重复或非法记录 ID")
            seen[id]=true
            local a=j.byAttemptId[id]
            G.Keys(a,{transactionId=true,orderId=true,sourceLetterId=true,letterInstanceId=true,attemptDay=true,status=true,originSchema=true,contentVersion=true,synthesisVersion=true,recipe=true,recipeDisplay=true,followup=true,rating=true,outcomeKey=true},"journal.record","STATE_INVALID")
            local accepted=data.live.orders.acceptedById[a.orderId]
            G.Need(accepted and a.transactionId==id and a.letterInstanceId==accepted.letterInstanceId and a.sourceLetterId==accepted.letterId,"STATE_INVALID","journal.source","记录来源不匹配")
            local n=tonumber(id:match("^"..a.orderId..":attempt:(%d+)$"))
            G.Need(U.Integer(n,1) and id==a.orderId..":attempt:"..n,"STATE_INVALID","journal.transactionId","试做序号非法")
            G.Need(n>(max[a.orderId] or 0),"STATE_INVALID","journal.attemptIds","同单试做顺序错误")
            max[a.orderId]=n
            G.Need(U.Integer(a.attemptDay,accepted.acceptedDay) and a.attemptDay<=data.live.gameFlow.day,"STATE_INVALID","journal.attemptDay","试做日期错误")
            G.Need(a.originSchema==2 or a.originSchema==3,"STATE_INVALID","journal.originSchema","来源版本错误")
            G.Need(a.contentVersion==data.contentVersion and a.synthesisVersion==content.synthesis.version,"STATE_INVALID","journal.version","记录配置版本错误")
            local definition=G.Known(content,"letters",a.sourceLetterId,"journal.sourceLetterId")
            local template=G.Known(content,"followupTemplates",definition.followupTemplateId,"journal.templateId")
            G.Keys(a.recipe,{orderId=true,baselineId=true,equipmentId=true,mainTokenId=true,auxTokenIds=true,ingredients=true,specialItemIds=true},"journal.recipe","STATE_INVALID")
            G.Need(a.recipe.orderId==a.orderId and a.recipe.baselineId==(a.originSchema==2 and a.orderId..":baseline" or a.orderId..":baseline:"..n),"STALE_BASELINE","journal.baselineId","记录基准与本次事务不对应")
            local available=U.Copy(data.live)
            for _,token in pairs(available.wordTokens.byId) do token.available=true end
            -- 历史卡可以已消耗；校验来源、槽位和数量，不要求今天仍有当时原料。
            for _,row in ipairs(a.recipe.ingredients) do available.economy.ingredients[row.ingredientId]=row.quantity end
            G.Value(require("systems.RecipeDraft").Validate(require("systems.RecipeDraft").Project(a.recipe),available,content))
            G.Need(a.recipe.mainTokenId~=false and U.Equal(a.recipeDisplay,J.Display(a.recipe,data.live,content)),"STATE_INVALID","journal.recipeDisplay","历史配方显示与来源不一致")
            G.Keys(a.followup,{letterId=true,fragmentIds=true,bindings=true,renderedText=true},"journal.followup","STATE_INVALID")
            G.Need(a.followup.letterId==template.letterId and content.GetLetter(a.followup.letterId) and U.String(a.followup.renderedText) and utf8.len(a.followup.renderedText) and type(a.followup.bindings)=="table","STATE_INVALID","journal.followup","缺少本单已保存回信")
            G.Array(a.followup.fragmentIds,"journal.fragmentIds","STATE_INVALID")
            local fragments={}
            for _,fid in ipairs(a.followup.fragmentIds) do
                local fragment=content.GetFragment(fid)
                G.Need(fragment and fragment.templateId==template.id and not fragments[fid],"STATE_INVALID","journal.fragmentIds","未知、跨单或重复片段"); fragments[fid]=true
            end
            G.Need(a.outcomeKey==J.OutcomeKey(a.followup),"STATE_INVALID","journal.outcomeKey","结局键不一致")
            G.Keys(a.rating,{stars=true,feedback=true,ruleId=true,factIds=true},"journal.rating","STATE_INVALID")
            local rule=G.Known(content,"orderRatings",a.rating.ruleId,"journal.rating.ruleId")
            G.Need(rule.ratingSetId==definition.ratingSetId and U.Equal(a.rating,{stars=rule.stars,feedback=rule.feedback,ruleId=rule.id,factIds=rule.requiresFacts}),"STATE_INVALID","journal.rating","历史评分快照错误")
            if a.status=="pending" then
                pending=pending+1
                local order=data.currentOrder
                G.Need(order and order.pending and order.pending.transactionId==id,"STATE_INVALID","journal.pending","待处理记录失去当前事务")
                G.Need(U.Equal(a,J.Record(data,a.orderId,order.pending,order.recipe,"pending",a.originSchema,content)),"STATE_INVALID","journal.pending","待处理快照不匹配")
            elseif a.status=="shipped" then
                local record=data.live.orders.confirmedById[a.orderId]
                G.Need(record and record.transactionId==id and U.Equal(a,J.Record(data,a.orderId,record,record.recipe,"shipped",a.originSchema,content)),"STATE_INVALID","journal.shipped","发货记录不匹配")
            else G.Need(a.status=="reset" and not (data.live.orders.confirmedById[a.orderId] and data.live.orders.confirmedById[a.orderId].transactionId==id),"STATE_INVALID","journal.status","记录状态错误") end
        end
        for id in pairs(j.byAttemptId) do G.Need(seen[id],"STATE_INVALID","journal.byAttemptId","未索引记录") end
        for _,record in pairs(data.live.orders.confirmedById) do G.Need(j.byAttemptId[record.transactionId] and j.byAttemptId[record.transactionId].status=="shipped","STATE_INVALID","journal.shipped","缺少发货历史") end
        local order=data.currentOrder
        G.Need(pending==((order and order.pending) and 1 or 0),"STATE_INVALID","journal.pending","待处理历史数量错误")
        if order then
            G.Need(order.nextAttemptSerial>(max[order.orderId] or 0),"STATE_INVALID","nextAttemptSerial","试做序号回退")
            if order.lastResetTransactionId then local a=j.byAttemptId[order.lastResetTransactionId]
                local n=tonumber(order.lastResetTransactionId:match("^"..order.orderId..":attempt:(%d+)$"))
                G.Need(U.Integer(n,1) and n<order.nextAttemptSerial,"STATE_INVALID","lastResetTransactionId","重置序号不可超出当前历史")
                -- schema2 未保存历史正文，迁移可保留旧重置 ID，但不得伪造该记录。
                G.Need((a and a.status=="reset" and a.orderId==order.orderId) or (not a and order.lastResetTransactionId:match("^"..order.orderId..":attempt:%d+$")),"STATE_INVALID","lastResetTransactionId","重置来源非法")
            end
        end
        return U.Copy(j)
    end)
end
return J
