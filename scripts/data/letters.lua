-- ============================================================================
-- 信件表
--
-- 每封正式订单信按设计文档要求包含三段：自我介绍、正文、详细地址。
-- 自我介绍的文字写在这里，人物资料取自 npcs.lua，不要重复写人物字段。
--
-- 字段：
--   id            唯一标识
--   senderId      寄信人，对应 npcs.lua 的 id
--   kind          order（订单信）/ direct_followup（直接回信）
--                 order：必须有 requirement 与固定报酬，进普通出现队列
--                 direct_followup：发货后在待确认结果中直接展示，无订单、无报酬、
--                 不进入普通出现队列，也不需要可剪标记
--   cuttable      正文是否可剪词。order=true；direct_followup=false（显式 false，不可省）
--   bottleType    漂流瓶外观：normal（普通）/ main（主线）/ old（陈年旧瓶）
--   title         信件列表里的标题
--   selfIntro     自我介绍段落（订单信用）
--   body          正文。用 {{词}} 标记可被剪下的位置，词必须存在于 words.lua
--   address       详细地址。可与 npcs.lua 里的地址不同 —— 差异本身就是线索
--   attachments   随信附件，可为空表；阶段 2 起接入档案桌
--   requirement   订单的字面要求，见下方说明（仅 order）
--   reward        本单固定报酬 { currency = 非负整数 }；一至三星完全同额（仅 order）
--   directRuleSetId    本单后续事实规则集，对应 followup.lua 的 DirectRule.ruleSetId（仅 order）
--   followupTemplateId 直接后续信件模板，对应 followup.lua 的 FollowupTemplate.id（仅 order）
--   ratingSetId        本单评分规则集，对应 followup.lua 的 RatingRule.ratingSetId（仅 order）
--   appearCondition  出现条件，由 Narrative 模块判定（仅 order）
--
-- requirement 字段：
--   desc        给玩家看的要求描述，必须能看出全部字面条件
--   tags        需要达到的最低效果权重，键取自 effects.lua
--   conditions  条件数组（B0 §3.3 的 kind）：
--                 duration / onset / workReady / residualAt / forbiddenEffect
--               未要求的属性不配条件；未知 kind 视为配置错误
--   forbiddenEffects 本单明确禁止的效果标签集合；没有禁止项时显式写空表
--   订单系统只判断「字面上是否达到」，不判断是否安全、是否道德
--
-- appearCondition 支持的条件键（阶段 1 先实现前两个）：
--   dayMin         最早在第几天出现
--   dayMax         最晚在第几天出现
--   afterLetter    必须已经读过某封信
--   minDelivered   至少已发货 N 单
--   worldState     世界状态条件，例如 { npc_passerby_a_sleep = "improved" }
-- ============================================================================

return {
    {
        id = "letter_pa_01",
        senderId = "npc_passerby_a",
        kind = "order",
        cuttable = true,
        bottleType = "normal",
        title = "码头来的第一封信",

        selfIntro = [[
写信的人叫埃利亚斯·沃德，在灰港码头搬货，住在铁锚巷。
他说自己不认识字，这封信是托面包坊的伙计代写的，写得不顺的地方请多见谅。
他家里还有一个妹妹，在面包坊帮工，两个人租了铁锚巷二楼的一间小屋。]],

        body = [[
尊敬的店主：

我不知道该怎么开头。听人说海边的魔药铺能帮人实现愿望，我本来是不信的，可是这个月实在熬不住了。

我最近真的很{{累}}。白天在码头上搬货，手上没劲，好几次差点把整箱的鱼摔在地上。
晚上也睡不好，隔壁酒馆闹到半夜，我倒不是嫌吵，就是躺下以后一直醒着，天快亮了才迷糊过去。

我妹妹在面包坊帮工，回来总说身上全是面粉味。她老嫌我脸上没个{{笑}}模样，可我也说不上到底哪里不好。

还有些事我不想再想起来。要是能{{忘记}}就好了。
前几天梦见我娘了，醒来以后我在床边坐了很久。那样的{{梦}}要是能多来几次也好。

我只希望哪天能{{安静}}一晚上，让我踏踏实实{{睡觉}}，第二天起来还有力气干活。

地址写在下面了。谢谢你看完。

埃利亚斯·沃德]],

        address = "灰港 铁锚巷 12 号 二楼",

        attachments = {},

        requirement = {
            -- 描述必须让玩家看得见全部字面条件（B0 §4.1）
            desc = "踏踏实实睡一晚：药效 3 小时内发作，睡眠持续 6～8 小时，第二天上工前散干净，起来还有力气干活",
            tags = { sleep = 0.8 },
            conditions = {
                -- 已接受调试范围：6～8 小时含边界（讨论结论 §3.2）
                { id = "sleep_duration", kind = "duration", minHours = 6, maxHours = 8 },
                -- 睡前服药，药效须在 3 小时内发作（A~D 实际为 2 小时，留 1 小时余量）
                { id = "sleep_onset", kind = "onset", maxDelayHours = 3 },
                -- 服药（设为睡前 21:00）到次晨上工（09:00）的工作间隔为 12 小时；
                -- 只判药效结束与恢复，不推断剧情中的能力
                { id = "morning_work", kind = "workReady", workAfterDoseHours = 12 },
                -- 上工时睡眠残留不得超过 0.4：合规单（8 小时睡眠）残留 0.164 以内，
                -- 10 小时的 E 在药效刚结束时为 0.6，会被拒绝
                { id = "morning_residual", kind = "residualAt", effectId = "sleep", atAfterDoseHours = 12, maxWeight = 0.4 },
            },
            -- 本单没有明确禁止的效果，显式空集合
            forbiddenEffects = {},
        },

        -- 固定报酬：调试初值 80（复算依据见 data/填写说明.md §4）
        reward = { currency = 80 },

        directRuleSetId = "rules_pa_01",
        followupTemplateId = "tpl_pa_01",
        ratingSetId = "rating_pa_01",

        appearCondition = {
            dayMin = 1,
        },
    },

    -- 首单的直接回信：发货后在待确认结果里立即展示，正文由 tpl_pa_01 的
    -- opening + 片段 + closing 组装，本表不重复写正文。
    -- 直接回信不能剪词、不能领附件（运行门禁保证；attachments 显式空集合）。
    {
        id = "letter_pa_01_followup",
        senderId = "npc_passerby_a",
        kind = "direct_followup",
        cuttable = false,
        bottleType = "normal",
        title = "埃利亚斯·沃德的回信",
        address = "灰港 铁锚巷 12 号 二楼",
        attachments = {},
        followupTemplateId = "tpl_pa_01",
    },
}
