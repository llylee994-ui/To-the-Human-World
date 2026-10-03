-- ============================================================================
-- 首单直接后续：事件事实、回信片段、模板与评分
--
-- 对应 [B1 计划的队友交付 C3] 与 [B0 交接稿 §4.2] 的结构（DirectRule / Fragment /
-- FollowupTemplate / RatingRule）。依据：纸面验证 §三～四、讨论结论 §3.3
-- （A/B 三星、C 二星、D 一星，D 必须由本人难受的事实与反馈支撑）。
--
-- 渲染顺序（Narrative）：opening → baseFragmentIds → 条件匹配片段 → closing。
-- 片段选择：关键定制 → 组合 → 单效果 → 通用；同档按 priority 降序、id 升序；
-- requiresFacts 全满足且 excludesFacts 未命中才入选；overrides 覆盖指定片段；
-- exclusiveGroup 同组只保留一个。重要事实无人覆盖时按 CONTENT_UNCOVERED 报错。
--
-- 条件只允许比较运算 eq/ne/gte/lte，输入限定在白名单来源（potion.effects / world.npcs /
-- context / facts）；药效表中缺某标签等价于该标签权重为 0。
-- 本文件只放内容数据；条件求值、片段拼装与评分顺序由程序按 B0 约定实现。
-- ============================================================================

