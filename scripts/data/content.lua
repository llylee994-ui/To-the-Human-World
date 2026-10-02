-- ============================================================================
-- 内容数据总入口
--
-- 所有静态配置的单一读取点。其它模块只 require 本文件，不直接 require 各分表，
-- 这样将来换存储格式（例如改成 JSON）只需要改这一处。
--
-- 见 docs/寄往人间_系统模块拆分与依赖设计.md ① Content 内容数据模块
-- 本模块只提供查询，不推进剧情、不改玩家状态、不计算药效。
-- ============================================================================

local Data = {}

Data.effects = require "data.effects"
Data.words = require "data.words"
Data.ingredients = require "data.ingredients"
Data.equipment = require "data.equipment"
Data.synthesis = require "data.synthesis"
Data.npcs = require "data.npcs"
Data.letters = require "data.letters"

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

---@type table<string, table>
local effectsById_ = {}
---@type table<string, table>
local wordsById_ = {}
---@type table<string, table?>
local wordsByText_ = {}
---@type table<string, table>
local ingredientsById_ = {}
---@type table<string, table>
local equipmentById_ = {}
---@type table<string, table>
local npcsById_ = {}
---@type table<string, table>
local lettersById_ = {}

-- ============================================================================
-- 索引
-- ============================================================================

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

--- 建立索引并做交叉校验。在 main.lua 启动时调用一次。
---@return boolean ok
---@return string[] errors 校验失败时的原因列表，可直接打印给文案同学定位
function Data.Load()
    effectsById_, wordsById_, wordsByText_ = {}, {}, {}
    ingredientsById_, equipmentById_, npcsById_, lettersById_ = {}, {}, {}, {}

    local errors = {}

    IndexById(Data.effects, effectsById_, errors, "effects.lua")
    IndexById(Data.words, wordsById_, errors, "words.lua")
    IndexById(Data.ingredients, ingredientsById_, errors, "ingredients.lua")
    IndexById(Data.equipment, equipmentById_, errors, "equipment.lua")
    IndexById(Data.npcs, npcsById_, errors, "npcs.lua")
    IndexById(Data.letters, lettersById_, errors, "letters.lua")

    -- 词条的显示文本必须唯一，否则信里的 {{词}} 无法确定指向哪一条
    for i = 1, #Data.words do
        local word = Data.words[i]
        if type(word.displayText) == "string" and word.displayText ~= "" then
            if wordsByText_[word.displayText] then
                errors[#errors + 1] = string.format(
                    "words.lua 里 displayText 重复：「%s」（%s 与 %s）",
                    word.displayText, wordsByText_[word.displayText].id, word.id
                )
            else
                wordsByText_[word.displayText] = word
            end
        elseif type(word.id) == "string" then
            errors[#errors + 1] = string.format("words.lua 的 %s 缺少 displayText", word.id)
        end
    end

    -- 词条与原料引用的效果标签必须存在
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

    -- 信件：寄信人存在、正文里的 {{词}} 都在词库里、订单标签存在
    for i = 1, #Data.letters do
        local letter = Data.letters[i]
        local fallbackName = "letters.lua 第 " .. i .. " 条"
        local letterName = (type(letter.id) == "string" and letter.id ~= "") and letter.id or fallbackName

        if type(letter.senderId) == "string" and not npcsById_[letter.senderId] then
            errors[#errors + 1] = string.format(
                "%s 的寄信人 %s 不存在于 npcs.lua", letterName, letter.senderId
            )
        end

        if type(letter.body) == "string" then
            local cutCount = 0
            for marked in string.gmatch(letter.body, "{{(.-)}}") do
                cutCount = cutCount + 1
                if not wordsByText_[marked] then
                    errors[#errors + 1] = string.format(
                        "%s 正文里标记了「%s」，但 words.lua 里没有 displayText 为「%s」的词条",
                        letterName, marked, marked
                    )
                end
            end
            if cutCount == 0 then
                errors[#errors + 1] = string.format("%s 正文里没有任何 {{词}} 标记", letterName)
            end
        else
            errors[#errors + 1] = string.format("%s 缺少 body", letterName)
        end

        if type(letter.requirement) ~= "table" then
            errors[#errors + 1] = string.format("%s 缺少 requirement", letterName)
        elseif type(letter.requirement.tags) == "table" then
            for tag in pairs(letter.requirement.tags) do
                if not effectsById_[tag] then
                    errors[#errors + 1] = string.format(
                        "%s 的订单要求引用了不存在的效果标签：%s", letterName, tostring(tag)
                    )
                end
            end
        end

        if type(letter.address) ~= "string" or letter.address == "" then
            errors[#errors + 1] = string.format("%s 缺少详细地址（设计上每封信都必须有地址）", letterName)
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
        "[Data] 校验通过：效果 %d / 词条 %d / 原料 %d / 设备 %d / 人物 %d / 信件 %d",
        #Data.effects, #Data.words, #Data.ingredients, #Data.equipment, #Data.npcs, #Data.letters
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
    return wordsByText_[text]
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

return Data
