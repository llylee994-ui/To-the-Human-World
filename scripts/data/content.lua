-- ============================================================================
-- 内容数据总入口
--
-- 所有静态配置的单一读取点。其它模块只 require 本文件，不直接 require 各分表，
-- 这样将来换存储格式（例如改成 JSON）只需要改这一处。
--
-- 见 docs/寄往人间_系统模块拆分与依赖设计.md ① Content 内容数据模块
-- 本模块只提供查询与校验，不推进剧情、不改玩家状态、不计算药效。
--
-- 两级校验：
--   Data.Load()          基础结构校验（旧样板 + 首单包新字段的引用合法性），启动时调用
--   Data.ValidateStage1() 首单包完整性校验（C1 开局账本 / C2 首单数值 / C3 事实与回信），
--                        在 Load 通过后调用；失败时入口必须阻止开局或受影响操作
-- ============================================================================

local Data = {}

Data.effects = require "data.effects"
local numericV02 = require "data.numeric_v02"
Data.words = numericV02.words
Data.ingredients = require "data.ingredients"
Data.equipment = require "data.equipment"
Data.synthesis = require "data.synthesis"
Data.npcs = numericV02.npcs
Data.letters = numericV02.letters
Data.stage1 = require "data.stage1"

local followup = numericV02
Data.directRules = followup.directRules
Data.factExclusionGroups = followup.factExclusionGroups
Data.fragments = followup.fragments
Data.followupTemplates = followup.followupTemplates
Data.orderRatings = followup.orderRatings
Data.attributeProfiles = Data.stage1.attributeProfiles
Data.contentVersion = Data.stage1.contentVersion

-- 供文案/程序复算的示例，不是 Potion 的配方白名单或查找表。
Data.recipes = numericV02.recipes

-- v02试用包替换旧故事配置；系统仍只通过本入口读取。
Data.contentVersion = "story-numeric-v02-r1"
Data.stage1.contentVersion = Data.contentVersion
Data.stage1.sampleCases = numericV02.sampleCases
Data.shop = { dailyStockPerIngredient = 6 }
Data.saveSlotId = "numeric_v02_trial"

-- 原料 mods 允许出现的键。写错键名不会报错，只会静默失效，所以在这里卡住。
---@type table<string, boolean?>
local ALLOWED_MOD_KEYS = {
    intensity = true,
    duration = true,
    speed = true,
    stability = true,
    sideEffect = true,
}

-- 设备槽位的四个键，缺一个会让炼药界面出问题
local REQUIRED_SLOT_KEYS = { "mainWord", "auxWord", "ingredient", "specialItem" }

-- 订单条件的类型（B0 §3.3）；未知 kind 一律报错，不当「未要求」放过
---@type table<string, boolean>
local CONDITION_KINDS = {
    duration = true,
    onset = true,
    workReady = true,
    residualAt = true,
    forbiddenEffect = true,
}

-- 条件/事实比较支持的运算符（首单只需要这四种）
---@type table<string, boolean>
local RULE_OPS = { eq = true, ne = true, gte = true, lte = true }

-- 条件与绑定的输入来源白名单
---@type table<string, boolean>
local BINDING_SOURCES = {
    ["potion.effects"] = true,
    ["world.npcs"] = true,
    ["context"] = true,
    ["facts"] = true,
}

-- 回信片段的类型（Narrative 选择顺序：key → combination → single → generic）
---@type table<string, boolean>
local FRAGMENT_KINDS = { key = true, combination = true, single = true, generic = true }

-- 状态变化允许的操作
---@type table<string, boolean>
local CHANGE_OPS = { set = true, add = true }

-- B0 §2 的错误码全集；内容样例声明的期望错误码必须来自这里
---@type table<string, boolean>
local KNOWN_ERROR_CODES = {
    CONFIG_MISSING = true, CONFIG_INVALID = true, UNKNOWN_ID = true,
    CONTENT_VERSION_MISMATCH = true,
    INVALID_REQUEST = true, SLOT_LIMIT = true,
    TOKEN_UNAVAILABLE = true, DUPLICATE_TOKEN = true,
    DUPLICATE_POLICY_MISSING = true, DUPLICATE_NOT_ALLOWED = true,
    INVENTORY_SHORT = true, SPECIAL_ITEM_UNAVAILABLE = true,
    ORDER_LOCKED = true, INVALID_ORDER_STATE = true, STALE_BASELINE = true,
    CONTENT_UNCOVERED = true, NARRATIVE_CONFLICT = true,
    FILL_SOURCE_MISSING = true, RATING_UNCOVERED = true,
    SAVE_ENCODE_FAILED = true, SAVE_WRITE_FAILED = true, SAVE_VERIFY_FAILED = true,
    SAVE_CORRUPT = true, SAVE_VERSION_UNSUPPORTED = true, SAVE_MIGRATION_REQUIRED = true,
}

-- ============================================================================
-- 小工具
-- ============================================================================

---@param v any
---@return boolean
local function IsInteger(v)
    return type(v) == "number" and v % 1 == 0
end

---@param v any
---@return boolean
local function IsNonNegativeInteger(v)
    return IsInteger(v) and v >= 0
end

---@param v any
---@return boolean
local function IsFiniteNumber(v)
    return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

-- ============================================================================
-- 索引
-- ============================================================================

---@type table<string, table>
local effectsById_ = {}
---@type table<string, table>
local wordsById_ = {}
---@type table<string, table|false>
local wordsByText_ = {}
---@type table<string, table>
local ingredientsById_ = {}
---@type table<string, table>
local equipmentById_ = {}
---@type table<string, table>
local npcsById_ = {}
---@type table<string, table>
local lettersById_ = {}
---@type table<string, table>
local attributeProfilesById_ = {}
---@type table<string, table>
local followupTemplatesById_ = {}
---@type table<string, table>
local fragmentsById_ = {}
---@type table<string, table>
local directRulesById_ = {}
---@type table<string, table>
local ratingsById_ = {}
---@type table<string, table[]>
local directRulesBySet_ = {}
---@type table<string, table[]>
local ratingsBySet_ = {}

local loaded_ = false

