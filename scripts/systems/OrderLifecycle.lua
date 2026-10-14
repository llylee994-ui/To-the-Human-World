-- Order 的私有职责拆分：只计划整份候选；磁盘提交/安装由 GameState 统一执行。
local U=require "core.StateUtil"
local G=require "systems.CalculationGuard"
local Lifecycle={}
function Lifecycle.Attach(api,content)
    local letter=require("systems.Letter").New(content)
    local words=require("systems.WordToken").New(content)
    local economy=require("systems.Economy").New(content)
    local world=require("systems.WorldState").New(content)
    local narrative=require("systems.Narrative").New(content)
    local orders={acceptedById={},confirmedById={}}
    ---@type false|table
    local current=false
    ---@type table|nil
    local coordinator
    function api.InitialSnapshot() return U.Ok({acceptedById={},confirmedById={}}) end
    function api.ValidateSnapshot(snapshot)
        return G.Run(function()
            G.Pure(snapshot,"orders","STATE_INVALID")
            G.Keys(snapshot,{acceptedById=true,confirmedById=true},"orders","STATE_INVALID")
            G.Need(type(snapshot.acceptedById)=="table" and type(snapshot.confirmedById)=="table","STATE_INVALID","orders","订单集合缺失")
            local used={}
            for id,record in pairs(snapshot.acceptedById) do
                G.Need(U.String(id) and id:match("^order:%d+$")~=nil,"STATE_INVALID","orders.id","订单实例 ID 无效")
                G.Keys(record,{letterId=true,letterInstanceId=true,acceptedDay=true},"orders.accepted","STATE_INVALID")
                local definition=G.Known(content,"letters",record.letterId,"orders.letterId")
                G.Need(definition.kind=="order" and U.Integer(record.acceptedDay,1) and U.String(record.letterInstanceId) and not used[record.letterInstanceId],"STATE_INVALID","orders.accepted","重复或非法来源订单")
                used[record.letterInstanceId]=true
            end
            for id,record in pairs(snapshot.confirmedById) do
                G.Need(snapshot.acceptedById[id]~=nil and type(record)=="table" and U.String(record.transactionId),"STATE_INVALID","orders.confirmed","确认明细缺少已接订单")
            end
            return U.Copy(snapshot)
        end)
    end
    function api.Restore(snapshot)
        local result=api.ValidateSnapshot(snapshot)
        if result.ok then orders=U.Copy(result.value) end
        return result
    end
    function api.GetSnapshot() return U.Copy(orders) end
    api.CurrentOrder={}
    function api.CurrentOrder.ValidateSnapshot(snapshot)
        return G.Run(function()
            if snapshot==false then return false end
            G.Pure(snapshot,"currentOrder","STATE_INVALID")
            G.Keys(snapshot,{orderId=true,letterInstanceId=true,phase=true,baseline=true,recipe=true,pending=true,nextAttemptSerial=true,lastResetTransactionId=true},"currentOrder","STATE_INVALID")
            G.Need(U.String(snapshot.orderId) and U.String(snapshot.letterInstanceId) and U.Integer(snapshot.nextAttemptSerial,1),"STATE_INVALID","currentOrder","订单 ID 或试做序号缺失")
            G.Need(snapshot.lastResetTransactionId==false or U.String(snapshot.lastResetTransactionId),"STATE_INVALID","currentOrder.lastResetTransactionId","重置记录须显式保存")
            G.Need(snapshot.phase=="accepted" or snapshot.phase=="brewing" or snapshot.phase=="pending","STATE_INVALID","currentOrder.phase","非法阶段")
            if snapshot.phase=="accepted" then
                G.Need(snapshot.baseline==false and snapshot.recipe==false and snapshot.pending==false,"STATE_INVALID","currentOrder","接单阶段不能带基准")
            else
                G.Need(type(snapshot.baseline)=="table","STATE_INVALID","currentOrder.baseline","缺少基准")
                if snapshot.phase=="pending" then G.Need(type(snapshot.pending)=="table" and type(snapshot.recipe)=="table","STATE_INVALID","currentOrder.pending","缺少待确认结果")
                else G.Need(snapshot.pending==false and snapshot.recipe==false,"STATE_INVALID","currentOrder","炼制阶段不得遗留待确认配方") end
            end
            return U.Copy(snapshot)
        end)
    end
    function api.CurrentOrder.Restore(snapshot)
        local result=api.CurrentOrder.ValidateSnapshot(snapshot)
        if result.ok then current=U.Copy(result.value) end
        return result
    end
    function api.CurrentOrder.GetSnapshot() return U.Copy(current) end
    api.ValidateEnvelope=require("systems.OrderAudit").New(content,api).ValidateEnvelope

    local function active(data,request)
        G.Need(type(data.currentOrder)=="table" and data.currentOrder.orderId==request.orderId,"INVALID_ORDER_STATE","orderId","当前没有该订单")
        return data.currentOrder
    end
    local function plan(data,value,events,changed)
        return {data=data,value=value,events=events or {},changed=changed~=false}
    end
    function api.PlanCommand(kind,data,request)
        return G.Run(function()
            G.Pure(request,"request")
            G.Value(api.ValidateEnvelope(data))
            local candidate=U.Copy(data)
            if kind=="Accept" then
                G.Keys(request,{letterInstanceId=true},"request")
                G.Need(U.String(request.letterInstanceId),"INVALID_REQUEST","letterInstanceId","缺少来源信实例")
                for id,accepted in pairs(data.live.orders.acceptedById) do
                    if accepted.letterInstanceId==request.letterInstanceId then
                        return plan(candidate,{orderId=id,phase=data.live.orders.confirmedById[id] and "confirmed" or data.currentOrder.phase,alreadyAccepted=true},{},false)
                    end
                end
                G.Need(data.currentOrder==false,"ORDER_LOCKED","currentOrder","先完成当前订单")
                local item=data.live.letters.byId[request.letterInstanceId]
                G.Need(item and item.received and item.read,"INVALID_ORDER_STATE","letterInstanceId","收到并读过订单信后才能接单")
                local definition=G.Known(content,"letters",item.letterId,"letterId")
                G.Need(definition.kind=="order","INVALID_ORDER_STATE","letterId","回信不能作为新订单")
                local id="order:" .. data.nextOrderSerial
                candidate.nextOrderSerial=data.nextOrderSerial+1
                candidate.live.orders.acceptedById[id]={letterInstanceId=request.letterInstanceId,letterId=item.letterId,acceptedDay=data.live.gameFlow.day}
                candidate.currentOrder={orderId=id,letterInstanceId=request.letterInstanceId,phase="accepted",baseline=false,recipe=false,pending=false,nextAttemptSerial=1,lastResetTransactionId=false}
                candidate.revision=data.revision+1
                return plan(candidate,{orderId=id,phase="accepted",alreadyAccepted=false},{"OrderAccepted"})
            end
            if kind=="Confirm" then
                G.Keys(request,{orderId=true,transactionId=true},"request")
                G.Need(U.String(request.orderId) and U.String(request.transactionId),"INVALID_REQUEST","request","缺少订单或事务 ID")
                local old=data.live.orders.confirmedById[request.orderId]
                if old then
                    G.Need(old.transactionId==request.transactionId,"INVALID_ORDER_STATE","transactionId","过期确认不能应用到另一事务")
                    return plan(candidate,{orderId=request.orderId,transactionId=old.transactionId,phase="confirmed",alreadyConfirmed=true,record=U.Copy(old)},{},false)
                end
            end
            local order=active(data,request)
            local nextOrder=candidate.currentOrder
            if kind=="CancelBrew" then
                G.Keys(request,{orderId=true},"request")
                G.Need(order.nextAttemptSerial==1 and order.lastResetTransactionId==false
                    and (order.phase=="accepted" or order.phase=="brewing"),
                    "ORDER_LOCKED","currentOrder","已有后续记录，只能确认或按原基准重置，不能返回剪词准备")
                if order.phase=="accepted" then
                    return plan(candidate,{orderId=order.orderId,phase="accepted",alreadyPrepared=true},{},false)
                end
                -- 只有从未产生后续的试配可放弃基准；不改 live，不回退试做序号。
                nextOrder.phase="accepted"; nextOrder.baseline=false; nextOrder.recipe=false; nextOrder.pending=false
                return plan(candidate,{orderId=order.orderId,phase="accepted",alreadyPrepared=false},{"BrewCancelled"})
            end
            if kind=="BeginBrew" then
                G.Keys(request,{orderId=true},"request")
                if order.baseline~=false then return plan(candidate,{orderId=order.orderId,baselineId=order.baseline.id,phase=order.phase},{},false) end
                nextOrder.baseline={id=order.orderId .. ":baseline",revision=data.revision,contentVersion=data.contentVersion,live=U.Copy(data.live)}
                nextOrder.phase="brewing"
                return plan(candidate,{orderId=order.orderId,baselineId=nextOrder.baseline.id,phase="brewing"},{"BrewStarted"})
            end
            G.Need(order.baseline~=false and order.baseline.revision==data.revision and U.Equal(order.baseline.live,data.live),"STALE_BASELINE","baseline","首次投料基准缺失或已过期")
            if kind=="Preview" then
                if order.phase=="pending" then
                    G.Need(U.Equal(request,order.recipe),"ORDER_LOCKED","recipe","先确认或重置本次结果")
                    return plan(candidate,{orderId=order.orderId,phase="pending",transactionId=order.pending.transactionId,potion=U.Copy(order.pending.potion)},{},false)
                end
                G.Need(order.phase=="brewing","INVALID_ORDER_STATE","phase","须先建立基准")
                local resolved=G.Value(api.ResolveRecipe(request,order.baseline))
                local potion=G.Value(require("systems.Potion").Calculate(resolved,content))
                local accepted=data.live.orders.acceptedById[order.orderId]
                local definition=G.Known(content,"letters",accepted.letterId,"letterId")
                local evaluated=G.Value(api.Evaluate(definition.requirement,potion))
                if not evaluated.canShip then return plan(candidate,{orderId=order.orderId,phase="brewing",requirementResult=evaluated,potion=U.Copy(potion)},{},false) end
                local context={letterId=definition.id,orderId=order.orderId,day=data.live.gameFlow.day}
                local simulation=G.Value(world.Simulate(order.baseline.live.world,potion,context))
                context.world=simulation.world; context.potion=potion
                local followup=G.Value(narrative.ResolveDirect(simulation.facts,context))
                local rating=G.Value(api.Rate(simulation.facts,definition.ratingSetId))
                local consumption=G.Value(words.PlanConsumption(data.live.wordTokens,G.Value(words.ResolveRecipe(data.live.wordTokens,request))))
                local settlement=G.Value(economy.PlanSettlement(data.live.economy,request.ingredients,request.specialItemIds,definition.reward))
                local transactionId=order.orderId .. ":attempt:" .. order.nextAttemptSerial
                local result={transactionId=transactionId,status="pending",contentVersion=content.contentVersion,synthesisVersion=content.synthesis.version,
                    potion=potion,requirementResult=evaluated,facts=simulation.facts,worldChanges=simulation.worldChanges,
                    followup=followup,rating=rating,consumption={ingredients=U.Copy(request.ingredients),consumedTokenIds=consumption.consumedTokenIds,specialItemIds=U.Copy(request.specialItemIds)},reward=U.Copy(definition.reward)}
                local after=U.Copy(data.live)
                after.wordTokens=consumption.state; after.economy=settlement.state; after.world=simulation.world
                after.gameFlow.deliveredOrders=after.gameFlow.deliveredOrders+1
                local archive=U.Copy(followup); archive.orderId=order.orderId; archive.transactionId=transactionId; archive.rating=rating
                after.letters=G.Value(letter.PlanArchive(after.letters,archive)).state
                local record=U.Copy(result); record.status=nil; record.recipe=U.Copy(request); record.letterInstanceId=order.letterInstanceId; record.deliveryDay=data.live.gameFlow.day
                after.orders.confirmedById[order.orderId]=record
                for _,id in ipairs(G.Value(narrative.FindAvailable(after))) do after.narrative.unlockedLetterIds[id]=true end
                result.candidateLive=after
                nextOrder.pending=result; nextOrder.recipe=U.Copy(request); nextOrder.phase="pending"
                nextOrder.nextAttemptSerial=order.nextAttemptSerial+1
                return plan(candidate,{orderId=order.orderId,transactionId=transactionId,phase="pending",potion=U.Copy(potion)},{"DeliveryPreviewReady"})
            elseif kind=="Confirm" then
                G.Need(order.phase=="pending" and order.pending.transactionId==request.transactionId,"INVALID_ORDER_STATE","transactionId","没有对应待确认事务")
                candidate.live=U.Copy(order.pending.candidateLive); candidate.currentOrder=false; candidate.revision=data.revision+1
                return plan(candidate,{orderId=order.orderId,transactionId=request.transactionId,phase="confirmed",alreadyConfirmed=false,record=U.Copy(candidate.live.orders.confirmedById[order.orderId])},
                    {"PotionDelivered","OrderRatingRecorded","MoneyChanged","ItemRemoved","NpcStateChanged","LetterArchived"})
            elseif kind=="Reset" then
                G.Keys(request,{orderId=true,baselineId=true,transactionId=true},"request")
                G.Need(request.baselineId==order.baseline.id,"STALE_BASELINE","baselineId","重置基准不匹配")
                if order.phase=="brewing" then
                    G.Need(request.transactionId==nil or request.transactionId==order.lastResetTransactionId,"INVALID_ORDER_STATE","transactionId","过期重置请求")
                    return plan(candidate,{orderId=order.orderId,baselineId=order.baseline.id,phase="brewing",alreadyReset=true},{},false)
                end
                G.Need(order.phase=="pending" and request.transactionId==order.pending.transactionId,"INVALID_ORDER_STATE","transactionId","须匹配当前待确认事务")
                nextOrder.lastResetTransactionId=order.pending.transactionId
                nextOrder.pending=false; nextOrder.recipe=false; nextOrder.phase="brewing"
                candidate.live=U.Copy(order.baseline.live)
                return plan(candidate,{orderId=order.orderId,baselineId=order.baseline.id,transactionId=request.transactionId,phase="brewing",alreadyReset=false},{"DeliveryReset"})
            end
            G.Need(false,"INVALID_REQUEST","command","未知订单命令")
        end)
    end
    function api.BindCoordinator(value) coordinator=value end
    for _,name in ipairs({"Accept","BeginBrew","CancelBrew","Preview","Confirm","Reset"}) do
        api[name]=function(request)
            if not coordinator then return U.Fail("STATE_NOT_READY","Order","订单协调器尚未装配") end
            return coordinator.OrderCommand(name,request)
        end
    end
    function api.GetView(request)
        return G.Run(function()
            if request~=nil then G.Keys(request,{orderId=true},"view") end
            G.Need(coordinator~=nil,"STATE_NOT_READY","Order","订单协调器尚未装配")
            if not coordinator then error(U.Error("STATE_NOT_READY","Order","订单协调器尚未装配"),0) end
            local data=coordinator.GetSnapshot()
            G.Need(type(data)=="table","STATE_NOT_READY","Order","尚未加载完整状态")
            local order=data.currentOrder
            local id=request and request.orderId or (order and order.orderId)
            if id and data.live.orders.confirmedById[id] then return {phase="confirmed",orderId=id,record=U.Copy(data.live.orders.confirmedById[id]),actions={}} end
            if id then G.Need(order and order.orderId==id,"INVALID_ORDER_STATE","orderId","不是当前订单") end
            local phase=order and order.phase or "idle"
            local view={phase=phase,formalInventory=U.Copy(data.live.economy),actions={}}
            if order then
                view.orderId=order.orderId; view.baseline=U.Copy(order.baseline); view.recipe=U.Copy(order.recipe)
                if order.pending then
                    view.pending=U.Copy(order.pending); view.trialInventory=U.Copy(order.pending.candidateLive.economy)
                end
            end
            for _,name in ipairs({"Accept","BeginBrew","CancelBrew","Preview","Confirm","Reset","NextDay","ReceiveLetter","ReadLetter","CutWord","Shop","ClaimAttachment"}) do
                view.actions[name]=coordinator.CheckAction(name)
            end
            return view
        end)
    end
end
return Lifecycle
