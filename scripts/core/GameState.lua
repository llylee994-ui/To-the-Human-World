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
    local schemaOptions = {content=options.content,contentVersion=options.contentVersion,synthesisVersion=options.synthesisVersion,economy=options.economy,salvageDailyLimit=options.salvageDailyLimit}
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
        local valid
        if schema==4 then valid=Schema.ValidateV4(data,schemaOptions)
        elseif schema==3 then valid=Schema.ValidateV3(data,schemaOptions)
        elseif schema==2 then valid=Schema.ValidateV2(data,schemaOptions)
        else return U.Fail("SAVE_UNSUPPORTED","schema","不支持的结构版本") end
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
        activeSlot=slot -- 首次读取失败也必须记住该槽，恢复按钮不能退到 slot1。
        local data, status = save.Load(slot)
        if status.status ~= "loaded" and status.status ~= "new" then return fail(status.status, status.error) end
        local schema, migrated = status.schema, false
        if status.status == "new" then
            if targetSchema == 1 then data = {gameFlow=flow.ValidateSnapshot(nil).value}
            elseif options.initialState then data = U.Copy(options.initialState); schema = targetSchema
            else return fail("migration_required", U.Error("CONFIG_MISSING", "initialState", "缺少完整开局配置")) end
        elseif targetSchema==4 and schema==3 then
            local result=require("core.SaveMigrations").ToV4(data,options.content,options.salvageDailyLimit)
            if not result.ok then return fail("migration_required",result.error) end
            data,schema,migrated=result.value,4,true
        elseif targetSchema==3 and (schema==1 or schema==2) then
            local result=require("core.SaveMigrations").ToV3(data,schema,options.content,options.salvageDailyLimit,options.initialState)
            if not result.ok then return fail("migration_required",result.error) end
            data,schema,migrated=result.value,3,true
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
        if migrated and (targetSchema==3 or targetSchema==4) then
            activeSlot=slot -- 失败后重试仍绑定本次迁移槽，不退回默认槽。
            busy=true
            local called,saved,problem=pcall(save.Save,slot,checked.value,targetSchema)
            busy=false
            if not called then
                activeSlot=slot
                return fail("recovery_required",type(saved)=="table" and saved or U.Error("SAVE_UNEXPECTED","migration",tostring(saved)))
            end
            if not saved then return fail("migration_required",problem) end
        end
        busy=true
        ---@type boolean, any
        local installed, applied = pcall(install, checked.value, schema)
        busy=false
        if not installed then return fail(migrated and "recovery_required" or "corrupt", U.Error("RESTORE_FAILED", "data", tostring(applied))) end
        if not applied.ok then return fail(migrated and "recovery_required" or "corrupt", applied.error) end
        envelope = U.Copy(checked.value)
        activeSlot = slot
        locked = false
        last = {status=migrated and "migrated" or status.status,schema=schema}
        if migrated and schema==3 then last.migrationNotice="旧档已升级；无正文的旧试做不补历史，旧选料需重选，今日捕捞额度保守用尽，明日恢复。" end
        if migrated and schema==4 then last.migrationNotice="同内容存档已升级；家居流水、草稿和试做记录已保留。" end
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
        local valid=prepare(candidate,targetSchema)
        if not valid.ok then return valid end
        local called,ok,err=pcall(save.Save,activeSlot,valid.value,targetSchema)
        if not called then
            local reason=type(ok)=="table" and ok or U.Error("SAVE_UNEXPECTED","save",tostring(ok))
            fail("recovery_required",reason)
            return {ok=false,error=reason}
        end
        if not ok then return {ok=false,error=err} end
        local applied,result=pcall(install,valid.value,targetSchema)
        if not applied or not result.ok then
            local reason=U.Error("COMMIT_RECOVERY_REQUIRED","restore","存档已提交但安装失败，必须读取同一存档对账",{committed=true,slot=activeSlot or "slot1"})
            fail("recovery_required",reason)
            return {ok=false,error=reason}
        end
        envelope=U.Copy(valid.value); last={status="loaded",schema=targetSchema}
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
    local function releaseGate(data,name)
        if targetSchema~=4 then return U.Ok(true) end
        if not data or not data.chapter then return U.Fail("STATE_NOT_READY","chapter","请先读取首发存档") end
        local called,result=pcall(function() return require("systems.ReleaseCoordinator").New(options.content).GetAction(data,name) end)
        if not called then return U.Fail("CONFIG_INVALID","release",tostring(result)) end
        return result
    end
    function api.CheckAction(name)
        if targetSchema==4 and envelope and api.CanMutate() then
            local gate=releaseGate(envelope,name)
            if not gate.ok then return {enabled=false,reasonCode=gate.error.code,message=gate.error.message} end
        end
        local enabled,code,message=true,"",""
        local phase=envelope and envelope.currentOrder and envelope.currentOrder.phase or "idle"
        if not api.CanMutate() then enabled,code,message=false,"STATE_LOCKED","请先读取存档排除配置或提交错误"
        elseif name=="PurchaseFurniture" and (targetSchema<2 or options.furnitureEnabled~=true) then enabled,code,message=false,"NOT_IMPLEMENTED","家具商店尚未接入"
        elseif name=="PurchaseHomeItem" and (targetSchema~=4 or not options.content or not options.content.release) then enabled,code,message=false,"NOT_IMPLEMENTED","首发采购账尚未接入"
        elseif (targetSchema==3 or targetSchema==4) then
            local order=envelope and envelope.currentOrder
            if phase=="pending" and not ({GetView=true,Save=true,Preview=true,Confirm=true,Reset=true})[name] then
                enabled,code,message=false,"ORDER_LOCKED","请先发货或重置本次结果"
            elseif name=="BeginBrew" or name=="CancelBrew" then enabled,code,message=false,"DEPRECATED_COMMAND","返回桌前仅导航；选料请更新草稿"
            elseif name=="ClaimAttachment" or (name=="Shop" and options.shopEnabled~=true) then enabled,code,message=false,"NOT_IMPLEMENTED","操作尚未接入"
            elseif name=="NextDay" and order and not require("systems.RecipeDraft").IsEmpty(order.draft) then enabled,code,message=false,"DRAFT_NOT_EMPTY","请先清空投料再跨天"
            elseif targetSchema==4 and (name=="PurchaseHomeItem" or name=="PurchaseFurniture") and order and not require("systems.RecipeDraft").IsEmpty(order.draft) then enabled,code,message=false,"DRAFT_NOT_EMPTY","请先清空投料再购置家居"
            elseif (name=="Confirm" and phase~="pending") or ((name=="Preview" or name=="UpdateDraft" or name=="Reset") and phase=="idle") or (name=="Accept" and phase~="idle") then
                enabled,code,message=false,"INVALID_ORDER_STATE","当前阶段不支持此操作"
            end
        elseif name=="CancelBrew" then
            local order=envelope and envelope.currentOrder
            if not order then enabled,code,message=false,"INVALID_ORDER_STATE","请先接单"
            elseif order.nextAttemptSerial~=1 or order.lastResetTransactionId~=false or phase=="pending" then
                enabled,code,message=false,"ORDER_LOCKED","已有后续记录，只能确认或按原基准重置，不能返回剪词准备"
            end
        elseif phase=="brewing" or phase=="pending" then
            local allowed={GetView=true,Save=true,BeginBrew=true,Preview=phase=="brewing",Confirm=phase=="pending",Reset=true}
            if not allowed[name] then enabled,code,message=false,"ORDER_LOCKED","先确认或重置当前订单，不能改变首次投料基准" end
        elseif name=="ClaimAttachment" or (name=="Shop" and options.shopEnabled~=true) then enabled,code,message=false,"NOT_IMPLEMENTED","该操作尚未接入"
        elseif (name=="Confirm" or name=="Reset" or name=="Preview") or (name=="BeginBrew" and phase=="idle") or (name=="Accept" and phase~="idle") then
            enabled,code,message=false,"INVALID_ORDER_STATE","当前阶段不支持此操作"
        end
        return {enabled=enabled,reasonCode=code,message=message}
    end
    function api.OrderCommand(kind,request)
        if busy then return U.Fail("COMMAND_BUSY","GameState","候选提交期间禁止嵌套命令") end
        if not api.CanMutate() then return U.Fail("STATE_LOCKED","GameState","请先排除配置或提交错误") end
        if targetSchema<2 or not options.order then return U.Fail("RESTORER_MISSING","Order","订单恢复器未接入") end
        local gate=releaseGate(api.GetSnapshot(),kind);if not gate.ok then return gate end
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
        local gate=releaseGate(api.GetSnapshot(),"NextDay");if not gate.ok then return gate end
        if targetSchema>=2 and envelope and envelope.currentOrder~=false and envelope.currentOrder.phase~="accepted" then
            return U.Fail("ORDER_LOCKED","currentOrder.phase","已建立炼药基准或待确认，禁止跨天")
        end
        if (targetSchema==3 or targetSchema==4) and envelope and envelope.currentOrder and not require("systems.RecipeDraft").IsEmpty(envelope.currentOrder.draft) then
            return U.Fail("DRAFT_NOT_EMPTY","draft","请先清空投料再跨天")
        end
        if targetSchema==4 and envelope.live.gameFlow.day>=options.content.release.finalDay then return api.BeginClosing({expectedRevision=envelope.revision}) end
        if targetSchema>=2 then
            busy=true
            local called,result=pcall(function()
                local candidate=api.GetSnapshot()
                local before=candidate.live.gameFlow.day
                candidate.live.gameFlow.day=before+1; candidate.live.gameFlow.phase="day"; candidate.live.gameFlow.canSalvage=true
                if (targetSchema==3 or targetSchema==4) then candidate.live.gameFlow.salvageUsedToday=0 end
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
        local name=kind=="receive" and "ReceiveLetter" or kind=="read" and "ReadLetter" or "CutWord"
        local gate=releaseGate(api.GetSnapshot(),name);if not gate.ok then return gate end
        if targetSchema < 2 then return U.Fail("V2_REQUIRED","schema","完整 v2 尚未启用，不能保存信件或词条") end
        if not envelope or not schemaOptions.letters or not schemaOptions.wordTokens then return U.Fail("RESTORER_MISSING","letters/wordTokens","真实信件和词条恢复器尚未接入") end
        busy = true
        local called,result = pcall(function()
            local valid = U.Validate(request)
            if not valid.ok then return valid end
            local allowed = kind=="receive" and {letterId=true} or kind=="read" and {letterInstanceId=true} or {letterInstanceId=true,spanId=true}
            valid = U.Keys(request,allowed,"request")
            if not valid.ok then return valid end
            local current = api.GetSnapshot()
            valid = prepare(current,targetSchema)
            if not valid.ok then return valid end
            if current.currentOrder ~= false and current.currentOrder.phase ~= "accepted" then
                return U.Fail("ORDER_LOCKED","currentOrder.phase","已建立炼药基准或待确认，禁止改变信件和词条",{phase=current.currentOrder.phase})
            end
            if targetSchema==4 then
                valid=require("systems.ReleaseCoordinator").New(options.content).CheckPreparationRequest(current,kind,request)
                if not valid.ok then return valid end
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
            if kind=="receive" and (targetSchema==3 or targetSchema==4) then
                candidate.live.gameFlow.salvageUsedToday=current.live.gameFlow.salvageUsedToday+1
                candidate.live.gameFlow.canSalvage=candidate.live.gameFlow.salvageUsedToday<options.salvageDailyLimit and candidate.live.gameFlow.phase=="day"
            end
            candidate.live.letters=planned.value.state
            candidate.revision=current.revision+1
            if targetSchema==4 then require("systems.ReleaseCoordinator").New(options.content).AfterPreparation(candidate) end
            if not U.Integer(candidate.revision) then return U.Fail("STATE_INVALID","revision","版本计数溢出") end
            valid=prepare(candidate,targetSchema)
            if not valid.ok then return valid end
            local saved,ok,err=pcall(save.Save,activeSlot,candidate,targetSchema)
            if not saved then
                local reason=type(ok)=="table" and ok or U.Error("SAVE_UNEXPECTED","save",tostring(ok))
                fail("recovery_required",reason)
                return {ok=false,error=reason}
            end
            if not ok then return {ok=false,error=err} end
            local installed,applied=pcall(install,valid.value,targetSchema)
            if not installed or not applied.ok then
                local reason=U.Error("COMMIT_RECOVERY_REQUIRED","restore","完整候选已提交，安装失败；必须读取同一存档对账",{committed=true,slot=activeSlot or "slot1"})
                fail("recovery_required",reason)
                return {ok=false,error=reason}
            end
            envelope=U.Copy(valid.value)
            last={status="loaded",schema=targetSchema}
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
    -- 购买与订单沿用同一个完整存档提交协议，基准建立后禁止购物。
    function api.Shop(request)
        local action=api.CheckAction("Shop")
        if not action.enabled then return U.Fail(action.reasonCode,"Shop",action.message) end
        if targetSchema<2 or not options.economy or not options.economy.PlanPurchase then return U.Fail("NOT_IMPLEMENTED","Shop","商店账本尚未接入") end
        busy=true
        local called,result=pcall(function()
            local current=api.GetSnapshot()
            local valid=prepare(current,targetSchema)
            if not valid.ok then return valid end
            local planned=options.economy.PlanPurchase(current.live.economy,request,current.live.gameFlow)
            if not planned.ok then return planned end
            local candidate=U.Copy(current)
            candidate.live.economy=planned.value.state
            candidate.revision=candidate.revision+1
            return commit(candidate,{ingredientId=planned.value.ingredientId,quantity=planned.value.quantity,cost=planned.value.cost},{"IngredientPurchased"})
        end)
        busy=false
        if not called then return U.Fail("COMMAND_FAILED","Shop",tostring(result)) end
        return result
    end
    function api.ClaimAttachment(_request)
        local action=api.CheckAction("ClaimAttachment")
        return U.Fail(action.reasonCode,"ClaimAttachment",action.message)
    end
    -- 家具只改变经济账本；正式扣款、所有权和流水在同一次整档提交中安装。
    function api.PurchaseHomeItem(request)
        if busy then return U.Fail("COMMAND_BUSY","GameState","候选提交期间禁止嵌套命令") end
        local action=api.CheckAction("PurchaseHomeItem")
        if not action.enabled then return U.Fail(action.reasonCode,"PurchaseHomeItem",action.message) end
        busy=true
        local called,result=pcall(function()
            local current=api.GetSnapshot();local valid=prepare(current,targetSchema)
            if not valid.ok then return valid end
            local context={day=current.live.gameFlow.day,deliveredOrders=current.live.gameFlow.deliveredOrders,revision=current.revision,kind="home"}
            local planned=require("systems.ReleaseLedger").New(options.content).PlanPurchase(current.live.economy,request,context)
            if not planned.ok then return planned end
            local value=planned.value --[[@as table]]
            local response={itemId=value.itemId,furnitureId=value.itemId,cost=value.cost,currency=value.state.currency,owned=true,
                transactionId=value.transactionId,alreadyPurchased=value.alreadyPurchased}
            if value.alreadyPurchased then return U.Ok(response) end
            local candidate=U.Copy(current);candidate.live.economy=value.state;candidate.revision=candidate.revision+1
            return commit(candidate,response,{"FurniturePurchased","MoneyChanged"})
        end)
        busy=false
        if not called then return U.Fail("COMMAND_FAILED","PurchaseHomeItem",tostring(result)) end
        return result
    end
    function api.PurchaseFurniture(request)
        if targetSchema==4 then
            local valid=U.Keys(request,{furnitureId=true},"furniture.request");if not valid.ok then return valid end
            ---@type number|nil
            local price
            for _,item in ipairs(options.content.release.homeItems) do if item.id==request.furnitureId then price=item.price end end
            if not price then return U.Fail("UNKNOWN_ID","furnitureId","未知家具") end
            local current=api.GetSnapshot()
            if not current then return U.Fail("STATE_LOCKED","GameState","请先读取存档") end
            return api.PurchaseHomeItem({itemId=request.furnitureId,expectedPrice=price,expectedDay=current.live.gameFlow.day,expectedRevision=current.revision})
        end
        if busy then return U.Fail("COMMAND_BUSY","GameState","候选提交期间禁止嵌套命令") end
        local action=api.CheckAction("PurchaseFurniture")
        if not action.enabled then return U.Fail(action.reasonCode,"PurchaseFurniture",action.message) end
        if not options.economy or not options.economy.PlanFurniturePurchase then return U.Fail("NOT_IMPLEMENTED","PurchaseFurniture","家具账本尚未接入") end
        busy=true
        local called,result=pcall(function()
            local current=api.GetSnapshot()
            local valid=prepare(current,targetSchema)
            if not valid.ok then return valid end
            local planned=options.economy.PlanFurniturePurchase(current.live.economy,request,current.live.gameFlow)
            if not planned.ok then return planned end
            local candidate=U.Copy(current)
            candidate.live.economy=planned.value.state; candidate.revision=candidate.revision+1
            return commit(candidate,{furnitureId=planned.value.furnitureId,cost=planned.value.cost,owned=true},{"FurniturePurchased","MoneyChanged"})
        end)
        busy=false
        if not called then return U.Fail("COMMAND_FAILED","PurchaseFurniture",tostring(result)) end
        return result
    end
    function api.ReleaseCommand(kind,request)
        if busy then return U.Fail("COMMAND_BUSY","GameState","候选提交期间禁止嵌套命令") end
        if not api.CanMutate() then return U.Fail("STATE_LOCKED","GameState","请先读取原槽核对进度") end
        if targetSchema~=4 then return U.Fail("NOT_IMPLEMENTED","release","当前存档未接入首发终局") end
        busy=true
        local called,result=pcall(function()
            local current=api.GetSnapshot();local valid=prepare(current,targetSchema)
            if not valid.ok then return valid end
            local planned=require("systems.ReleaseCoordinator").New(options.content).Plan(kind,current,request,options.initialState)
            if not planned.ok then return planned end
            if not planned.value.changed then return U.Ok(planned.value.value) end
            return commit(planned.value.data,planned.value.value,planned.value.events)
        end)
        busy=false
        if not called then return U.Fail("COMMAND_FAILED","release",type(result)=="table" and result.message or tostring(result)) end
        return result
    end
    if targetSchema==4 then
        for _,name in ipairs({"PurchaseTravelTicket","BeginClosing","BeginWish","UpdateWishDraft","ConfirmEnding","RestoreEndingCheckpoint","StartNewPlaythrough"}) do
            api[name]=function(request)return api.ReleaseCommand(name,request)end
        end
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
