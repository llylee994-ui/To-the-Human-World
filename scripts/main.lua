-- ============================================================================
-- 《寄往人间》— 游戏入口
--
-- 结构基于 templates/scaffold-2d.lua（纯 UI / NanoVG，无 Scene 与 Viewport）。
-- 开发阶段划分与验收标准见 docs/寄往人间_开发计划与验收标准.md
--
-- 当前进度：阶段 0（工程骨架）
--   main.lua + core/{EventBus, SaveSystem, GameFlow} + debug/{DebugPanel, SelfTest}
--   + data/ 样板配置
--   阶段 1 起在此之上接入 Letter / WordToken / Potion / Order / WorldState / Narrative
-- ============================================================================

local UI = require("urhox-libs/UI")
local EventBus = require "core.EventBus"
local SaveSystem = require "core.SaveSystem"
local GameFlow = require "core.GameFlow"
local GameState = require "core.GameState"
local Economy = require "systems.Economy"
local Data = require "data.content"
local StateUtil = require "core.StateUtil"
local DebugPanel = require "debug.DebugPanel"
local SelfTest = require "debug.SelfTest"

local TITLE = "寄往人间"

---@type Widget|nil
local uiRoot_ = nil
---@type Label|nil
local dayLabel_ = nil
local uiFrameCount_ = 0
local uiLayoutChecked_ = false
---@type table
local gameState_ = {}
local startupStatus_ = ""
local ledgerStatus_ = ""
---@type string
local b1Request_ = require "debug.B1RunRequest"

-- ============================================================================
-- 生命周期
-- ============================================================================

function Start()
    graphics.windowTitle = TITLE

    InitUI()

    -- 内容配置校验：配置写错时在这里一次性列出来，不让错误流到运行时
    local dataReady, dataErrors = Data.Load()
    local dataError
    if not dataReady then
        dataError = StateUtil.Error("CONFIG_INVALID", "Data.Load", table.concat(dataErrors, "；"))
    else
        local initial = Economy.InitialSnapshot()
        if not initial.ok then
            dataReady, dataError = false, initial.error
        else
            dataReady, dataErrors = Data.ValidateStage1()
            if not dataReady then dataError = StateUtil.Error("CONFIG_INVALID", "Data.ValidateStage1", table.concat(dataErrors, "；")) end
        end
    end
    if dataReady then ledgerStatus_ = "\n首单配置已校验；完整模块恢复器就绪后启用账本"
    else ledgerStatus_ = "" end

    -- 阶段 0 自检（B2 / B3 / B4）。会改动 GameFlow 状态，必须在正式载入存档之前跑。
    SelfTest.RunAll(EventBus, GameFlow, SaveSystem)
    GameFlow.Init(nil)
    gameState_ = GameState.New({gameFlow=GameFlow,saveSystem=SaveSystem,eventBus=EventBus,dataReady=dataReady,dataError=dataError})

    -- 仅无存档时新开局；配置/读档失败保留诊断并锁定写入和推进。
    local _, status = LoadProgress(nil)
    startupStatus_ = DebugPanel.DescribeStatus(status)
    startupStatus_ = startupStatus_ .. ledgerStatus_

    CreateUI()
    SubscribeToEvents()
    DebugPanel.Log(startupStatus_)
    if status.status ~= "loaded" and status.status ~= "new" then DebugPanel.SetVisible(true) end

    print(string.format("=== %s 启动完成（第 %d 天）===", TITLE, GameFlow.GetDay()))
end

function LoadProgress(slotName)
    local data, status = gameState_.Load(slotName)
    RefreshHeader()
    return data, status
end

function Stop()
    UI.Shutdown()
    print("=== " .. TITLE .. " 已退出 ===")
end

-- ============================================================================
-- 初始化
-- ============================================================================

