-- ============================================================================
-- 技术扩展测试包（非正式剧情；B2 的 T16 / 正式 A12 专用）
--
-- 用途：验证「只改 data、不改代码」时，新增订单信与新增词定义能被解析与接收。
--   * 对应 B2 计划 §4 的 T16：技术新增订单信/词定义，改变可用信输入；
--   * 正文含两处相同 {{词}}（「灯」两次），可直接作为 T2 的重复词夹具：
--     body:1 与 body:2 应各自独立成位置，剪第一处不使第二处消失。
--
-- 边界（务必遵守）：
--   * 本包**不被 data/content.lua 加载**，不进入正式内容版本，不是可玩剧情；
--   * 首单原配置（letter_pa_01 的 ID、正文顺序、body:N 位置）保持不变；
--     本包只新增 ID，不改名、不重排任何既有位置；
--   * 新增词不配 attributeProfileId：B2 只做解析与剪裁，涉及时间换算时
--     由 B3 按「缺少 profile」报 CONFIG_MISSING（这是预期行为，不是缺陷）；
--   * 报酬、出现日、事实与片段文本全部是技术值，不参与任何经济或剧情验证。
--
-- 用法（注入方式由测试方决定，本包只提供定义）：
--   以 data.content 的深副本为基准，把本包的 npcs / words / letters /
--   directRules / fragments / followupTemplates / orderRatings 追加到同名字段，
--   再按你们的注入方式重建索引；不要修改 data.content 本体。
--   appearCondition.dayMin = 2 支持「改变可用信输入」：第 1 天不可用、第 2 天起可用
--   （测试适配器按 dayMin/dayMax 产生输入；真实调度在 B4 接 Narrative）。
--
-- 组合后应通过 Data.Load() 与 Data.ValidateStage1()（交付时已用本地脚本核对）。
-- ============================================================================

