-- 整体存档协调入口。校验 -> 全部恢复 -> 通知；事件不承担状态提交。
local U = require "core.StateUtil"
local Schema = require "core.SaveSchema"
local GameState = {}
local BLOCKS = {"gameFlow","letters","wordTokens","economy","world","narrative","orders","currentOrder"}

function GameState.New(options)
    local api={}
    ---@type table
    local last={status="new"}
    ---@type table<string,any>|nil
    local envelope
    local locked = options.dataReady == false
    local targetSchema = options.targetSchema or 1
    local flow, save = options.gameFlow, options.saveSystem
    ---@type boolean
    local busy=false
    ---@type string|nil
    local activeSlot
    local letters = options.letters or (options.adapters and options.adapters.letters)
    local words = options.wordTokens or (options.adapters and options.adapters.wordTokens)
    local schemaOptions = {contentVersion=options.contentVersion,synthesisVersion=options.synthesisVersion,economy=options.economy}
    if letters and words and type(letters.ResolveSource)=="function" and type(words.PlanCut)=="function" then
        schemaOptions.letters, schemaOptions.wordTokens = letters, words
    end
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
        return Schema.ValidateV2(candidate, schemaOptions)
    end
    local function prepare(data, schema)
        if schema == 1 then return validateV1(data) end
        local valid = Schema.ValidateV2(data, schemaOptions)
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
        if options.order then
            local audited=options.order.ValidateEnvelope(data)
            if not audited.ok then return audited end
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
    function api.CanMutate() return not locked and not busy and options.dataReady ~= false end
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
        if busy then return nil,{status="busy",error=U.Error("COMMAND_BUSY","GameState","候选提交期间禁止嵌套操作")} end
        if last.status=="recovery_required" and (slot or "slot1")~=(activeSlot or "slot1") then
            return nil,{status="recovery_required",error=U.Error("RECOVERY_SLOT_MISMATCH","slot","须读取提交结果不确定的同一存档槽对账")}
        end
        if envelope and envelope.currentOrder and envelope.currentOrder.phase~="accepted" and (slot or "slot1")~=(activeSlot or "slot1") then
            return nil,{status="locked",error=U.Error("ORDER_LOCKED","slot","已有本单基准，只能重新读取同一存档槽")}
        end
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
        if not checked.ok then
            local code=checked.error.code
            local migration=code=="RESTORER_MISSING" or code=="CONTENT_VERSION_MISMATCH" or code=="SYNTHESIS_VERSION_MISMATCH"
            return fail(migration and "migration_required" or "corrupt",checked.error)
        end
        busy=true
        ---@type boolean, any
        local installed, applied = pcall(install, checked.value, schema)
        busy=false
        if not installed then return fail("corrupt", U.Error("RESTORE_FAILED", "data", tostring(applied))) end
        if not applied.ok then return fail("corrupt", applied.error) end
        envelope = U.Copy(checked.value)
        activeSlot = slot
        locked = false
        last = {status=migrated and "migrated" or status.status,schema=schema}
        busy=true
        local notified,problem=pcall(options.eventBus.Emit,"SaveLoaded",U.Copy(last))
        busy=false
        if not notified then last.notificationError=U.Error("EVENT_FAILED","SaveLoaded",tostring(problem)) end
        return U.Copy(checked.value), U.Copy(last)
    end
    -- 恢复按钮必须对账当前槽，不能把省略参数的 Load（默认 slot1）当作重载。
    function api.ReloadCurrent() return api.Load(activeSlot) end
    function api.Save(slot)
        if not api.CanMutate() then return false, U.Error("STATE_LOCKED", "GameState", "请先排除配置或读档错误") end
        busy=true
        ---@return boolean, table?
        local function saveSnapshot()
            local candidate=api.GetSnapshot()
            local checked=prepare(candidate,targetSchema)
            if not checked.ok then return false,checked.error end
            local called,ok,err=pcall(save.Save,slot,candidate,targetSchema)
            if not called then
                local reason=type(ok)=="table" and ok or U.Error("SAVE_UNEXPECTED","save",tostring(ok))
                activeSlot=slot; fail("recovery_required",reason)
                return false,reason
            end
            if not ok then return false,err end
            envelope=U.Copy(candidate)
            return true,nil
        end
        local ran,result,problem=pcall(saveSnapshot)
        busy=false
        if not ran then return false,U.Error("SAVE_FAILED","GameState",tostring(result)) end
        return result,problem
    end
    local function commit(candidate,value,events)
        local valid=prepare(candidate,2)
        if not valid.ok then return valid end
        local called,ok,err=pcall(save.Save,activeSlot,valid.value,2)
        if not called then
            local reason=type(ok)=="table" and ok or U.Error("SAVE_UNEXPECTED","save",tostring(ok))
            fail("recovery_required",reason)
            return {ok=false,error=reason}
        end
        if not ok then return {ok=false,error=err} end
        local applied,result=pcall(install,valid.value,2)
        if not applied or not result.ok then
            local reason=U.Error("COMMIT_RECOVERY_REQUIRED","restore","存档已提交但安装失败，必须读取同一存档对账",{committed=true,slot=activeSlot or "slot1"})
            fail("recovery_required",reason)
            return {ok=false,error=reason}
        end
        envelope=U.Copy(valid.value); last={status="loaded",schema=2}
        value=U.Copy(value); value.revision=candidate.revision
        local errors={}
        for _,event in ipairs(events or {}) do
            local name=type(event)=="table" and event.name or event
            local payload=type(event)=="table" and U.Copy(event.payload) or U.Copy(value)
            payload.revision=candidate.revision
            local notified,problem=pcall(options.eventBus.Emit,name,payload)
            if not notified then errors[#errors+1]=U.Error("EVENT_FAILED",name,tostring(problem)) end
        end
        if #errors>0 then value.notificationErrors=errors end
        return U.Ok(value)
    end
    function api.CheckAction(name)
        local enabled,code,message=true,"",""
        local phase=envelope and envelope.currentOrder and envelope.currentOrder.phase or "idle"
        if not api.CanMutate() then enabled,code,message=false,"STATE_LOCKED","请先读取存档排除配置或提交错误"
        elseif name=="CancelBrew" then
            local order=envelope and envelope.currentOrder
            if not order then enabled,code,message=false,"INVALID_ORDER_STATE","请先接单"
            elseif order.nextAttemptSerial~=1 or order.lastResetTransactionId~=false or phase=="pending" then
                enabled,code,message=false,"ORDER_LOCKED","已有后续记录，只能确认或按原基准重置，不能返回剪词准备"
            end
        elseif phase=="brewing" or phase=="pending" then
            local allowed={GetView=true,Save=true,BeginBrew=true,Preview=phase=="brewing",Confirm=phase=="pending",Reset=true}
            if not allowed[name] then enabled,code,message=false,"ORDER_LOCKED","先确认或重置当前订单，不能改变首次投料基准" end
        elseif name=="Shop" or name=="ClaimAttachment" then enabled,code,message=false,"NOT_IMPLEMENTED","该操作尚未接入"
        elseif (name=="Confirm" or name=="Reset" or name=="Preview") or (name=="BeginBrew" and phase=="idle") or (name=="Accept" and phase~="idle") then
            enabled,code,message=false,"INVALID_ORDER_STATE","当前阶段不支持此操作"
        end
        return {enabled=enabled,reasonCode=code,message=message}
    end
    function api.OrderCommand(kind,request)
        if busy then return U.Fail("COMMAND_BUSY","GameState","候选提交期间禁止嵌套命令") end
        if not api.CanMutate() then return U.Fail("STATE_LOCKED","GameState","请先排除配置或提交错误") end
        if targetSchema~=2 or not options.order then return U.Fail("RESTORER_MISSING","Order","订单恢复器未接入") end
        busy=true
        local called,result=pcall(function()
            local current=api.GetSnapshot()
            local planned=options.order.PlanCommand(kind,current,request)
            if not planned.ok then return planned end
            if not planned.value.changed then return U.Ok(planned.value.value) end
            return commit(planned.value.data,planned.value.value,planned.value.events)
        end)
        busy=false
        if not called then return U.Fail("COMMAND_FAILED","Order",type(result)=="table" and result.message or tostring(result)) end
        return result
    end
    function api.NextDay()
        if not api.CanMutate() then return U.Fail("STATE_LOCKED", "GameState", "当前禁止推进") end
        if targetSchema==2 and envelope and envelope.currentOrder~=false and envelope.currentOrder.phase~="accepted" then
            return U.Fail("ORDER_LOCKED","currentOrder.phase","已建立炼药基准或待确认，禁止跨天")
        end
        if targetSchema==2 then
            busy=true
            local called,result=pcall(function()
                local candidate=api.GetSnapshot()
                local before=candidate.live.gameFlow.day
                candidate.live.gameFlow.day=before+1; candidate.live.gameFlow.phase="day"; candidate.live.gameFlow.canSalvage=true
                candidate.revision=candidate.revision+1
                return commit(candidate,{day=before+1},{{name="DayEnded",payload={day=before}},{name="DayStarted",payload={day=before+1}}})
            end)
            busy=false
            if not called then return U.Fail("COMMAND_FAILED","NextDay",tostring(result)) end
            return result
        end
        flow.NextDay()
        return U.Ok(flow.Serialize())
    end
    -- B2 命令仅用于完整 v2；value={letterInstanceId,tokenId?,source?,changed,revision,notificationErrors?}。
    -- options.narrative.FindAvailable(liveSnapshot, conditions) -> Result<letterId[]>，B4 接真实筛选器。
    local function command(kind,request)
        if busy then return U.Fail("COMMAND_BUSY","GameState","候选提交期间禁止嵌套操作") end
        if not api.CanMutate() then return U.Fail("STATE_LOCKED","GameState","请先排除配置、读档或提交错误") end
        if targetSchema ~= 2 then return U.Fail("V2_REQUIRED","schema","完整 v2 尚未启用，不能保存信件或词条") end
        if not envelope or not schemaOptions.letters or not schemaOptions.wordTokens then return U.Fail("RESTORER_MISSING","letters/wordTokens","真实信件和词条恢复器尚未接入") end
        busy = true
        local called,result = pcall(function()
            local valid = U.Validate(request)
            if not valid.ok then return valid end
            local allowed = kind=="receive" and {letterId=true} or kind=="read" and {letterInstanceId=true} or {letterInstanceId=true,spanId=true}
            valid = U.Keys(request,allowed,"request")
            if not valid.ok then return valid end
            local current = api.GetSnapshot()
            valid = prepare(current,2)
            if not valid.ok then return valid end
            if current.currentOrder ~= false and current.currentOrder.phase ~= "accepted" then
                return U.Fail("ORDER_LOCKED","currentOrder.phase","已建立炼药基准或待确认，禁止改变信件和词条",{phase=current.currentOrder.phase})
            end
            local candidate, planned, token = U.Copy(current), nil, nil
            if kind=="receive" then planned=letters.PlanReceive(current.live.letters,request.letterId)
            elseif kind=="read" then planned=letters.PlanMarkRead(current.live.letters,request.letterInstanceId)
            else planned=letters.PlanMarkCut(current.live.letters,request.letterInstanceId,request.spanId) end
            if not planned.ok then return planned end
            if kind=="cut" then
                token=words.PlanCut(current.live.wordTokens,planned.value.source)
                if not token.ok then return token end
                candidate.live.wordTokens=token.value.state
            end
            local value = {letterInstanceId=planned.value.instanceId,changed=planned.value.changed,revision=current.revision}
            if token then value.tokenId=token.value.tokenId; value.source=U.Copy(token.value.source) end
            if not value.changed then return U.Ok(value) end
            if kind=="receive" then
                if current.live.gameFlow.canSalvage ~= true or current.live.gameFlow.phase ~= "day" then return U.Fail("SALVAGE_DISABLED","gameFlow","当前不能打捞") end
                if not options.narrative or type(options.narrative.FindAvailable) ~= "function" then return U.Fail("RESTORER_MISSING","Narrative.FindAvailable","可用信件筛选尚未接入") end
                local available = options.narrative.FindAvailable(U.Copy(current.live),U.Copy(options.conditions))
                if type(available)~="table" or not available.ok then return type(available)=="table" and available or U.Fail("VALIDATOR_FAILED","Narrative.FindAvailable","筛选器未返回 Result") end
                if not U.Array(available.value) then return U.Fail("VALIDATOR_FAILED","Narrative.FindAvailable","可用信列表须为稠密数组") end
                local found=false
                for _, id in ipairs(available.value) do if id==request.letterId then found=true end end
                if not found then return U.Fail("LETTER_NOT_AVAILABLE","letterId","该信尚未满足出现条件") end
            end
            candidate.live.letters=planned.value.state
            candidate.revision=current.revision+1
            if not U.Integer(candidate.revision) then return U.Fail("STATE_INVALID","revision","版本计数溢出") end
            valid=prepare(candidate,2)
            if not valid.ok then return valid end
            local saved,ok,err=pcall(save.Save,activeSlot,candidate,2)
            if not saved then
                local reason=type(ok)=="table" and ok or U.Error("SAVE_UNEXPECTED","save",tostring(ok))
                fail("recovery_required",reason)
                return {ok=false,error=reason}
            end
            if not ok then return {ok=false,error=err} end
            local installed,applied=pcall(install,valid.value,2)
            if not installed or not applied.ok then
                local reason=U.Error("COMMIT_RECOVERY_REQUIRED","restore","完整候选已提交，安装失败；必须读取同一存档对账",{committed=true,slot=activeSlot or "slot1"})
                fail("recovery_required",reason)
                return {ok=false,error=reason}
            end
            envelope=U.Copy(valid.value)
            last={status="loaded",schema=2}
            value.revision=candidate.revision
            local events=kind=="receive" and {"LetterReceived"} or kind=="read" and {"LetterRead"} or {"WordCut","WordStored"}
            local notifications={}
            for _, name in ipairs(events) do
                local notified,problem=pcall(options.eventBus.Emit,name,U.Copy(value))
                if not notified then notifications[#notifications+1]=U.Error("EVENT_FAILED",name,tostring(problem)) end
            end
            if #notifications>0 then value.notificationErrors=notifications end
            return U.Ok(value)
        end)
        busy=false
        if not called then return U.Fail("COMMAND_FAILED","GameState",tostring(result)) end
        return result
    end
    function api.ReceiveLetter(request) return command("receive",request) end
    function api.ReadLetter(request) return command("read",request) end
    function api.CutWord(request) return command("cut",request) end
    -- 尚无商店/领附件实现；即使未来 UI 接错入口，也不允许绕过本单门禁。
    function api.Shop(_request)
        local action=api.CheckAction("Shop")
        return U.Fail(action.reasonCode,"Shop",action.message)
    end
    function api.ClaimAttachment(_request)
        local action=api.CheckAction("ClaimAttachment")
        return U.Fail(action.reasonCode,"ClaimAttachment",action.message)
    end
    -- 仅调试专项使用：连同协调器的锁定/状态一起恢复，不能让测试解锁真实坏档。
    function api.WithPreservedState(callback)
        local before, oldEnvelope, oldLast, oldLocked, oldSlot = api.GetSnapshot(), U.Copy(envelope), U.Copy(last), locked, activeSlot
        local called, result = pcall(callback)
        local restored = install(before, targetSchema)
        envelope, last, locked = oldEnvelope, oldLast, oldLocked
        activeSlot=oldSlot
        if not restored.ok then locked = true; error(restored.error, 0) end
        if not called then error(result, 0) end
        return result
    end
    return api
end
return GameState