function InitUI()
    -- UI.Init 内部完成字体、主题、事件订阅与 NanoVG 上下文创建，
    -- 不需要手动 nvgCreate / nvgCreateFont（见 engine-docs/recipes/ui.md）
    --
    -- 字体必须显式指定：default-dark 主题默认找 Fonts/NotoSansSC-*.ttf，
    -- 而运行时实际只带 Fonts/MiSans-Regular.ttf，不覆盖会因字体加载失败导致整屏不渲染。
    -- options.fonts 的优先级高于 theme.fonts（见 ui.md §初始化）。
    UI.Init({
        theme = "default-dark",
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/MiSans-Regular.ttf",
            } },
        },
        -- DPR + 小屏密度自适应：1 基准像素 ≈ 1 CSS 像素，
        -- 尺寸按 Web/CSS 常识写（按钮 40-48px、正文 14-16px、间距 8/16/24px）
        scale = UI.Scale.DEFAULT,
    })
end

-- ============================================================================
-- 界面
-- ============================================================================

function CreateUI()
    -- 全部界面最外层套 SafeAreaView，避开刘海与 TapTap 胶囊（见开发计划 1.3）
    local root = UI.SafeAreaView {
        id = "safeArea",
        width = "100%",
        height = "100%",
        children = {
            UI.Panel {
                id = "mainPanel",
                width = "100%",
                height = "100%",
                justifyContent = "center",
                alignItems = "center",
                gap = 10,
                padding = 24,
                children = {
                    UI.Label {
                        id = "titleLabel",
                        text = TITLE,
                        fontSize = 28,
                        fontWeight = "bold",
                        fontColor = { 235, 225, 200, 255 },
                    },
                    UI.Label {
                        id = "subtitleLabel",
                        text = "海边魔药铺 · 阶段 0 工程骨架",
                        fontSize = 13,
                        fontColor = { 150, 165, 190, 220 },
                    },
                    UI.Label {
                        id = "dayLabel",
                        text = "",
                        fontSize = 15,
                        fontColor = { 200, 215, 240, 255 },
                        marginTop = 12,
                    },
                    UI.Label {
                        id = "saveStatusLabel",
                        text = startupStatus_,
                        fontSize = 12,
                        fontColor = { 230, 195, 145, 255 },
                        width = "100%",
                        textAlign = "center",
                    },
                    UI.Button {
                        id = "debugToggleButton",
                        text = "调试面板",
                        onClick = function() DebugPanel.Toggle() end,
                    },
                    UI.Label {
                        id = "hintLabel",
                        text = "F6 检查 · F7 写测试档 · F8 读测试档",
                        fontSize = 12,
                        fontColor = { 130, 140, 165, 200 },
                        position = "absolute",
                        bottom = 24,
                        left = 0,
                        right = 0,
                        textAlign = "center",
                    },
                },
            },
        },
    }

    -- 调试面板挂到 SafeAreaView 下，先入树再 SetRoot，避免根控件设定后补挂导致首帧不渲染
    DebugPanel.Attach(root, {
        gameFlow = GameFlow,
        save = function(slot)
            local ok, err = gameState_.Save(slot)
            RefreshHeader()
            return ok, err
        end,
        load = LoadProgress,
        nextDay = function() return gameState_.NextDay() end,
        canMutate = function() return gameState_.CanMutate() end,
    })
    DebugPanel.SetWorldStateProvider(function()
        -- 阶段 1 接入 WorldState 后改读真实世界状态
        return {}
    end)

    uiRoot_ = root
    dayLabel_ = root:FindById("dayLabel") --[[@as Label?]]

    UI.SetRoot(root)
    RefreshHeader()
end

--- 刷新主界面顶部信息。
function RefreshHeader()
    if not dayLabel_ then
        return
    end
    dayLabel_:SetText(string.format("第 %d 天 · 时段 %s", GameFlow.GetDay(), GameFlow.GetPhase()))
    if uiRoot_ then
        local statusLabel = uiRoot_:FindById("saveStatusLabel") --[[@as Label?]]
        if statusLabel then statusLabel:SetText(DebugPanel.DescribeStatus(gameState_.GetStatus()) .. ledgerStatus_) end
    end
