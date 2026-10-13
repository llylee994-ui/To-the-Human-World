-- ============================================================================
-- 《寄往人间》— 游戏入口
--
-- 结构基于 templates/scaffold-2d.lua（纯 UI / NanoVG，无 Scene 与 Viewport）。
-- 开发阶段划分与验收标准见 docs/寄往人间_开发计划与验收标准.md
--
-- B6：真实首单模块、v2 存档与文字按钮玩法界面。
-- ============================================================================

local UI = require("urhox-libs/UI")
local EventBus = require "core.EventBus"
local SaveSystem = require "core.SaveSystem"
local GameFlow = require "core.GameFlow"
local GameState = require "core.GameState"
local GameSession = require "core.GameSession"
local Economy = require "systems.Economy"
local Data = require "data.content"
local StateUtil = require "core.StateUtil"
local DebugPanel = require "debug.DebugPanel"
local SelfTest = require "debug.SelfTest"
local PlayView = require "ui.PlayView"
---@type table|nil
local playView_
---@type integer|nil
local playListener_

local TITLE = "寄往人间"

---@type Widget|nil
local uiRoot_ = nil
---@type Label|nil
local dayLabel_ = nil
local uiFrameCount_ = 0
local uiLayoutChecked_ = false
---@type table
local gameState_ = {}
---@type table
local session_ = {}
---@type table
local legacyDebugState_ = {}
local startupStatus_ = ""
local ledgerStatus_ = ""
local dismissedPlayerError_ = false
local observedPlayerStatus_ = ""
---@type string
local b1Request_ = require "debug.B1RunRequest"
---@type string
local b2Request_ = require "debug.B2RunRequest"
---@type string
local b6Request_ = require "debug.B6RunRequest"
local developerMode_ = require "debug.DeveloperMode"
    or b1Request_ ~= "off" or b2Request_ ~= "off" or b6Request_ ~= "off"

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
    if dataReady then ledgerStatus_ = ""
    else ledgerStatus_ = "" end

    -- 阶段 0 自检（B2 / B3 / B4）。会改动 GameFlow 状态，必须在正式载入存档之前跑。
    if developerMode_ then SelfTest.RunAll(EventBus, GameFlow, SaveSystem) end
    GameFlow.Init(nil)
    legacyDebugState_ = GameState.New({gameFlow=GameFlow,saveSystem=SaveSystem,eventBus=EventBus,dataReady=dataReady,dataError=dataError})
    local sessionSave = SaveSystem
    if b6Request_ == "b6_uncertain_20261004_a" then
        sessionSave = require("debug.B6UncertainStorage").New(SaveSystem, b6Request_)
    end
    session_ = GameSession.New(Data,{gameFlow=GameFlow,saveSystem=sessionSave,eventBus=EventBus,dataReady=dataReady,dataError=dataError,
        targetSchema=b6Request_~="off" and 2 or 3}) -- 仅显式旧 B6 验收入口保留 schema 2。
    gameState_ = session_.state

    -- 仅无存档时新开局；配置/读档失败保留诊断并锁定写入和推进。
    assert(b6Request_ == "off" or (b6Request_:match("^b6_[%w_]+$") and #b6Request_ <= 64), "非法 B6 验收槽")
    assert(b6Request_ == "off" or (b1Request_ == "off" and b2Request_ == "off"), "B6 验收不能与 B1/B2 自动检查混用")
    local _, status = LoadProgress(b6Request_ ~= "off" and b6Request_ or nil)
    if b6Request_ ~= "off" then ledgerStatus_ = " · B6 验收槽 " .. b6Request_ end
    startupStatus_ = DebugPanel.DescribeStatus(status)
    startupStatus_ = startupStatus_ .. ledgerStatus_

    CreateUI()
    SubscribeToEvents()
    DebugPanel.Log(startupStatus_)
    if developerMode_ and status.status ~= "loaded" and status.status ~= "new" then DebugPanel.SetVisible(true) end

    print(string.format("=== %s 启动完成（第 %d 天）===", TITLE, session_.modules.gameFlow.GetDay()))
end

function LoadProgress(slotName)
    -- v02使用独立试玩槽，保留旧slot1；显式验收槽仍优先。
    local data, status = gameState_.Load(slotName or Data.saveSlotId)
    RefreshHeader()
    return data, status
end

-- B6 通过公共协调器/订单接口操作；不暴露任何模块的私有状态。
function GetGameSession() return session_ end

function Stop()
    if playListener_ then EventBus.Off("",playListener_); playListener_=nil end
    playView_=nil
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
    -- 保留运行时 MiSans 注册，并为海港主题注册项目内的 OFL 手写字体子集。
    -- HarborTheme 统一使用 story；regular/bold 共用正文笔画，避免伪粗体糊字。
    -- options.fonts 的优先级高于 theme.fonts（见 ui.md §初始化）。
    UI.Init({
        theme = require "ui.landscape.HarborTheme",
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/MiSans-Regular.ttf",
            } },
            { family = "story", weights = {
                normal = "fonts/HarborHand-Regular.ttf",
                bold = "fonts/HarborHand-Regular.ttf",
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
        backgroundColor = {48, 42, 34, 255},
        backgroundImage = require("ui.landscape.SeaArt").background,
        backgroundFit = "cover",
        width = "100%",
        height = "100%",
        children = {
            UI.Panel {
                id = "mainPanel",
                width = "100%",
                height = "100%",
                justifyContent = "flex-start",
                alignItems = "stretch",
                gap = 6,
                padding = 12,
                children = {
                    UI.Label {
                        id = "titleLabel",
                        text = TITLE,
                        fontSize = 22,
                        fontWeight = "bold",
                        fontColor = { 235, 225, 200, 255 },
                    },
                    UI.Label {
                        id = "subtitleLabel",
                        text = "海边魔药铺",
                        fontSize = 13,
                        fontColor = { 150, 165, 190, 220 },
                    },
                    UI.Label {
                        id = "dayLabel",
                        visible = developerMode_,
                        text = "",
                        fontSize = 15,
                        fontColor = { 200, 215, 240, 255 },
                        marginTop = 0,
                    },
                    UI.Label {
                        id = "saveStatusLabel",
                        visible = developerMode_,
                        text = startupStatus_,
                        fontSize = 12,
                        fontColor = { 230, 195, 145, 255 },
                        width = "100%",
                        textAlign = "center",
                        whiteSpace = "normal",
                    },
                    UI.Label {
                        id = "hintLabel",
                        visible = false,
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

    playView_=PlayView.New(session_,Data,function() return gameState_==session_.state end)
    assert(root:FindById("mainPanel")):AddChild(playView_.root)
    -- 正式错误提示由入口拥有；关闭仅收起提示，协调器保持锁定，可同槽重试。
    if not developerMode_ then
        local panel=assert(root:FindById("mainPanel"))
        panel:AddChild(UI.Panel {id="playerSaveError",width="100%",flexDirection="column",gap=12,visible=false,children={
            UI.Label {text="进度暂时无法读取或保存。原存档已保留，请重新读取后继续。",whiteSpace="normal",width="100%",fontSize=18},
            UI.Button {id="playerSaveErrorClose",text="关闭提示",minHeight=48,onClick=function() dismissedPlayerError_=true; RefreshHeader() end},
        }})
        panel:AddChild(UI.Button {id="playerSaveRetry",text="重新读取原存档",minHeight=48,visible=false,onClick=function()
            dismissedPlayerError_=false
            local _,status=gameState_.ReloadCurrent()
            if status.error then print("[PlayerRecovery] "..cjson.encode(status.error)) end
            RefreshHeader()
        end})
    end

    -- 调试面板挂到 SafeAreaView 下，先入树再 SetRoot，避免根控件设定后补挂导致首帧不渲染
    if developerMode_ then
    local mainPanel = assert(root:FindById("mainPanel"))
    mainPanel:AddChild(UI.Button {id="debugToggleButton",text="开发工具",minHeight=48,onClick=function() DebugPanel.Toggle() end})
    mainPanel:AddChild(UI.Button {id="b2CheckButton",text="B2 信件检查",minHeight=48,onClick=function() RunB2Checks() end})
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
    if b6Request_ ~= "off" then DebugPanel.SetTestSlot(b6Request_) end
    DebugPanel.SetWorldStateProvider(function()
        return session_.modules.world.GetSnapshot()
    end)
    end

    uiRoot_ = root
    dayLabel_ = root:FindById("dayLabel") --[[@as Label?]]

    UI.SetRoot(root)
    RefreshHeader()
end

--- 刷新主界面顶部信息。
function RefreshHeader()
    if playView_ then playView_.Refresh() end
    if not dayLabel_ then
        return
    end
    ---@type table
    local flow=gameState_==legacyDebugState_ and GameFlow or session_.modules.gameFlow
    dayLabel_:SetText(string.format("第 %d 天 · 时段 %s", flow.GetDay(), flow.GetPhase()))
    if uiRoot_ then
        if not developerMode_ then
            local status=gameState_.GetStatus()
            observedPlayerStatus_=status.status
            local locked=status.status~="new" and status.status~="loaded" and status.status~="migrated"
            if not locked then dismissedPlayerError_=false end
            local errorPanel=uiRoot_:FindById("playerSaveError")
            local retry=uiRoot_:FindById("playerSaveRetry")
            if errorPanel then errorPanel:SetVisible(locked and not dismissedPlayerError_) end
            if retry then retry:SetVisible(locked) end
            if playView_ then playView_.root:SetVisible(not locked) end
        end
        local statusLabel = uiRoot_:FindById("saveStatusLabel") --[[@as Label?]]
        if statusLabel then statusLabel:SetText(DebugPanel.DescribeStatus(gameState_.GetStatus()) .. ledgerStatus_) end
    end
end

-- ============================================================================
-- 事件订阅
-- ============================================================================

function SubscribeToEvents()
    SubscribeToEvent("Update", "HandleUpdate")
    if developerMode_ then SubscribeToEvent("KeyDown", "HandleKeyDown") end
    playListener_=EventBus.OnAny(function()
        RefreshHeader()
    end,"B6/play")

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
    -- 旧调试流程档有非零发货计数却没有订单明细；只能在专用 v1 协调器内读写。
    gameState_=legacyDebugState_
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
    if not developerMode_ and observedPlayerStatus_~=gameState_.GetStatus().status then RefreshHeader() end
    local timeStep = eventData["TimeStep"]:GetFloat()
    DebugPanel.Update(timeStep)
    if playView_ then playView_.Update() end

    -- 首帧布局完成后做一次界面自检（B1），只跑一次
    if developerMode_ and not uiLayoutChecked_ then
        uiFrameCount_ = uiFrameCount_ + 1
        if uiFrameCount_ == 30 then
            uiLayoutChecked_ = true
            SelfTest.CheckUILayout(uiRoot_)
            if b6Request_ ~= "off" then require("debug.B6Evidence").Print(b6Request_, session_.state, uiRoot_) end
            if b2Request_ == "check" then RunB2Checks() end
            if b1Request_ == "write" then
                RunB1RestartCheck(true)
            elseif b1Request_ == "read" then
                RunB1RestartCheck(false)
            elseif b1Request_ == "error" then
                SaveSystem.Save("b1_error_ui", {gameFlow=GameFlow.Serialize(),unknownBusiness={}})
                DebugPanel.SetVisible(true)
                DebugPanel.SetTestSlot("b1_error_ui")
                gameState_=legacyDebugState_
                DebugPanel.LoadProgress("b1_error_ui")
            end
        end
    end
end

---@param _eventType string
---@param eventData KeyDownEventData
function HandleKeyDown(_eventType, eventData)
    if not developerMode_ then return end
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
    if not developerMode_ then return false end
    DebugPanel.SetVisible(true)
    local previous=gameState_
    local result = previous.WithPreservedState(function()
        gameState_=legacyDebugState_
        ---@type boolean, any
        local called,value=pcall(SelfTest.RunB1,{
            gameFlow = GameFlow, saveSystem = SaveSystem,
            loadStartup = LoadProgress, loadDebug = DebugPanel.LoadProgress,
            refresh = function() RefreshHeader(); DebugPanel.Refresh() end,
            getTexts = function()
                if not uiRoot_ or not dayLabel_ then return {header="",panel=""} end
                local panelDay = uiRoot_:FindById("debugDayLabel") --[[@as Label?]]
                return { header = dayLabel_:GetText(), panel = panelDay and panelDay:GetText() or "" }
            end,
        })
        gameState_=previous
        if not called then error(tostring(value),0) end
        return value
    end)
    RefreshHeader()
    DebugPanel.Refresh()
    return result
end

-- 必须先绑定测试槽。B2 内部用真实模块+显式夹具，不给生产 v2 安装假恢复器。
---@return boolean
function RunB2Checks()
    if not developerMode_ then return false end
    DebugPanel.SetTestSlot("b2_debug_flow")
    DebugPanel.SetVisible(true)
    local previous=gameState_
    local ok,result=pcall(function()
        return previous.WithPreservedState(function()
            -- v2 跨天会自动保存；必须在任何真实按钮回调之前绑定隔离协调器的活动槽。
            gameState_=legacyDebugState_
            LoadProgress("b2_debug_flow")
            return SelfTest.RunB2({buttons=function()
                local buttons={}
                for _, id in ipairs({"debugNextDayButton","debugSaveButton","debugLoadButton"}) do
                    local button=assert(uiRoot_):FindById(id)
                    if button then buttons[#buttons+1]=button end
                end
                return buttons
            end})
        end)
    end)
    -- 即使检查失败，后续调试按钮也不能回到生产默认槽。
    gameState_=legacyDebugState_
    RefreshHeader(); DebugPanel.Refresh()
    DebugPanel.Log(ok and result and "B2 模块与隔离联调检查通过" or "B2 检查未完成：" .. tostring(result))
    if not ok then print("[B2] entry ERROR " .. tostring(result)) end
    return ok and result == true
end