---@param list table[]
---@param index table<string, table?>
---@param errors string[]
---@param tableName string
local function IndexById(list, index, errors, tableName)
    for i = 1, #list do
        local item = list[i]
        if type(item) ~= "table" or type(item.id) ~= "string" or item.id == "" then
            errors[#errors + 1] = string.format("%s 第 %d 条缺少合法的 id", tableName, i)
        elseif index[item.id] then
            errors[#errors + 1] = string.format("%s 里 id 重复：%s", tableName, item.id)
        else
            index[item.id] = item
        end
    end
end

--- 按集合 ID 建立分组索引（规则集 / 评分集）。
---@param list table[]
---@param index table<string, table[]>
---@param setIdField string
local function IndexBySetId(list, index, setIdField)
    for i = 1, #list do
        local item = list[i]
        if type(item) == "table" and type(item[setIdField]) == "string" then
            local bucket = index[item[setIdField]]
            if not bucket then
                bucket = {}
                index[item[setIdField]] = bucket
            end
            bucket[#bucket + 1] = item
        end
    end
end

--- 校验订单条件各 kind 的必填字段（Load 级结构检查）。
---@param cond table
---@param path string
---@param errors string[]
local function CheckConditionFields(cond, path, errors)
    if type(cond.id) ~= "string" or cond.id == "" then
        errors[#errors + 1] = string.format("%s 缺少条件 id", path)
    end
    if cond.kind == "duration" then
        if not (IsFiniteNumber(cond.minHours) and IsFiniteNumber(cond.maxHours) and cond.minHours < cond.maxHours) then
            errors[#errors + 1] = string.format("%s 的 duration 条件必须给出 minHours < maxHours", path)
        end
    elseif cond.kind == "onset" then
        if not (IsFiniteNumber(cond.maxDelayHours) and cond.maxDelayHours >= 0) then
            errors[#errors + 1] = string.format("%s 的 onset 条件必须给出非负的 maxDelayHours", path)
        end
    elseif cond.kind == "workReady" then
        if not (IsFiniteNumber(cond.workAfterDoseHours) and cond.workAfterDoseHours > 0) then
            errors[#errors + 1] = string.format("%s 的 workReady 条件必须给出正的 workAfterDoseHours", path)
        end
    elseif cond.kind == "residualAt" then
        if type(cond.effectId) ~= "string" or not effectsById_[cond.effectId] then
            errors[#errors + 1] = string.format("%s 的 residualAt 引用了不存在的效果：%s", path, tostring(cond.effectId))
        end
        if not (IsFiniteNumber(cond.atAfterDoseHours) and cond.atAfterDoseHours >= 0) then
            errors[#errors + 1] = string.format("%s 的 residualAt 必须给出非负的 atAfterDoseHours", path)
        end
        if not (IsFiniteNumber(cond.maxWeight) and cond.maxWeight >= 0) then
            errors[#errors + 1] = string.format("%s 的 residualAt 必须给出非负的 maxWeight", path)
        end
    elseif cond.kind == "forbiddenEffect" then
        if type(cond.effectId) ~= "string" or not effectsById_[cond.effectId] then
            errors[#errors + 1] = string.format("%s 的 forbiddenEffect 引用了不存在的效果：%s", path, tostring(cond.effectId))
        end
        if cond.maxWeight ~= nil and not (IsFiniteNumber(cond.maxWeight) and cond.maxWeight >= 0) then
            errors[#errors + 1] = string.format("%s 的 forbiddenEffect 的 maxWeight 必须是非负数", path)
        end
    end
end

-- ============================================================================
-- 基础校验（Data.Load）
-- ============================================================================

--- 建立索引并做交叉校验。在 main.lua 启动时调用一次。
---@return boolean ok
---@return string[] errors 校验失败时的原因列表，可直接打印给文案同学定位
function Data.Load()
    effectsById_, wordsById_, wordsByText_ = {}, {}, {}
    ingredientsById_, equipmentById_, npcsById_, lettersById_ = {}, {}, {}, {}
    attributeProfilesById_, followupTemplatesById_, fragmentsById_ = {}, {}, {}
    directRulesById_, ratingsById_ = {}, {}
    directRulesBySet_, ratingsBySet_ = {}, {}

    local errors = {}

    IndexById(Data.effects, effectsById_, errors, "effects.lua")
    IndexById(Data.words, wordsById_, errors, "words.lua")
    IndexById(Data.ingredients, ingredientsById_, errors, "ingredients.lua")
    IndexById(Data.equipment, equipmentById_, errors, "equipment.lua")
    IndexById(Data.npcs, npcsById_, errors, "npcs.lua")
    IndexById(Data.letters, lettersById_, errors, "letters.lua")
    IndexById(Data.attributeProfiles, attributeProfilesById_, errors, "stage1.lua attributeProfiles")
    IndexById(Data.followupTemplates, followupTemplatesById_, errors, "followup.lua followupTemplates")
    IndexById(Data.fragments, fragmentsById_, errors, "followup.lua fragments")
    IndexById(Data.directRules, directRulesById_, errors, "followup.lua directRules")
    IndexById(Data.orderRatings, ratingsById_, errors, "followup.lua orderRatings")
    IndexBySetId(Data.directRules, directRulesBySet_, "ruleSetId")
    IndexBySetId(Data.orderRatings, ratingsBySet_, "ratingSetId")

    loaded_ = true

    -- 同字不同定义须由信件的cutWordIds按位置辨别；无映射的旧标记仍要求字面唯一。
    for i = 1, #Data.words do
        local word = Data.words[i]
        if type(word.displayText) == "string" and word.displayText ~= "" then
            if wordsByText_[word.displayText] ~= nil then
                wordsByText_[word.displayText] = false
            else
                wordsByText_[word.displayText] = word
            end
        elseif type(word.id) == "string" then
            errors[#errors + 1] = string.format("words.lua 的 %s 缺少 displayText", word.id)
        end
    end

    -- 词条：效果标签存在、reusable 显式、时间属性 profile 引用存在
    for i = 1, #Data.words do
        local word = Data.words[i]
        if type(word.effects) == "table" then
            for tag in pairs(word.effects) do
                if not effectsById_[tag] then
                    errors[#errors + 1] = string.format(
                        "words.lua 的 %s 引用了不存在的效果标签：%s", tostring(word.id), tostring(tag)
                    )
                end
            end
        end
        if word.reusable == nil then
            errors[#errors + 1] = string.format("words.lua 的 %s 缺少 reusable 字段", tostring(word.id))
        end
        if word.attributeProfileId ~= nil then
            if type(word.attributeProfileId) ~= "string" or not attributeProfilesById_[word.attributeProfileId] then
                errors[#errors + 1] = string.format(
                    "words.lua 的 %s 引用了不存在的 attributeProfileId：%s",
                    tostring(word.id), tostring(word.attributeProfileId)
                )
            end
        end
    end

    -- 原料的属性键必须是允许的 5 项之一
    for i = 1, #Data.ingredients do
        local ing = Data.ingredients[i]
        if type(ing.mods) == "table" then
            for key in pairs(ing.mods) do
                if not ALLOWED_MOD_KEYS[key] then
                    errors[#errors + 1] = string.format(
                        "ingredients.lua 的 %s 用了未知属性键「%s」（允许：intensity / duration / speed / stability / sideEffect）",
                        tostring(ing.id), tostring(key)
                    )
                end
            end
        end
        if type(ing.addTags) == "table" then
            for tag in pairs(ing.addTags) do
                if not effectsById_[tag] then
                    errors[#errors + 1] = string.format(
                        "ingredients.lua 的 %s 引用了不存在的效果标签：%s", tostring(ing.id), tostring(tag)
                    )
                end
            end
        end
    end

    -- 设备的槽位必须四键齐全
    for i = 1, #Data.equipment do
        local kit = Data.equipment[i]
        if type(kit.slots) ~= "table" then
            errors[#errors + 1] = string.format("equipment.lua 的 %s 缺少 slots", tostring(kit.id))
        else
            for k = 1, #REQUIRED_SLOT_KEYS do
                local key = REQUIRED_SLOT_KEYS[k]
                if type(kit.slots[key]) ~= "number" then
                    errors[#errors + 1] = string.format(
                        "equipment.lua 的 %s 槽位缺少 %s", tostring(kit.id), key
                    )
                end
            end
        end
    end

    -- 信件：寄信人存在、按 kind 分类型校验
    for i = 1, #Data.letters do
        ---@type table
        local letter = Data.letters[i]
        local fallbackName = "letters.lua 第 " .. i .. " 条"
        local letterName = (type(letter.id) == "string" and letter.id ~= "") and letter.id or fallbackName

        if type(letter.senderId) == "string" and not npcsById_[letter.senderId] then
            errors[#errors + 1] = string.format(
                "%s 的寄信人 %s 不存在于 npcs.lua", letterName, letter.senderId
            )
        end

        if letter.kind ~= "order" and letter.kind ~= "direct_followup" then
            errors[#errors + 1] = string.format(
                "%s 的 kind 必须是 order 或 direct_followup（当前：%s）", letterName, tostring(letter.kind)
            )
        end
        if type(letter.cuttable) ~= "boolean" then
            errors[#errors + 1] = string.format("%s 缺少 cuttable 布尔值（显式 true/false，不可缺省）", letterName)
        end

        if letter.kind == "order" then
            -- order：正文必须存在；cuttable 与 {{词}} 标记必须一致
            if type(letter.body) == "string" then
                local cutCount = 0
                for marked in string.gmatch(letter.body, "{{(.-)}}") do
                    cutCount = cutCount + 1
                    local mapped = letter.cutWordIds
                    local word = mapped and type(mapped) == "table" and wordsById_[mapped[cutCount]] or nil
                    if mapped ~= nil and (not word or word.displayText ~= marked) then
                        errors[#errors + 1] = string.format("%s 的 cutWordIds 第 %d 位与正文不对应", letterName, cutCount)
                    elseif mapped == nil and not wordsByText_[marked] then
                        errors[#errors + 1] = string.format(
                            "%s 正文里标记了「%s」，但 words.lua 里没有 displayText 为「%s」的词条",
                            letterName, marked, marked
                        )
                    end
                end
                if letter.cutWordIds ~= nil then
                    local ids = letter.cutWordIds
                    if type(ids) ~= "table" or #ids ~= cutCount then
                        errors[#errors + 1] = string.format("%s 的 cutWordIds 数量与正文标记不对应", letterName)
                    else
                        for key in pairs(ids) do
                            if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > cutCount then
                                errors[#errors + 1] = string.format("%s 的 cutWordIds 必须为稠密数组", letterName)
                            end
                        end
                    end
                end
                if letter.cuttable == true and cutCount == 0 then
                    errors[#errors + 1] = string.format("%s 声明可剪但正文里没有任何 {{词}} 标记", letterName)
                elseif letter.cuttable == false and cutCount > 0 then
                    errors[#errors + 1] = string.format("%s 声明 cuttable=false，正文不应出现 {{词}} 标记", letterName)
                end
            else
                errors[#errors + 1] = string.format("%s 缺少 body", letterName)
            end

            -- requirement：tags 必须存在，conditions 按 kind 校验，禁止效果显式声明
            if type(letter.requirement) ~= "table" then
                errors[#errors + 1] = string.format("%s 缺少 requirement", letterName)
            else
                ---@type table
                local req = letter.requirement
                if type(req.tags) ~= "table" then
                    errors[#errors + 1] = string.format("%s 的 requirement 缺少 tags", letterName)
                else
                    for tag in pairs(req.tags) do
                        if not effectsById_[tag] then
                            errors[#errors + 1] = string.format(
                                "%s 的订单要求引用了不存在的效果标签：%s", letterName, tostring(tag)
                            )
                        end
                    end
                end
                if req.conditions ~= nil then
                    if type(req.conditions) ~= "table" then
                        errors[#errors + 1] = string.format("%s 的 requirement.conditions 必须是数组", letterName)
                    else
                        for c = 1, #req.conditions do
                            local cond = req.conditions[c]
                            local cpath = string.format("%s.requirement.conditions[%d]", letterName, c)
                            if type(cond) ~= "table" or type(cond.kind) ~= "string" or not CONDITION_KINDS[cond.kind] then
                                errors[#errors + 1] = string.format(
                                    "%s 的 kind 非法（允许：duration / onset / workReady / residualAt / forbiddenEffect）", cpath
                                )
                            else
                                CheckConditionFields(cond, cpath, errors)
                            end
                        end
                    end
                end
                if req.forbiddenEffects ~= nil and type(req.forbiddenEffects) ~= "table" then
                    errors[#errors + 1] = string.format("%s 的 requirement.forbiddenEffects 必须是数组（没有禁止项时显式写空表）", letterName)
                end
            end

            -- 固定报酬：非负整数
            if type(letter.reward) ~= "table" or not IsNonNegativeInteger(letter.reward.currency) then
                errors[#errors + 1] = string.format("%s 缺少合法的 reward.currency（非负整数）", letterName)
            end

            -- 规则集 / 模板 / 评分集引用必须可解析
            if type(letter.directRuleSetId) ~= "string" or not directRulesBySet_[letter.directRuleSetId] then
                errors[#errors + 1] = string.format(
                    "%s 的 directRuleSetId 缺失或在 followup.lua 中没有对应规则：%s",
                    letterName, tostring(letter.directRuleSetId)
                )
            end
            if type(letter.followupTemplateId) ~= "string" or not followupTemplatesById_[letter.followupTemplateId] then
                errors[#errors + 1] = string.format(
                    "%s 的 followupTemplateId 缺失或不存在：%s", letterName, tostring(letter.followupTemplateId)
                )
            end
            if type(letter.ratingSetId) ~= "string" or not ratingsBySet_[letter.ratingSetId] then
                errors[#errors + 1] = string.format(
                    "%s 的 ratingSetId 缺失或在 followup.lua 中没有对应规则：%s",
                    letterName, tostring(letter.ratingSetId)
                )
            end
        elseif letter.kind == "direct_followup" then
            -- 直接回信：不可剪、无订单、无报酬；正文由模板组装，本文不重复写
            if letter.cuttable ~= false then
                errors[#errors + 1] = string.format("%s 是直接回信，cuttable 必须显式 false", letterName)
            end
            if type(letter.body) == "string" then
                for marked in string.gmatch(letter.body, "{{(.-)}}") do
                    errors[#errors + 1] = string.format(
                        "%s 是直接回信，正文不得有可剪标记「%s」", letterName, marked
                    )
                    break
                end
            end
            if letter.requirement ~= nil then
                errors[#errors + 1] = string.format("%s 是直接回信，不应配置 requirement（没有新订单）", letterName)
            end
            if letter.reward ~= nil then
                errors[#errors + 1] = string.format("%s 是直接回信，不应配置 reward", letterName)
            end
            if type(letter.followupTemplateId) ~= "string" or not followupTemplatesById_[letter.followupTemplateId] then
                errors[#errors + 1] = string.format(
                    "%s 的 followupTemplateId 缺失或不存在：%s", letterName, tostring(letter.followupTemplateId)
                )
            end
        end

        -- 地址：订单信必须有；直接回信可选
        if letter.kind == "order" and (type(letter.address) ~= "string" or letter.address == "") then
            errors[#errors + 1] = string.format("%s 缺少详细地址（设计上每封订单信都必须有地址）", letterName)
        end
    end

    -- 后续模板：指向 direct_followup 信、文本齐备、片段引用与归属正确
    for i = 1, #Data.followupTemplates do
        local tpl = Data.followupTemplates[i]
        local tplName = (type(tpl.id) == "string" and tpl.id ~= "") and tpl.id or ("followup.lua 第 " .. i .. " 条模板")
        local letter = (type(tpl.letterId) == "string") and lettersById_[tpl.letterId] or nil
        if not letter then
            errors[#errors + 1] = string.format("%s 指向不存在的信：%s", tplName, tostring(tpl.letterId))
        elseif letter.kind ~= "direct_followup" then
            errors[#errors + 1] = string.format("%s 指向的信 %s 不是 direct_followup", tplName, tostring(tpl.letterId))
        end
        if type(tpl.opening) ~= "string" then
            errors[#errors + 1] = string.format("%s 缺少 opening", tplName)
        end
        if type(tpl.closing) ~= "string" then
            errors[#errors + 1] = string.format("%s 缺少 closing", tplName)
        end
        local function CheckFragmentList(listName, ids)
            if type(ids) ~= "table" then
                errors[#errors + 1] = string.format("%s 的 %s 必须是数组", tplName, listName)
                return
            end
            for k = 1, #ids do
                local frag = fragmentsById_[ids[k]]
                if not frag then
                    errors[#errors + 1] = string.format("%s 的 %s 引用了不存在的片段：%s", tplName, listName, tostring(ids[k]))
                elseif frag.templateId ~= tpl.id then
                    errors[#errors + 1] = string.format(
                        "片段 %s 的 templateId（%s）与引用它的模板 %s 不一致",
                        tostring(ids[k]), tostring(frag.templateId), tplName
                    )
                end
            end
        end
        CheckFragmentList("baseFragmentIds", tpl.baseFragmentIds)
        CheckFragmentList("fragmentIds", tpl.fragmentIds)
        CheckFragmentList("fallbackFragmentIds", tpl.fallbackFragmentIds)
    end

    -- 片段：类型、模板归属、引用的效果标签
    for i = 1, #Data.fragments do
        local frag = Data.fragments[i]
        local fragName = (type(frag.id) == "string" and frag.id ~= "") and frag.id or ("followup.lua 第 " .. i .. " 条片段")
        if frag.kind ~= nil and not FRAGMENT_KINDS[frag.kind] then
            errors[#errors + 1] = string.format(
                "%s 的 kind 非法（允许：key / combination / single / generic）", fragName
            )
        end
        if type(frag.templateId) ~= "string" or not followupTemplatesById_[frag.templateId] then
            errors[#errors + 1] = string.format("%s 的 templateId 缺失或不存在：%s", fragName, tostring(frag.templateId))
        end
        if type(frag.text) ~= "string" or frag.text == "" then
            errors[#errors + 1] = string.format("%s 缺少 text", fragName)
        end
    end

    -- 评分规则：星级与集合声明
    for i = 1, #Data.orderRatings do
        ---@type table
        local rule = Data.orderRatings[i]
        local ruleName = (type(rule.id) == "string" and rule.id ~= "") and rule.id or ("followup.lua 第 " .. i .. " 条评分规则")
        if rule.stars ~= 1 and rule.stars ~= 2 and rule.stars ~= 3 then
            errors[#errors + 1] = string.format("%s 的 stars 只能是 1、2、3（当前：%s）", ruleName, tostring(rule.stars))
        end
        if type(rule.ratingSetId) ~= "string" or rule.ratingSetId == "" then
            errors[#errors + 1] = string.format("%s 缺少 ratingSetId", ruleName)
        end
    end

    if #errors > 0 then
        print("========== 内容配置校验失败 ==========")
        for i = 1, #errors do
            print(string.format("  [%d] %s", i, errors[i]))
        end
        print("======================================")
        return false, errors
    end

    print(string.format(
        "[Data] 校验通过：效果 %d / 词条 %d / 原料 %d / 设备 %d / 人物 %d / 信件 %d / 时间属性 %d / 规则 %d / 片段 %d / 评分 %d",
        #Data.effects, #Data.words, #Data.ingredients, #Data.equipment, #Data.npcs, #Data.letters,
        #Data.attributeProfiles, #Data.directRules, #Data.fragments, #Data.orderRatings
    ))
    return true, {}
end

-- ============================================================================
-- 查询
-- ============================================================================

---@param id string
---@return table|nil
function Data.GetWord(id)
    return wordsById_[id]
end

--- 按显示文本查词条。解析信件正文里的 {{词}} 标记时使用。
---@param text string
---@return table|nil
function Data.GetWordByText(text)
    return wordsByText_[text] or nil
end

---@param id string
---@return table|nil
function Data.GetEffect(id)
    return effectsById_[id]
end

---@param id string
---@return table|nil
function Data.GetIngredient(id)
    return ingredientsById_[id]
end

---@param id string
---@return table|nil
function Data.GetEquipment(id)
    return equipmentById_[id]
end

---@param id string
---@return table|nil
function Data.GetNpc(id)
    return npcsById_[id]
end

---@param id string
---@return table|nil
function Data.GetLetter(id)
    return lettersById_[id]
end

---@param id string
---@return table|nil
function Data.GetAttributeProfile(id)
    return attributeProfilesById_[id]
end

---@param id string
---@return table|nil
function Data.GetFollowupTemplate(id)
    return followupTemplatesById_[id]
end

---@param id string
---@return table|nil
function Data.GetFragment(id)
    return fragmentsById_[id]
end

--- 返回某个规则集的全部事实规则（调用者只读，不得修改配置表）。
---@param ruleSetId string
---@return table[]
function Data.GetDirectRulesOf(ruleSetId)
    return directRulesBySet_[ruleSetId] or {}
end

--- 返回某个评分集的全部评分规则（调用者只读，不得修改配置表）。
---@param ratingSetId string
---@return table[]
function Data.GetRatingRulesOf(ratingSetId)
    return ratingsBySet_[ratingSetId] or {}
end

--- 取出某封信正文里全部可剪词（按出现顺序，可能重复）。
---@param letterId string
---@return string[] 词条的 displayText 列表
function Data.GetCuttableWordsOf(letterId)
    local letter = lettersById_[letterId]
    if not letter or type(letter.body) ~= "string" then
        return {}
    end
    local result = {}
    for marked in string.gmatch(letter.body, "{{(.-)}}") do
        result[#result + 1] = marked
    end
    return result
end

-- ============================================================================
-- 首单包完整性校验（Data.ValidateStage1）
-- ============================================================================

--- 校验 schema 与值是否匹配（enum / text / integer / number / boolean / map）。
---@param value any
---@param schema table
---@param path string
---@param errors string[]
local function CheckValueAgainstSchema(value, schema, path, errors)
    if type(schema) ~= "table" or type(schema.type) ~= "string" then
        errors[#errors + 1] = string.format("%s 的 schema 缺少 type", path)
        return
    end
    local t = schema.type
    if t == "enum" then
        local matched = false
        if type(schema.values) == "table" then
            for i = 1, #schema.values do
                if value == schema.values[i] then
                    matched = true
                    break
                end
            end
        end
        if not matched then
            errors[#errors + 1] = string.format("%s 的值 %s 不在允许集合内（%s）", path, tostring(value), tostring(schema.desc))
        end
    elseif t == "text" then
        if type(value) ~= "string" or value == "" then
            errors[#errors + 1] = string.format("%s 必须是非空字符串", path)
        end
    elseif t == "integer" then
        if not IsInteger(value) then
            errors[#errors + 1] = string.format("%s 必须是整数（当前：%s）", path, tostring(value))
        end
    elseif t == "number" then
        if not IsFiniteNumber(value) then
            errors[#errors + 1] = string.format("%s 必须是有限数（当前：%s）", path, tostring(value))
        end
    elseif t == "boolean" then
        if type(value) ~= "boolean" then
            errors[#errors + 1] = string.format("%s 必须是布尔值", path)
        end
    elseif t == "map" then
        if type(value) ~= "table" then
            errors[#errors + 1] = string.format("%s 必须是对象", path)
            return
        end
        if type(schema.keys) == "table" then
            for i = 1, #schema.keys do
                local key = schema.keys[i]
                if value[key] == nil then
                    errors[#errors + 1] = string.format("%s 缺少声明的键 %s", path, tostring(key))
                end
            end
        end
        if type(schema.entry) == "table" then
            for mapKey, entryValue in pairs(value) do
                for fieldName, fieldSchema in pairs(schema.entry) do
                    if entryValue[fieldName] == nil then
                        errors[#errors + 1] = string.format("%s.%s 缺少字段 %s", path, tostring(mapKey), tostring(fieldName))
                    else
                        CheckValueAgainstSchema(entryValue[fieldName], fieldSchema, string.format("%s.%s.%s", path, tostring(mapKey), tostring(fieldName)), errors)
                    end
                end
            end
        end
    else
        errors[#errors + 1] = string.format("%s 的 schema.type 未知：%s", path, tostring(t))
    end
end

--- 解析「相对人物」的字段路径（changes 去掉 world.npcs. 之后、bindings 的 path）。
---@param relPath string
---@param errors string[]
---@param label string
---@return boolean
local function ResolveNpcRelativePath(relPath, errors, label)
    if type(relPath) ~= "string" or relPath == "" then
        errors[#errors + 1] = string.format("%s 缺少路径", label)
        return false
    end
    ---@type string[]
    local parts = {}
    for seg in string.gmatch(relPath, "[^.]+") do
        parts[#parts + 1] = seg
    end
    local npc = npcsById_[parts[1]]
    if not npc then
        errors[#errors + 1] = string.format("%s 指向不存在的人物：%s", label, tostring(parts[1]))
        return false
    end
    local node = npc.initialState
    for i = 2, #parts do
        if type(node) ~= "table" then
            errors[#errors + 1] = string.format("%s 的字段 %s 不存在于人物初态", label, parts[i])
            return false
        end
        node = node[parts[i]]
    end
    if node == nil then
        errors[#errors + 1] = string.format("%s 的字段路径不存在于人物初态：%s", label, relPath)
        return false
    end
    return true
end

--- 校验条件数组（when / unless）。
---@param conditions table|nil
---@param owner string
---@param fieldName string
---@param errors string[]
local function CheckConditions(conditions, owner, fieldName, errors)
    if conditions == nil then
        return
    end
    if type(conditions) ~= "table" then
        errors[#errors + 1] = string.format("%s 的 %s 必须是数组", owner, fieldName)
        return
    end
    for i = 1, #conditions do
        local cond = conditions[i]
        local path = string.format("%s.%s[%d]", owner, fieldName, i)
        if type(cond) ~= "table" then
            errors[#errors + 1] = string.format("%s 必须是条件表", path)
        else
            if type(cond.source) ~= "string" or not BINDING_SOURCES[cond.source] then
                errors[#errors + 1] = string.format(
                    "%s 的 source 非法（允许：potion.effects / world.npcs / context / facts）", path
                )
            end
            if type(cond.path) ~= "string" or cond.path == "" then
                errors[#errors + 1] = string.format("%s 缺少 path", path)
            end
            if type(cond.op) ~= "string" or not RULE_OPS[cond.op] then
                errors[#errors + 1] = string.format("%s 的 op 非法（允许：eq / ne / gte / lte）", path)
            end
            if cond.value == nil then
                errors[#errors + 1] = string.format("%s 缺少 value", path)
            end
        end
    end
end

--- 校验事实引用是否存在；requiresFacts 另检查互斥组冲突（同时要求同组两个事实
--- 永远不可能成立）。excludes / covers 允许同时出现同组事实（「两个都不要」是合法条件）。
---@param factRefs table|nil
---@param owner string
---@param fieldName string
---@param factIds table<string, boolean>
---@param groupOf table<string, string?>
---@param checkGroupConflict boolean
---@param errors string[]
local function CheckFactRefs(factRefs, owner, fieldName, factIds, groupOf, checkGroupConflict, errors)
    if factRefs == nil then
        return
    end
    if type(factRefs) ~= "table" then
        errors[#errors + 1] = string.format("%s 的 %s 必须是数组", owner, fieldName)
        return
    end
    local groupSeen = {}
    for i = 1, #factRefs do
        local factId = factRefs[i]
        if type(factId) ~= "string" or not factIds[factId] then
            errors[#errors + 1] = string.format("%s 的 %s 引用了未定义事实：%s", owner, fieldName, tostring(factId))
        elseif checkGroupConflict then
            local group = groupOf[factId]
            if group then
                if groupSeen[group] then
                    errors[#errors + 1] = string.format(
                        "%s 的 %s 同时要求互斥组 %s 的两个事实，永远不可能同时成立", owner, fieldName, group
                    )
                end
                groupSeen[group] = true
            end
        end
    end
end

--- 首单包完整性校验（B1 队友交付 C1/C2/C3 的机器检查）。
--- 在 Data.Load 之后调用；任何一条失败都应阻止开局或受影响操作，
--- 并显示带 [C1]/[C2]/[C3] 前缀的具体路径。
---@return boolean ok
---@return string[] errors
function Data.ValidateStage1()
    if not loaded_ then
        Data.Load()
    end

    local errors = {}
    local stage1 = Data.stage1

    if type(stage1) ~= "table" then
        return false, { "[C1] data/stage1.lua 无法读取" }
    end

    -- ------------------------------------------------------------------
    -- C1：内容版本与开局账本
    -- ------------------------------------------------------------------
    if type(stage1.contentVersion) ~= "string" or stage1.contentVersion == "" then
        errors[#errors + 1] = "[C1] stage1.contentVersion 必须是非空字符串（整包内容修订标识）"
    end

    local economy = stage1.initialEconomy
    if type(economy) ~= "table" then
        errors[#errors + 1] = "[C1] stage1.initialEconomy 缺失"
    else
        if not IsNonNegativeInteger(economy.currency) then
            errors[#errors + 1] = "[C1] initialEconomy.currency 必须是明确给出的非负整数（缺省不得补 0）"
        end
        if type(economy.ingredients) ~= "table" then
            errors[#errors + 1] = "[C1] initialEconomy.ingredients 缺失"
        else
            local expectedIngredients = { "ing_sea_salt", "ing_night_dew", "ing_ashen_herb", "ing_dried_petal" }
            for i = 1, #expectedIngredients do
                local ingId = expectedIngredients[i]
                local count = economy.ingredients[ingId]
                if count == nil then
                    errors[#errors + 1] = string.format("[C1] initialEconomy.ingredients 缺少已接受的四种原料之一：%s", ingId)
                elseif not IsNonNegativeInteger(count) then
                    errors[#errors + 1] = string.format("[C1] initialEconomy.ingredients.%s 必须是非负整数（当前：%s）", ingId, tostring(count))
                end
            end
            for ingId, count in pairs(economy.ingredients) do
                if not ingredientsById_[ingId] then
                    errors[#errors + 1] = string.format("[C1] initialEconomy.ingredients 出现未知材料 ID：%s", tostring(ingId))
                elseif not IsNonNegativeInteger(count) then
                    errors[#errors + 1] = string.format("[C1] initialEconomy.ingredients.%s 必须是非负整数（当前：%s）", tostring(ingId), tostring(count))
                end
            end
        end
        local specialItems = economy.specialItems
        if type(specialItems) ~= "table" then
            errors[#errors + 1] = "[C1] initialEconomy.specialItems 必须显式为空集合 {}"
        elseif #specialItems ~= 0 then
            errors[#errors + 1] = "[C1] 首信无附件，initialEconomy.specialItems 必须为空集合"
        else
            for key in pairs(specialItems) do
                errors[#errors + 1] = string.format("[C1] initialEconomy.specialItems 必须为空集合（发现键 %s）", tostring(key))
                break
            end
        end
    end

    local startKit = (type(stage1.initialEquipmentId) == "string") and equipmentById_[stage1.initialEquipmentId] or nil
    if not startKit then
        errors[#errors + 1] = string.format("[C1] initialEquipmentId 缺失或不是合法设备：%s", tostring(stage1.initialEquipmentId))
    else
        if startKit.owned ~= true then
            errors[#errors + 1] = string.format("[C1] initialEquipmentId 指向的设备 %s 的 owned 不是 true", startKit.id)
        end
        for i = 1, #Data.equipment do
            local kit = Data.equipment[i]
            if kit.id ~= startKit.id and kit.owned == true then
                errors[#errors + 1] = string.format(
                    "[C1] 设备 %s 的 owned=true 与 initialEquipmentId 不一致（开局只能拥有 %s）",
                    tostring(kit.id), startKit.id
                )
            end
        end
    end

    if type(stage1.errorSamples) ~= "table" or #stage1.errorSamples == 0 then
        errors[#errors + 1] = "[C1] 缺少最小错误样例（缺金币 / 负或小数库存 / 未知 ID）"
    else
        for i = 1, #stage1.errorSamples do
            local sample = stage1.errorSamples[i]
            local sampleName = (type(sample) == "table" and type(sample.id) == "string") and sample.id or ("errorSamples[" .. i .. "]")
            if type(sample) ~= "table" then
                errors[#errors + 1] = string.format("[C1] errorSamples[%d] 必须是表", i)
            else
                if type(sample.path) ~= "string" or sample.path == "" then
                    errors[#errors + 1] = string.format("[C1] %s 缺少 path", sampleName)
                end
                if type(sample.mutation) ~= "table" or type(sample.mutation.op) ~= "string" then
                    errors[#errors + 1] = string.format("[C1] %s 缺少 mutation.op", sampleName)
                end
                if type(sample.expectCode) ~= "string" or not KNOWN_ERROR_CODES[sample.expectCode] then
                    errors[#errors + 1] = string.format("[C1] %s 的 expectCode 不是已知错误码：%s", sampleName, tostring(sample.expectCode))
                end
            end
        end
    end

    -- ------------------------------------------------------------------
    -- C2：投料策略、时间属性与样例
    -- ------------------------------------------------------------------
    local policy = stage1.recipePolicy
    if type(policy) ~= "table"
        or type(policy.repeatIngredient) ~= "boolean"
        or type(policy.repeatWordDefinition) ~= "boolean" then
        errors[#errors + 1] = "[C2] recipePolicy 必须显式给出两个布尔策略（未配置不能猜允许或禁止）"
    end

    if type(stage1.baseline) ~= "table" or type(stage1.baseline.id) ~= "string" then
        errors[#errors + 1] = "[C2] stage1.baseline 缺少 id"
    end

    -- 时间属性 profile
    if type(Data.attributeProfiles) ~= "table" or #Data.attributeProfiles == 0 then
        errors[#errors + 1] = "[C2] stage1.attributeProfiles 为空，时间换算无法进行"
    else
        for i = 1, #Data.attributeProfiles do
            local profile = Data.attributeProfiles[i]
            local pName = "attributeProfiles." .. tostring(profile.id or i)
            if not (IsFiniteNumber(profile.baseDurationHours) and profile.baseDurationHours >= 0) then
                errors[#errors + 1] = string.format("[C2] %s.baseDurationHours 必须是非负有限数", pName)
            end
            if not IsFiniteNumber(profile.durationHoursPerPoint) then
                errors[#errors + 1] = string.format("[C2] %s.durationHoursPerPoint 必须是有限数", pName)
            end
            if not (IsFiniteNumber(profile.recoveryAfterEndHours) and profile.recoveryAfterEndHours >= 0) then
                errors[#errors + 1] = string.format("[C2] %s.recoveryAfterEndHours 必须是非负有限数", pName)
            end
            if type(profile.speedToDelayHours) ~= "table" or #profile.speedToDelayHours == 0 then
                errors[#errors + 1] = string.format("[C2] %s.speedToDelayHours 为空（必须精确映射首单可达速度值）", pName)
            else
                local lastSpeed = nil
                for k = 1, #profile.speedToDelayHours do
                    ---@type table
                    local entry = profile.speedToDelayHours[k]
                    local entryPath = string.format("%s.speedToDelayHours[%d]", pName, k)
                    if type(entry) ~= "table" or not IsFiniteNumber(entry.speed) or not IsFiniteNumber(entry.delayHours) then
                        errors[#errors + 1] = string.format("[C2] %s 必须提供 speed / delayHours 数值", entryPath)
                    else
                        if entry.delayHours < 0 then
                            errors[#errors + 1] = string.format("[C2] %s.delayHours 不能为负", entryPath)
                        end
                        if lastSpeed ~= nil and entry.speed <= lastSpeed then
                            errors[#errors + 1] = string.format("[C2] %s 的 speed 必须严格递增且不重复", entryPath)
                        end
                        lastSpeed = entry.speed
                    end
                end
            end
            if type(profile.residualRules) ~= "table" or #profile.residualRules == 0 then
                errors[#errors + 1] = string.format("[C2] %s.residualRules 为空（首单需要 sleep 残留表）", pName)
            else
                for k = 1, #profile.residualRules do
                    local rule = profile.residualRules[k]
                    local rPath = string.format("%s.residualRules[%d]", pName, k)
                    if type(rule) ~= "table" or type(rule.effectId) ~= "string" or not effectsById_[rule.effectId] then
                        errors[#errors + 1] = string.format("[C2] %s 引用了不存在的效果", rPath)
                    end
                    if type(rule) ~= "table" or type(rule.points) ~= "table" or #rule.points == 0 then
                        errors[#errors + 1] = string.format("[C2] %s.points 必须是非空数组", rPath)
                    else
                        local lastHour, lastRatio = nil, nil
                        for p = 1, #rule.points do
                            ---@type table
                            local point = rule.points[p]
                            local pPath = string.format("%s.points[%d]", rPath, p)
                            if type(point) ~= "table" or not IsInteger(point.hoursAfterEnd) or not IsFiniteNumber(point.ratio) then
                                errors[#errors + 1] = string.format("[C2] %s 必须提供整数 hoursAfterEnd 与数值 ratio", pPath)
                            else
                                if point.hoursAfterEnd < 0 then
                                    errors[#errors + 1] = string.format("[C2] %s.hoursAfterEnd 不能为负", pPath)
                                end
                                if p == 1 and point.hoursAfterEnd ~= 0 then
                                    errors[#errors + 1] = string.format("[C2] %s 必须从 hoursAfterEnd = 0 开始", pPath)
                                end
                                if lastHour ~= nil and point.hoursAfterEnd ~= lastHour + 1 then
                                    errors[#errors + 1] = string.format("[C2] %s 必须按整小时连续（上一点 %d）", pPath, lastHour)
                                end
                                if point.ratio < 0 or point.ratio > 1 then
                                    errors[#errors + 1] = string.format("[C2] %s.ratio 必须在 0~1 之间", pPath)
                                end
                                if lastRatio ~= nil and point.ratio > lastRatio then
                                    errors[#errors + 1] = string.format("[C2] %s.ratio 必须单调不增（残留只会衰减）", pPath)
                                end
                                lastHour, lastRatio = point.hoursAfterEnd, point.ratio
                            end
                        end
                    end
                end
            end
        end
    end

    -- 样例：结构、槽位、主词 profile、期望字段
    local cases = stage1.sampleCases
    if type(cases) ~= "table" or #cases == 0 then
        errors[#errors + 1] = "[C2] stage1.sampleCases 为空（必须交付 A~F 与至少三组同主词不同原料）"
    else
        local caseIdSet = {}
        for i = 1, #cases do
            local case = cases[i]
            local caseName = "sampleCases." .. tostring(case and (case.id or i))
            if type(case) ~= "table" then
                errors[#errors + 1] = string.format("[C2] %s 必须是表", caseName)
            else
                caseIdSet[case.id] = true
                local recipe = case.recipe
                if type(recipe) ~= "table" then
                    errors[#errors + 1] = string.format("[C2] %s.recipe 缺失", caseName)
                else
                    local kit = equipmentById_[recipe.equipmentId]
                    local mainWord = wordsById_[recipe.mainWordId]
                    if not kit then
                        errors[#errors + 1] = string.format("[C2] %s 使用了未知设备 %s", caseName, tostring(recipe.equipmentId))
                    end
                    if not mainWord then
                        errors[#errors + 1] = string.format("[C2] %s 使用了未知主词 %s", caseName, tostring(recipe.mainWordId))
                    elseif mainWord.attributeProfileId == nil then
                        errors[#errors + 1] = string.format(
                            "[C2] %s 的主词 %s 没有 attributeProfileId，时间换算无法完成", caseName, mainWord.id
                        )
                    end
                    local aux = recipe.auxWordIds or {}
                    if kit and #aux > kit.slots.auxWord then
                        errors[#errors + 1] = string.format("[C2] %s 的辅助词数量超过 %s 的槽位", caseName, kit.id)
                    end
                    local auxSeen = {}
                    for a = 1, #aux do
                        if not wordsById_[aux[a]] then
                            errors[#errors + 1] = string.format("[C2] %s 的辅助词 %s 不存在", caseName, tostring(aux[a]))
                        end
                        if auxSeen[aux[a]] then
                            errors[#errors + 1] = string.format("[C2] %s 的辅助词 %s 重复（策略不允许同定义重复占槽）", caseName, tostring(aux[a]))
                        end
                        auxSeen[aux[a]] = true
                    end
                    local quantityTotal = 0
                    local ingredientSeen = {}
                    local ingredients = recipe.ingredients or {}
                    for g = 1, #ingredients do
                        local row = ingredients[g]
                        if type(row) ~= "table" or not ingredientsById_[row.ingredientId] then
                            errors[#errors + 1] = string.format("[C2] %s 的原料 %s 不存在", caseName, tostring(row and row.ingredientId))
                        elseif not IsNonNegativeInteger(row.quantity) or row.quantity < 1 then
                            errors[#errors + 1] = string.format("[C2] %s 的原料 %s 份数必须是正整数", caseName, tostring(row.ingredientId))
                        else
                            quantityTotal = quantityTotal + row.quantity
                        end
                        if type(row) == "table" and ingredientSeen[row.ingredientId] then
                            errors[#errors + 1] = string.format("[C2] %s 的原料 %s 出现多行（应按 ID 聚合为一行）", caseName, tostring(row.ingredientId))
                        end
                        if type(row) == "table" then
                            ingredientSeen[row.ingredientId] = true
                        end
                    end
                    if kit and quantityTotal > kit.slots.ingredient then
                        errors[#errors + 1] = string.format("[C2] %s 的原料份数 %d 超过 %s 的槽位 %d", caseName, quantityTotal, kit.id, kit.slots.ingredient)
                    end
                    local specialIds = recipe.specialItemIds or {}
                    if kit and #specialIds > kit.slots.specialItem then
                        errors[#errors + 1] = string.format("[C2] %s 的特殊物品超过 %s 的槽位", caseName, kit.id)
                    end
                end
                local expect = case.expect
                if type(expect) ~= "table" then
                    errors[#errors + 1] = string.format("[C2] %s.expect 缺失", caseName)
                else
                    if type(expect.canShip) ~= "boolean" then
                        errors[#errors + 1] = string.format("[C2] %s.expect.canShip 必须是布尔值", caseName)
                    end
                    local failures = expect.failures or {}
                    if expect.canShip == false and #failures == 0 then
                        errors[#errors + 1] = string.format("[C2] %s 预期不可发货，但没有列出失败原因", caseName)
                    end
                    if expect.canShip == true and #failures > 0 then
                        errors[#errors + 1] = string.format("[C2] %s 预期可发货，但仍列有失败原因", caseName)
                    end
                    if type(expect.effects) ~= "table" or next(expect.effects) == nil then
                        errors[#errors + 1] = string.format("[C2] %s.expect.effects 必须给出标签权重", caseName)
                    end
                    if type(expect.tiers) == "table" then
                        for tag in pairs(expect.tiers) do
                            if type(expect.effects) == "table" and expect.effects[tag] == nil then
                                errors[#errors + 1] = string.format("[C2] %s.expect.tiers 的 %s 在 effects 里没有对应权重", caseName, tostring(tag))
                            end
                        end
                    end
                    if not (IsFiniteNumber(expect.durationHours) and expect.durationHours > 0) then
                        errors[#errors + 1] = string.format("[C2] %s.expect.durationHours 必须是正有限数", caseName)
                    end
                    if not (IsFiniteNumber(expect.onsetDelayHours) and expect.onsetDelayHours >= 0) then
                        errors[#errors + 1] = string.format("[C2] %s.expect.onsetDelayHours 必须是非负有限数", caseName)
                    end
                end
            end
        end

        -- A~F 必须齐全
        local requiredCases = { "A", "B", "C", "D", "E", "F" }
        for i = 1, #requiredCases do
            if not caseIdSet[requiredCases[i]] then
                errors[#errors + 1] = string.format("[C2] sampleCases 缺少必需样例 %s", requiredCases[i])
            end
        end

        -- 同主词、不同原料至少 3 种（A13；不能只用换辅助词的 A~D 代替）
        local signatureByMain = {}
        for i = 1, #cases do
            local case = cases[i]
            if type(case) == "table" and type(case.recipe) == "table" and type(case.recipe.mainWordId) == "string" then
                local signatureParts = {}
                local ingredients = case.recipe.ingredients or {}
                for g = 1, #ingredients do
                    local row = ingredients[g]
                    if type(row) == "table" and type(row.ingredientId) == "string" then
                        signatureParts[#signatureParts + 1] = row.ingredientId .. "x" .. tostring(row.quantity)
                    end
                end
                table.sort(signatureParts)
                local signature = table.concat(signatureParts, "+")
                local bucket = signatureByMain[case.recipe.mainWordId]
                if not bucket then
                    bucket = {}
                    signatureByMain[case.recipe.mainWordId] = bucket
                end
                bucket[signature] = true
            end
        end
        local maxVariants = 0
        for _, bucket in pairs(signatureByMain) do
            local count = 0
            for _ in pairs(bucket) do
                count = count + 1
            end
            if count > maxVariants then
                maxVariants = count
            end
        end
        if maxVariants < 3 then
            errors[#errors + 1] = "[C2] 同主词不同原料的样例不足 3 种（A13：不能只用换辅助词的 A~D 代替）"
        end
    end

    -- ------------------------------------------------------------------
    -- C3：人物初态、事实规则、片段、模板与评分
    -- ------------------------------------------------------------------

    -- 人物初态与类型声明
    local passerby = npcsById_["npc_passerby_a"]
    if not passerby then
        errors[#errors + 1] = "[C3] npcs.lua 缺少 npc_passerby_a"
    else
        if type(passerby.initialState) ~= "table" then
            errors[#errors + 1] = "[C3] npc_passerby_a 缺少 initialState"
        end
        if type(passerby.initialStateSchema) ~= "table" then
            errors[#errors + 1] = "[C3] npc_passerby_a 缺少 initialStateSchema（字段类型与允许值）"
        end
        if type(passerby.initialState) == "table" and type(passerby.initialStateSchema) == "table" then
            for fieldName, fieldSchema in pairs(passerby.initialStateSchema) do
                local value = passerby.initialState[fieldName]
                if value == nil then
                    errors[#errors + 1] = string.format("[C3] npc_passerby_a.initialState 缺少字段 %s", tostring(fieldName))
                else
                    CheckValueAgainstSchema(value, fieldSchema, "npc_passerby_a.initialState." .. tostring(fieldName), errors)
                end
            end
        end
        if type(passerby.family) == "string" and string.find(passerby.family, "独居", 1, true) then
            errors[#errors + 1] = "[C3] npc_passerby_a.family 仍写「独居」，与首信「与妹妹两人同住」矛盾"
        end
    end

    -- 事实规则与事实表
    local factIds = {}
    if type(Data.directRules) ~= "table" or #Data.directRules == 0 then
        errors[#errors + 1] = "[C3] followup.lua directRules 为空"
    else
        for i = 1, #Data.directRules do
            local rule = Data.directRules[i]
            local rName = "directRules." .. tostring(rule.id or i)
            if type(rule.ruleSetId) ~= "string" or rule.ruleSetId == "" then
                errors[#errors + 1] = string.format("[C3] %s 缺少 ruleSetId", rName)
            end
            if not IsFiniteNumber(rule.priority) then
                errors[#errors + 1] = string.format("[C3] %s 缺少数值 priority", rName)
            end
            CheckConditions(rule.when, rName, "when", errors)
            CheckConditions(rule.unless, rName, "unless", errors)
            if type(rule.facts) ~= "table" or #rule.facts == 0 then
                errors[#errors + 1] = string.format("[C3] %s 没有产出事实", rName)
            else
                for f = 1, #rule.facts do
                    local fact = rule.facts[f]
                    local fPath = string.format("%s.facts[%d]", rName, f)
                    if type(fact) ~= "table" or type(fact.id) ~= "string" or fact.id == "" then
                        errors[#errors + 1] = string.format("[C3] %s 缺少事实 id", fPath)
                    else
                        if type(fact.subjectId) ~= "string" or not npcsById_[fact.subjectId] then
                            errors[#errors + 1] = string.format("[C3] %s 的 subjectId 不是已声明人物：%s", fPath, tostring(fact.subjectId))
                        end
                        if fact.objectId ~= nil then
                            local npc = npcsById_[fact.subjectId]
                            local declared = (type(npc) == "table") and npc.initialState
                                and npc.initialState.memories and npc.initialState.memories[fact.objectId]
                            if not declared then
                                errors[#errors + 1] = string.format(
                                    "[C3] %s 的 objectId %s 不在人物声明的私人记忆对象里", fPath, tostring(fact.objectId)
                                )
                            end
                        end
                        if type(fact.important) ~= "boolean" then
                            errors[#errors + 1] = string.format("[C3] %s 缺少 important 布尔值", fPath)
                        end
                        if factIds[fact.id] == nil then
                            factIds[fact.id] = true
                        end
                    end
                end
            end
            if type(rule.changes) ~= "table" then
                errors[#errors + 1] = string.format("[C3] %s 的 changes 必须是数组（可为空表）", rName)
            else
                for c = 1, #rule.changes do
                    local change = rule.changes[c]
                    local cPath = string.format("%s.changes[%d]", rName, c)
                    if type(change) ~= "table" or type(change.path) ~= "string" or not CHANGE_OPS[change.op or ""] then
                        errors[#errors + 1] = string.format("[C3] %s 必须提供 path 与 set/add 操作", cPath)
                    else
                        local rel = string.match(change.path, "^world%.npcs%.(.+)$")
                        if not rel then
                            errors[#errors + 1] = string.format("[C3] %s 的 path 必须以 world.npcs. 开头：%s", cPath, tostring(change.path))
                        else
                            ResolveNpcRelativePath(rel, errors, cPath)
                        end
                        if change.value == nil then
                            errors[#errors + 1] = string.format("[C3] %s 缺少 value", cPath)
                        end
                    end
                end
            end
        end
    end

    -- 事实互斥组
    ---@type table<string, string?>
    local groupOf = {}
    if type(Data.factExclusionGroups) == "table" then
        for i = 1, #Data.factExclusionGroups do
            local group = Data.factExclusionGroups[i]
            local gName = "factExclusionGroups." .. tostring(group.id or i)
            if type(group.factIds) ~= "table" or #group.factIds < 2 then
                errors[#errors + 1] = string.format("[C3] %s 至少要声明两个互斥事实", gName)
            else
                for f = 1, #group.factIds do
                    local factId = group.factIds[f]
                    if not factIds[factId] then
                        errors[#errors + 1] = string.format("[C3] %s 引用了未定义事实：%s", gName, tostring(factId))
                    else
                        groupOf[factId] = group.id
                    end
                end
            end
        end
    end

    -- 片段：引用、互斥、绑定与占位符
    if type(Data.fragments) ~= "table" or #Data.fragments == 0 then
        errors[#errors + 1] = "[C3] followup.lua fragments 为空"
    else
        for i = 1, #Data.fragments do
            ---@type table
            local frag = Data.fragments[i]
            local fName = "fragments." .. tostring(frag.id or i)
            CheckFactRefs(frag.requiresFacts, fName, "requiresFacts", factIds, groupOf, true, errors)
            CheckFactRefs(frag.excludesFacts, fName, "excludesFacts", factIds, groupOf, false, errors)
            CheckFactRefs(frag.coversFacts, fName, "coversFacts", factIds, groupOf, false, errors)
            if frag.overrides ~= nil then
                if type(frag.overrides) ~= "table" then
                    errors[#errors + 1] = string.format("[C3] %s 的 overrides 必须是数组", fName)
                else
                    for k = 1, #frag.overrides do
                        if not fragmentsById_[frag.overrides[k]] then
                            errors[#errors + 1] = string.format("[C3] %s 的 overrides 引用了不存在的片段：%s", fName, tostring(frag.overrides[k]))
                        end
                    end
                end
            end
            -- bindings 与 text 占位符必须一致，来源必须在白名单内且可解析
            ---@type table<string, table>
            local bindings = frag.bindings or {}
            local usedPlaceholder = {}
            local text = type(frag.text) == "string" and frag.text or ""
            for name in string.gmatch(text, "{{(.-)}}") do
                usedPlaceholder[name] = true
                if bindings[name] == nil then
                    errors[#errors + 1] = string.format("[C3] %s 的占位符 {{%s}} 没有对应 bindings 声明", fName, name)
                end
            end
            for name, binding in pairs(bindings) do
                local bName = string.format("%s.bindings.%s", fName, tostring(name))
                if type(binding) ~= "table" or type(binding.source) ~= "string" or not BINDING_SOURCES[binding.source] then
                    errors[#errors + 1] = string.format(
                        "[C3] %s 缺少合法 source（允许：potion.effects / world.npcs / context / facts）", bName
                    )
                elseif binding.source == "world.npcs" then
                    ResolveNpcRelativePath(binding.path, errors, bName)
                elseif type(binding.path) ~= "string" or binding.path == "" then
                    errors[#errors + 1] = string.format("[C3] %s 缺少 path", bName)
                end
                if not usedPlaceholder[name] then
                    errors[#errors + 1] = string.format("[C3] %s 未在 text 中使用", bName)
                end
            end
            if type(frag.requiresFacts) == "table" and #frag.requiresFacts == 0
                and type(frag.coversFacts) == "table" and #frag.coversFacts == 0
                and frag.kind ~= "generic" then
                errors[#errors + 1] = string.format("[C3] %s 既不要求也不覆盖任何事实；只有 kind=generic 的兜底片段可以这样", fName)
            end
        end
    end

    -- 模板：片段清单完整（无孤儿片段）
    if type(Data.followupTemplates) == "table" then
        for i = 1, #Data.followupTemplates do
            local tpl = Data.followupTemplates[i]
            local listed = {}
            local function MarkListed(ids)
                if type(ids) == "table" then
                    for k = 1, #ids do
                        listed[ids[k]] = true
                    end
                end
            end
            MarkListed(tpl.baseFragmentIds)
            MarkListed(tpl.fragmentIds)
            MarkListed(tpl.fallbackFragmentIds)
            for j = 1, #Data.fragments do
                local frag = Data.fragments[j]
                if frag.templateId == tpl.id and not listed[frag.id] then
                    errors[#errors + 1] = string.format("[C3] 片段 %s 属于模板 %s，但没有列入任何片段清单（孤儿片段）", tostring(frag.id), tostring(tpl.id))
                end
            end
        end
    end

    -- 重要事实覆盖：按「订单信 → 规则集的事实」对「订单信 → 模板的片段」配对检查。
    -- 每封订单只对自己的规则集事实负责，不跨订单要求（新增信件时不牵连既有模板）。
    for i = 1, #Data.letters do
        ---@type table
        local letter = Data.letters[i]
        if letter.kind == "order"
            and type(letter.followupTemplateId) == "string"
            and type(letter.directRuleSetId) == "string" then
            local tpl = followupTemplatesById_[letter.followupTemplateId --[[@as string]]] --[[@as table|nil]]
            local rules = directRulesBySet_[letter.directRuleSetId --[[@as string]]] --[[@as table[]|nil]]
            if tpl and rules then
                local covered = {}
                for j = 1, #Data.fragments do
                    local frag = Data.fragments[j]
                    if frag.templateId == tpl.id and type(frag.coversFacts) == "table" then
                        for k = 1, #frag.coversFacts do
                            covered[frag.coversFacts[k]] = true
                        end
                    end
                end
                local reported = {}
                for r = 1, #rules do
                    local facts = rules[r].facts
                    if type(facts) == "table" then
                        for f = 1, #facts do
                            local fact = facts[f]
                            if type(fact) == "table" and fact.important == true
                                and fact.id ~= nil and not covered[fact.id] and not reported[fact.id] then
                                reported[fact.id] = true
                                errors[#errors + 1] = string.format(
                                    "[C3] 订单 %s 的模板 %s：重要事实 %s 没有任何片段 covers，发货时会报 CONTENT_UNCOVERED",
                                    tostring(letter.id), tostring(tpl.id), tostring(fact.id)
                                )
                            end
                        end
                    end
                end
            end
        end
    end

    -- 评分：一至三星覆盖、事实引用、反馈与互斥
    for i = 1, #Data.letters do
        local letter = Data.letters[i]
        if letter.kind == "order" and type(letter.ratingSetId) == "string" then
            local rules = ratingsBySet_[letter.ratingSetId] or {}
            local hasStars = { [1] = false, [2] = false, [3] = false }
            for j = 1, #rules do
                local rule = rules[j]
                local rName = "orderRatings." .. tostring(rule.id or j)
                if rule.stars == 1 or rule.stars == 2 or rule.stars == 3 then
                    hasStars[rule.stars] = true
                end
                if type(rule.feedback) ~= "string" or rule.feedback == "" then
                    errors[#errors + 1] = string.format("[C3] %s 缺少反馈句", rName)
                end
                if not IsFiniteNumber(rule.priority) then
                    errors[#errors + 1] = string.format("[C3] %s 缺少数值 priority", rName)
                end
                CheckFactRefs(rule.requiresFacts, rName, "requiresFacts", factIds, groupOf, true, errors)
                CheckFactRefs(rule.excludesFacts, rName, "excludesFacts", factIds, groupOf, false, errors)
            end
            for star = 1, 3 do
                if not hasStars[star] then
                    errors[#errors + 1] = string.format(
                        "[C3] 评分集 %s 缺少 %d 星规则（A19 要求一至三星都可达）", letter.ratingSetId, star
                    )
                end
            end
        end
    end

    -- 样例引用的跨表检查（事实 / 片段 / 评分规则）
    if type(cases) == "table" then
        for i = 1, #cases do
            local case = cases[i]
            if type(case) == "table" and type(case.expect) == "table" then
                local expect = case.expect
                local caseName = "sampleCases." .. tostring(case.id or i)
                if type(expect.facts) == "table" then
                    for k = 1, #expect.facts do
                        if not factIds[expect.facts[k]] then
                            errors[#errors + 1] = string.format("[C3] %s.expect.facts 引用了未定义事实：%s", caseName, tostring(expect.facts[k]))
                        end
                    end
                end
                if type(expect.followupFragments) == "table" then
                    for k = 1, #expect.followupFragments do
                        if not fragmentsById_[expect.followupFragments[k]] then
                            errors[#errors + 1] = string.format("[C3] %s.expect.followupFragments 引用了不存在的片段：%s", caseName, tostring(expect.followupFragments[k]))
                        end
                    end
                end
                if type(expect.rating) == "table" and expect.rating.ruleId ~= nil then
                    if not ratingsById_[expect.rating.ruleId] then
                        errors[#errors + 1] = string.format("[C3] %s.expect.rating.ruleId 引用了不存在的评分规则：%s", caseName, tostring(expect.rating.ruleId))
                    end
                end
            end
        end
    end

    if #errors > 0 then
        print("========== 首单包校验失败（C1/C2/C3） ==========")
        for i = 1, #errors do
            print(string.format("  [%d] %s", i, errors[i]))
        end
        print("================================================")
        return false, errors
    end

    print(string.format(
        "[Data] 首单包校验通过：C1 开局账本 / C2 首单数值 / C3 事实与回信；contentVersion = %s",
        tostring(stage1.contentVersion)
    ))
    return true, {}
end

return Data