return {
    -- ========================================================================
    -- 事实规则（DirectRule）
    --
    -- 规则全部针对同一输入快照匹配，再汇总 changes；规则之间不互相读取本批新事实。
    -- changes 的 path 从 world 根写起，必须指向 npcs.lua 已声明的字段。
    -- 事实 ID 汇总（重要事实必须被至少一个片段 covers）：
    --   fx_sleep_improved / fx_morning_work_ok   基础结果（所有合规单都有）
    --   fx_dreamt_mother                         认出母亲（B）
    --   fx_dreamt_figure_unclear / fx_self_distressed  认不清且难受（D）
    --   fx_mother_memory_faded                   母亲相关的私人记忆变淡（C/D）
    --   fx_restless_dreams                       零碎多梦（副作用标签 dream=0.4 触发）
    -- ========================================================================
    directRules = {
        -- 喜悦梦境 / 理性梦境；遗忘排除，组合覆盖普通母亲梦。
        {
            ruleSetId = "rules_pa_01",
            when = {
                { value = 0.8, op = "gte", path = "sleep", source = "potion.effects" },
                { value = 0.6, op = "gte", path = "dream", source = "potion.effects" },
                { value = 0.6, op = "gte", path = "happy", source = "potion.effects" },
            },
            priority = 30,
            id = "rule_pa_fish_choir",
            changes = {},
            facts = {
                { subjectId = "npc_passerby_a", id = "fx_pa_fish_choir", value = true, important = true, objectId = "mem_mother" },
            },
            unless = {
                { value = 0.6, op = "gte", path = "forget", source = "potion.effects" },
            },
        },
        {
            ruleSetId = "rules_pa_01",
            when = {
                { value = 0.8, op = "gte", path = "sleep", source = "potion.effects" },
                { value = 0.6, op = "gte", path = "dream", source = "potion.effects" },
                { value = 0.6, op = "gte", path = "reason", source = "potion.effects" },
                { source = "potion.effects", path = "happy", op = "lte", value = 0.6 },
                { source = "potion.effects", path = "happy", op = "ne", value = 0.6 },
            },
            priority = 30,
            id = "rule_pa_dream_ledger",
            changes = {},
            facts = {
                { subjectId = "npc_passerby_a", id = "fx_pa_dream_ledger", value = true, important = true, objectId = "mem_mother" },
            },
            unless = {
                { value = 0.6, op = "gte", path = "forget", source = "potion.effects" },
            },
        },
        {
            id = "rule_pa_rest_ok",
            ruleSetId = "rules_pa_01",
            priority = 10,
            desc = "睡好且次晨有力气：首单愿望的基础结果",
            when = {
                { source = "potion.effects", path = "sleep", op = "gte", value = 0.8 },
            },
            facts = {
                { id = "fx_sleep_improved", subjectId = "npc_passerby_a", value = true, important = true },
                { id = "fx_morning_work_ok", subjectId = "npc_passerby_a", value = true, important = true },
            },
            changes = {
                { path = "world.npcs.npc_passerby_a.sleepState", op = "set", value = "improved" },
                { path = "world.npcs.npc_passerby_a.workState", op = "set", value = "recovered" },
            },
        },
        {
            id = "rule_pa_dream_mother",
            ruleSetId = "rules_pa_01",
            priority = 30,
            desc = "梦到母亲并能认出：dream 达标且本单未使用遗忘",
            when = {
                { source = "potion.effects", path = "sleep", op = "gte", value = 0.8 },
                { source = "potion.effects", path = "dream", op = "gte", value = 0.6 },
            },
            unless = {
                { source = "potion.effects", path = "forget", op = "gte", value = 0.6 },
            },
            facts = {
                { id = "fx_dreamt_mother", subjectId = "npc_passerby_a", objectId = "mem_mother", value = true, important = true },
            },
            changes = {},
        },
        {
            id = "rule_pa_dream_unclear",
            ruleSetId = "rules_pa_01",
            priority = 40,
            desc = "梦境与遗忘交叉：看见重要的人却认不清，本人为此难受",
            when = {
                { source = "potion.effects", path = "sleep", op = "gte", value = 0.8 },
                { source = "potion.effects", path = "dream", op = "gte", value = 0.6 },
                { source = "potion.effects", path = "forget", op = "gte", value = 0.6 },
            },
            facts = {
                { id = "fx_dreamt_figure_unclear", subjectId = "npc_passerby_a", objectId = "mem_mother", value = true, important = true },
                { id = "fx_self_distressed", subjectId = "npc_passerby_a", value = true, important = true },
            },
            changes = {},
        },
        {
            id = "rule_pa_forget_fade",
            ruleSetId = "rules_pa_01",
            priority = 20,
            desc = "遗忘作用于本单指定的私人记忆（母亲相关）；状态变化在药效结束后仍保留",
            when = {
                { source = "potion.effects", path = "sleep", op = "gte", value = 0.8 },
                { source = "potion.effects", path = "forget", op = "gte", value = 0.6 },
            },
            facts = {
                { id = "fx_mother_memory_faded", subjectId = "npc_passerby_a", objectId = "mem_mother", value = "faded", important = true },
            },
            changes = {
                { path = "world.npcs.npc_passerby_a.memories.mem_mother.state", op = "set", value = "faded" },
            },
        },
        {
            id = "rule_pa_restless_dream",
            ruleSetId = "rules_pa_01",
            priority = 10,
            desc = "灰烬草副作用附加的 dream=0.4：零碎多梦，不构成「认出母亲」，也不作证据",
            when = {
                { source = "potion.effects", path = "sleep", op = "gte", value = 0.8 },
                { source = "potion.effects", path = "dream", op = "gte", value = 0.4 },
            },
            unless = {
                { source = "potion.effects", path = "dream", op = "gte", value = 0.6 },
            },
            facts = {
                { id = "fx_restless_dreams", subjectId = "npc_passerby_a", value = true, important = false },
            },
            changes = {},
        },
    },

    -- 事实互斥组：同组事实不得同时成立（规则条件已保证；此处声明供校验与后续扩展）
    factExclusionGroups = {
        {
            id = "xgroup_pa_dream",
            desc = "同一单的梦境结果互斥：要么认出母亲，要么认不清",
            factIds = { "fx_dreamt_mother", "fx_dreamt_figure_unclear" },
        },
    },

    -- ========================================================================
    -- 回信片段（Fragment）
    --
    -- kind：key（关键定制）/ combination（组合）/ single（单效果）/ generic（通用兜底）
    -- coversFacts 声明该片段「表达」了哪些事实；重要事实必须有片段覆盖。
    -- bindings 的 {{占位名}} 必须与 text 中出现的一致；来源限定白名单前缀。
    -- ========================================================================
    fragments = {
        {
            coversFacts = { "fx_pa_fish_choir", "fx_dreamt_mother" },
            templateId = "tpl_pa_01",
            text = "娘还在梦里当起了码头合唱团的指挥，指挥的是一排鱼，唱得比酒馆还齐。我醒来高兴，讲给妹妹听。她说下次挑一条会唱的回来，我说那可得另算工钱。",
            kind = "combination",
            priority = 60,
            id = "frag_pa_fish_choir",
            exclusiveGroup = "pa_dream_outcome",
            overrides = { "frag_pa_dream_mother" },
            requiresFacts = { "fx_pa_fish_choir", "fx_dreamt_mother" },
        },
        {
            coversFacts = { "fx_pa_dream_ledger", "fx_dreamt_mother" },
            templateId = "tpl_pa_01",
            text = "我梦见娘拿着账本，叫我查梦里的搬货工钱。每算清一笔，箱子就多出一条腿。娘看得直乐，我醒来也乐了：账目得按规矩来，梦里那些箱子却不肯。",
            kind = "combination",
            priority = 60,
            id = "frag_pa_dream_ledger",
            exclusiveGroup = "pa_dream_outcome",
            overrides = { "frag_pa_dream_mother" },
            requiresFacts = { "fx_pa_dream_ledger", "fx_dreamt_mother" },
        },
        {
            id = "frag_pa_work_recovered",
            templateId = "tpl_pa_01",
            kind = "key",
            priority = 100,
            desc = "共同基础反馈：睡好与次晨工作（A~D 都包含）",
            requiresFacts = { "fx_sleep_improved", "fx_morning_work_ok" },
            coversFacts = { "fx_sleep_improved", "fx_morning_work_ok" },
            overrides = {},
            text = "昨晚终于睡踏实了，隔壁酒馆什么时候散的，我都不知道。今天搬货，手上也有劲了。",
        },
        {
            id = "frag_pa_sleep_only",
            templateId = "tpl_pa_01",
            kind = "single",
            priority = 10,
            desc = "只有睡眠效果（A、G1、G4）：朴素收尾",
            requiresFacts = { "fx_sleep_improved" },
            excludesFacts = {
                "fx_dreamt_mother", "fx_mother_memory_faded",
                "fx_dreamt_figure_unclear", "fx_self_distressed", "fx_restless_dreams",
            },
            coversFacts = {},
            overrides = {},
            text = "今晚妹妹回来，我想早点吃完饭，早点歇着。多谢你。",
        },
        {
            id = "frag_pa_dream_mother",
            templateId = "tpl_pa_01",
            kind = "single",
            priority = 30,
            desc = "梦境单效果（B）：短暂梦到母亲，本人愿意",
            requiresFacts = { "fx_dreamt_mother" },
            excludesFacts = { "fx_dreamt_figure_unclear", "fx_mother_memory_faded" },
            coversFacts = { "fx_dreamt_mother" },
            overrides = {},
            exclusiveGroup = "pa_dream_outcome",
            text = "夜里还梦见了我娘，只有短短一会儿。醒来以后，我把这个梦讲给妹妹听，她让我也替她道声谢。",
        },
        {
            id = "frag_pa_forget_song",
            templateId = "tpl_pa_01",
            kind = "single",
            priority = 30,
            desc = "遗忘单效果（C）：母亲唱的歌想不起来了；歌名由人物记忆对象填充",
            requiresFacts = { "fx_mother_memory_faded" },
            excludesFacts = { "fx_dreamt_figure_unclear", "fx_self_distressed" },
            coversFacts = { "fx_mother_memory_faded" },
            overrides = {},
            bindings = {
                songTitle = { source = "world.npcs", path = "npc_passerby_a.memories.mem_mother.songTitle" },
            },
            text = "那些让我难受的事淡了一些。可今天妹妹哼起娘以前常唱的《{{songTitle}}》，我一时想不起后面的调子。她又哼了两遍，我还是没接上。",
        },
        {
            id = "frag_pa_dream_unclear",
            templateId = "tpl_pa_01",
            kind = "combination",
            priority = 50,
            desc = "梦境×遗忘组合（D）：认不清背影并难受；覆盖 B/C 的相关单效果片段",
            requiresFacts = { "fx_dreamt_figure_unclear" },
            excludesFacts = { "fx_dreamt_mother" },
            coversFacts = { "fx_dreamt_figure_unclear", "fx_self_distressed", "fx_mother_memory_faded" },
            overrides = { "frag_pa_dream_mother", "frag_pa_forget_song" },
            exclusiveGroup = "pa_dream_outcome",
            text = "夜里像是见着一个熟悉的背影。我知道那个人对我很要紧，可转过脸是什么样，醒着想也想不清。妹妹问我梦见了谁，我没答上来。那一整天，心里都像压着块石头。",
        },
        {
            id = "frag_pa_restless_dreams",
            templateId = "tpl_pa_01",
            kind = "single",
            priority = 20,
            desc = "副作用标签 dream=0.4 的单效果（G2/G3）：零碎多梦，不碍事",
            requiresFacts = { "fx_restless_dreams" },
            excludesFacts = { "fx_dreamt_mother", "fx_dreamt_figure_unclear" },
            coversFacts = { "fx_restless_dreams" },
            overrides = {},
            text = "夜里梦见码头的鱼排队领工钱，最小那条还嫌少。醒来想不起别的，倒记得该给妹妹讲这个笑话。不碍上工。",
        },
        {
            id = "frag_pa_generic",
            templateId = "tpl_pa_01",
            kind = "generic",
            priority = 0,
            desc = "合法兜底：没有专属片段可用时的通用反馈；不声称任何未配置的具体事实",
            requiresFacts = {},
            coversFacts = {},
            overrides = {},
            text = "睡是睡到了天亮。别的事我嘴笨，说不清楚，就先这样吧。",
        },
    },

    -- ========================================================================
    -- 后续信模板（FollowupTemplate）
    -- ========================================================================
    followupTemplates = {
        {
            id = "tpl_pa_01",
            letterId = "letter_pa_01_followup",
            opening = "店主，还是我，埃利亚斯，又请晨炉面包坊的卢卡替我写几句。",
            closing = "明天还要早起上工，就写到这里吧。\n\n埃利亚斯·沃德",
            baseFragmentIds = { "frag_pa_work_recovered" },
            fragmentIds = {
                "frag_pa_fish_choir",
                "frag_pa_dream_ledger",
                "frag_pa_sleep_only",
                "frag_pa_dream_mother",
                "frag_pa_forget_song",
                "frag_pa_dream_unclear",
                "frag_pa_restless_dreams",
            },
            fallbackFragmentIds = { "frag_pa_generic" },
        },
    },

    -- ========================================================================
    -- 评分规则（RatingRule）
    --
    -- 匹配顺序：三星 → 二星 → 一星；同星级内按 priority 降序、id 升序。
    -- 低星规则即使 priority 更高也不能压过高星。反馈必须可追溯到事实；
    -- 合规订单没有更高评价条件时落到一星兜底，不出现合规却无评价。
    -- ========================================================================
    orderRatings = {
        {
            id = "r3_mother_dream",
            ratingSetId = "rating_pa_01",
            priority = 30,
            stars = 3,
            desc = "B：愿望满足，本人愿意梦到母亲",
            requiresFacts = { "fx_sleep_improved", "fx_dreamt_mother" },
            excludesFacts = { "fx_dreamt_figure_unclear", "fx_self_distressed" },
            feedback = "这一觉睡到了大天亮，还见着了娘。店主，多谢你，我说不出更好的话了。",
        },
        {
            id = "r3_plain",
            ratingSetId = "rating_pa_01",
            priority = 20,
            stars = 3,
            desc = "A/G：完整满足睡眠与工作的愿望，无额外的记忆或梦境变化",
            requiresFacts = { "fx_sleep_improved", "fx_morning_work_ok" },
            excludesFacts = {
                "fx_dreamt_mother", "fx_mother_memory_faded",
                "fx_dreamt_figure_unclear", "fx_self_distressed",
            },
            feedback = "昨晚是我这阵子睡得最踏实的一晚，今早起来浑身是劲。多谢你啊，店主。",
        },
        {
            id = "r2_song_faded",
            ratingSetId = "rating_pa_01",
            priority = 20,
            stars = 2,
            desc = "C：愿望实现，但丢掉一段记忆，本人遗憾",
            requiresFacts = { "fx_sleep_improved", "fx_mother_memory_faded" },
            excludesFacts = { "fx_dreamt_mother", "fx_dreamt_figure_unclear", "fx_self_distressed" },
            feedback = "睡是睡好了，可有些东西跟着一起淡了。店主，我不知道该谢你还是该怪你。",
        },
        {
            id = "r1_distress",
            ratingSetId = "rating_pa_01",
            priority = 20,
            stars = 1,
            desc = "D：字面满足，但认不清重要的人令本人难受（难受有专门事实，不是因为有遗忘就扣星）",
            requiresFacts = { "fx_dreamt_figure_unclear", "fx_self_distressed" },
            excludesFacts = {},
            feedback = "这一觉睡得沉，可我一天都不痛快——像弄丢了什么要紧的东西，又说不上来。店主，下回别这样了。",
        },
        {
            id = "r1_fallback",
            ratingSetId = "rating_pa_01",
            priority = 0,
            stars = 1,
            desc = "兜底：仅当没有更高星规则匹配时使用；只引用所有合规首单都会产生的 fx_sleep_improved",
            requiresFacts = { "fx_sleep_improved" },
            excludesFacts = {},
            feedback = "睡是睡到了天亮。可我心里总觉得不太对劲，说不上来是哪里。就先这样吧。",
        },
    },
}
