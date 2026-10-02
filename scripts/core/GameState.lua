-- 整体存档协调入口。校验 -> 全部恢复 -> 通知；事件不承担状态提交。
local U = require "core.StateUtil"
local Schema = require "core.SaveSchema"
local GameState = {}
local BLOCKS = {"gameFlow","letters","wordTokens","economy","world","narrative","orders","currentOrder"}

function GameState.New(options)
    local api, last, envelope = {}, {status="new"}, nil
    local locked = options.dataReady == false
    local targetSchema = options.targetSchema or 1
    local flow, save = options.gameFlow, options.saveSystem
    local function fail(status, err)
        last = {status=status,error=err}; locked = true
        return nil, U.Copy(last)
    end
    local function validateV1(data)
        local result = U.Keys(data, {gameFlow=true}, "data")
        if not result.ok then return result end
        if type(data.gameFlow) ~= "table" then return U.Fail("STATE_INVALID", "gameFlow", "缺少流程子表") end
        result = flow.ValidateSnapshot(data.gameFlow)
        if not result.ok then return result end
        return U.Ok({gameFlow=result.value})
    end
    function api.MigrateV1(data, initial)
        local valid = validateV1(data)
        if not valid.ok then return valid end
        if valid.value.gameFlow.deliveredOrders ~= 0 then
            return U.Fail("MIGRATION_REQUIRED", "gameFlow.deliveredOrders", "旧档有发货计数但没有明细，保留原档等待迁移")
        end
        if type(initial) ~= "table" then return U.Fail("MIGRATION_REQUIRED", "initialState", "缺少完整、已校验的内容初态") end
        local candidate = U.Copy(initial)
        if type(candidate.live) ~= "table" then return U.Fail("MIGRATION_REQUIRED", "initialState.live", "缺少完整初态") end
        candidate.live.gameFlow = valid.value.gameFlow
        return Schema.ValidateV2(candidate, options)
    end
    local function prepare(data, schema)
        if schema == 1 then return validateV1(data) end
        local valid = Schema.ValidateV2(data, options)
        if not valid.ok then return valid end
        for _, key in ipairs(BLOCKS) do
            local adapter = options.adapters and options.adapters[key]
            if not adapter or type(adapter.ValidateSnapshot) ~= "function" or type(adapter.Restore) ~= "function" or type(adapter.GetSnapshot) ~= "function" then
                return U.Fail("RESTORER_MISSING", key, "真实模块恢复器尚未接入，禁止部分恢复")
            end
            local value = data.live[key]
            if key == "currentOrder" then value = data.currentOrder end
            local called, checked = pcall(adapter.ValidateSnapshot, U.Copy(value))
            if not called or type(checked) ~= "table" then return U.Fail("VALIDATOR_FAILED", key, "模块校验器异常") end
            if not checked.ok then return checked end
        end
        return valid
    end
    local function install(data, schema)
        if schema == 1 then return flow.Restore(data.gameFlow) end
        local before, installed = {}, {}
        for _, key in ipairs(BLOCKS) do before[key] = options.adapters[key].GetSnapshot() end
        for _, key in ipairs(BLOCKS) do
            local value = data.live[key]
            if key == "currentOrder" then value = data.currentOrder end
            installed[#installed + 1] = key -- 失败的恢复器也可能已变更，须回滚它。
            local called, result = pcall(options.adapters[key].Restore, U.Copy(value))
            if not called or type(result) ~= "table" or not result.ok then
                local rolledBack = true
                for i = #installed, 1, -1 do
                    local name = installed[i]
                    local restored, response = pcall(options.adapters[name].Restore, U.Copy(before[name]))
                    rolledBack = rolledBack and restored and type(response) == "table" and response.ok
                end
                return U.Fail(rolledBack and "RESTORE_FAILED" or "ROLLBACK_FAILED", key, "恢复失败，已尝试回滚全部已安装模块", {rolledBack=rolledBack})
            end
        end
        return U.Ok(data)
    end
    function api.CanMutate() return not locked and options.dataReady ~= false end
    function api.GetStatus() return U.Copy(last) end
    function api.GetSnapshot()
        if targetSchema == 1 then return {gameFlow=flow.Serialize()} end
        if not envelope then return nil end
        local result = U.Copy(envelope)
        for _, key in ipairs(BLOCKS) do
            local value = options.adapters[key].GetSnapshot()
            if key == "currentOrder" then result.currentOrder = value else result.live[key] = value end
        end
        return result
    end
    function api.Load(slot)
        if options.dataReady == false then
            return fail("config_error", options.dataError or U.Error("CONFIG_INVALID", "Data.Load", "内容校验失败，禁止写入和推进"))
        end
        local data, status = save.Load(slot)
        if status.status ~= "loaded" and status.status ~= "new" then return fail(status.status, status.error) end
        local schema, migrated = status.schema, false
        if status.status == "new" then
            if targetSchema == 1 then data = {gameFlow=flow.ValidateSnapshot(nil).value}
            elseif options.initialState then data = U.Copy(options.initialState); schema = 2
            else return fail("migration_required", U.Error("CONFIG_MISSING", "initialState", "缺少完整开局配置")) end
        elseif schema == 1 and targetSchema == 2 then
            local result = api.MigrateV1(data, options.initialState)
            if not result.ok then return fail("migration_required", result.error) end
            data, schema, migrated = result.value, 2, true
        elseif schema ~= targetSchema then
            return fail("migration_required", U.Error("RESTORER_MISSING", "schema", "完整 v2 运行恢复尚未启用，保留原档"))
        end
        ---@type boolean, any
        local prepared, checked = pcall(prepare, data, schema)
        if not prepared then return fail("corrupt", U.Error("VALIDATOR_FAILED", "data", tostring(checked))) end
        if not checked.ok then return fail(checked.error.code == "RESTORER_MISSING" and "migration_required" or "corrupt", checked.error) end
        ---@type boolean, any
        local installed, applied = pcall(install, checked.value, schema)
        if not installed then return fail("corrupt", U.Error("RESTORE_FAILED", "data", tostring(applied))) end
        if not applied.ok then return fail("corrupt", applied.error) end
        envelope = U.Copy(checked.value)
        locked = false
        last = {status=migrated and "migrated" or status.status,schema=schema}
        options.eventBus.Emit("SaveLoaded", U.Copy(last))
        return U.Copy(checked.value), U.Copy(last)
    end
    function api.Save(slot)
        if not api.CanMutate() then return false, U.Error("STATE_LOCKED", "GameState", "请先排除配置或读档错误") end
        local candidate = api.GetSnapshot()
        -- 保存现有快照不制造一次业务变更。B5 提交候选时负责推进 revision/基准。
        local checked = prepare(candidate, targetSchema)
        if not checked.ok then return false, checked.error end
        local called, ok, err = pcall(save.Save, slot, candidate, targetSchema)
        if not called then
            local reason = type(ok) == "table" and ok or U.Error("SAVE_UNEXPECTED", "save", tostring(ok))
            fail("recovery_required", reason)
            return false, reason -- code 明确表示未知结果；所有推进已锁住，必须读档对账。
        end
        if not ok then return false, err end
        envelope = U.Copy(candidate)
        return true
    end
    function api.NextDay()
        if not api.CanMutate() then return U.Fail("STATE_LOCKED", "GameState", "当前禁止推进") end
        flow.NextDay()
        return U.Ok(flow.Serialize())
    end
    -- 仅调试专项使用：连同协调器的锁定/状态一起恢复，不能让测试解锁真实坏档。
    function api.WithPreservedState(callback)
        local before, oldEnvelope, oldLast, oldLocked = api.GetSnapshot(), U.Copy(envelope), U.Copy(last), locked
        local called, result = pcall(callback)
        local restored = install(before, targetSchema)
        envelope, last, locked = oldEnvelope, oldLast, oldLocked
        if not restored.ok then locked = true; error(restored.error, 0) end
        if not called then error(result, 0) end
        return result
    end
    return api
end
return GameState
