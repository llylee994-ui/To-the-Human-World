-- ============================================================================
-- SelfTest — 阶段 0 验收自检
--
-- 启动时跑一遍，把结果打到预览日志，用于走查开发计划的 B2 / B3 / B4。
-- 只用专用存档槽位 selftest，不碰正式存档。
--
-- 这是开发期脚手架。阶段 0 验收通过后可以不再随 main.lua 启动调用。
-- ============================================================================

local SelfTest = {}

local passed_ = 0
local failed_ = 0

---@param name string
---@param ok boolean
---@param detail? string
local function Check(name, ok, detail)
    if ok then
        passed_ = passed_ + 1
        print(string.format("[SelfTest] PASS  %s", name))
    else
        failed_ = failed_ + 1
        print(string.format("[SelfTest] FAIL  %s%s", name, detail and ("  —— " .. detail) or ""))
    end
end

---@param a any
---@param b any
---@return boolean
local function DeepEqual(a, b)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= "table" then
        return a == b
    end
    for key, value in pairs(a) do
        if not DeepEqual(value, b[key]) then
            return false
        end
    end
    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end
    return true
end

-- ============================================================================
-- B2 事件总线
-- ============================================================================

---@param eventBus table
local function TestEventBus(eventBus)
    local received = {}

    local idLow = eventBus.On("SelfTestEvent", function(_, payload)
        received[#received + 1] = "low:" .. tostring(payload and payload.value)
    end, 0, "SelfTest/lower")

    local idHigh = eventBus.On("SelfTestEvent", function(_, payload)
        received[#received + 1] = "high:" .. tostring(payload and payload.value)
    end, 10, "SelfTest/higher")

    local idLow2 = eventBus.On("SelfTestEvent", function()
        received[#received + 1] = "low2"
    end, 0, "SelfTest/lower2")

    eventBus.Emit("SelfTestEvent", { value = 7 })

    Check("B2 两个监听者都收到事件", #received == 3,
        "收到 " .. #received .. " 次")
    Check("B2 高优先级先收到", received[1] == "high:7",
        "实际顺序 " .. table.concat(received, ","))
    Check("B2 同优先级按注册顺序", received[2] == "low:7" and received[3] == "low2",
        "实际顺序 " .. table.concat(received, ","))

    -- 退订后不再收到
    eventBus.Off("SelfTestEvent", idHigh)
    received = {}
    eventBus.Emit("SelfTestEvent", { value = 8 })
    Check("B2 退订生效", #received == 2 and received[1] == "low:8",
        "实际顺序 " .. table.concat(received, ","))

    eventBus.Off("SelfTestEvent", idLow)
    eventBus.Off("SelfTestEvent", idLow2)
end

-- ============================================================================
-- B3 存档系统
-- ============================================================================

---@param saveSystem table
---@param gameFlow table
local function TestSaveSystem(saveSystem, gameFlow)
    local slot = "selftest"
    saveSystem.Delete(slot) -- 清除上次中断留下的专用测试槽，不触碰玩家槽。

    -- 1. 嵌套表往返
    local original = {
        day = 3,
        nested = { a = 1, b = { c = "中文文本" } },
        list = { 1, 2, 3 },
        flag = true,
    }
    local ok = saveSystem.Save(slot, original)
    local loaded = saveSystem.Load(slot)
    Check("B3 存档往返一致", ok and DeepEqual(original, loaded),
        ok and "读回内容不一致" or "写入失败")

    -- 2. 字段缺失的存档：读取不崩溃，交给调用方补默认值
    saveSystem.Save(slot, { day = 5 })
    local partial = saveSystem.Load(slot)
    local partialOk = pcall(gameFlow.Init, partial)
    Check("B3 字段缺失不崩溃且补齐默认值",
        partialOk and gameFlow.GetDay() == 5 and gameFlow.GetPhase() == "day",
        partialOk and ("实际 day=" .. tostring(gameFlow.GetDay())) or "Init 抛异常")

    -- 3. 版本号过新：回落 nil
    saveSystem.Delete(slot) -- 新协议仍优先于旧 JSON；此处独立验证旧文件兼容路径。
    local file = File("save_" .. slot .. ".json", FILE_WRITE)
    if file:IsOpen() then
        file:WriteString('{"schema":999,"data":{"day":1}}')
        file:Close()
    end
    Check("B3 版本号过新时回落默认值", saveSystem.Load(slot) == nil)

    -- 4. 内容损坏：回落 nil，不抛异常
    local badFile = File("save_" .. slot .. ".json", FILE_WRITE)
    if badFile:IsOpen() then
        badFile:WriteString("{不是合法的 JSON")
        badFile:Close()
    end
    local corruptOk, corruptResult = pcall(saveSystem.Load, slot)
    Check("B3 内容损坏时回落默认值", corruptOk and corruptResult == nil,
        corruptOk and "未回落" or "Load 抛异常")

    saveSystem.Delete(slot)
end

-- ============================================================================
-- B4 游戏流程
-- ============================================================================

---@param eventBus table
---@param gameFlow table
local function TestGameFlow(eventBus, gameFlow)
    local dayStartCount, dayEndCount = 0, 0
    local endedDay = nil

    local idStart = eventBus.On("DayStarted", function(_, _payload)
        dayStartCount = dayStartCount + 1
    end, 0, "SelfTest/GameFlow")

    local idEnd = eventBus.On("DayEnded", function(_, payload)
        dayEndCount = dayEndCount + 1
        endedDay = payload and payload.day
    end, 0, "SelfTest/GameFlow")

    local before = gameFlow.GetDay()
    gameFlow.NextDay()

    Check("B4 跨天后天数 +1", gameFlow.GetDay() == before + 1,
        string.format("期望 %d，实际 %d", before + 1, gameFlow.GetDay()))
    Check("B4 派发 DayEnded 且带当天编号", dayEndCount == 1 and endedDay == before)
    Check("B4 派发 DayStarted", dayStartCount == 1)

    eventBus.Off("DayStarted", idStart)
    eventBus.Off("DayEnded", idEnd)
end

-- ============================================================================
-- B1 界面布局
-- ============================================================================

--- 确认 Yoga 真的算出了非零尺寸。这是「UI 已进入渲染树」的间接证据：
--- 纯白截图既可能是 UI 没渲染，也可能是截图抓不到 NanoVG 图层，靠尺寸才能区分。
---@param root Widget|nil UI 根控件
function SelfTest.CheckUILayout(root)
    if not root then
        Check("B1 UI 根控件存在", false, "root 为 nil")
        return
    end

    local ids = { "safeArea", "mainPanel", "titleLabel", "dayLabel" }
    local allOk = true

    for i = 1, #ids do
        local id = ids[i]
        local widget = root:FindById(id) --[[@as Widget?]]
        if not widget then
            allOk = false
            print(string.format("[SelfTest] FAIL  B1 找不到控件 %s", id))
        else
            local w, h = widget:GetComputedSize()
            local ok = type(w) == "number" and type(h) == "number" and w > 0 and h > 0
            if not ok then
                allOk = false
            end
            print(string.format(
                "[SelfTest] %s  B1 控件 %s 布局尺寸 %.0f x %.0f",
                ok and "PASS" or "FAIL", id, tonumber(w) or -1, tonumber(h) or -1
            ))
        end
    end

    if allOk then
        passed_ = passed_ + 1
    else
        failed_ = failed_ + 1
    end
    print(string.format("[SelfTest] B1 布局自检结束：通过 %d，失败 %d", passed_, failed_))
end

-- ============================================================================
-- 入口
-- ============================================================================

--- 运行全部自检。会修改 gameFlow 的天数与存档槽 selftest，调用方需在其后重新 Init。
---@param eventBus table
---@param gameFlow table
---@param saveSystem table
function SelfTest.RunAll(eventBus, gameFlow, saveSystem)
    passed_, failed_ = 0, 0
    print("========== 阶段 0 自检开始 ==========")

    TestEventBus(eventBus)
    local saveChecksRan, saveCheckError = pcall(TestSaveSystem, saveSystem, gameFlow)
    if not saveChecksRan then
        Check("B3 存档自检执行异常", false,
            type(saveCheckError) == "table" and saveCheckError.message or tostring(saveCheckError))
    end
    TestGameFlow(eventBus, gameFlow)

    print(string.format("========== 阶段 0 自检结束：通过 %d，失败 %d ==========", passed_, failed_))
end

--- 仅由显式调试操作触发，普通启动不注入文件故障。
function SelfTest.RunB1(context)
    return require("debug.SaveSystemTest").RunRecovery(context)
end

return SelfTest
