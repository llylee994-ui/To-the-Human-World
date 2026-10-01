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
local Data = require "data.init"
local DebugPanel = require "debug.DebugPanel"
local SelfTest = require "debug.SelfTest"

local TITLE = "寄往人间"

---@type Widget|nil
local uiRoot_ = nil
---@type Widget|nil
local dayLabel_ = nil
local uiFrameCount_ = 0
local uiLayoutChecked_ = false

-- ============================================================================
-- 生命周期
-- ============================================================================

function Start()
    graphics.windowTitle = TITLE

    InitUI()

    -- 内容配置校验：配置写错时在这里一次性列出来，不让错误流到运行时
    Data.Load()

    -- 阶段 0 自检（B2 / B3 / B4）。会改动 GameFlow 状态，必须在正式载入存档之前跑。
    SelfTest.RunAll(EventBus, GameFlow, SaveSystem)

    -- 载入存档；没有存档或存档不合格时按新游戏开始
    local saved = SaveSystem.Load(nil)
    GameFlow.Init(saved)

    CreateUI()
    SubscribeToEvents()

    print(string.format("=== %s 启动完成（第 %d 天）===", TITLE, GameFlow.GetDay()))
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
                        id = "hintLabel",
                        text = "按 Z 打开调试面板",
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
        saveSystem = SaveSystem,
        saveProvider = function()
            return {
                gameFlow = GameFlow.Serialize(),
            }
        end,
    })
    DebugPanel.SetWorldStateProvider(function()
        -- 阶段 1 接入 WorldState 后改读真实世界状态
        return {}
    end)

    uiRoot_ = root
    dayLabel_ = root:FindById("dayLabel") --[[@as Widget?]]

    UI.SetRoot(root)
    RefreshHeader()
end

--- 刷新主界面顶部信息。
function RefreshHeader()
    if not dayLabel_ then
        return
    end
    dayLabel_:SetText(string.format("第 %d 天 · 时段 %s", GameFlow.GetDay(), GameFlow.GetPhase()))
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
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local timeStep = eventData:GetFloat("TimeStep")
    DebugPanel.Update(timeStep)

    -- 首帧布局完成后做一次界面自检（B1），只跑一次
    if not uiLayoutChecked_ then
        uiFrameCount_ = uiFrameCount_ + 1
        if uiFrameCount_ == 30 then
            uiLayoutChecked_ = true
            SelfTest.CheckUILayout(uiRoot_)
        end
    end
end

---@param eventType string
---@param eventData KeyDownEventData
function HandleKeyDown(eventType, eventData)
    local key = eventData:GetInt("Key")

    if key == KEY_Z then
        DebugPanel.Toggle()
    end
end
