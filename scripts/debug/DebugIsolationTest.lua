-- 仅供 run_b1.py 的独立进程场景；File/UI 已替换，不可在真实引擎中调用。
-- 经过 main 的真实快捷键/首帧分支和 DebugPanel 按钮，防止测试进度写入玩家槽。
local Tests = {}
local Save = require "core.SaveSystem"
local Flow = require "core.GameFlow"
local U = require "core.StateUtil"
local Panel = require "debug.DebugPanel"
local EventBus = require "core.EventBus"
local Restart = require "debug.SaveSystemTest"

local function defaultFiles()
    local storage, files = Save.EngineStorage(), {}
    for _, suffix in ipairs({".json", "_a.json", "_b.json", "_a.commit", "_b.commit"}) do
        local path = "save_slot1" .. suffix
        files[path] = storage.exists(path) and storage.read(path) or false
    end
    return files
end

local function corruptRestartV2()
    Save.Delete("b1_restart_v2")
    local storage = Save.EngineStorage()
    storage.write("save_b1_restart_v2.json", "{broken")
    assert(storage.read("save_b1_restart_v2.json") == "{broken", "R2 损坏夹具写入失败")
end

---@param scenario string
---@param testAdapters boolean runner 显式保证存储与 UI 隔离
function Tests.Prepare(scenario, testAdapters)
    assert(testAdapters == true, "DebugIsolationTest 仅允许测试替身")
    if scenario ~= "missing" then
        assert(Save.Save(nil, {gameFlow={day=3,phase="day",canSalvage=true,
            mainStoryStage="prologue",deliveredOrders=0}}))
    end
    local automatic = scenario:match("^auto_") ~= nil
    local missingFlow = scenario:find("flow_missing", 1, true) ~= nil
    local corruptV2 = scenario:find("v2_corrupt", 1, true) ~= nil
    if automatic and not missingFlow and scenario ~= "auto_write" then
        Restart.WriteRestartFixture()
    end
    if automatic and corruptV2 then corruptRestartV2() end
    package.loaded["debug.B1RunRequest"] = automatic and (scenario == "auto_write" and "write" or "read") or "off"
    -- 只驱动真实 HandleUpdate 的首帧调试分支；不把 UI 替身尺寸当布局验收。
    if automatic then require("debug.SelfTest").CheckUILayout = function() end end
    return {scenario=scenario,automatic=automatic,missingFlow=missingFlow,corruptV2=corruptV2,
        originalDefault=defaultFiles()}
end

---@param context table
---@param dispatchKey fun(key: integer)
---@param advanceFrame fun()
---@param root Widget
function Tests.Run(context, dispatchKey, advanceFrame, root)
    local title = assert(root:FindById("debugTitleLabel")) --[[@as Label]]
    local function click(id)
        local button = assert(root:FindById(id))
        button:GetProps().onClick()
    end
    local function unchanged()
        assert(U.Equal(defaultFiles(), context.originalDefault),
            "R2 DEFAULT_SLOT_CHANGED: 测试操作覆盖或创建了默认玩家槽")
    end
    local function isolated()
        return title:GetText():find("b1_restart_flow", 1, true) ~= nil and Panel.IsVisible()
    end
    -- 观察状态安装后的同步事件；此时必须已经绑定并展示测试上下文。
    local installs, isolationBeforeInstall = 0, true
    local listener = EventBus.On("SaveLoaded", function()
        installs = installs + 1
        isolationBeforeInstall = isolationBeforeInstall and isolated()
    end, 0, "R2/isolation")

    local called, err = pcall(function()
        if context.automatic then
            for _ = 1, 30 do advanceFrame() end
        else
            if not context.missingFlow then dispatchKey(KEY_F7) end
            if context.corruptV2 then corruptRestartV2() end
            dispatchKey(KEY_F8)
        end
    end)
    EventBus.Off("SaveLoaded", listener)
    print(string.format("[R2] %s after load day=%d title=%s", context.scenario, Flow.GetDay(), title:GetText()))
    -- 即使夹具断言失败，也继续点真实保存按钮，捕获失败路径上的同一覆盖问题。
    click("debugSaveButton")
    unchanged()
    assert(called, "R2 调试错误应显示在面板，不能向引擎抛出：" .. tostring(err))
    assert(installs > 0 and isolationBeforeInstall, "R2 必须在状态安装之前显示隔离上下文")
    assert(isolated(), "R2 面板必须保持显示 b1_restart_flow")
    if context.missingFlow or context.corruptV2 then
        local diagnostic = table.concat(Panel.GetLogLines(), "\n")
        assert(diagnostic:find("B1 隔离检查未完成", 1, true), "R2 失败诊断缺失")
        local failure = context.missingFlow and "测试流程档 b1_restart_flow" or "待确认夹具 b1_restart_v2"
        assert(diagnostic:find(failure, 1, true), "R2 失败诊断未指明夹具")
    end

    local expectedDay = context.missingFlow and 1 or 5
    assert(Flow.GetDay() == expectedDay)
    assert(assert(Save.Load("b1_restart_flow"), "R2 测试流程档读取失败").gameFlow.day == expectedDay, "R2 保存未落在测试槽")
    click("debugNextDayButton")
    assert(Flow.GetDay() == expectedDay + 1)
    click("debugLoadButton")
    assert(Flow.GetDay() == expectedDay, "R2 读取未保持测试槽")
    click("debugNextDayButton")
    click("debugSaveButton")
    assert(assert(Save.Load("b1_restart_flow"), "R2 测试流程档读取失败").gameFlow.day == expectedDay + 1)
    click("debugLoadButton")
    unchanged()
    assert(isolated() and Flow.GetDay() == expectedDay + 1)
    print("[R2] PASS " .. context.scenario .. " default bytes preserved; load/save/nextDay isolated")
end

return Tests
