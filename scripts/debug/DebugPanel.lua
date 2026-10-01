-- ============================================================================
-- DebugPanel — 开发期调试面板
--
-- 按 Z 键开关。显示当前天数、世界状态、最近事件日志，并提供推进天数与
-- 存档读写的按钮，用于本地预览时走查验收项（开发计划 B3 / B4 / B5）。
--
-- 正式版本发布前应停止挂载本面板（见开发计划 1.3 的「不做」清单）。
-- ============================================================================

local UI = require("urhox-libs/UI")
local EventBus = require "core.EventBus"

local DebugPanel = {}

local MAX_LOG_LINES = 12
local REFRESH_INTERVAL = 0.25

---@type table|nil 挂载时传入的依赖
local deps_ = nil

---@type Widget|nil
local panel_ = nil
---@type Widget|nil
local dayLabel_ = nil
---@type Widget|nil
local worldStateLabel_ = nil
---@type Widget|nil
local logLabel_ = nil

local logLines_ = {}
local visible_ = false
local sinceRefresh_ = 0

---@type fun(): table|nil
local worldStateProvider_ = nil

-- ============================================================================
-- 日志
-- ============================================================================

--- 追加一行事件日志。
---@param text string
function DebugPanel.Log(text)
    logLines_[#logLines_ + 1] = text
    while #logLines_ > MAX_LOG_LINES do
        table.remove(logLines_, 1)
    end
end

---@return string[]
function DebugPanel.GetLogLines()
    local copy = {}
    for i = 1, #logLines_ do
        copy[i] = logLines_[i]
    end
    return copy
end

-- ============================================================================
-- 挂载
-- ============================================================================

--- 构建调试面板并挂到根控件上。
---@param root Widget UI 根控件
---@param deps { gameFlow: table, saveSystem: table, saveProvider: fun(): table }
---@return Widget 面板控件
function DebugPanel.Attach(root, deps)
    assert(root, "DebugPanel.Attach: 需要 UI 根控件")
    assert(type(deps) == "table" and deps.gameFlow and deps.saveSystem, "DebugPanel.Attach: deps 缺少 gameFlow 或 saveSystem")
    deps_ = deps

    local logScroll = UI.ScrollView {
        id = "debugLogScroll",
        width = "100%",
        height = 150,
        children = {
            UI.Label {
                id = "debugLogLabel",
                text = "",
                fontSize = 11,
                fontColor = { 170, 220, 170, 255 },
            },
        },
    }

    panel_ = UI.Panel {
        id = "debugPanel",
        visible = false,
        position = "absolute",
        top = 8,
        left = 8,
        right = 8,
        padding = 10,
        gap = 6,
        backgroundColor = { 0, 0, 0, 190 },
        borderRadius = 6,
        pointerEvents = "auto",
        children = {
            UI.Label {
                text = "调试面板（Z 键开关）",
                fontSize = 13,
                fontColor = { 255, 220, 140, 255 },
            },
            UI.Label {
                id = "debugDayLabel",
                text = "",
                fontSize = 12,
                fontColor = { 255, 255, 255, 255 },
            },
            UI.Label {
                id = "debugWorldStateLabel",
                text = "",
                fontSize = 11,
                fontColor = { 200, 210, 255, 255 },
            },
            logScroll,
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                gap = 6,
                marginTop = 2,
                children = {
                    UI.Button {
                        id = "debugNextDayButton",
                        text = "结束当天",
                        variant = "primary",
                        onClick = function()
                            deps_.gameFlow.NextDay()
                        end,
                    },
                    UI.Button {
                        id = "debugSaveButton",
                        text = "保存",
                        onClick = function()
                            deps_.saveSystem.Save(nil, deps_.saveProvider())
                        end,
                    },
                    UI.Button {
                        id = "debugLoadButton",
                        text = "读取",
                        onClick = function()
                            local data = deps_.saveSystem.Load(nil)
                            DebugPanel.Log(data and "读取存档成功" or "读取存档失败（已回落默认值）")
                        end,
                    },
                },
            },
        },
    }

    root:AddChild(panel_)

    dayLabel_ = panel_:FindById("debugDayLabel") --[[@as Widget?]]
    worldStateLabel_ = panel_:FindById("debugWorldStateLabel") --[[@as Widget?]]
    logLabel_ = logScroll:FindById("debugLogLabel") --[[@as Widget?]]

    -- 自动记录所有事件，便于在不打断游戏的情况下观察模块间的通信
    EventBus.OnAny(function(eventName, payload)
        if payload == nil then
            DebugPanel.Log(eventName)
        else
            local parts = {}
            for key, value in pairs(payload) do
                parts[#parts + 1] = tostring(key) .. "=" .. tostring(value)
            end
            table.sort(parts)
            DebugPanel.Log(eventName .. "  " .. table.concat(parts, " "))
        end
    end, "DebugPanel")

    DebugPanel.Refresh()
    print("[DebugPanel] 已挂载，按 Z 键开关")
    return panel_
end

---@param provider fun(): table|nil
function DebugPanel.SetWorldStateProvider(provider)
    worldStateProvider_ = provider
end

-- ============================================================================
-- 显示控制
-- ============================================================================

---@return boolean
function DebugPanel.IsVisible()
    return visible_
end

---@param value boolean
function DebugPanel.SetVisible(value)
    visible_ = value
    if panel_ then
        panel_:SetVisible(value)
    end
    if value then
        DebugPanel.Refresh()
    end
end

function DebugPanel.Toggle()
    DebugPanel.SetVisible(not visible_)
    print("[DebugPanel] " .. (visible_ and "ON" or "OFF"))
end

-- ============================================================================
-- 刷新
-- ============================================================================

---@return string
local function BuildWorldStateText()
    local state = worldStateProvider_ and worldStateProvider_() or nil
    if type(state) ~= "table" or next(state) == nil then
        return "世界状态：（暂无数据，阶段 1 接入 WorldState）"
    end

    local keys = {}
    for key in pairs(state) do
        keys[#keys + 1] = tostring(key)
    end
    table.sort(keys)

    local parts = {}
    for i = 1, #keys do
        local key = keys[i]
        parts[#parts + 1] = key .. "=" .. tostring(state[key])
    end
    return "世界状态：" .. table.concat(parts, "  ")
end

--- 立即刷新面板文字。
function DebugPanel.Refresh()
    if not visible_ or not panel_ then
        return
    end
    if not deps_ then
        return
    end

    if dayLabel_ then
        dayLabel_:SetText(string.format(
            "第 %d 天 · 时段 %s · 可打捞 %s · 已发货 %d",
            deps_.gameFlow.GetDay(),
            deps_.gameFlow.GetPhase(),
            tostring(deps_.gameFlow.CanSalvage()),
            deps_.gameFlow.GetDeliveredOrders()
        ))
    end

    if worldStateLabel_ then
        worldStateLabel_:SetText(BuildWorldStateText())
    end

    if logLabel_ then
        logLabel_:SetText(table.concat(DebugPanel.GetLogLines(), "\n"))
    end
end

--- 每帧调用，内部按固定间隔节流，不每帧重排文字。
---@param timeStep number
function DebugPanel.Update(timeStep)
    if not visible_ then
        return
    end
    sinceRefresh_ = sinceRefresh_ + timeStep
    if sinceRefresh_ < REFRESH_INTERVAL then
        return
    end
    sinceRefresh_ = 0
    DebugPanel.Refresh()
end

return DebugPanel
