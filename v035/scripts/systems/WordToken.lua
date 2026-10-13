-- 词条实例唯一归属。PlanCut/PlanConsumption -> {state,...}；ResolveRecipe 不计算药效。
local U = require "core.StateUtil"
local WordToken = {}
local function tokenId(letterId,spanId)
    return "token:" .. #letterId .. ":" .. letterId .. ":" .. #spanId .. ":" .. spanId
end
function WordToken.New(content)
    ---@type table|nil
    local state
    local api = {}
    local parser = require("systems.Letter").New(content)
    local function sourceValid(source)
        local keys = U.Keys(source,{wordId=true,sourceLetterInstanceId=true,sourceSpanId=true,sourceNpcId=true},"source")
        if not keys.ok then return keys end
        for _, key in ipairs({"wordId","sourceLetterInstanceId","sourceSpanId","sourceNpcId"}) do
            if not U.String(source[key]) then return U.Fail("INVALID_REQUEST","source." .. key,"来源字段须为非空字符串") end
        end
        local word = content.GetWord(source.wordId)
        if not word then return U.Fail("UNKNOWN_ID","source.wordId","未知词定义") end
        if type(word.reusable) ~= "boolean" then return U.Fail("CONFIG_INVALID","words." .. word.id .. ".reusable","缺少复用标志") end
        local letterId = source.sourceLetterInstanceId:match("^letter:(.+)$")
        local letter = letterId and content.GetLetter(letterId)
        if not letter or letter.kind ~= "order" or letter.senderId ~= source.sourceNpcId or not content.GetNpc(source.sourceNpcId) then
            return U.Fail("SOURCE_INVALID","source","来源信或寄信人不相符")
        end
        local parsed = parser.ParseDefinition(letterId)
        if not parsed.ok then return parsed end
        for _, span in ipairs(parsed.value.spans) do
            if span.spanId == source.sourceSpanId and span.wordId == source.wordId then return U.Ok(U.Copy(source)) end
        end
        return U.Fail("SOURCE_INVALID","source.sourceSpanId","来源位置与词定义不相符")
    end
    function api.InitialSnapshot()
        if not U.String(content.contentVersion) then return U.Fail("CONFIG_MISSING","contentVersion","缺少内容版本") end
        return U.Ok({byId={}})
    end
    function api.ValidateSnapshot(s)
        local valid = U.Validate(s)
        if not valid.ok then return valid end
        valid = U.Keys(s,{byId=true},"wordTokens")
        if not valid.ok then return valid end
        if type(s.byId) ~= "table" then return U.Fail("STATE_INVALID","wordTokens.byId","缺少词条实例对象") end
        for id, item in pairs(s.byId) do
            valid = U.Keys(item,{wordId=true,sourceLetterInstanceId=true,sourceSpanId=true,sourceNpcId=true,available=true,consumedByOrderId=true},"wordTokens.byId." .. tostring(id))
            if not valid.ok then return valid end
            local source = {wordId=item.wordId,sourceLetterInstanceId=item.sourceLetterInstanceId,sourceSpanId=item.sourceSpanId,sourceNpcId=item.sourceNpcId}
            valid = sourceValid(source)
            if not valid.ok then return valid end
            if id ~= tokenId(item.sourceLetterInstanceId,item.sourceSpanId) or type(item.available) ~= "boolean"
                or (item.available and item.consumedByOrderId ~= false)
                or (not item.available and (not U.String(item.consumedByOrderId) or content.GetWord(item.wordId).reusable)) then
                return U.Fail("STATE_INVALID","wordTokens.byId." .. tostring(id),"非法实例 ID、可用性或消耗记录")
            end
        end
        return U.Ok(U.Copy(s))
    end
    function api.Restore(s)
        local checked = api.ValidateSnapshot(s)
        if checked.ok then state = U.Copy(checked.value) end
        return checked
    end
    function api.GetSnapshot() return state and U.Copy(state) or nil end
    function api.PlanCut(s,source)
        local valid = api.ValidateSnapshot(s)
        if not valid.ok then return valid end
        local checked = sourceValid(source)
        if not checked.ok then return checked end
        source = checked.value
        local id = tokenId(source.sourceLetterInstanceId,source.sourceSpanId)
        local old = valid.value.byId[id]
        if old then return U.Ok({state=valid.value,tokenId=id,token=U.Copy(old),source=source,changed=false}) end
        local item = U.Copy(source); item.available=true; item.consumedByOrderId=false
        valid.value.byId[id] = item
        return U.Ok({state=valid.value,tokenId=id,token=U.Copy(item),source=source,changed=true})
    end
    local function reference(id,item)
        return {tokenId=id,definition=U.Copy(content.GetWord(item.wordId)),source={wordId=item.wordId,
            sourceLetterInstanceId=item.sourceLetterInstanceId,sourceSpanId=item.sourceSpanId,sourceNpcId=item.sourceNpcId}}
    end
    function api.GetInventory()
        if not state then return U.Fail("STATE_NOT_READY","wordTokens","词条状态尚未恢复") end
        local ids, inventory = {}, {}
        for id in pairs(state.byId) do ids[#ids+1]=id end
        table.sort(ids)
        for _, id in ipairs(ids) do
            local item = state.byId[id]
            local view = reference(id,item)
            view.available, view.consumedByOrderId = item.available, item.consumedByOrderId
            inventory[#inventory+1] = view
        end
        return U.Ok(inventory)
    end
    -- 只读投影：cards 保留全部历史来源；groups 的剩余张数仅数 available 实例。
    -- 返回具体 tokenId，由玩家选择来源；这里不替 UI 自动选卡或执行结局判定。
    function api.GetInventoryView()
        local inventory=api.GetInventory()
        if not inventory.ok then return inventory end
        local view={cards=inventory.value,groups={},availableCount=0,availableDefinitionCount=0,availableCategoryCount=0}
        local groups,categories={},{}
        for _,card in ipairs(inventory.value) do
            local id=card.definition.id
            local group=groups[id]
            if not group then
                group={wordId=id,definition=U.Copy(card.definition),collectedCount=0,availableCount=0,availableTokenIds={}}
                groups[id]=group; view.groups[#view.groups+1]=group
            end
            group.collectedCount=group.collectedCount+1
            if card.available then
                group.availableCount=group.availableCount+1
                group.availableTokenIds[#group.availableTokenIds+1]=card.tokenId
                view.availableCount=view.availableCount+1
                categories[card.definition.category]=true
            end
        end
        table.sort(view.groups,function(a,b) return a.wordId<b.wordId end)
        for _,group in ipairs(view.groups) do
            if group.availableCount>0 then view.availableDefinitionCount=view.availableDefinitionCount+1 end
        end
        for _ in pairs(categories) do view.availableCategoryCount=view.availableCategoryCount+1 end
        return U.Ok(view)
    end
    -- value={orderId,recipe(词引用投影),main={tokenId,definition,source},aux=[同型]}。
    -- 完整 RecipeRequest 的设备/槽数/同定义策略留给 B3，不放开同一实例重复引用。
    function api.ResolveRecipe(s,recipe)
        local valid = api.ValidateSnapshot(s)
        if not valid.ok then return valid end
        valid = U.Validate(recipe)
        if not valid.ok then return valid end
        valid = U.Keys(recipe,{orderId=true,baselineId=true,equipmentId=true,mainTokenId=true,auxTokenIds=true,ingredients=true,specialItemIds=true},"recipe")
        if not valid.ok then return valid end
        if not U.String(recipe.orderId) or not U.String(recipe.mainTokenId) or not U.Array(recipe.auxTokenIds) then
            return U.Fail("INVALID_REQUEST","recipe","缺少订单、主词或辅助词数组")
        end
        local seen, aux = {}, {}
        local function resolve(id)
            if not U.String(id) then return U.Fail("INVALID_REQUEST","tokenId","词实例 ID 非法") end
            if seen[id] then return U.Fail("DUPLICATE_TOKEN","tokenId","同一实例不能同时占多个槽") end
            seen[id]=true
            local item = s.byId[id]
            if not item or not item.available then return U.Fail("TOKEN_UNAVAILABLE","tokenId","词实例不存在或已消耗",{tokenId=id}) end
            return U.Ok(reference(id,item))
        end
        local main = resolve(recipe.mainTokenId)
        if not main.ok then return main end
        for _, id in ipairs(recipe.auxTokenIds) do
            local item = resolve(id)
            if not item.ok then return item end
            aux[#aux+1]=item.value
        end
        return U.Ok({orderId=recipe.orderId,recipe={orderId=recipe.orderId,mainTokenId=recipe.mainTokenId,auxTokenIds=U.Copy(recipe.auxTokenIds)},main=main.value,aux=aux})
    end
    function api.PlanConsumption(s,resolved)
        local pure = U.Validate(resolved)
        if not pure.ok then return pure end
        if type(resolved) ~= "table" then return U.Fail("INVALID_REQUEST","resolved","缺少已解析引用") end
        local fresh = api.ResolveRecipe(s,resolved.recipe)
        if not fresh.ok then return fresh end
        if not U.Equal(fresh.value,resolved) then return U.Fail("INVALID_REQUEST","resolved","引用或定义被改写") end
        local candidate, consumed = U.Copy(s), {}
        local references = {fresh.value.main}
        for _, item in ipairs(fresh.value.aux) do references[#references+1]=item end
        for _, item in ipairs(references) do
            if not item.definition.reusable then
                candidate.byId[item.tokenId].available=false
                candidate.byId[item.tokenId].consumedByOrderId=resolved.orderId
                consumed[#consumed+1]=item.tokenId
            end
        end
        return U.Ok({state=candidate,consumedTokenIds=consumed})
    end
    return api
end
return WordToken