return {
    -- 显式标记：测试可用它断言「正在使用技术夹具」，日志可打印区分
    marker = "TECHNICAL_EXTENSION_TEST",

    -- 组合内容建议使用的版本标识：与正式内容区分，避免技术夹具被当成正式修订。
    -- 是否采用由测试方决定；本包不修改 data/content.lua 的 contentVersion。
    suggestedContentVersion = "stage1-b0v0.2-r1+extension-test",

    notes = "T16/A12 扩展性单测专用；非正式剧情；用法见 data/填写说明.md §7.5",

    -- 技术人物：只用于让新信件有可解析的寄信人，不进入正式人物表
    npcs = {
        {
            id = "npc_ext_test",
            name = "测试灯匠",
            occupation = "修灯人（技术夹具）",
            family = "技术夹具，不适用",
            background = "扩展性测试用人物，不进入正式剧情。",
            address = "灰港 技术测试巷 0 号（非正式地址）",
            inCase = false,
            notes = "T16/A12 扩展性单测专用",
        },
    },

    -- 新增词定义：只使用现有效果标签（calm / brave），不新增标签
    words = {
        {
            id = "word_ext_lamp",
            displayText = "灯",
            category = "感知类",
            reusable = true,
            effects = { calm = 0.5 },
        },
        {
            id = "word_ext_nightwatch",
            displayText = "守夜",
            category = "行为类",
            reusable = true,
            effects = { calm = 0.4, brave = 0.3 },
        },
    },

    -- 技术订单信：kind=order、可剪、可进普通打捞队列（不是直接回信；
    -- 第二封可打捞首信的技术样张，不冒充正式剧情）
    letters = {
        {
            id = "letter_pa_ext_01",
            senderId = "npc_ext_test",
            kind = "order",
            cuttable = true,
            bottleType = "normal",
            title = "【技术测试】扩展信样张（非正式剧情）",

            selfIntro = [[
（技术测试用信件，非正式剧情。）写信的人叫「测试灯匠」，是扩展性单测的夹具人物。
这封信只用来验证：新增订单信与新增词定义后，系统不改代码即可解析与接收。]],

            body = [[
店主：

这是一封技术测试信。第一处{{灯}}和第二处{{灯}}是同一个词的两个位置，应当各自独立；
后面还有一枚{{守夜}}。剪开这封信，扩展性检查就算通过。

正文到此为止。]],

            address = "灰港 技术测试巷 0 号（非正式地址）",

            attachments = {},

            requirement = {
                desc = "技术测试要求：镇静权重不低于 0.4（不对应任何正式订单）",
                tags = { calm = 0.4 },
                -- 技术夹具不设时长/残留等条件；也没有明确禁止的效果，显式空集合
                forbiddenEffects = {},
            },

            -- 技术值（1），非正式报酬
            reward = { currency = 1 },

            directRuleSetId = "rules_pa_ext",
            followupTemplateId = "tpl_pa_ext",
            ratingSetId = "rating_pa_ext",

            -- 第 1 天不可用、第 2 天起可用：支持 T16「改变可用信输入」
            appearCondition = { dayMin = 2 },
        },
        {
            id = "letter_pa_ext_followup",
            senderId = "npc_ext_test",
            kind = "direct_followup",
            cuttable = false,
            bottleType = "normal",
            title = "【技术测试】扩展信直接回信（非正式剧情）",
            address = "灰港 技术测试巷 0 号（非正式地址）",
            attachments = {},
            followupTemplateId = "tpl_pa_ext",
        },
    },

    -- 技术回信链：只为让组合内容通过 Load/ValidateStage1 并可在后续批次联调引用；
    -- 文本全部是技术夹具，不声称任何正式后果
    directRules = {
        {
            id = "rule_ext_test_done",
            ruleSetId = "rules_pa_ext",
            priority = 10,
            desc = "技术夹具规则：镇静达标即产生一条技术事实",
            when = { { source = "potion.effects", path = "calm", op = "gte", value = 0.4 } },
            facts = {
                { id = "fx_ext_test_done", subjectId = "npc_ext_test", value = true, important = true },
            },
            changes = {},
        },
    },

    fragments = {
        {
            id = "frag_ext_test_base",
            templateId = "tpl_pa_ext",
            kind = "key",
            priority = 100,
            desc = "技术夹具基础片段",
            requiresFacts = { "fx_ext_test_done" },
            coversFacts = { "fx_ext_test_done" },
            text = "技术夹具回信：测试灯匠说他收到了信。（不是正式剧情文本）",
        },
        {
            id = "frag_ext_test_fallback",
            templateId = "tpl_pa_ext",
            kind = "generic",
            priority = 0,
            desc = "技术夹具兜底片段",
            requiresFacts = {},
            coversFacts = {},
            text = "技术夹具回信：暂无对应片段。（不是正式剧情文本）",
        },
    },

    followupTemplates = {
        {
            id = "tpl_pa_ext",
            letterId = "letter_pa_ext_followup",
            opening = "技术夹具开场：店主，我是修灯的。",
            closing = "技术夹具结尾。（不是正式剧情文本）",
            baseFragmentIds = { "frag_ext_test_base" },
            fragmentIds = {},
            fallbackFragmentIds = { "frag_ext_test_fallback" },
        },
    },

    orderRatings = {
        {
            id = "r3_ext_test",
            ratingSetId = "rating_pa_ext",
            priority = 30,
            stars = 3,
            desc = "技术夹具三星",
            requiresFacts = { "fx_ext_test_done" },
            excludesFacts = {},
            feedback = "技术夹具反馈（三星）。（不是正式剧情文本）",
        },
        {
            id = "r2_ext_test",
            ratingSetId = "rating_pa_ext",
            priority = 20,
            stars = 2,
            desc = "技术夹具二星",
            requiresFacts = {},
            excludesFacts = {},
            feedback = "技术夹具反馈（二星）。（不是正式剧情文本）",
        },
        {
            id = "r1_ext_test",
            ratingSetId = "rating_pa_ext",
            priority = 10,
            stars = 1,
            desc = "技术夹具一星（兜底）",
            requiresFacts = {},
            excludesFacts = {},
            feedback = "技术夹具反馈（一星）。（不是正式剧情文本）",
        },
    },
}
