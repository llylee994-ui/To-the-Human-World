-- B0 v0.2 Envelope 的结构层。业务差异/配置引用须再经真实模块验证，不能单凭本文件放行玩法。
local U = require "core.StateUtil"
local Flow = require "core.GameFlow"
local Schema = {}
local function need(ok, path, message)
    if not ok then error(U.Error("STATE_INVALID", path, message or "字段类型或关联不合法"), 0) end
end
local function object(t, fields, path, optional)
    need(type(t) == "table", path)
    local allowed = {}
    for name in fields:gmatch("%S+") do allowed[name] = true; need(t[name] ~= nil, path .. "." .. name, "缺少字段") end
    for name in (optional or ""):gmatch("%S+") do allowed[name]=true end
    local valid = U.Keys(t, allowed, path)
    if not valid.ok then error(valid.error, 0) end
end
local function map(t, path)
    need(type(t) == "table", path)
    for k in pairs(t) do need(U.String(k), path, "需要字符串键对象") end
end
local function ids(t, path)
    need(U.Array(t), path, "需要稠密 ID 数组")
    local seen = {}
    for _, id in ipairs(t) do need(U.String(id) and not seen[id], path, "ID 为空或重复"); seen[id] = true end
end
local function set(t, path)
    map(t, path)
    for _, v in pairs(t) do need(v == true, path, "集合值须为 true") end
end
local function quantities(t, path)
    need(U.Array(t), path)
    local seen = {}
    for _, row in ipairs(t) do
        object(row, "ingredientId quantity", path)
        need(U.String(row.ingredientId) and not seen[row.ingredientId] and U.Integer(row.quantity, 1), path)
        seen[row.ingredientId] = true
    end
end
local function rating(t, path)
    object(t, "stars feedback ruleId factIds", path)
    need(U.Integer(t.stars, 1) and t.stars <= 3 and U.String(t.feedback) and U.String(t.ruleId), path)
    ids(t.factIds, path .. ".factIds")
