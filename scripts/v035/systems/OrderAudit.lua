-- B5 保存结果审计。只校验已存结果，不调用 Simulate / ResolveDirect / Rate 生成或替换回信。
local U=require "v035.core.StateUtil"
local G=require "v035.systems.CalculationGuard"
local R=require "v035.systems.StoryRules"
local Audit={}
local function same(a,b,path)
    G.Need(U.Equal(a,b),"STATE_INVALID",path,"保存结果与来源、结算或候选差异不一致")
end
local function serial(id)
    G.Need(U.String(id),"STATE_INVALID","orderId","非法订单 ID")
    local n=tonumber(id:match("^order:(%d+)$"))
    G.Need(U.Integer(n,1) and id=="order:" .. n,"STATE_INVALID","orderId","非法订单序号")
    return assert(n)
end
local function rank(a,b)
    if a.priority~=b.priority then return a.priority>b.priority end
    return a.id<b.id
end
function Audit.New(content,orderApi)
    local api={}
    local letters=require("v035.systems.Letter").New(content)
    local words=require("v035.systems.WordToken").New(content)
    local economy=require("v035.systems.Economy").New(content)
    local world=require("v035.systems.WorldState").New(content)
    local narrative=require("v035.systems.Narrative").New(content)
    -- 依据已冻结配置核对完整事实集合及所有写入来源，不产生新的可展示结果。
    local function factsAndChanges(record,definition,before,context)
        R.Facts(record.facts,content)
        local sources={world=before,potion=record.potion,context=context,facts={}}
        local expectedFacts,writes,rules={},{},{}
        for _,rule in ipairs(content.directRules) do if rule.ruleSetId==definition.directRuleSetId then rules[#rules+1]=rule end end
        table.sort(rules,rank)
        for _,rule in ipairs(rules) do
            local matched,_,whenEvidence=R.Conditions(rule.when,sources,content,"directRules.when")
            local _,excluded,unlessEvidence=R.Conditions(rule.unless,sources,content,"directRules.unless",true)
            if matched and not excluded then
                for _,fact in ipairs(rule.facts) do
                    local expected=U.Copy(fact); expected.sourceRuleId=rule.id
                    expected.inputs={potionEffects=U.Copy(record.potion.effects),subjectState=U.Copy(before.npcs[fact.subjectId]),context=U.Copy(context),when=whenEvidence,unless=unlessEvidence}
                    expectedFacts[#expectedFacts+1]=expected
                end
                for _,change in ipairs(rule.changes) do
                    G.Need(change.path:sub(1,11)=="world.npcs.","CONFIG_INVALID","changes","仅支持人物字段")
                    local old=R.Read({world=before},change.path,"STATE_INVALID")
                    local write=writes[change.path]
                    if write then
                        G.Need(write.op==change.op and (change.op=="add" or U.Equal(write.value,change.value)),"NARRATIVE_CONFLICT",change.path,"变化冲突")
                    else write={path=change.path,op=change.op,value=change.op=="add" and 0 or U.Copy(change.value),before=U.Copy(old),sourceRuleIds={}}; writes[change.path]=write end
                    if change.op=="add" then write.value=write.value+change.value
                    else G.Need(change.op=="set","CONFIG_INVALID",change.path,"未知变化操作") end
                    write.sourceRuleIds[#write.sourceRuleIds+1]=rule.id
                end
            end
        end
        table.sort(expectedFacts,function(a,b) return a.id<b.id end)
        same(record.facts,expectedFacts,"record.facts")
        local result,expectedChanges=U.Copy(before),{}
        for _,path in ipairs(G.Sorted(writes)) do
            local write=writes[path]
            local after
            if write.op=="add" then after=write.before+write.value else after=U.Copy(write.value) end
            write.after=after; expectedChanges[#expectedChanges+1]=write
            local parts=R.Path(path); local node={world=result}
            for i=1,#parts-1 do node=node[parts[i]] end
            node[parts[#parts]]=U.Copy(after)
        end
        same(record.worldChanges,expectedChanges,"record.worldChanges")
        G.Value(world.ValidateSnapshot(result))
        return result
    end
    local function followupAndRating(record,definition,after,context)
        local index,values,definitions=R.Facts(record.facts,content)
        local f=record.followup
        G.Keys(f,{letterId=true,fragmentIds=true,bindings=true,renderedText=true},"followup","STATE_INVALID")
        local template=G.Known(content,"followupTemplates",definition.followupTemplateId,"templateId")
        same(f.letterId,template.letterId,"followup.letterId")
        local selected=R.Ids(f.fragmentIds,"followup.fragmentIds")
        local allowed={}
        for _,list in ipairs({template.baseFragmentIds,template.fragmentIds,template.fallbackFragmentIds}) do for _,id in ipairs(list) do allowed[id]=true end end
        for i,id in ipairs(template.baseFragmentIds) do same(f.fragmentIds[i],id,"followup.baseFragments") end
        local rendered={}; local covered,groups,bindings={},{},{}
        if template.opening~="" then rendered[#rendered+1]=template.opening end
        -- 旧文案只作为严格比对来源；不重写存档，也不放过未知历史正文。
        ---@type {opening:string,closing:string,baseFragmentIds:string[],fragments:table<string,table?>}|nil
        local legacy=template.legacy
        local legacyValid=type(legacy)=="table"
        local legacyRendered,legacyBindings={},{}
        if legacy and legacyValid then
            legacyRendered[1]=legacy.opening
            for i,id in ipairs(legacy.baseFragmentIds) do
                if f.fragmentIds[i]~=id then legacyValid=false end
            end
        end
        local expanded=U.Copy(context); expanded.world=after; expanded.potion=record.potion
        local sources={world=after,potion=record.potion,context=expanded,facts=values}
        for _,id in ipairs(f.fragmentIds) do
            G.Need(allowed[id],"STATE_INVALID","followup.fragmentIds","片段不属于本单模板")
            local fragment=G.Known(content,"fragments",id,"followup.fragmentIds")
            G.Need(fragment.templateId==template.id and R.Matches(fragment,index,definitions,"fragments"),"NARRATIVE_CONFLICT","followup","保存的片段与事实不相容")
            if fragment.exclusiveGroup then
                G.Need(not groups[fragment.exclusiveGroup],"NARRATIVE_CONFLICT","followup","互斥片段同时保存")
                groups[fragment.exclusiveGroup]=true
            end
            for _,target in ipairs(fragment.overrides or {}) do G.Need(not selected[target],"NARRATIVE_CONFLICT","followup","覆盖与被覆盖片段同时保存") end
            for _,factId in ipairs(fragment.coversFacts) do G.Need(index[factId]~=nil,"NARRATIVE_CONFLICT","followup","文本声称未发生事实"); covered[factId]=true end
            local text,filled=R.Render(fragment.text,fragment.bindings,sources,content,"followup." .. id)
            rendered[#rendered+1]=text; bindings[id]=filled
            if legacy and legacyValid then
                local old=legacy.fragments[id]
                if old then
                    local oldText,oldBindings=R.Render(old.text,old.bindings,sources,content,"followup.legacy." .. id)
                    legacyRendered[#legacyRendered+1]=oldText; legacyBindings[id]=oldBindings
                else legacyValid=false end
            end
        end
        for id,fact in pairs(index) do G.Need(not fact.important or covered[id],"CONTENT_UNCOVERED","followup","重要事实未表达") end
        if template.closing~="" then rendered[#rendered+1]=template.closing end
        if legacy and legacyValid then legacyRendered[#legacyRendered+1]=legacy.closing end
        local matchesLegacy=legacyValid and U.Equal(f.bindings,legacyBindings)
            and f.renderedText==table.concat(legacyRendered,"\n\n")
        if not matchesLegacy then
            same(f.bindings,bindings,"followup.bindings")
            same(f.renderedText,table.concat(rendered,"\n\n"),"followup.renderedText")
        end
        local matches={}
        for _,rule in ipairs(content.orderRatings) do
            if rule.ratingSetId==definition.ratingSetId and R.Matches(rule,index,definitions,"rating") then matches[#matches+1]=rule end
        end
        table.sort(matches,function(a,b) if a.stars~=b.stars then return a.stars>b.stars end; return rank(a,b) end)
        local chosen=matches[1]
        G.Need(chosen~=nil,"RATING_UNCOVERED","rating","没有评分覆盖")
        if not chosen then error(U.Error("RATING_UNCOVERED","rating","没有评分覆盖"),0) end
        same(record.rating,{stars=chosen.stars,feedback=chosen.feedback,ruleId=chosen.id,factIds=U.Copy(chosen.requiresFacts)},"record.rating")
    end
    local function auditRecord(record,before,id,day)
        local accepted=before.orders.acceptedById[id]
        G.Need(accepted~=nil and record.letterInstanceId==accepted.letterInstanceId,"STATE_INVALID","record","确认来源不一致")
        same(record.contentVersion,content.contentVersion,"record.contentVersion")
        same(record.synthesisVersion,content.synthesis.version,"record.synthesisVersion")
        G.Need(U.Integer(day,accepted.acceptedDay),"STATE_INVALID","deliveryDay","发货天数不合法")
        local definition=G.Known(content,"letters",accepted.letterId,"letterId")
        G.Need(U.String(record.transactionId) and record.transactionId:match("^" .. id .. ":attempt:%d+$")~=nil,"STATE_INVALID","transactionId","事务不属于订单")
        same(record.recipe.orderId,id,"recipe.orderId"); same(record.recipe.baselineId,id .. ":baseline","recipe.baselineId")
        local baseline={id=record.recipe.baselineId,revision=0,contentVersion=content.contentVersion,live=before}
        local resolved=G.Value(orderApi.ResolveRecipe(record.recipe,baseline))
        local calculated=G.Value(require("v035.systems.Potion").Calculate(resolved,content))
        same(record.potion,calculated,"record.potion")
        local evaluation=G.Value(orderApi.Evaluate(definition.requirement,record.potion))
        G.Need(evaluation.canShip,"STATE_INVALID","requirementResult","失败药效不能有确认结果")
        same(record.requirementResult,evaluation,"record.requirementResult")
        local context={letterId=definition.id,orderId=id,day=day}
        local afterWorld=factsAndChanges(record,definition,before.world,context)
        followupAndRating(record,definition,afterWorld,context)
        same(record.reward,definition.reward,"record.reward")
        local consumed=G.Value(words.PlanConsumption(before.wordTokens,G.Value(words.ResolveRecipe(before.wordTokens,record.recipe))))
        same(record.consumption,{ingredients=U.Copy(record.recipe.ingredients),consumedTokenIds=consumed.consumedTokenIds,specialItemIds=U.Copy(record.recipe.specialItemIds)},"record.consumption")
        local after=U.Copy(before)
        after.world=afterWorld; after.wordTokens=consumed.state
        after.economy=G.Value(economy.PlanSettlement(before.economy,record.consumption.ingredients,record.consumption.specialItemIds,record.reward)).state
        after.gameFlow.deliveredOrders=before.gameFlow.deliveredOrders+1
        local archive=U.Copy(record.followup); archive.orderId=id; archive.transactionId=record.transactionId; archive.rating=record.rating
        after.letters=G.Value(letters.PlanArchive(before.letters,archive)).state
        after.orders.confirmedById[id]=U.Copy(record)
        for _,letterId in ipairs(G.Value(narrative.FindAvailable(after))) do after.narrative.unlockedLetterIds[letterId]=true end
        return after
    end
    function api.ValidateEnvelope(data)
        return G.Run(function()
            G.Pure(data,"data","STATE_INVALID")
            G.Value(require("v035.core.SaveSchema").ValidateV2(data,{contentVersion=content.contentVersion,synthesisVersion=content.synthesis.version,economy=economy,letters=letters,wordTokens=words}))
            G.Value(orderApi.ValidateSnapshot(data.live.orders)); G.Value(orderApi.CurrentOrder.ValidateSnapshot(data.currentOrder))
            G.Value(world.ValidateSnapshot(data.live.world)); G.Value(narrative.ValidateSnapshot(data.live.narrative))
            local accepted,confirmed=data.live.orders.acceptedById,data.live.orders.confirmedById
            local history,open,acceptedCount={},0,0
            ---@type number
            local maxSerial=0
            for id,entry in pairs(accepted) do
                acceptedCount=acceptedCount+1
                local n=serial(id); maxSerial=math.max(maxSerial,n)
                local item=data.live.letters.byId[entry.letterInstanceId]
                G.Need(item and item.read and item.received and item.letterId==entry.letterId and entry.acceptedDay<=data.live.gameFlow.day,"STATE_INVALID","orders.accepted","接单来源未阅读或天数错误")
                if confirmed[id] then history[#history+1]=id else
                    open=open+1
                    G.Need(data.currentOrder and data.currentOrder.orderId==id,"STATE_INVALID","currentOrder","未确认订单不能失去当前状态")
                end
            end
            G.Need(open<=1 and (open==1)==(data.currentOrder~=false),"STATE_INVALID","currentOrder","当前订单与未确认记录不一致")
            same(data.nextOrderSerial,maxSerial+1,"nextOrderSerial")
            same(acceptedCount,maxSerial,"orders.serials") -- 不按坏档中的巨大序号循环。
            table.sort(history,function(a,b) return serial(a)<serial(b) end)
            -- 账本重放包含购买与已确认订单；购买不能借用之后的订单报酬。
            local replay=U.Copy(data.live)
            replay.world=G.Value(world.InitialSnapshot()); replay.economy=G.Value(economy.InitialSnapshot())
            replay.orders.confirmedById={}; replay.letters.directArchive={}; replay.gameFlow.deliveredOrders=0
            replay.narrative=G.Value(narrative.InitialSnapshot())
            for _,token in pairs(replay.wordTokens.byId) do token.available=true; token.consumedByOrderId=false end
            local purchases=data.live.economy.shopPurchases or {}
            local purchaseIndex=1
            local lastDay=1
            local function replayPurchases(delivered,untilDay)
                while purchaseIndex<=#purchases and purchases[purchaseIndex].afterDeliveredOrders==delivered do
                    local p=purchases[purchaseIndex]
                    G.Need(p.day>=lastDay and p.day<=untilDay,"STATE_INVALID","shopPurchases.day","购买时间不属于对应发货进度")
                    local planned=G.Value(economy.PlanPurchase(replay.economy,{ingredientId=p.ingredientId,quantity=p.quantity},{day=p.day,deliveredOrders=delivered}))
                    same(planned.state.shopPurchases[#planned.state.shopPurchases],p,"shopPurchases")
                    replay.economy=planned.state; purchaseIndex=purchaseIndex+1
                end
            end
            for _,id in ipairs(history) do
                local record=confirmed[id]
                G.Need(U.Integer(record.deliveryDay,lastDay) and record.deliveryDay<=data.live.gameFlow.day,"STATE_INVALID","record.deliveryDay","历史确认天数错误")
                replayPurchases(replay.gameFlow.deliveredOrders,record.deliveryDay)
                lastDay=record.deliveryDay; replay.gameFlow.day=record.deliveryDay
                replay=auditRecord(record,replay,id,record.deliveryDay)
            end
            replayPurchases(replay.gameFlow.deliveredOrders,data.live.gameFlow.day)
            G.Need(purchaseIndex==#purchases+1,"STATE_INVALID","shopPurchases","购买记录借用了未来发货数")
            for _,key in ipairs({"world","economy","wordTokens"}) do same(data.live[key],replay[key],"live." .. key) end
            -- 解锁是已声明订单集合；其保存可包含已领取项。阶段条件由实际查询复核。
            if data.currentOrder then
                local order=data.currentOrder
                same(serial(order.orderId),maxSerial,"currentOrder.orderId")
                if order.baseline then
                    G.Need(order.baseline.id==order.orderId .. ":baseline" and order.baseline.revision==data.revision,"STALE_BASELINE","baseline","基准标识或版本错误")
                    same(order.baseline.live,data.live,"baseline.live")
                end
                if order.pending then
                    local p=order.pending
                    same(p.transactionId,order.orderId .. ":attempt:" .. (order.nextAttemptSerial-1),"pending.transactionId")
                    local record=U.Copy(p); record.status=nil; record.candidateLive=nil
                    record.recipe=U.Copy(order.recipe); record.letterInstanceId=order.letterInstanceId; record.deliveryDay=data.live.gameFlow.day
                    local expected=auditRecord(record,data.live,order.orderId,data.live.gameFlow.day)
                    same(p.candidateLive,expected,"pending.candidateLive")
                end
            end
            return U.Copy(data)
        end)
    end
    return api
end
return Audit
