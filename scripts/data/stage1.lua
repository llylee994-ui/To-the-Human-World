-- ============================================================================
-- 阶段 1 首单包：内容版本、开局账本、投料策略、时间属性与验收样例
--
-- 本文件对应 [B0 交接稿 v0.2] 与 [B1 计划的队友交付 C1/C2]：
--   C1 开局配置：contentVersion / initialEconomy / initialEquipmentId
--   C2 首单数值：recipePolicy / attributeProfiles / sampleCases / errorSamples
-- C3 的人物初态、事实、回信与评分在 data/followup.lua 与 data/npcs.lua。
--
-- 字段语义、单位、八步边界与填写方法见 data/填写说明.md。
-- 本文件只放内容数据，不含任何计算逻辑；程序经 data/content.lua 读取。
-- ============================================================================

-- 首单可达的速度修正 → 生效延迟映射（精确查表；漏项报错，不做插值）
-- 可达速度值：0（无夜露）/ 2（夜露×1）/ 4（夜露×2）
local SPEED_TO_DELAY_HOURS = {
    { speed = 0, delayHours = 2 },
    { speed = 2, delayHours = 1 },
    { speed = 4, delayHours = 0 },
}

-- 睡眠标签的残留衰减表：按「药效结束后的整小时」取点，ratio 是相对最终权重的残留比例。
-- 采样规则（冻结）：采样点必须落在已声明点上；早于 0（采样时药效仍在）按 1.0 处理；
-- 超出表尾（> 4 小时）按 0 处理。两条都是显式声明，不是插值。
-- 本表由 sleep_basic / tired_basic 共用；新增标签或新主词需要自己的残留表。
local SLEEP_RESIDUAL_POINTS = {
    { hoursAfterEnd = 0, ratio = 0.6 },
    { hoursAfterEnd = 1, ratio = 0.3 },
    { hoursAfterEnd = 2, ratio = 0.1 },
    { hoursAfterEnd = 3, ratio = 0.05 },
    { hoursAfterEnd = 4, ratio = 0.0 },
}

