-- 最小账本。候选计算不会保存、安装状态或发出奖励事件。
local U = require "core.StateUtil"
local Economy = {}

function Economy.New(content)
    ---@type table|nil
    local state
    local api = {}
    local function known(list, id)
        for _, item in ipairs(list or {}) do if item.id == id then return true end end
        return false
    end
    function api.ValidateSnapshot(s)
        local valid = U.Validate(s)
        if not valid.ok then return valid end
        valid = U.Keys(s, {currency=true,ingredients=true,specialItems=true,ownedEquipmentIds=true,shopPurchases=content.shop~=nil}, "economy")
        if not valid.ok then return valid end
        if not U.Integer(s.currency) or type(s.ingredients) ~= "table" or type(s.specialItems) ~= "table"
            or type(s.ownedEquipmentIds) ~= "table" then
            return U.Fail("ECONOMY_INVALID", "economy", "金币/份数须为非负整数，设备须为集合")
        end
        if content.shop then
            if not U.Integer(content.shop.dailyStockPerIngredient,1) then return U.Fail("CONFIG_INVALID","shop","每日限购量须为正整数") end
            if not U.Array(s.shopPurchases) then return U.Fail("ECONOMY_INVALID","shopPurchases","缺少购买记录") end
            local day,delivered,stock=1,0,{}
            for _,p in ipairs(s.shopPurchases) do
                local fields=U.Keys(p,{day=true,afterDeliveredOrders=true,ingredientId=true,quantity=true,unitPrice=true},"shopPurchases")
                if not fields.ok then return fields end
                if not U.Integer(p.day,day) or not U.Integer(p.afterDeliveredOrders,delivered) or not U.Integer(p.quantity,1) then
                    return U.Fail("ECONOMY_INVALID","shopPurchases","购买时序或份数错误")
                end
                local definition
                for _,v in ipairs(content.ingredients) do if v.id==p.ingredientId then definition=v end end
                if not definition or not U.Integer(definition.price,1) or p.unitPrice~=definition.price then return U.Fail("ECONOMY_INVALID","shopPurchases","购买原料或单价错误") end
                if p.day~=day then stock={} end
                day,delivered=p.day,p.afterDeliveredOrders
                stock[p.ingredientId]=(stock[p.ingredientId] or 0)+p.quantity
                if stock[p.ingredientId]>content.shop.dailyStockPerIngredient then return U.Fail("ECONOMY_INVALID","shopPurchases","超过当日限购量") end
            end
        end
        for id, qty in pairs(s.ingredients) do
            if not known(content.ingredients, id) or not U.Integer(qty) then
                return U.Fail("ECONOMY_INVALID", "economy.ingredients." .. tostring(id), "未知原料或非法份数")
            end
        end
        for id, owned in pairs(s.ownedEquipmentIds) do
            if not known(content.equipment, id) or owned ~= true then return U.Fail("ECONOMY_INVALID", "economy.ownedEquipmentIds", "未知设备或非 true 集合值") end
        end
        for id, item in pairs(s.specialItems) do
            if not U.String(id) or type(item) ~= "table" or not U.String(item.sourceLetterInstanceId)
                or type(item.available) ~= "boolean" or not known(content.specialItems, item.itemId) then
                return U.Fail("ECONOMY_INVALID", "economy.specialItems", "特殊物品实例或定义无效")
            end
            local fields = U.Keys(item, {itemId=true,sourceLetterInstanceId=true,available=true}, "economy.specialItems." .. id)
            if not fields.ok then return fields end
        end
        return U.Ok(U.Copy(s))
    end
    function api.InitialSnapshot()
        local stage = content.stage1
        local function required(value, predicate, path, message)
            if value == nil then return U.Fail("CONFIG_MISSING", path, "缺少配置：" .. path) end
            if not predicate(value) then return U.Fail("CONFIG_INVALID", path, message) end
        end
        local function isTable(value) return type(value) == "table" end
        local invalid = required(content.contentVersion, U.String, "contentVersion", "内容版本须为非空字符串")
            or required(stage, isTable, "stage1", "首单配置须为对象")
        if invalid then return invalid end
        invalid = required(stage.initialEconomy, isTable, "stage1.initialEconomy", "开局账本须为对象")
            or required(stage.initialEquipmentId, U.String, "stage1.initialEquipmentId", "初始设备须为非空 ID")
        if invalid then return invalid end
        local initial = stage.initialEconomy
        local path = "stage1.initialEconomy"
        invalid = required(initial.currency, U.Integer, path .. ".currency", "开局金币须为非负整数")
            or required(initial.ingredients, isTable, path .. ".ingredients", "开局原料须为 ID 到份数的对象")
            or required(initial.specialItems, isTable, path .. ".specialItems", "特殊物品须为实例集合")
        if invalid then return invalid end
        for id, quantity in pairs(initial.ingredients) do
            if not known(content.ingredients, id) then return U.Fail("UNKNOWN_ID", path .. ".ingredients." .. tostring(id), "未知原料 ID") end
            if not U.Integer(quantity) then return U.Fail("CONFIG_INVALID", path .. ".ingredients." .. id, "原料份数须为非负整数") end
        end
        -- 开局份数必须显式声明（可为 0）；恢复旧库存不应用这项开局完整性要求。
        for _, item in ipairs(content.ingredients or {}) do
            if initial.ingredients[item.id] == nil then return U.Fail("CONFIG_MISSING", path .. ".ingredients." .. item.id, "缺少原料开局份数") end
        end
        if next(initial.specialItems) ~= nil then return U.Fail("CONFIG_INVALID", path .. ".specialItems", "C1 开局特殊物品集合须为空") end
        if not known(content.equipment, stage.initialEquipmentId) then
            return U.Fail("UNKNOWN_ID", "stage1.initialEquipmentId", "未知初始设备 ID")
        end
        for _, item in ipairs(content.equipment or {}) do
            if (item.id == stage.initialEquipmentId and item.owned ~= true)
                or (item.id ~= stage.initialEquipmentId and item.owned == true) then
                return U.Fail("CONFIG_INVALID", "stage1.initialEquipmentId", "初始设备与设备配置 owned 标记不一致")
            end
        end
        local fields = U.Keys(initial, {currency=true,ingredients=true,specialItems=true}, path)
        if not fields.ok then return U.Fail("CONFIG_INVALID", fields.error.path, "未知开局账本字段") end
        local pure = U.Validate(initial)
        if not pure.ok then return U.Fail("CONFIG_INVALID", path, "开局账本包含不可保存的值", pure.error) end
        initial = U.Copy(initial)
        initial.ownedEquipmentIds = { [stage.initialEquipmentId] = true }
        if content.shop then initial.shopPurchases={} end
        return api.ValidateSnapshot(initial)
    end
    function api.Restore(s)
        local result = api.ValidateSnapshot(s)
        if result.ok then state = U.Copy(result.value) end
        return result
    end
    ---@return table|nil
    function api.GetSnapshot() return state and U.Copy(state) or nil end
    -- 只做购买候选；协调器校验门禁、保存成功后才安装。购买记录供OrderAudit逐单重放。
    function api.PlanPurchase(base,request,context)
        if not content.shop then return U.Fail("NOT_IMPLEMENTED","shop","该内容包未配置商店") end
        local valid=api.ValidateSnapshot(base)
        if not valid.ok then return valid end
        valid=U.Keys(request,{ingredientId=true,quantity=true},"shop.request")
        if not valid.ok then return valid end
        if not U.String(request.ingredientId) or not U.Integer(request.quantity,1) then return U.Fail("INVALID_REQUEST","shop.request","请选择原料和正整数份数") end
        local definition
        for _,v in ipairs(content.ingredients) do if v.id==request.ingredientId then definition=v end end
        if not definition then return U.Fail("UNKNOWN_ID","ingredientId","未知原料") end
        if not U.Integer(definition.price,1) then return U.Fail("CONFIG_INVALID","ingredient.price","原料售价须为正整数") end
        if type(context)~="table" or not U.Integer(context.day,1) or not U.Integer(context.deliveredOrders) then return U.Fail("INVALID_REQUEST","shop.context","购买须使用正式天数和发货计数") end
        local spent=0
        for _,p in ipairs(base.shopPurchases) do
            if p.day>context.day or p.afterDeliveredOrders>context.deliveredOrders then return U.Fail("ECONOMY_INVALID","shopPurchases","购买记录超出当前进度") end
            if p.day==context.day and p.ingredientId==request.ingredientId then spent=spent+p.quantity end
        end
        if spent+request.quantity>content.shop.dailyStockPerIngredient then return U.Fail("SHOP_STOCK_SHORT","quantity","超过当日剩余供货量") end
        local cost=definition.price*request.quantity
        if not U.Integer(cost,1) then return U.Fail("INVALID_REQUEST","quantity","购买金额溢出") end
        if base.currency<cost then return U.Fail("CURRENCY_SHORT","currency","金币不足") end
        local candidate=U.Copy(base)
        candidate.currency=base.currency-cost
        candidate.ingredients[definition.id]=(candidate.ingredients[definition.id] or 0)+request.quantity
        candidate.shopPurchases[#candidate.shopPurchases+1]={day=context.day,afterDeliveredOrders=context.deliveredOrders,ingredientId=definition.id,quantity=request.quantity,unitPrice=definition.price}
        valid=api.ValidateSnapshot(candidate)
        if not valid.ok then return valid end
        return U.Ok({state=valid.value,cost=cost,ingredientId=definition.id,quantity=request.quantity})
    end
    function api.PlanSettlement(base, ingredientUses, specialUses, reward)
        local valid = api.ValidateSnapshot(base)
        if not valid.ok then return valid end
        if not U.Array(ingredientUses) or not U.Array(specialUses) or type(reward) ~= "table"
            or not U.Integer(reward.currency) then return U.Fail("REQUEST_INVALID", "settlement", "用量需为数组，奖励需为非负整数") end
        local candidate, delta = valid.value, {currency=reward.currency,ingredients={},specialItemIds={}}
        local rewardFields = U.Keys(reward, {currency=true}, "reward")
        if not rewardFields.ok then return rewardFields end
        local used = {}
        for i, use in ipairs(ingredientUses) do
            if type(use) ~= "table" or not known(content.ingredients, use.ingredientId) or not U.Integer(use.quantity, 1) then
                return U.Fail("REQUEST_INVALID", "ingredients." .. i, "未知原料或非法用量")
            end
            local id = use.ingredientId
            local fields = U.Keys(use, {ingredientId=true,quantity=true}, "ingredients." .. i)
            if not fields.ok then return fields end
            if used[id] then return U.Fail("REQUEST_INVALID", id, "原料必须先聚合，不能重复行") end
            used[id] = use.quantity
            if used[id] > (base.ingredients[id] or 0) then return U.Fail("INVENTORY_SHORT", id, "原料不足") end
            candidate.ingredients[id] = base.ingredients[id] - used[id]
            delta.ingredients[id] = -used[id]
        end
        used = {}
        for _, id in ipairs(specialUses) do
            if not U.String(id) or used[id] or not candidate.specialItems[id] or not candidate.specialItems[id].available then
                return U.Fail("SPECIAL_ITEM_UNAVAILABLE", "specialUses", "未知或重复特殊物品实例")
            end
            used[id] = true
            candidate.specialItems[id].available = false
            delta.specialItemIds[#delta.specialItemIds + 1] = id
        end
        candidate.currency = candidate.currency + reward.currency
        if not U.Integer(candidate.currency) or candidate.currency < base.currency then
            return U.Fail("ECONOMY_INVALID", "currency", "金币溢出")
        end
        return U.Ok({state=candidate,delta=delta})
    end
    return api
end

-- 正式实例只读取统一内容入口；测试显式 New(技术夹具)。
local live = Economy.New(require "data.content")
Economy.InitialSnapshot = live.InitialSnapshot
Economy.ValidateSnapshot = live.ValidateSnapshot
Economy.GetSnapshot = live.GetSnapshot
Economy.Restore = live.Restore
Economy.PlanSettlement = live.PlanSettlement
return Economy
