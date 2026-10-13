-- 纯迁移候选；由 GameState 在原槽使用完整提交协议落盘后才安装。
local U=require "v035.core.StateUtil"
local G=require "v035.systems.CalculationGuard"
local J=require "v035.systems.BrewJournal"
local D=require "v035.systems.RecipeDraft"
local M={}
function M.ToV3(data,schema,content,limit,initial)
    return G.Run(function()
        local legacy=require("v035.systems.Order").New(content)
        if schema==1 then
            G.Keys(data,{gameFlow=true},"data","STATE_INVALID")
            local flow=G.Value(require("v035.core.GameFlow").ValidateSnapshot(data.gameFlow))
            G.Need(flow.deliveredOrders==0,"MIGRATION_REQUIRED","deliveredOrders","旧发货计数缺少明细，保留原档")
            data=require("v035.core.SchemaProjection").V2(initial); data.live.gameFlow=flow
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
return M
