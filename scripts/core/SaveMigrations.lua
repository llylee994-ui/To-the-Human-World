-- 纯迁移候选；由 GameState 在原槽使用完整提交协议落盘后才安装。
local U=require "core.StateUtil"
local G=require "systems.CalculationGuard"
local J=require "systems.BrewJournal"
local D=require "systems.RecipeDraft"
local M={}
function M.ToV3(data,schema,content,limit,initial)
    return G.Run(function()
        local legacy=require("systems.Order").New(content)
        if schema==1 then
            G.Keys(data,{gameFlow=true},"data","STATE_INVALID")
            local flow=G.Value(require("core.GameFlow").ValidateSnapshot(data.gameFlow))
            G.Need(flow.deliveredOrders==0,"MIGRATION_REQUIRED","deliveredOrders","旧发货计数缺少明细，保留原档")
            data=require("core.SchemaProjection").V2(initial); data.live.gameFlow=flow
        else G.Need(schema==2,"SAVE_UNSUPPORTED","schema","不支持该结构迁移") end
        G.Value(legacy.ValidateEnvelope(data))
        local candidate=U.Copy(data)
        candidate.journal=J.Empty()
        local function flow(live)
            -- 旧档没有当日捕捞时间证据：保守耗尽今日额度，下一天恢复。
            live.gameFlow.salvageUsedToday=limit; live.gameFlow.canSalvage=false
        end
        flow(candidate.live)
        local records={}
        for oid,record in pairs(candidate.live.orders.confirmedById) do records[#records+1]={id=oid,record=record} end
        table.sort(records,function(a,b) return tonumber(a.id:match("%d+"))<tonumber(b.id:match("%d+")) end)
        for _,row in ipairs(records) do J.Insert(candidate.journal,J.Record(candidate,row.id,row.record,row.record.recipe,"shipped",2,content)) end
        local order=candidate.currentOrder
        if order then
            if order.pending then
                flow(order.baseline.live); flow(order.pending.candidateLive)
                order.draft=D.Project(order.recipe)
                J.Insert(candidate.journal,J.Record(candidate,order.orderId,order.pending,order.recipe,"pending",2,content))
            else
                order.phase="accepted"; order.baseline=false; order.recipe=false; order.pending=false
                order.draft=D.Empty(content.stage1.initialEquipmentId)
            end
        end
        return candidate
    end)
end
function M.ToV4(data,content,limit)
    return G.Run(function()
        -- 先用原结构审计；不同内容版本及坏旧账不能先转换后放行。
        G.Value(require("systems.OrderTrial").Wrap(require("systems.Order").New(content),content,limit,3).ValidateEnvelope(data))
        local candidate=U.Copy(data)
        local function convert(live)
            local e=live.economy;e.itemPurchases={}
            for _,row in ipairs(e.furniturePurchases or {}) do
                e.itemPurchases[#e.itemPurchases+1]={itemId=row.furnitureId,unitPrice=row.unitPrice,day=row.day,
                    afterDeliveredOrders=row.afterDeliveredOrders,transactionId="purchase:"..row.furnitureId}
            end
            e.furniturePurchases=nil;e.ownedFurnitureIds=nil
        end
        convert(candidate.live)
        if candidate.currentOrder and candidate.currentOrder.pending then convert(candidate.currentOrder.baseline.live);convert(candidate.currentOrder.pending.candidateLive) end
        candidate.chapter=require("systems.ReleaseLedger").EmptyChapter()
        return G.Value(require("systems.OrderTrial").Wrap(require("systems.Order").New(content,{schema4Projection=true}),content,limit,4).ValidateEnvelope(candidate))
    end)
end
return M
