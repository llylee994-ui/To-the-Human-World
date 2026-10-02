-- ============================================================================
-- GameFlow — 游戏流程：天数 / 时段 / 主线阶段
--
-- 见 docs/寄往人间_系统模块拆分与依赖设计.md ② GameFlow 游戏流程模块
--
-- 负责：当前天数、当前时段、每日开始与结束、主线阶段、是否允许打捞
-- 不负责：决定今天出现哪封信、处理具体 NPC、解锁剧情内容
--
-- 输出事件：DayStarted / DayEnded / PhaseChanged / MainStoryStageChanged
-- ============================================================================

local EventBus = require "core.EventBus"
local U = require "core.StateUtil"

local GameFlow = {}

--- 时段。每天先打捞处理订单，再结算进入下一天。
local PHASE = {
    DAY = "day",       -- 白天：打捞、读信、炼药、发货
    ENDED = "ended",   -- 已结束当天，等待进入下一天
}

---@class GameFlowState
---@field day integer 当前天数，从 1 开始
---@field phase string PHASE 之一
---@field canSalvage boolean 当天是否还允许打捞
---@field mainStoryStage string 主线阶段标记
---@field deliveredOrders integer 累计发货订单数

---@return GameFlowState
local function DefaultState()
    return {
        day = 1,
        phase = PHASE.DAY,
        canSalvage = true,
        mainStoryStage = "prologue",
        deliveredOrders = 0,
    }
end

---@type GameFlowState
local state_ = DefaultState()

-- ============================================================================
-- 初始化 / 序列化
-- ============================================================================

--- 初始化。传 saved 则从存档恢复，缺字段按默认值补齐（不因存档字段缺失而崩溃）。
---@param saved? table 仅 gameFlow 子表；非法类型不安装，缺字段才补默认。
---@return table Result
function GameFlow.Init(saved)
    local result = GameFlow.ValidateSnapshot(saved)
    if result.ok then state_ = U.Copy(result.value) end
    return result
end

function GameFlow.ValidateSnapshot(saved)
    if saved == nil then return U.Ok(DefaultState()) end
    local valid = U.Keys(saved, {day=true,phase=true,canSalvage=true,mainStoryStage=true,deliveredOrders=true}, "gameFlow")
    if not valid.ok then return valid end
    local candidate = DefaultState()
    for k, v in pairs(saved) do candidate[k] = v end
    if not U.Integer(candidate.day, 1) or not U.Integer(candidate.deliveredOrders)
        or (candidate.phase ~= PHASE.DAY and candidate.phase ~= PHASE.ENDED)
        or type(candidate.canSalvage) ~= "boolean" or not U.String(candidate.mainStoryStage) then
        return U.Fail("FLOW_INVALID", "gameFlow", "天数、时段、布尔值或主线字段非法")
    end
    return U.Ok(candidate)
end

GameFlow.Restore = GameFlow.Init

--- 导出为存档数据。
---@return table
function GameFlow.Serialize()
    return {
        day = state_.day,
        phase = state_.phase,
        canSalvage = state_.canSalvage,
        mainStoryStage = state_.mainStoryStage,
        deliveredOrders = state_.deliveredOrders,
    }
end
GameFlow.GetSnapshot = GameFlow.Serialize

-- ============================================================================
-- 查询
-- ============================================================================

---@return integer
function GameFlow.GetDay()
    return state_.day
end

---@return string PHASE 之一
function GameFlow.GetPhase()
    return state_.phase
end

---@return boolean
function GameFlow.CanSalvage()
    return state_.canSalvage and state_.phase == PHASE.DAY
end

---@return string
function GameFlow.GetMainStoryStage()
    return state_.mainStoryStage
end

--- 时段常量，供其它模块比较。
GameFlow.PHASE = PHASE

-- ============================================================================
-- 推进
-- ============================================================================

--- 记录一次订单发货（阶段 1 起由 Order 模块调用）。
function GameFlow.RecordDelivery()
    state_.deliveredOrders = state_.deliveredOrders + 1
end

---@return integer
function GameFlow.GetDeliveredOrders()
    return state_.deliveredOrders
end

--- 当天是否还能继续打捞（阶段 1 起由 Letter 模块按每日上限调用）。
---@param allowed boolean
function GameFlow.SetCanSalvage(allowed)
    if state_.canSalvage == allowed then
        return
    end
    state_.canSalvage = allowed
    EventBus.Emit("PhaseChanged", {
        day = state_.day,
        phase = state_.phase,
        canSalvage = state_.canSalvage,
    })
end

--- 设置主线阶段。
---@param stage string
function GameFlow.SetMainStoryStage(stage)
    assert(type(stage) == "string" and stage ~= "", "GameFlow.SetMainStoryStage: stage 必须是非空字符串")
    if state_.mainStoryStage == stage then
        return
    end
    local previous = state_.mainStoryStage
    state_.mainStoryStage = stage
    EventBus.Emit("MainStoryStageChanged", {
        day = state_.day,
        previous = previous,
        current = stage,
    })
end

--- 结束当天并进入下一天。
--- 派发顺序：DayEnded(当天) -> 重置当天状态 -> DayStarted(下一天)
function GameFlow.NextDay()
    local endedDay = state_.day

    state_.phase = PHASE.ENDED
    EventBus.Emit("DayEnded", { day = endedDay })

    state_.day = endedDay + 1
    state_.phase = PHASE.DAY
    state_.canSalvage = true

    EventBus.Emit("DayStarted", { day = state_.day })
end

--- 重开到第一天（阶段 4 的回溯会用到，这里先留最小实现）。
function GameFlow.Reset()
    state_ = DefaultState()
    EventBus.Emit("DayStarted", { day = state_.day })
end

return GameFlow