end
-- 实际 B2 恢复器在结构层之后检查配置与双向来源；B1 无模块时保留结构层检查。
function Schema.ValidateLetterTokens(letters,tokens,options)
    local l = options.letters.ValidateSnapshot(letters)
    if not l.ok then return l end
    local w = options.wordTokens.ValidateSnapshot(tokens)
    if not w.ok then return w end
    local sources = {}
    for id, token in pairs(tokens.byId) do
        local item = letters.byId[token.sourceLetterInstanceId]
        local source = options.letters.ResolveSource(letters,token.sourceLetterInstanceId,token.sourceSpanId)
        if not source.ok then return source end
        if not item.cutSpans[token.sourceSpanId] or source.value.wordId ~= token.wordId or source.value.sourceNpcId ~= token.sourceNpcId then
            return U.Fail("SOURCE_INVALID","wordTokens.byId." .. id,"词实例与信件缺口不一致")
        end
        local key = #token.sourceLetterInstanceId .. ":" .. token.sourceLetterInstanceId .. token.sourceSpanId
        if sources[key] then return U.Fail("SOURCE_INVALID","wordTokens.byId","同一位置产生多个词实例") end
        sources[key]=true
    end
    for id, item in pairs(letters.byId) do
        for span in pairs(item.cutSpans) do
            if not sources[#id .. ":" .. id .. span] then return U.Fail("SOURCE_INVALID","letters.byId." .. id .. ".cutSpans." .. span,"剪裁缺口没有词实例") end
        end
    end
    return U.Ok({letters=U.Copy(letters),wordTokens=U.Copy(tokens)})
end
local function live(s, path, options)
    object(s, "gameFlow letters wordTokens economy world narrative orders", path)
    need(Flow.ValidateSnapshot(s.gameFlow).ok, path .. ".gameFlow")
    object(s.gameFlow, "day phase canSalvage mainStoryStage deliveredOrders", path .. ".gameFlow")
    object(s.letters, "byId bottleQueue directArchive", path .. ".letters")
    map(s.letters.byId, path .. ".letters.byId")
    ids(s.letters.bottleQueue, path .. ".letters.bottleQueue")
    map(s.letters.directArchive, path .. ".letters.directArchive")
    for id, letter in pairs(s.letters.byId) do
        object(letter, "letterId senderId received read cutSpans claimedAttachmentIds", path .. ".letters." .. id)
        need(U.String(letter.letterId) and U.String(letter.senderId) and type(letter.received) == "boolean" and type(letter.read) == "boolean", path .. ".letters." .. id)
        set(letter.cutSpans, path .. ".cutSpans"); ids(letter.claimedAttachmentIds, path .. ".attachments")
    end
    for _, id in ipairs(s.letters.bottleQueue) do need(s.letters.byId[id] ~= nil, path .. ".bottleQueue") end
    object(s.wordTokens, "byId", path .. ".wordTokens")
    map(s.wordTokens.byId, path .. ".wordTokens.byId")
    local sources = {}
    for id, token in pairs(s.wordTokens.byId) do
        object(token, "wordId sourceLetterInstanceId sourceSpanId sourceNpcId available consumedByOrderId", path .. ".tokens." .. id)
        local letter = s.letters.byId[token.sourceLetterInstanceId]
        need(U.String(token.wordId) and U.String(token.sourceSpanId) and U.String(token.sourceNpcId)
            and type(token.available) == "boolean" and (token.consumedByOrderId == false or U.String(token.consumedByOrderId)), path .. ".tokens." .. id)
        need(letter and letter.cutSpans[token.sourceSpanId] == true, path .. ".tokens." .. id, "来源剪裁标记缺失")
        local key = token.sourceLetterInstanceId .. ":" .. token.sourceSpanId
        need(not sources[key], path .. ".tokens", "重复词条来源"); sources[key] = true
    end
    local ledger = options.economy.ValidateSnapshot(s.economy)
    if not ledger.ok then error(ledger.error, 0) end
    object(s.world, "npcs flags", path .. ".world"); map(s.world.npcs, path .. ".npcs"); map(s.world.flags, path .. ".flags")
    object(s.narrative, "unlockedLetterIds delayedQueue resolvedEventIds", path .. ".narrative")
    set(s.narrative.unlockedLetterIds, path .. ".unlockedLetterIds"); set(s.narrative.resolvedEventIds, path .. ".resolvedEventIds")
    need(U.Array(s.narrative.delayedQueue), path .. ".delayedQueue")
    for _, item in ipairs(s.narrative.delayedQueue) do
        object(item, "eventId sourceOrderId conditionId", path .. ".delayedQueue")
        need(U.String(item.eventId) and U.String(item.sourceOrderId) and U.String(item.conditionId), path .. ".delayedQueue")
    end
    object(s.orders, "acceptedById confirmedById", path .. ".orders")
    map(s.orders.acceptedById, path .. ".acceptedById"); map(s.orders.confirmedById, path .. ".confirmedById")
    local count = 0
    for id, order in pairs(s.orders.acceptedById) do
        object(order, "letterInstanceId letterId acceptedDay", path .. ".orders." .. id)
        need(s.letters.byId[order.letterInstanceId] and U.String(order.letterId) and U.Integer(order.acceptedDay, 1), path .. ".orders." .. id)
    end
    for id, record in pairs(s.orders.confirmedById) do
        object(record, "transactionId contentVersion synthesisVersion potion requirementResult facts worldChanges followup rating consumption reward letterInstanceId recipe", path .. ".confirmedById." .. id, "deliveryDay")
        need(U.String(record.transactionId) and s.orders.acceptedById[id] and record.letterInstanceId == s.orders.acceptedById[id].letterInstanceId, path .. ".confirmedById." .. id)
        need(type(record.followup) == "table", path .. ".confirmedById.followup")
        rating(record.rating, path .. ".confirmedById.rating")
        local archive = s.letters.directArchive[id]
        object(archive, "transactionId letterId renderedText fragmentIds rating", path .. ".directArchive." .. id)
        need(archive.transactionId == record.transactionId and archive.letterId == record.followup.letterId
            and archive.renderedText == record.followup.renderedText and U.Equal(archive.fragmentIds, record.followup.fragmentIds)
            and U.Equal(archive.rating, record.rating), path .. ".directArchive." .. id, "归档与确认结果不一致")
        count = count + 1
    end
    for id in pairs(s.letters.directArchive) do need(s.orders.confirmedById[id] ~= nil, path .. ".directArchive", "孤立归档") end
    need(count == s.gameFlow.deliveredOrders, path .. ".deliveredOrders", "发货数与确认记录不一致")
    if options.letters or options.wordTokens then
        need(options.letters and options.wordTokens,path,"信件与词条恢复器必须一起提供")
        local joined = Schema.ValidateLetterTokens(s.letters,s.wordTokens,options)
        if not joined.ok then error(joined.error,0) end
    end
    -- 已确认明细与世界字段语义留给 Order/World/Narrative 恢复器，不在结构层猜测。
end

function Schema.ValidateV2(data, options)
    local serializable = U.Validate(data)
    if not serializable.ok then return serializable end
    local ok, err = pcall(function()
        object(data, "contentVersion revision nextOrderSerial live currentOrder", "data")
        need(U.String(data.contentVersion) and U.Integer(data.revision) and U.Integer(data.nextOrderSerial, 1), "data")
        if data.contentVersion ~= options.contentVersion then error(U.Error("CONTENT_VERSION_MISMATCH", "contentVersion", "内容版本不相容"), 0) end
        live(data.live, "live", options)
        if data.currentOrder == false then return end
        local order = data.currentOrder
        object(order, "orderId letterInstanceId phase baseline recipe pending", "currentOrder", "nextAttemptSerial lastResetTransactionId")
        need(U.String(order.orderId) and U.String(order.letterInstanceId) and data.live.orders.acceptedById[order.orderId], "currentOrder")
        need(data.live.orders.acceptedById[order.orderId].letterInstanceId == order.letterInstanceId, "currentOrder.letterInstanceId")
        need(not data.live.orders.confirmedById[order.orderId], "currentOrder", "当前订单已确认")
        if order.phase == "accepted" then
            need(order.baseline == false and order.recipe == false and order.pending == false, "accepted")
            return
        end
        need(order.phase == "brewing" or order.phase == "pending", "currentOrder.phase")
        local base = order.baseline
        object(base, "id revision contentVersion live", "baseline")
        need(U.String(base.id) and base.revision == data.revision and base.contentVersion == data.contentVersion, "baseline", "基准过期或版本不相容")
        live(base.live, "baseline.live", options)
        need(U.Equal(base.live, data.live), "baseline.live", "试做期间正式状态偏离基准")
        local recipe = order.recipe
        if recipe ~= false then
            object(recipe, "orderId baselineId equipmentId mainTokenId auxTokenIds ingredients specialItemIds", "recipe")
            need(recipe.orderId == order.orderId and recipe.baselineId == base.id and U.String(recipe.equipmentId) and U.String(recipe.mainTokenId), "recipe")
            ids(recipe.auxTokenIds, "recipe.auxTokenIds"); quantities(recipe.ingredients, "recipe.ingredients"); ids(recipe.specialItemIds, "recipe.specialItemIds")
        end
        if order.phase == "brewing" then need(order.pending == false, "brewing.pending"); return end
        need(recipe ~= false, "pending.recipe")
        local p = order.pending
        object(p, "transactionId status contentVersion synthesisVersion potion requirementResult facts worldChanges followup rating consumption reward candidateLive", "pending")
        need(U.String(p.transactionId) and p.status == "pending" and p.contentVersion == data.contentVersion, "pending")
        if not (U.String(options.synthesisVersion) or U.Integer(options.synthesisVersion,1)) or p.synthesisVersion ~= options.synthesisVersion then
            error(U.Error("SYNTHESIS_VERSION_MISMATCH", "pending.synthesisVersion", "计算规则版本不相容"), 0)
        end
        object(p.potion, "synthesisVersion contentVersion effects intensityByEffect mods durationHours onsetDelayHours recoveryAfterEndHours residuals stability unstable sideEffects trace", "potion")
        need(p.potion.contentVersion == p.contentVersion and p.potion.synthesisVersion == p.synthesisVersion, "potion.version")
        for _, key in ipairs({"durationHours","onsetDelayHours","recoveryAfterEndHours"}) do need(type(p.potion[key]) == "number" and p.potion[key] >= 0, "potion." .. key) end
        need(type(p.potion.unstable) == "boolean" and type(p.potion.stability) == "number", "potion")
        map(p.potion.effects, "potion.effects"); map(p.potion.intensityByEffect, "potion.intensityByEffect")
        object(p.potion.mods, "intensity duration speed stability sideEffect", "potion.mods")
        for _, v in pairs(p.potion.mods) do need(type(v) == "number", "potion.mods") end
        need(U.Array(p.potion.residuals) and U.Array(p.potion.sideEffects) and U.Array(p.potion.trace), "potion.arrays")
        need(#p.potion.trace == 8, "potion.trace", "八步计算记录不完整")
        for i, step in ipairs(p.potion.trace) do
            object(step, "step inputs outputs sourceIds", "potion.trace." .. i)
            need(step.step == i and type(step.inputs) == "table" and type(step.outputs) == "table", "potion.trace." .. i)
            ids(step.sourceIds, "potion.trace.sourceIds")
        end
        object(p.requirementResult, "canShip checks failures", "requirementResult")
        need(p.requirementResult.canShip == true and U.Array(p.requirementResult.checks) and U.Array(p.requirementResult.failures) and #p.requirementResult.failures == 0, "requirementResult")
        need(type(p.facts) == "table" and type(p.worldChanges) == "table", "pending.facts")
        object(p.followup, "letterId fragmentIds bindings renderedText", "followup")
        need(U.String(p.followup.letterId) and U.String(p.followup.renderedText), "followup")
        ids(p.followup.fragmentIds, "followup.fragmentIds"); map(p.followup.bindings, "followup.bindings")
        rating(p.rating, "rating")
        object(p.consumption, "ingredients consumedTokenIds specialItemIds", "consumption")
        quantities(p.consumption.ingredients, "consumption.ingredients"); ids(p.consumption.consumedTokenIds, "consumption.consumedTokenIds"); ids(p.consumption.specialItemIds, "consumption.specialItemIds")
        object(p.reward, "currency", "reward"); need(U.Integer(p.reward.currency), "reward.currency")
        live(p.candidateLive, "candidateLive", options)
        local confirmed = p.candidateLive.orders.confirmedById[order.orderId]
        need(confirmed and confirmed.transactionId == p.transactionId and U.Equal(confirmed.recipe, recipe), "candidateLive.confirmedById")
        for _, key in ipairs({"contentVersion","synthesisVersion","potion","requirementResult","facts","worldChanges","followup","rating","consumption","reward"}) do
            need(U.Equal(confirmed[key], p[key]), "candidateLive.confirmedById." .. key, "确认记录与待确认结果不一致")
        end
        need(p.candidateLive.gameFlow.deliveredOrders == data.live.gameFlow.deliveredOrders + 1, "candidateLive.deliveredOrders")
        local settlement = options.economy.PlanSettlement(base.live.economy, p.consumption.ingredients, p.consumption.specialItemIds, p.reward)
        need(settlement.ok and U.Equal(settlement.value.state, p.candidateLive.economy), "candidateLive.economy", "候选账本与消耗奖励不一致")
    end)
    if not ok then return {ok=false,error=type(err) == "table" and err or U.Error("STATE_INVALID", "data", tostring(err))} end
    return U.Ok(U.Copy(data))
end
function Schema.ValidateV3(data,options)
    local valid=U.Validate(data)
    if not valid.ok then return valid end
    local ok,err=pcall(function()
        object(data,"contentVersion revision nextOrderSerial live currentOrder journal","data")
        local flow=Flow.New(options.salvageDailyLimit)
        local function checkFlow(l)
            if options.schema4Projection~=true then need(type(l.economy)=="table" and l.economy.itemPurchases==nil,"economy.itemPurchases","schema3不能加载schema4永久流水") end
            local result=flow.ValidateSnapshot(l.gameFlow)
            if not result.ok then error(result.error,0) end
        end
        checkFlow(data.live)
        local order=data.currentOrder
        if order then
            object(order,"orderId letterInstanceId phase baseline recipe pending nextAttemptSerial lastResetTransactionId draft","currentOrder")
            need(order.phase=="accepted" or order.phase=="pending","currentOrder.phase")
            if order.phase=="pending" then
                checkFlow(order.baseline.live); checkFlow(order.pending.candidateLive)
                need(U.Equal(order.baseline.live,data.live),"baseline.live")
                need(order.baseline.id==order.recipe.baselineId,"baseline.id")
                need(U.Equal(order.pending.candidateLive.gameFlow,{day=data.live.gameFlow.day,phase=data.live.gameFlow.phase,
                    canSalvage=data.live.gameFlow.canSalvage,mainStoryStage=data.live.gameFlow.mainStoryStage,
                    salvageUsedToday=data.live.gameFlow.salvageUsedToday,deliveredOrders=data.live.gameFlow.deliveredOrders+1}),"candidateLive.gameFlow")
            end
        end
        local old=require("core.SchemaProjection").V2(data)
        local legacy=Schema.ValidateV2(old,options)
        if not legacy.ok then error(legacy.error,0) end
    end)
    if not ok then return {ok=false,error=type(err)=="table" and err or U.Error("STATE_INVALID","data",tostring(err))} end
    return U.Ok(U.Copy(data))
end
function Schema.ValidateV4(data,options)
    local pure=U.Validate(data);if not pure.ok then return pure end
    local ok,err=pcall(function()
        object(data,"contentVersion revision nextOrderSerial live currentOrder journal chapter","data")
        object(data.chapter,"phase wishDraftSourceIds ending endingTransactionId checkpoint","chapter")
        need(U.Equal(data.chapter,require("systems.ReleaseLedger").EmptyChapter()),"chapter","终局协调尚未开放")
        local function ledger(l)
            need(U.Array(l.economy.itemPurchases) and l.economy.furniturePurchases==nil and l.economy.ownedFurnitureIds==nil,"itemPurchases")
            for _,row in ipairs(l.economy.itemPurchases) do need(row.itemId~="travel_ticket","chapter","船票需终局协调事务") end
        end
        ledger(data.live)
        if data.currentOrder and data.currentOrder.pending then ledger(data.currentOrder.baseline.live);ledger(data.currentOrder.pending.candidateLive) end
        local projected=U.Copy(data);projected.chapter=nil
        local projectionOptions=U.Copy(options);projectionOptions.schema4Projection=true
        local r=Schema.ValidateV3(projected,projectionOptions);if not r.ok then error(r.error,0) end
    end)
    if not ok then return {ok=false,error=type(err)=="table" and err or U.Error("STATE_INVALID","data",tostring(err))} end
    return U.Ok(U.Copy(data))
end
return Schema