end

-- ============================================================================
-- 事件订阅
-- ============================================================================

function SubscribeToEvents()
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("KeyDown", "HandleKeyDown")

    -- 跨天时刷新主界面信息
    EventBus.On("DayStarted", function()
        RefreshHeader()
        DebugPanel.Refresh()
    end, 0, "main")

    EventBus.On("PhaseChanged", function()
        RefreshHeader()
    end, 0, "main")
    EventBus.On("SaveLoaded", function()
        RefreshHeader()
        DebugPanel.Refresh()
    end, 0, "main")
end

-- 先绑定隔离槽再运行检查；中途失败也保留该槽，防止已安装的测试进度写入玩家槽。
---@param writeFixture boolean
---@return boolean
local function RunB1RestartCheck(writeFixture)
    DebugPanel.SetTestSlot("b1_restart_flow")
    DebugPanel.SetVisible(true)
    local ok, err = pcall(function()
        local tests = require "debug.SaveSystemTest"
        if writeFixture then
            assert(RunB1Checks(), "B1 专项检查失败")
            tests.WriteRestartFixture()
        end
        tests.ReadRestartFixture(DebugPanel.LoadProgress)
    end)
    if not ok then DebugPanel.Log("B1 隔离检查未完成：" .. tostring(err)) end
    RefreshHeader()
    DebugPanel.Refresh()
    return ok
end

---@param _eventType string
---@param eventData UpdateEventData
function HandleUpdate(_eventType, eventData)
    local timeStep = eventData["TimeStep"]:GetFloat()
    DebugPanel.Update(timeStep)

    -- 首帧布局完成后做一次界面自检（B1），只跑一次
    if not uiLayoutChecked_ then
        uiFrameCount_ = uiFrameCount_ + 1
        if uiFrameCount_ == 30 then
            uiLayoutChecked_ = true
            SelfTest.CheckUILayout(uiRoot_)
            if b1Request_ == "write" then
                RunB1RestartCheck(true)
            elseif b1Request_ == "read" then
                RunB1RestartCheck(false)
            elseif b1Request_ == "error" then
                SaveSystem.Save("b1_error_ui", {gameFlow=GameFlow.Serialize(),unknownBusiness={}})
                DebugPanel.SetVisible(true)
                DebugPanel.SetTestSlot("b1_error_ui")
                DebugPanel.LoadProgress("b1_error_ui")
            end
        end
    end
end

---@param _eventType string
---@param eventData KeyDownEventData
function HandleKeyDown(_eventType, eventData)
    local key = eventData["Key"]:GetInt()

    if key == KEY_Z then
        DebugPanel.Toggle()
    elseif key == KEY_F6 then
        DebugPanel.SetVisible(true)
        RunB1Checks()
    elseif key == KEY_F7 then
        require("debug.SaveSystemTest").WriteRestartFixture()
    elseif key == KEY_F8 then
        RunB1RestartCheck(false)
    end
end

---@return boolean
function RunB1Checks()
    DebugPanel.SetVisible(true)
    local result = gameState_.WithPreservedState(function()
        return SelfTest.RunB1({
            gameFlow = GameFlow, saveSystem = SaveSystem,
            loadStartup = LoadProgress, loadDebug = DebugPanel.LoadProgress,
            refresh = function() RefreshHeader(); DebugPanel.Refresh() end,
            getTexts = function()
                if not uiRoot_ or not dayLabel_ then return {header="",panel=""} end
                local panelDay = uiRoot_:FindById("debugDayLabel") --[[@as Label?]]
                return { header = dayLabel_:GetText(), panel = panelDay and panelDay:GetText() or "" }
            end,
        })
    end)
    RefreshHeader()
    DebugPanel.Refresh()
    return result
end