return {
    -- ========================================================================
    -- C1：内容版本与开局账本
    -- ========================================================================

    -- 整包内容修订标识：与 synthesis.version（计算规则）、存档 schema（文件结构）分开。
    -- 任何会改变已保存基准/待确认解释的改动都必须递增本串；基准与待确认记录均保存它。
    contentVersion = "stage1-b0v0.2-r1",

    -- 开局账本（已接受调试初值；完整经济表与商店在阶段 2/3，本批只验证初始化与恢复）
    initialEconomy = {
        -- 非负整数金币。调试初值 30：约等于两份普通原料的价值，
        -- 不做开局补贴（旅行票 300、家居合计 480 需靠经营赚取）；不采用演算示例的 80/400。
        currency = 30,

        -- 原料 ID → 非负整数份数。四种原料各 3 份为已接受初值。
        -- 一份占一个原料槽；旧锅原料槽上限 2（见 equipment.lua）。
        ingredients = {
            ing_sea_salt = 3,
            ing_night_dew = 3,
            ing_ashen_herb = 3,
            ing_dried_petal = 3,
        },

        -- 特殊物品为库存实例数组。首信无附件，显式空集合；
        -- 不得因特殊槽容量为 1 就赠送物品。
        specialItems = {},
    },

    -- 开局已拥有设备；必须与 equipment.lua 的 owned 标记一致（旧锅 owned=true、铜锅 false）
    initialEquipmentId = "kit_old_cauldron",

    -- 同锅重复投料策略（B0 DUP 系列错误码依据；未声明的重复一律不允许）
    recipePolicy = {
        -- 同种原料重复占槽：允许。同一 ingredientId 聚合成一行、quantity 份数累加，
        -- 每份占一个原料槽（两份海盐占 2 格）。理由：原料是消耗品，重复只影响一项属性，
        -- 槽位上限 2 已经封顶，不产生退化配方。
        repeatIngredient = true,
        -- 同定义词条副本：不允许。不同 tokenId 但同一 wordId 视为重复投料，返回
        -- DUPLICATE_NOT_ALLOWED。理由：词条是「语义」，同一词义只应出现一次；
        -- 首信各词目前只有一个实例，本策略先用技术夹具验证。
        -- 注意：reusable=true 只表示跨次炼制可复用，与重复占槽无关；同一 tokenId 跨槽始终非法。
        repeatWordDefinition = false,
    },

    -- 样例统一假定的本单基准（B0 §5.1 的 S0）：首信已读、六处词已剪、订单已接、尚未投料；
    -- 正式账本 = initialEconomy，人物初态 = npcs.lua 的 npc_passerby_a.initialState。
    baseline = {
        id = "S0",
        desc = "首信已读、六处词已剪、订单已接、尚未投料；正式账本与人物初态均未变化",
    },

    -- ========================================================================
    -- C2：时间属性 profile
    --
    -- 主词条通过 words[].attributeProfileId 引用本表。时间换算只读主词的 profile：
    --   durationHours = baseDurationHours + mods.duration × durationHoursPerPoint
    --   onsetDelayHours = speedToDelayHours 按 mods.speed 精确查表（漏项报错）
    --   recoveryAfterEndHours = 药效结束到完全恢复的固定小时数
    -- 未配置 profile 的主词条：涉及时间换算的请求报 CONFIG_MISSING，不默认套用其他词。
    -- ========================================================================
    attributeProfiles = {
        {
            id = "sleep_basic",
            desc = "「睡觉」主词：已接受调试样板（基础 8 小时，每点持续修正 +1 小时）",
            baseDurationHours = 8,
            durationHoursPerPoint = 1,
            speedToDelayHours = SPEED_TO_DELAY_HOURS,
            recoveryAfterEndHours = 1,
            residualRules = {
                { effectId = "sleep", points = SLEEP_RESIDUAL_POINTS },
            },
        },
        {
            id = "tired_basic",
            desc = "「累」主词：调试初值（基础 6 小时）。只保证负例 F 与玩家实际投料可完整计算，正式值待校准",
            baseDurationHours = 6,
            durationHoursPerPoint = 1,
            speedToDelayHours = SPEED_TO_DELAY_HOURS,
            recoveryAfterEndHours = 1,
            residualRules = {
                -- 与 sleep_basic 共用同一张 sleep 残留表：残留是标签属性，两个 profile 显式声明同一张，
                -- 避免「累」主词被采样时缺表。其余标签（calm 等）未声明，被采样时按缺配置报错。
                { effectId = "sleep", points = SLEEP_RESIDUAL_POINTS },
            },
        },
    },

    -- ========================================================================
    -- C2：首单验收样例（A~F 来自 B0 §5；G1~G4 为「同主词不同原料」补充，对应 A13）
    --
    -- recipe 用 wordId 书写（实际请求用剪出的 tokenId）；expect 是本包的期望输出，
    -- 由程序验证后共同冻结。判定针对 letter_pa_01 的条件（6~8 小时等）。
    -- 期望值由当前配置算术推算（auxWeight 0.6 / sameTagBonus 0.4 / intensityScale 0.25 /
    -- 闭区间上界分级），不是 Potion 模块的运行结果。
    -- ========================================================================
    sampleCases = {
        {
            id = "A",
            purpose = "首单正例：安稳睡好（三星）",
            baselineId = "S0",
            recipe = {
                equipmentId = "kit_old_cauldron",
                mainWordId = "word_sleep",
                auxWordIds = {},
                ingredients = { { ingredientId = "ing_sea_salt", quantity = 1 } },
                specialItemIds = {},
            },
            expect = {
                effects = { sleep = 1.0 },
                tiers = { sleep = "明显" },
                durationHours = 8,
                onsetDelayHours = 2,
                stability = 1,
                unstable = false,
                sideEffects = {},
                residualSample = { effectId = "sleep", atAfterDoseHours = 12, weight = 0.1 },
                canShip = true,
                failures = {},
                facts = { "fx_sleep_improved", "fx_morning_work_ok" },
                followupFragments = { "frag_pa_work_recovered", "frag_pa_sleep_only" },
                rating = { stars = 3, ruleId = "r3_plain" },
            },
        },
        {
            id = "B",
            purpose = "首单正例：睡好并梦到母亲（三星）",
            baselineId = "S0",
            recipe = {
                equipmentId = "kit_old_cauldron",
                mainWordId = "word_sleep",
                auxWordIds = { "word_dream" },
                ingredients = { { ingredientId = "ing_sea_salt", quantity = 1 } },
                specialItemIds = {},
            },
            expect = {
                -- sleep = 1.0 + 0.4×0.6 + 0.4 = 1.64
                effects = { sleep = 1.64, dream = 0.6 },
                tiers = { sleep = "强烈", dream = "微弱" },
                durationHours = 8,
                onsetDelayHours = 2,
                stability = 1,
                unstable = false,
                sideEffects = {},
                residualSample = { effectId = "sleep", atAfterDoseHours = 12, weight = 0.164 },
                canShip = true,
                failures = {},
                facts = { "fx_sleep_improved", "fx_morning_work_ok", "fx_dreamt_mother" },
                followupFragments = { "frag_pa_work_recovered", "frag_pa_dream_mother" },
                rating = { stars = 3, ruleId = "r3_mother_dream" },
            },
        },
        {
            id = "C",
            purpose = "首单正例：睡好但淡忘母亲的歌（二星）",
            baselineId = "S0",
            recipe = {
                equipmentId = "kit_old_cauldron",
                mainWordId = "word_sleep",
                auxWordIds = { "word_forget" },
                ingredients = { { ingredientId = "ing_sea_salt", quantity = 1 } },
                specialItemIds = {},
            },
            expect = {
                effects = { sleep = 1.0, forget = 0.6 },
                tiers = { sleep = "明显", forget = "微弱" },
                durationHours = 8,
                onsetDelayHours = 2,
                stability = 1,
                unstable = false,
                sideEffects = {},
                residualSample = { effectId = "sleep", atAfterDoseHours = 12, weight = 0.1 },
                canShip = true,
                failures = {},
                facts = { "fx_sleep_improved", "fx_morning_work_ok", "fx_mother_memory_faded" },
                followupFragments = { "frag_pa_work_recovered", "frag_pa_forget_song" },
                rating = { stars = 2, ruleId = "r2_song_faded" },
            },
        },
        {
            id = "D",
            purpose = "首单正例：梦到背影却认不清、本人难受（一星）",
            baselineId = "S0",
            recipe = {
                equipmentId = "kit_old_cauldron",
                mainWordId = "word_sleep",
                auxWordIds = { "word_dream", "word_forget" },
                ingredients = { { ingredientId = "ing_sea_salt", quantity = 1 } },
                specialItemIds = {},
            },
            expect = {
                effects = { sleep = 1.64, dream = 0.6, forget = 0.6 },
                tiers = { sleep = "强烈", dream = "微弱", forget = "微弱" },
                durationHours = 8,
                onsetDelayHours = 2,
                stability = 1,
                unstable = false,
                sideEffects = {},
                residualSample = { effectId = "sleep", atAfterDoseHours = 12, weight = 0.164 },
                canShip = true,
                failures = {},
                -- 梦境与遗忘的交叉：认不清 + 本人难受；不得同时出现「完整认出母亲」
                facts = {
                    "fx_sleep_improved", "fx_morning_work_ok", "fx_mother_memory_faded",
                    "fx_dreamt_figure_unclear", "fx_self_distressed",
                },
                followupFragments = { "frag_pa_work_recovered", "frag_pa_dream_unclear" },
                rating = { stars = 1, ruleId = "r1_distress" },
            },
        },
        {
            id = "E",
            purpose = "首单负例：干花瓣延长到 10 小时，越过 6~8 小时且违反次晨工作条件",
            baselineId = "S0",
            recipe = {
                equipmentId = "kit_old_cauldron",
                mainWordId = "word_sleep",
                auxWordIds = {},
                ingredients = { { ingredientId = "ing_dried_petal", quantity = 1 } },
                specialItemIds = {},
            },
            expect = {
                effects = { sleep = 1.0 },
                tiers = { sleep = "明显" },
                durationHours = 10,
                onsetDelayHours = 2,
                stability = 0,
                unstable = false,
                sideEffects = {},
                residualSample = { effectId = "sleep", atAfterDoseHours = 12, weight = 0.6 },
                canShip = false,
                failures = {
                    { id = "sleep_duration", kind = "duration", expected = { min = 6, max = 8 }, actual = 10, unit = "game_hour" },
                    -- 2（生效）+ 10（持续）+ 1（恢复）= 13 > 12
                    { id = "morning_work", kind = "workReady", expected = { max = 12 }, actual = 13, unit = "game_hour" },
                    { id = "morning_residual", kind = "residualAt", expected = { max = 0.4 }, actual = 0.6, unit = "weight" },
                },
            },
        },
        {
            id = "F",
            purpose = "首单负例：主词「累」的睡眠权重 0.6 未达 0.8，且 0.6 正好是分级边界",
            baselineId = "S0",
            recipe = {
                equipmentId = "kit_old_cauldron",
                mainWordId = "word_tired",
                auxWordIds = {},
                ingredients = { { ingredientId = "ing_sea_salt", quantity = 1 } },
                specialItemIds = {},
            },
            expect = {
                effects = { calm = 0.6, sleep = 0.6 },
                tiers = { calm = "微弱", sleep = "微弱" },
                durationHours = 6,
                onsetDelayHours = 2,
                stability = 1,
                unstable = false,
                sideEffects = {},
                canShip = false,
                failures = {
                    { id = "tag.sleep", kind = "tag", expected = { min = 0.8 }, actual = 0.6, unit = "weight" },
                },
            },
        },
        {
            id = "G1",
            purpose = "同主词换原料（A13）：海盐+夜露，速效版",
            baselineId = "S0",
            recipe = {
                equipmentId = "kit_old_cauldron",
                mainWordId = "word_sleep",
                auxWordIds = {},
                ingredients = {
                    { ingredientId = "ing_sea_salt", quantity = 1 },
                    { ingredientId = "ing_night_dew", quantity = 1 },
                },
                specialItemIds = {},
            },
            expect = {
                effects = { sleep = 1.0 },
                tiers = { sleep = "明显" },
                durationHours = 8,
                onsetDelayHours = 1,
                stability = 0,
                unstable = false,
                sideEffects = {},
                residualSample = { effectId = "sleep", atAfterDoseHours = 12, weight = 0.05 },
                canShip = true,
                failures = {},
                facts = { "fx_sleep_improved", "fx_morning_work_ok" },
                followupFragments = { "frag_pa_work_recovered", "frag_pa_sleep_only" },
                rating = { stars = 3, ruleId = "r3_plain" },
            },
        },
        {
            id = "G2",
            purpose = "同主词换原料（A13）：灰烬草，浓烈版并触发微弱多梦（副作用标签交叉）",
            baselineId = "S0",
            recipe = {
                equipmentId = "kit_old_cauldron",
                mainWordId = "word_sleep",
                auxWordIds = {},
                ingredients = { { ingredientId = "ing_ashen_herb", quantity = 1 } },
                specialItemIds = {},
            },
            expect = {
                -- intensity 2 → 缩放 (1 + 2×0.25) = 1.5；sideEffect 2 触发规则，附加 dream 0.4（不缩放）
                effects = { sleep = 1.5, dream = 0.4 },
                tiers = { sleep = "强烈", dream = "微弱" },
                durationHours = 8,
                onsetDelayHours = 2,
                stability = 0,
                unstable = false,
                sideEffects = { { ruleId = "se_dream", addTags = { dream = 0.4 } } },
                residualSample = { effectId = "sleep", atAfterDoseHours = 12, weight = 0.15 },
                canShip = true,
                failures = {},
                facts = { "fx_sleep_improved", "fx_morning_work_ok", "fx_restless_dreams" },
                followupFragments = { "frag_pa_work_recovered", "frag_pa_restless_dreams" },
                rating = { stars = 3, ruleId = "r3_plain" },
            },
        },
        {
            id = "G3",
            purpose = "同主词换原料（A13）：夜露+灰烬草，速效浓烈；稳定性 -1 只给提示不影响发货",
            baselineId = "S0",
            recipe = {
                equipmentId = "kit_old_cauldron",
                mainWordId = "word_sleep",
                auxWordIds = {},
                ingredients = {
                    { ingredientId = "ing_night_dew", quantity = 1 },
                    { ingredientId = "ing_ashen_herb", quantity = 1 },
                },
                specialItemIds = {},
            },
            expect = {
                effects = { sleep = 1.5, dream = 0.4 },
                tiers = { sleep = "强烈", dream = "微弱" },
                durationHours = 8,
                onsetDelayHours = 1,
                stability = -1,
                unstable = true,
                sideEffects = { { ruleId = "se_dream", addTags = { dream = 0.4 } } },
                residualSample = { effectId = "sleep", atAfterDoseHours = 12, weight = 0.075 },
                canShip = true,
                failures = {},
                facts = { "fx_sleep_improved", "fx_morning_work_ok", "fx_restless_dreams" },
                followupFragments = { "frag_pa_work_recovered", "frag_pa_restless_dreams" },
                rating = { stars = 3, ruleId = "r3_plain" },
            },
        },
        {
            id = "G4",
            purpose = "同种原料重复占槽（recipePolicy.repeatIngredient）：夜露×2，覆盖 speed=4 映射",
            baselineId = "S0",
            recipe = {
                equipmentId = "kit_old_cauldron",
                mainWordId = "word_sleep",
                auxWordIds = {},
                ingredients = { { ingredientId = "ing_night_dew", quantity = 2 } },
                specialItemIds = {},
            },
            expect = {
                effects = { sleep = 1.0 },
                tiers = { sleep = "明显" },
                durationHours = 8,
                onsetDelayHours = 0,
                stability = -2,
                unstable = true,
                sideEffects = {},
                residualSample = { effectId = "sleep", atAfterDoseHours = 12, weight = 0.0 },
                canShip = true,
                failures = {},
                facts = { "fx_sleep_improved", "fx_morning_work_ok" },
                followupFragments = { "frag_pa_work_recovered", "frag_pa_sleep_only" },
                rating = { stars = 3, ruleId = "r3_plain" },
            },
        },
    },

    -- ========================================================================
    -- C1：最小错误样例
    --
    -- 供 Economy 初始化校验的负例断言使用（程序按 path 在 initialEconomy 副本上施加
    -- mutation，验证返回 expectCode）。这些是测试说明数据，不是可运行配置。
    -- ========================================================================
    errorSamples = {
        {
            id = "err_missing_currency",
            desc = "缺少开局金币（不得补 0）",
            path = "initialEconomy.currency",
            mutation = { op = "remove" },
            expectCode = "CONFIG_MISSING",
        },
        {
            id = "err_negative_currency",
            desc = "金币为负",
            path = "initialEconomy.currency",
            mutation = { op = "set", value = -1 },
            expectCode = "CONFIG_INVALID",
        },
        {
            id = "err_fractional_ingredient",
            desc = "材料份数为小数",
            path = "initialEconomy.ingredients.ing_night_dew",
            mutation = { op = "set", value = 1.5 },
            expectCode = "CONFIG_INVALID",
        },
        {
            id = "err_negative_ingredient",
            desc = "材料份数为负",
            path = "initialEconomy.ingredients.ing_sea_salt",
            mutation = { op = "set", value = -1 },
            expectCode = "CONFIG_INVALID",
        },
        {
            id = "err_missing_ingredient",
            desc = "缺少一种开局原料（四种必须齐全）",
            path = "initialEconomy.ingredients.ing_dried_petal",
            mutation = { op = "remove" },
            expectCode = "CONFIG_MISSING",
        },
        {
            id = "err_unknown_ingredient",
            desc = "未知材料 ID",
            path = "initialEconomy.ingredients.ing_ghost",
            mutation = { op = "add", value = 3 },
            expectCode = "UNKNOWN_ID",
        },
        {
            id = "err_unknown_equipment",
            desc = "未知设备 ID",
            path = "initialEquipmentId",
            mutation = { op = "set", value = "kit_ghost" },
            expectCode = "UNKNOWN_ID",
        },
    },
}
