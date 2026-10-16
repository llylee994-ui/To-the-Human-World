-- 前端只读契约：每次读取协调器当前快照，绝不缓存、保存或发送业务事件。
local U=require "core.StateUtil"
local G=require "systems.CalculationGuard"
local D=require "systems.RecipeDraft"
local Q={}
function Q.New(session,content)
    local api={}
    local function snapshot()
        local data=session.state.GetSnapshot()
        G.Need(data and data.live,"STATE_LOCKED","snapshot","请先完成读取存档")
        return data
    end
    local function query(callback)
        return function(...) local args=table.pack(...); return G.Run(function() return U.Copy(callback(snapshot(),table.unpack(args,1,args.n))) end) end
    end
    local function definition(id) return G.Known(content,"letters",id,"sourceLetterId") end
    local function title(d) return d.title or content.GetNpc(d.senderId).name end
    local function journal(data)
        G.Need(data.journal~=nil,"NOT_IMPLEMENTED","journal","此存档版本尚未接入永久试做记录")
        return data.journal
    end
    api.GetLetters=query(function(data)
        local rows={}
        for _,id in ipairs(G.Sorted(data.live.letters.byId)) do
            local item=data.live.letters.byId[id]; local d=definition(item.letterId)
            local count=0
            for _,span in ipairs(G.Value(session.modules.letters.ParseDefinition(d.id)).spans) do if not item.cutSpans[span.spanId] then count=count+1 end end
            local status="unaccepted"
            for oid,accepted in pairs(data.live.orders.acceptedById) do if accepted.letterInstanceId==id then
                status=data.live.orders.confirmedById[oid] and "confirmed" or data.currentOrder.phase
                if status=="brewing" then status="accepted" end
            end end
            rows[#rows+1]={letterInstanceId=id,sourceLetterId=d.id,title=title(d),senderName=content.GetNpc(d.senderId).name,
                read=item.read,remainingCutCount=count,orderStatus=status}
        end
        return rows
    end)
    api.GetWordTray=query(function(data)
        local cards,categories,groups={},{},{}
        local current=data.currentOrder
        local draft=current and (current.draft or current.recipe)
        for _,id in ipairs(G.Sorted(data.live.wordTokens.byId)) do
            local token=data.live.wordTokens.byId[id]; local word=content.GetWord(token.wordId)
            local category=word.category; local role=false --[[@as string|false]]
            if draft then
                if draft.mainTokenId==id then role="main" else for _,aux in ipairs(draft.auxTokenIds) do if aux==id then role="aux" end end end
            end
            if not groups[category] then groups[category]={id=category,title=category,availableCount=0} end
            if token.available then groups[category].availableCount=groups[category].availableCount+1 end
            local source=data.live.letters.byId[token.sourceLetterInstanceId]
            cards[#cards+1]={tokenId=id,wordId=token.wordId,text=word.displayText,categoryId=category,
                sourceLetterInstanceId=token.sourceLetterInstanceId,sourceTitle=title(definition(source.letterId)),available=token.available,selectedRole=role}
        end
        for _,id in ipairs(G.Sorted(groups)) do categories[#categories+1]=groups[id] end
        return {cards=cards,categories=categories}
    end)
    api.GetJournalStories=query(function(data)
        local j=journal(data); local rows={}
        local function row(d)
            local count,seen=0,{}
            for _,tid in ipairs(j.attemptIds) do local a=j.byAttemptId[tid]; if a.sourceLetterId==d.id then count=count+1; seen[a.outcomeKey]=true end end
            local template=content.GetFollowupTemplate(d.followupTemplateId)
            return {sourceLetterId=d.id,title=title(d),received=data.live.letters.byId["letter:"..d.id]~=nil,
                attemptCount=count,discoveredOutcomeCount=#G.Sorted(seen),totalBranchCount=template and #template.fragmentIds or 0}
        end
        -- 记录书标签：首发故事按订单顺序在前（未收到的也列出，供灰置标签），其余已收故事接在后面。
        local listed={}
        for _,sourceId in ipairs(content.release and content.release.requiredOrderIds or {}) do
            local d=definition(sourceId); rows[#rows+1]=row(d); listed[d.id]=true
        end
        for _,id in ipairs(G.Sorted(data.live.letters.byId)) do
            local d=definition(data.live.letters.byId[id].letterId)
            if not listed[d.id] then rows[#rows+1]=row(d); listed[d.id]=true end
        end
        return rows
    end)
    api.GetJournalPage=query(function(data,id)
        local d=definition(id)
        G.Need(data.live.letters.byId["letter:"..id]~=nil,"UNKNOWN_ID","sourceLetterId","尚未收到该信件")
        local template=content.GetFollowupTemplate(d.followupTemplateId)
        local candidates=template and template.fragmentIds or {}
        -- 一条记录属于哪一支：取模板候选里实际用到的那个片段；兜底用记录的第一个片段。
        local function branchOf(record)
            for _,fid in ipairs(candidates) do
                for _,used in ipairs(record.followup.fragmentIds) do if used==fid then return fid end end
            end
            return record.followup.fragmentIds[1]
        end
        local j=journal(data); local outcomes,index={},{}
        for _,tid in ipairs(j.attemptIds) do
            local a=j.byAttemptId[tid]
            if a.sourceLetterId==id then
                local group=index[a.outcomeKey]
                if not group then
                    local branchId=branchOf(a); local frag=content.GetFragment(branchId)
                    group={outcomeKey=a.outcomeKey,branchFragmentId=branchId,shortName=frag and frag.shortName or false,
                        displayTitle=title(content.GetLetter(a.followup.letterId)),attempts={}}
                    index[a.outcomeKey]=group; outcomes[#outcomes+1]=group
                end
                group.attempts[#group.attempts+1]={transactionId=tid,status=a.status,stars=a.rating.stars,
                    day=a.attemptDay,text=a.followup.renderedText,recipeSummary=U.Copy(a.recipeDisplay)}
            end
        end
        -- 分支目录：模板全部候选（含未收集空位），短名取自内容配置。
        local branches={}
        for _,fid in ipairs(candidates) do
            local frag=content.GetFragment(fid)
            branches[#branches+1]={fragmentId=fid,shortName=frag and frag.shortName or false}
        end
        return {sourceLetterId=id,title=title(d),branches=branches,outcomes=outcomes}
    end)
    api.GetAttempt=query(function(data,id)
        G.Need(U.String(id),"INVALID_REQUEST","transactionId","缺少事务 ID")
        local record=journal(data).byAttemptId[id]
        G.Need(record~=nil,"UNKNOWN_ID","transactionId","未知试做记录")
        return record
    end)
    api.GetSalvageView=query(function(data)
        local limit=(content.gameplay or require("data.gameplay")).salvageDailyLimit
        local used=data.live.gameFlow.salvageUsedToday or (data.live.gameFlow.canSalvage and 0 or limit)
        local available=G.Value(session.modules.narrative.FindAvailable(data.live)); local ids={}
        for _,id in ipairs(available) do if not data.live.letters.byId["letter:"..id] then ids[#ids+1]=id end end
        local action=session.state.CheckAction("ReceiveLetter")
        if action.enabled and (used>=limit or data.live.gameFlow.phase~="day") then action={enabled=false,reasonCode="SALVAGE_DISABLED",message="今日捕捞次数已用完"}
        elseif action.enabled and #ids==0 then action={enabled=false,reasonCode="LETTER_NOT_AVAILABLE",message="目前没有可打捞的新信"} end
        return {dailyLimit=limit,usedToday=used,remaining=math.max(0,limit-used),availableLetterIds=ids,enabled=action.enabled,reasonCode=action.reasonCode,message=action.message}
    end)
    api.GetShopView=query(function(data)
        local rows={}; local action=session.state.CheckAction("Shop")
        if content.shop then for _,item in ipairs(content.ingredients) do
            local used=0
            for _,p in ipairs(data.live.economy.shopPurchases) do if p.day==data.live.gameFlow.day and p.ingredientId==item.id then used=used+p.quantity end end
            rows[#rows+1]={ingredientId=item.id,name=item.name,price=item.price,ownedQuantity=data.live.economy.ingredients[item.id] or 0,remainingToday=math.max(0,content.shop.dailyStockPerIngredient-used)}
        end end
        return {currency=data.live.economy.currency,items=rows,enabled=action.enabled,reasonCode=action.reasonCode,message=action.message}
    end)
    api.GetFurnitureShopView=query(function(data)
        local rows={}; local action=session.state.CheckAction("PurchaseFurniture")
        local owned=data.live.economy.ownedFurnitureIds or {}
        if data.live.economy.itemPurchases then owned=G.Value(require("systems.ReleaseLedger").New(content).Validate(data.live.economy.itemPurchases)) end
        for _,item in ipairs(content.furniture or {}) do
            rows[#rows+1]={furnitureId=item.id,name=item.name,price=item.price,owned=owned[item.id]==true,
                quote={itemId=item.id,expectedPrice=item.price,expectedDay=data.live.gameFlow.day,expectedRevision=data.revision}}
        end
        return {currency=data.live.economy.currency,items=rows,enabled=action.enabled,reasonCode=action.reasonCode,message=action.message}
    end)
    api.GetOrderSummary=query(function(data)
        local order=data.currentOrder; local actions={}
        for _,name in ipairs({"Accept","UpdateDraft","Preview","Confirm","Reset","Shop","NextDay"}) do actions[name]=session.state.CheckAction(name) end
        local result={orderId=false --[[@as string|false]],phase="idle" --[[@as string]],sourceLetterId=false --[[@as string|false]],
            title="",requirementDesc="",draft=false --[[@as table|false]],pending=false --[[@as table|false]],
            potionPreview=false --[[@as table|false]],actions=actions,requirementHint={evaluated=false}}
        if not order then return result end
        local accepted=data.live.orders.acceptedById[order.orderId]; local d=definition(accepted.letterId)
        result.orderId=order.orderId; result.phase=order.phase=="brewing" and "accepted" or order.phase
        result.sourceLetterId=d.id; result.title=title(d); result.requirementDesc=d.requirement.desc or d.requirementDesc or ""
        result.requirement=U.Copy(d.requirement)
        result.draft=order.draft or (order.recipe and D.Project(order.recipe)) or D.Empty(content.stage1.initialEquipmentId)
        if order.pending then result.pending={transactionId=order.pending.transactionId,followup=order.pending.followup,rating=order.pending.rating} end
        if result.draft.mainTokenId and not order.pending then
            local recipe=U.Copy(result.draft); recipe.orderId=order.orderId; recipe.baselineId=order.orderId..":query"
            local base={id=recipe.baselineId,revision=data.revision,contentVersion=data.contentVersion,live=data.live}
            local resolved=G.Value(session.order.ResolveRecipe(recipe,base))
            local potion=G.Value(require("systems.Potion").Calculate(resolved,content))
            local evaluated=G.Value(session.order.Evaluate(d.requirement,potion))
            result.requirementHint={evaluated=true,canShip=evaluated.canShip,failures=evaluated.failures}
            result.potionPreview={effects=U.Copy(potion.effects),intensityByEffect=U.Copy(potion.intensityByEffect)}
        end
        return result
    end)
    api.GetCaseBoard=query(function(data) return G.Value(require("systems.CaseBoardProjection").Get(data,content)) end)
    if session.initial and session.initial.chapter then
    api.GetReleaseProgress=query(function(data)
        G.Need(data.chapter~=nil,"NOT_IMPLEMENTED","release","此存档尚未接入首发终局")
        local progress=G.Value(require("systems.ReleaseEndings").New(content).GetProgress(data))
        progress.phase=data.chapter.phase
        progress.endingsReady={departure=require("systems.ReleaseEndings").New(content).TextReady("departure"),
            apprentice=require("systems.ReleaseEndings").New(content).TextReady("apprentice"),wish=require("systems.ReleaseEndings").New(content).TextReady("wish")}
        return progress
    end)
    api.GetTravelTicketView=query(function(data)
        G.Need(data.chapter~=nil,"NOT_IMPLEMENTED","release","此存档尚未接入首发终局")
        return G.Value(require("systems.ReleaseCoordinator").New(content).GetTravelTicketView(data))
    end)
    api.GetWishView=query(function(data)
        G.Need(data.chapter~=nil,"NOT_IMPLEMENTED","release","此存档尚未接入首发终局")
        return G.Value(require("systems.ReleaseCoordinator").New(content).GetWishView(data))
    end)
    api.GetEndingView=query(function(data)
        G.Need(data.chapter~=nil,"NOT_IMPLEMENTED","release","此存档尚未接入首发终局")
        return G.Value(require("systems.ReleaseCoordinator").New(content).GetEndingView(data))
    end)
    end
    return api
end
return Q
