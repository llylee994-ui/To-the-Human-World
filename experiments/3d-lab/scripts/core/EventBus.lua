-- ============================================================================
-- EventBus — 游戏内事件总线（注册 / 派发 / 优先级）
--
-- 模块之间只通过事件通信，不直接调用彼此的写操作。
-- 见 docs/寄往人间_系统模块拆分与依赖设计.md 四、核心事件总线建议
--
-- 范围：只做「注册 / 派发 / 优先级」，同帧同步派发，不做异步或调度。
-- 派发时不捕获异常：handler 出错会直接抛到预览日志，便于开发期定位。
-- ============================================================================

---@class EventListener
---@field id integer 递增序号，同优先级时保证派发顺序稳定
---@field handler fun(eventName: string, payload: table|nil)
---@field priority number 越大越先收到
---@field owner string|nil 便于调试时定位订阅方

local EventBus = {}

---@type table<string, EventListener[]?>
local registry_ = {}

---@type EventListener[]
local anyListeners_ = {}

local nextListenerId_ = 0

-- ============================================================================
-- 订阅
-- ============================================================================

--- 订阅指定事件。
---@param eventName string 事件名，如 "DayStarted"
---@param handler fun(eventName: string, payload: table|nil)
---@param priority? number 默认 0；越大越先收到
---@param owner? string 订阅方名称，仅用于调试
---@return integer listenerId 用于 EventBus.Off 退订
function EventBus.On(eventName, handler, priority, owner)
    assert(type(eventName) == "string" and eventName ~= "", "EventBus.On: eventName 必须是非空字符串")
    assert(type(handler) == "function", "EventBus.On: handler 必须是函数")

    nextListenerId_ = nextListenerId_ + 1
    local listener = {
        id = nextListenerId_,
        handler = handler,
        priority = priority or 0,
        owner = owner,
    }

    local list = registry_[eventName]
    if not list then
        list = {}
        registry_[eventName] = list
    end
    table.insert(list, listener)

    -- 按优先级降序；同优先级按注册先后（用 id 兜底，table.sort 本身不稳定）
    table.sort(list, function(a, b)
        if a.priority ~= b.priority then
            return a.priority > b.priority
        end
        return a.id < b.id
    end)

    return listener.id
end

--- 订阅所有事件（调试面板用于自动记录事件日志）。
--- 在具体事件的 handler 之后调用。
---@param handler fun(eventName: string, payload: table|nil)
---@param owner? string
---@return integer listenerId
function EventBus.OnAny(handler, owner)
    assert(type(handler) == "function", "EventBus.OnAny: handler 必须是函数")

    nextListenerId_ = nextListenerId_ + 1
    local listener = {
        id = nextListenerId_,
        handler = handler,
        priority = 0,
        owner = owner,
    }
    table.insert(anyListeners_, listener)
    return listener.id
end

--- 退订。
---@param eventName string
---@param listenerId integer EventBus.On / OnAny 的返回值
---@return boolean 是否找到并移除
function EventBus.Off(eventName, listenerId)
    local list = registry_[eventName]
    if list then
        for i = #list, 1, -1 do
            if list[i].id == listenerId then
                table.remove(list, i)
                return true
            end
        end
    end
    for i = #anyListeners_, 1, -1 do
        if anyListeners_[i].id == listenerId then
            table.remove(anyListeners_, i)
            return true
        end
    end
    return false
end

-- ============================================================================
-- 派发
-- ============================================================================

--- 同步派发事件。按优先级从高到低依次调用 handler。
---@param eventName string
---@param payload? table 传给 handler 的数据表（纯 Lua table，不是引擎 VariantMap）
---@return integer 实际调用到的 handler 数量
function EventBus.Emit(eventName, payload)
    assert(type(eventName) == "string" and eventName ~= "", "EventBus.Emit: eventName 必须是非空字符串")

    local list = registry_[eventName]
    local anyList = anyListeners_

    -- 先取快照：handler 内部可能会订阅或退订，直接遍历原表会漏调或错位
    local targets = {}
    if list then
        for i = 1, #list do
            targets[#targets + 1] = list[i]
        end
    end
    for i = 1, #anyList do
        targets[#targets + 1] = anyList[i]
    end

    for i = 1, #targets do
        targets[i].handler(eventName, payload)
    end
    return #targets
end

-- ============================================================================
-- 维护
-- ============================================================================

--- 清空订阅。传 eventName 只清该事件，不传清全部（回溯 / 重开时用）。
---@param eventName? string
function EventBus.Clear(eventName)
    if eventName then
        registry_[eventName] = nil
    else
        registry_ = {}
        anyListeners_ = {}
    end
end

--- 查询某事件的订阅者数量，供调试面板显示。
---@param eventName string
---@return integer
function EventBus.GetListenerCount(eventName)
    local list = registry_[eventName]
    return list and #list or 0
end

--- 列出全部已注册的事件名，供调试面板显示。
---@return string[]
function EventBus.GetEventNames()
    local names = {}
    for name in pairs(registry_) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

return EventBus
