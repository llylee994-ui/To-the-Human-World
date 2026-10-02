local Fixtures = require "debug.fixtures.B1Fixtures"
local Tests = {}
local U = require "core.StateUtil"
local EventBus = require "core.EventBus"

-- 显式调用；只写专用槽，通过真实启动/面板入口观察三个独立问题。
function Tests.RunRecovery(context)
    local flow, save = context.gameFlow, context.saveSystem
    local before = flow.Serialize()
    local checks = {}
    ---@type integer|nil
    local recoveryListener
    local function check(name, actual, expected)
        local passed = actual == expected
        checks[#checks + 1] = passed
        print(string.format("[B1] %s %s actual=%s expected=%s",
            passed and "PASS" or "FAIL", name, tostring(actual), tostring(expected)))
    end
    local ok, err = pcall(function()
        local saved = save.Save(Fixtures.SLOT, { gameFlow = Fixtures.Flow() })
        assert(saved, "B1 fixture save failed")
        context.loadStartup(Fixtures.SLOT)
        check("V1 nested startup day", flow.GetDay(), 5)
        check("V1 stage", flow.GetMainStoryStage(), "b1_fixture")
        flow.Init(Fixtures.Flow())
        check("V2 explicit false", flow.Serialize().canSalvage, false)
        flow.Init({day=5})
        check("V2 absent boolean", flow.Serialize().canSalvage, true)
        local invalid = flow.Init({day=0})
        check("V2 invalid input", invalid.ok, false)
        check("V2 invalid preserves state", flow.GetDay(), 5)
        local restored = flow.Restore(flow.Serialize())
        restored.value.day = 999
        check("V9 flow restore result isolated", flow.GetDay(), 5)
        flow.NextDay()
        local notifications = 0
        local id = EventBus.On("SaveLoaded", function() notifications = notifications + 1 end, 0, "B1")
        recoveryListener = id
        context.loadDebug(Fixtures.SLOT)
        EventBus.Off("SaveLoaded", id)
        recoveryListener = nil
        check("V3 single notification", notifications, 1)
        check("V3 debug load day", flow.GetDay(), 5)
        local texts = context.getTexts()
        check("V3 header day", texts.header:find("第 5 天", 1, true) ~= nil, true)
        check("V3 panel day", texts.panel:find("第 5 天", 1, true) ~= nil, true)
        Tests.RunStorage(check)
        Tests.RunSchema(check)
        require("debug.EconomyTest").Run(check)
        Tests.RunContentLedger(check)
    end)
    if recoveryListener then EventBus.Off("SaveLoaded", recoveryListener) end
    -- 即使旧 Init 尚有 false 缺陷，也将运行前许可单独恢复。
    flow.Init(before)
    flow.SetCanSalvage(before.canSalvage)
    context.refresh()
    if not ok then print("[B1] ERROR " .. tostring(err)) end
    local failed = 0
    for _, passed in ipairs(checks) do if not passed then failed = failed + 1 end end
    print(string.format("[B1] all checks=%d failed=%d runtimeError=%s", #checks, failed, tostring(not ok)))
    return ok and failed == 0
end

-- 只有 economy 来自真实 C1，其他 Envelope 块仍是技术夹具；不安装虚构业务恢复器。
function Tests.RunContentLedger(check)
    local Data = require "data.content"
    local Economy = require "systems.Economy"
    local Save = require "core.SaveSystem"
    local Schema = require "core.SaveSchema"
    local slot = "b1_c1_ledger"
    local e = Economy.New(Data)
    local initial = e.InitialSnapshot()
    assert(initial.ok and e.Restore(initial.value).ok)
    local base = assert(e.GetSnapshot())
    local id = Data.ingredients[1].id
    local uses, reward = {{ingredientId=id,quantity=1}}, {currency=1} -- 技术请求，非首单报酬。
    local planned = e.PlanSettlement(base, uses, {}, reward)
    assert(planned.ok)
    check("C1 settlement repeat", U.Equal(planned, e.PlanSettlement(base, uses, {}, reward)), true)
    check("C1 settlement leaves live", U.Equal(base, e.GetSnapshot()), true)
    local envelope = Fixtures.V2("accepted")
    envelope.contentVersion, envelope.live.economy = Data.contentVersion, planned.value.state
    local options = {contentVersion=Data.contentVersion,synthesisVersion=Data.synthesis.version,economy=e}
    check("C1 ledger in complete test envelope", Schema.ValidateV2(envelope, options).ok, true)
    Save.Delete(slot)
    check("C1 ledger save", Save.Save(slot, envelope, 2), true)
    local loaded, status = Save.New().Load(slot)
    assert(status.status == "loaded" and Schema.ValidateV2(loaded, options).ok)
    check("C1 envelope roundtrip", U.Equal(loaded, envelope), true)
    -- 新模块先计算开局候选，再恢复已消耗库存；开局配置不能覆盖存档值。
    local restored = Economy.New(Data)
    assert(restored.InitialSnapshot().ok and restored.Restore(loaded.live.economy).ok)
    check("C1 saved currency restored", assert(restored.GetSnapshot()).currency, base.currency + reward.currency)
    check("C1 saved quantity restored", assert(restored.GetSnapshot()).ingredients[id], base.ingredients[id] - 1)
    check("C1 no regrant on init query", restored.InitialSnapshot().ok and U.Equal(restored.GetSnapshot(), planned.value.state), true)
    local diskBefore = U.Copy(loaded)
    local shortage = restored.PlanSettlement(assert(restored.GetSnapshot()), {{ingredientId=id,quantity=base.ingredients[id] + 1}}, {}, reward)
    check("C1 shortage preserves state", not shortage.ok and U.Equal(restored.GetSnapshot(), planned.value.state), true)
    check("C1 calculation has no disk writes", U.Equal(Save.New().Load(slot), diskBefore), true)
    Save.Delete(slot)
end

function Tests.RunStorage(check)
    local Save = require "core.SaveSystem"
    local raw = Save.EngineStorage()
    local slot = "b1_faults"
    local old, new = {gameFlow=Fixtures.Flow()}, {gameFlow=Fixtures.Flow()}
    new.gameFlow.day = 9
    local function reset()
        Save.Delete(slot)
        assert(Save.Save(slot, old))
    end
    reset()
    local cyc = {}; cyc.self = cyc
    for _, bad in ipairs({{fn=function() end},cyc,{number=0/0},{number=math.huge},{[2]="hole"}}) do
        local ok, err = Save.Save(slot, bad)
        check("V5 invalid data protected", ok == false and type(err) == "table" and U.Equal(Save.Load(slot), old), true)
    end
    -- 每次从已验证 a 代开始，所有破坏都限制在 b1_faults 的非活动 b 代。
    local modes = {"snapshot_false","snapshot_throw","snapshot_partial","readback_bad","readback_throw",
        "before_commit","commit_partial","commit_full_false","commit_close_throw","after_commit","commit_unreadable"}
    for _, mode in ipairs(modes) do
        reset()
        local active = false
        local io = {
            exists=raw.exists,delete=raw.delete,
            write=function(path, value)
                if path == "save_b1_faults_b.json" then
                    active = true
                    if mode == "snapshot_false" then return false end
                    if mode == "snapshot_throw" then error("injected write open failure") end
                    if mode == "snapshot_partial" then raw.write(path, value:sub(1, #value // 2)); return false end
                elseif path == "save_b1_faults_b.commit" then
                    if mode == "commit_partial" then raw.write(path, value:sub(1, 5)); return false end
                    if mode == "commit_full_false" then raw.write(path, value); return false end
                    if mode == "commit_close_throw" then raw.write(path, value); error("injected close failure after complete marker") end
                end
                return raw.write(path, value)
            end,
            read=function(path)
                if active and path == "save_b1_faults_b.json" then
                    if mode == "readback_bad" then return "bad" end
                    if mode == "readback_throw" then error("injected read failure") end
                end
                if active and path == "save_b1_faults_b.commit" and mode == "commit_unreadable" then error("injected unavailable commit read") end
                return raw.read(path)
            end,
            checkpoint=function(stage)
                if stage == mode then error("injected interruption " .. stage) end
            end,
        }
        local faulty = Save.New(io)
        ---@type boolean, any
        local called, result = pcall(faulty.Save, slot, new)
        local committed = mode == "commit_full_false" or mode == "commit_close_throw" or mode == "after_commit" or mode == "commit_unreadable"
        local restored = Save.New().Load(slot) -- 新 reader，没有沿用写者缓存。
        check("V6 " .. mode .. " restart", U.Equal(restored, committed and new or old), true)
        if mode == "commit_unreadable" then
            check("V6 uncertainty explicit", not called and type(result) == "table" and result.code == "SAVE_COMMIT_UNCERTAIN", true)
            reset(); active = false
            local flow = require "core.GameFlow"
            flow.Restore(new.gameFlow)
            local coordinator = require("core.GameState").New({gameFlow=flow,saveSystem=faulty,eventBus=EventBus,dataReady=true})
            local saved, reason = coordinator.Save(slot)
            check("V6 coordinator uncertainty", saved == false and reason.code == "SAVE_COMMIT_UNCERTAIN", true)
            check("V6 uncertainty locks advance", coordinator.NextDay().ok, false)
            local _, retry = coordinator.Save(slot)
            check("V6 uncertainty locks retry", retry.code, "STATE_LOCKED")
            io.read = raw.read
            local reconciled, info = coordinator.Load(slot)
            check("V6 reconcile committed", info.status == "loaded" and U.Equal(reconciled, new) and coordinator.CanMutate(), true)
        else check("V5/V6 " .. mode .. " return", called and result == committed, true) end
    end
    Save.Delete(slot)
    local _, status = Save.Load(slot)
    check("V4 new", status.status, "new")
    raw.write("save_b1_faults.json", "{broken")
    local original = raw.read("save_b1_faults.json")
    _, status = Save.Load(slot)
    check("V4 corrupt", assert(status).status, "corrupt")
    check("V4 no overwrite corrupt", Save.Save(slot, new), false)
    check("V4 corrupt unchanged", raw.read("save_b1_faults.json"), original)
    raw.write("save_b1_faults.json", '{"schema":999,"data":{}}')
    _, status = Save.Load(slot)
    check("V4 unsupported", assert(status).status, "unsupported")
    Save.Delete(slot)
end

function Tests.RunSchema(check)
    local Save = require "core.SaveSystem"
    local State = require "core.GameState"
    local Schema = require "core.SaveSchema"
    local flow = require "core.GameFlow"
    local economy = require("systems.Economy").New(Fixtures.Content())
    local options = {contentVersion="b1_fixture_v1",synthesisVersion="b1_synthesis_v1",economy=economy,
        gameFlow=flow,saveSystem=Save,eventBus=EventBus,dataReady=true,targetSchema=2}
    local slot = "b1_envelope"
    for _, phase in ipairs({"accepted","brewing","pending"}) do
        local data = Fixtures.V2(phase)
        local valid = Schema.ValidateV2(data, options)
        check("V11 structure " .. phase, valid.ok, true)
        if not valid.ok then print("[B1] schema " .. valid.error.path .. " " .. valid.error.message) end
        assert(valid.ok)
        Save.Delete(slot)
        check("V11 save " .. phase, Save.Save(slot, data, 2), true)
        check("V11 roundtrip " .. phase, U.Equal(Save.New().Load(slot), data), true)
    end
    local data = Fixtures.V2("pending")
    for _, mutate in ipairs({
        function(d) d.currentOrder.baseline = false end,
        function(d) d.currentOrder.baseline.revision = 6 end,
        function(d) d.currentOrder.pending.synthesisVersion = "future" end,
        function(d) d.contentVersion = "future" end,
        function(d) d.currentOrder.pending.rating.stars = 4 end,
        function(d) d.currentOrder.pending.candidateLive.economy.currency = 999 end,
        function(d) d.live.unknown = {} end,
        function(d) d.currentOrder.pending = nil end,
    }) do
        local bad = U.Copy(data); mutate(bad)
        check("V11 invalid snapshot rejected", Schema.ValidateV2(bad, options).ok, false)
    end
    local state = State.New(options)
    local before = flow.Serialize()
    local _, status = state.Load(slot)
    check("V12 missing restorers", status.status, "migration_required")
    check("V12 preserves flow", U.Equal(before, flow.Serialize()), true)
    check("V10 orphan count", state.MigrateV1({gameFlow=Fixtures.Flow()}, Fixtures.V2("accepted")).error.code, "MIGRATION_REQUIRED")
    local zero = Fixtures.Flow(); zero.deliveredOrders = 0
    check("V10 missing initial", state.MigrateV1({gameFlow=zero}, nil).error.code, "MIGRATION_REQUIRED")
    check("V10 valid migration fixture", state.MigrateV1({gameFlow=zero}, Fixtures.V2("accepted")).ok, true)
    -- 恢复器仅是测试替身。中途失败后验证所有已变动块（包括失败块）回滚。
    local holders, adapters, failOnce = {}, {}, true
    local initial = Fixtures.V2("accepted")
    for _, key in ipairs({"gameFlow","letters","wordTokens","economy","world","narrative","orders","currentOrder"}) do
        holders[key] = U.Copy(key == "currentOrder" and initial.currentOrder or initial.live[key])
        adapters[key] = {
            GetSnapshot=function() return U.Copy(holders[key]) end,
            ValidateSnapshot=function(value) return U.Ok(value) end,
            Restore=function(value)
                holders[key] = U.Copy(value)
                if key == "economy" and failOnce then failOnce=false; return U.Fail("TEST_FAILURE", key, "injected") end
                return U.Ok(value)
            end,
        }
    end
    options.adapters = adapters
    local allBefore, notifications = U.Copy(holders), 0
    local id = EventBus.On("SaveLoaded", function() notifications = notifications + 1 end, 0, "B1/schema")
    local coordinator = State.New(options)
    local _, failed = coordinator.Load(slot)
    EventBus.Off("SaveLoaded", id)
    check("V12 restore failure", failed.error.code, "RESTORE_FAILED")
    check("V12 rollback all", U.Equal(holders, allBefore), true)
    check("V12 no success notification", notifications, 0)
    local ready = State.New({gameFlow=flow,saveSystem=Save,eventBus=EventBus,dataReady=false})
    check("V12 config error lock", ready.CanMutate(), false)
    check("V12 config error no save", ready.Save(slot), false)
    check("V12 config error no advance", ready.NextDay().ok, false)
    Save.Delete(slot)
    assert(Save.Save(slot, {gameFlow=Fixtures.Flow(),unknownBusiness={doNotDiscard=true}}))
    local current = State.New({gameFlow=flow,saveSystem=Save,eventBus=EventBus,dataReady=true})
    local actualBefore = flow.Serialize()
    local _, unknown = current.Load(slot)
    check("V12 unknown business rejected", unknown.error.code, "UNKNOWN_FIELD")
    check("V12 unknown state preserved", U.Equal(flow.Serialize(), actualBefore), true)
    check("V12 unknown cannot overwrite", current.Save(slot), false)
    check("V12 unknown disk preserved", Save.Load(slot).unknownBusiness.doNotDiscard, true)
    Save.Delete(slot)
end

function Tests.WriteRestartFixture()
    local Save = require "core.SaveSystem"
    assert(Save.Save("b1_restart_flow", {gameFlow=Fixtures.Flow()}))
    assert(Save.Save("b1_restart_v2", Fixtures.V2("pending"), 2))
    print("[B1] RESTART_WRITTEN flow=5 false / technical ledger=17 / pending text saved; now exit and reopen")
end
function Tests.ReadRestartFixture(load)
    local Save = require "core.SaveSystem"
    local data, status = load("b1_restart_flow")
    print("[B1] RESTART_OBSERVED status=" .. tostring(status.status) .. " day=" .. tostring(data and data.gameFlow and data.gameFlow.day)
        .. " error=" .. tostring(status.error and status.error.code))
    assert(status.status == "loaded" and U.Equal(data.gameFlow, Fixtures.Flow()),
        "测试流程档 b1_restart_flow 缺失、读取失败或内容不符（状态：" .. tostring(status.status) .. "）")
    local pending, info = Save.Load("b1_restart_v2")
    assert(info.schema == 2 and U.Equal(pending, Fixtures.V2("pending")),
        "待确认夹具 b1_restart_v2 缺失、损坏或内容不符（状态：" .. tostring(info.status) .. "）")
    local e = require("systems.Economy").New(Fixtures.Content())
    assert(e.Restore(pending.live.economy).ok and U.Equal(e.GetSnapshot(), Fixtures.Economy()))
    print("[B1] RESTART_READ_PASS flow=5 false / technical ledger=17 / pending identical; business restorers NOT connected")
end
return Tests
