-- schema 3 持久草稿与按次试做。旧计算器仅接收临时 schema 2 投影；正式提交由 GameState 完成。
local U=require "v035.core.StateUtil"
local G=require "v035.systems.CalculationGuard"
local D=require "v035.systems.RecipeDraft"
local J=require "v035.systems.BrewJournal"
local P=require "v035.core.SchemaProjection"
local T={}
function T.Wrap(legacy,content,limit)
    local api={}
    for key,value in pairs(legacy) do api[key]=value end
    local current=false
    ---@type table|nil
    local coordinator
    api.CurrentOrder={}
    function api.CurrentOrder.ValidateSnapshot(value)
        return G.Run(function()
            if value==false then return false end
            G.Keys(value,{orderId=true,letterInstanceId=true,phase=true,baseline=true,recipe=true,pending=true,nextAttemptSerial=true,lastResetTransactionId=true,draft=true},"currentOrder","STATE_INVALID")
            G.Need(value.phase=="accepted" or value.phase=="pending","STATE_INVALID","phase","不能持久化视觉熬制阶段")
            local old=U.Copy(value); old.draft=nil
            G.Value(legacy.CurrentOrder.ValidateSnapshot(old))
            G.Need(type(value.draft)=="table","STATE_INVALID","draft","缺少持久草稿")
            return U.Copy(value)
        end)
    end
    function api.CurrentOrder.Restore(value) local r=api.CurrentOrder.ValidateSnapshot(value); if r.ok then current=r.value end; return r end
    function api.CurrentOrder.GetSnapshot() return U.Copy(current) end
    function api.ValidateEnvelope(data)
        return G.Run(function()
            G.Value(require("v035.core.SaveSchema").ValidateV3(data,{contentVersion=content.contentVersion,synthesisVersion=content.synthesis.version,
                economy=require("v035.systems.Economy").New(content),letters=require("v035.systems.Letter").New(content),wordTokens=require("v035.systems.WordToken").New(content),salvageDailyLimit=limit}))
            G.Value(api.CurrentOrder.ValidateSnapshot(data.currentOrder))
            G.Value(J.Validate(data,content))
            if data.currentOrder then
                local order=data.currentOrder
                G.Value(D.Validate(order.draft,data.live,content))
                if order.pending then G.Need(U.Equal(order.draft,D.Project(order.recipe)),"STATE_INVALID","draft","待处理配方与草稿不一致") end
            end
            G.Value(legacy.ValidateEnvelope(P.V2(data)))
            return U.Copy(data)
        end)
    end
    local function plan(data,value,events,changed) return {data=data,value=value,events=events or {},changed=changed~=false} end
    function api.PlanCommand(kind,data,request)
        return G.Run(function()
            G.Pure(request,"request"); G.Value(api.ValidateEnvelope(data))
            local candidate=U.Copy(data)
            if kind=="Accept" then
                local old=G.Value(legacy.PlanCommand(kind,P.V2(data),request))
                if not old.changed then return plan(candidate,old.value,{},false) end
                candidate.live.orders.acceptedById=old.data.live.orders.acceptedById
                candidate.nextOrderSerial=old.data.nextOrderSerial
                candidate.currentOrder=old.data.currentOrder; candidate.currentOrder.draft=D.Empty(content.stage1.initialEquipmentId)
                candidate.revision=old.data.revision
                return plan(candidate,old.value,old.events)
            end
            if kind=="Confirm" then
                G.Keys(request,{orderId=true,transactionId=true},"request")
                local record=data.live.orders.confirmedById[request.orderId]
                if record then
                    G.Need(record.transactionId==request.transactionId,"STALE_TRANSACTION","transactionId","发货事务已过期")
                    return plan(candidate,{orderId=request.orderId,transactionId=record.transactionId,phase="confirmed",alreadyConfirmed=true,record=U.Copy(record)},{},false)
                end
            end
            local order=data.currentOrder; local nextOrder=candidate.currentOrder
            G.Need(order and order.orderId==request.orderId,"INVALID_ORDER_STATE","orderId","没有该活动订单")
            if kind=="UpdateDraft" then
                G.Keys(request,{orderId=true,draft=true},"request")
                G.Need(order.phase=="accepted","ORDER_LOCKED","phase","请先发货或重置")
                local draft=G.Value(D.Validate(request.draft,data.live,content))
                if U.Equal(draft,order.draft) then return plan(candidate,{orderId=order.orderId,draft=draft},{},false) end
                nextOrder.draft=draft; candidate.revision=data.revision+1
                return plan(candidate,{orderId=order.orderId,draft=draft},{"DraftChanged"})
            elseif kind=="BeginBrew" or kind=="CancelBrew" then
                return G.Value(U.Fail("DEPRECATED_COMMAND","command","选料请用 UpdateDraft；开始熬制请用 Preview；返回桌前仅导航"))
            elseif kind=="Preview" then
                G.Keys(request,{orderId=true,equipmentId=true,mainTokenId=true,auxTokenIds=true,ingredients=true,specialItemIds=true},"request")
                local selected=D.Project(request)
                G.Need(U.Equal(selected,order.draft),order.pending and "ORDER_LOCKED" or "STALE_DRAFT","draft","请使用已保存的当前草稿")
                if order.pending then return plan(candidate,{orderId=order.orderId,phase="pending",transactionId=order.pending.transactionId,potion=order.pending.potion},{},false) end
                G.Value(D.Validate(selected,data.live,content))
                G.Need(selected.mainTokenId~=false,"INVALID_REQUEST","mainTokenId","请先放入主词")
                local projected=P.V2(data)
                local begun=G.Value(legacy.PlanCommand("BeginBrew",projected,{orderId=order.orderId})).data
                local recipe=U.Copy(selected); recipe.orderId=order.orderId; recipe.baselineId=order.orderId..":baseline"
                local result=G.Value(legacy.PlanCommand("Preview",begun,recipe))
                if not result.changed then result.value.phase="accepted"; return plan(candidate,result.value,{},false) end
                local baselineId=order.orderId..":baseline:"..order.nextAttemptSerial
                nextOrder.phase="pending"; nextOrder.recipe=U.Copy(recipe); nextOrder.recipe.baselineId=baselineId
                nextOrder.baseline={id=baselineId,revision=data.revision,contentVersion=data.contentVersion,live=U.Copy(data.live)}
                nextOrder.pending=result.data.currentOrder.pending
                nextOrder.pending.candidateLive.gameFlow=U.Copy(data.live.gameFlow)
                nextOrder.pending.candidateLive.gameFlow.deliveredOrders=data.live.gameFlow.deliveredOrders+1
                -- 恢复之前已确认记录的真实基准；仅本次新记录使用新按次 ID。
                for oid,record in pairs(data.live.orders.confirmedById) do nextOrder.pending.candidateLive.orders.confirmedById[oid]=U.Copy(record) end
                nextOrder.pending.candidateLive.orders.confirmedById[order.orderId].recipe=U.Copy(nextOrder.recipe)
                nextOrder.nextAttemptSerial=order.nextAttemptSerial+1
                J.Insert(candidate.journal,J.Record(candidate,order.orderId,nextOrder.pending,nextOrder.recipe,"pending",3,content))
                return plan(candidate,result.value,{"DeliveryPreviewReady"})
            elseif kind=="Reset" then
                G.Keys(request,{orderId=true,baselineId=true,transactionId=true},"request")
                if order.phase=="accepted" and request.transactionId==order.lastResetTransactionId then
                    local record=data.journal.byAttemptId[request.transactionId]
                    G.Need(record and record.recipe.baselineId==request.baselineId,"STALE_BASELINE","baselineId","重置基准不匹配")
                    return plan(candidate,{orderId=order.orderId,phase="accepted",alreadyReset=true},{},false)
                end
                G.Need(order.pending and request.transactionId==order.pending.transactionId,"STALE_TRANSACTION","transactionId","重置事务已过期")
                G.Need(request.baselineId==order.baseline.id,"STALE_BASELINE","baselineId","重置基准已过期")
                candidate.journal.byAttemptId[request.transactionId].status="reset"
                nextOrder.phase="accepted"; nextOrder.baseline=false; nextOrder.recipe=false; nextOrder.pending=false
                nextOrder.draft=D.Empty(order.draft.equipmentId); nextOrder.lastResetTransactionId=request.transactionId
                candidate.revision=data.revision+1
                return plan(candidate,{orderId=order.orderId,phase="accepted",transactionId=request.transactionId},{"DeliveryReset"})
            elseif kind=="Confirm" then
                G.Need(order.pending and order.pending.transactionId==request.transactionId,"STALE_TRANSACTION","transactionId","发货事务已过期")
                candidate.live=U.Copy(order.pending.candidateLive); candidate.currentOrder=false; candidate.revision=data.revision+1
                candidate.journal.byAttemptId[request.transactionId].status="shipped"
                return plan(candidate,{orderId=order.orderId,transactionId=request.transactionId,phase="confirmed",alreadyConfirmed=false,record=U.Copy(candidate.live.orders.confirmedById[order.orderId])},
                    {"PotionDelivered","OrderRatingRecorded","MoneyChanged","ItemRemoved","NpcStateChanged","LetterArchived"})
            end
            return G.Value(U.Fail("INVALID_REQUEST","command","未知订单命令"))
        end)
    end
    function api.BindCoordinator(state) coordinator=state end
    for _,kind in ipairs({"Accept","UpdateDraft","BeginBrew","CancelBrew","Preview","Confirm","Reset"}) do
        api[kind]=function(request)
            if not coordinator then return U.Fail("STATE_NOT_READY","Order","尚未装配协调器") end
            return coordinator.OrderCommand(kind,request)
        end
    end
    function api.GetView(request)
        return G.Run(function()
            if not coordinator then return G.Value(U.Fail("STATE_NOT_READY","Order","尚未装配协调器")) end
            if request then G.Keys(request,{orderId=true},"view") end
            local data=coordinator.GetSnapshot()
            G.Need(data~=nil,"STATE_NOT_READY","Order","尚未载入存档")
            local order=data.currentOrder; local id=request and request.orderId or (order and order.orderId)
            if id and data.live.orders.confirmedById[id] then return {phase="confirmed",orderId=id,record=U.Copy(data.live.orders.confirmedById[id]),actions={}} end
            G.Need(not id or (order and order.orderId==id),"UNKNOWN_ID","orderId","未知订单")
            local view=order and U.Copy(order) or {phase="idle"}
            view.formalInventory=U.Copy(data.live.economy); view.actions={}
            if order and order.pending then view.trialInventory=U.Copy(order.pending.candidateLive.economy) end
            for _,name in ipairs({"Accept","UpdateDraft","BeginBrew","CancelBrew","Preview","Confirm","Reset","NextDay","ReceiveLetter","ReadLetter","CutWord","Shop","ClaimAttachment"}) do view.actions[name]=coordinator.CheckAction(name) end
            return view
        end)
    end
    return api
end
return T
