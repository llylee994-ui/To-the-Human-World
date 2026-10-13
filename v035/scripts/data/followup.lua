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
            coversFacts = { "fx_sleep_improved", "fx_morning_work_ok", "fx_pa_fish_choir", "fx_dreamt_mother" },
            templateId = "tpl_pa_01",
            text = [[
昨晚梦见娘站在码头边上，面前整整齐齐排着一溜大白鱼，全都张着嘴等她领头唱。

她拍着手打拍子，前面的鱼倒跟得上，就末尾那条大胖鱼总是慢半拍。我想过去帮她把那条鱼抓出来，抱起来才发现那鱼身上全是滑溜溜的黏液，脱了手掉在地上瞎蹦腾。娘还嫌我挡着鱼看她的手势，嚷嚷着让我快放回去。

早上把这事讲给妹妹听，她正嚼着面包，笑得直咳嗽，渣子掉了一桌。她说娘以前带我俩唱调子也是这样，我老是抢拍子唱错，反倒去怪妹妹没跟上。

今天在码头搬鱼箱，看着箱子里堆的死鱼，我忍不住多看了两眼。旁边的同伴打趣问我是不是想顺一条回家煮汤，我摆摆手，一把将箱子扛上肩。干了一整天活都没觉得乏，晚上回铁锚巷，还要跟妹妹比划比划母亲指挥众鱼的模样。]],
            kind = "combination",
            priority = 60,
            id = "frag_pa_fish_choir",
            exclusiveGroup = "pa_dream_outcome",
            overrides = { "frag_pa_dream_mother" },
            requiresFacts = { "fx_pa_fish_choir", "fx_dreamt_mother" },
        },
        {
            coversFacts = { "fx_sleep_improved", "fx_morning_work_ok", "fx_pa_dream_ledger", "fx_dreamt_mother" },
            templateId = "tpl_pa_01",
            text = [[
昨晚梦见我又回到了码头，娘手里捧着个大账本坐在搬货的木台子上，催我赶紧把搬完的货报给她算工钱。

我跟她说我不识字看不懂账本，她白了我一眼，说让我只管报箱数，字由她来写。我点着头去数，刚数到十二，后头三个大木箱突然伸出几条木腿，撒丫子就往栈桥底下跑。我赶忙追过去抱住一个，另外两个又顺着水洼溜了。

娘抱着账本坐在台上笑，笑够了才起身帮我把最小的那只箱子拦在路中间。我解下裤腰上的麻绳，把这几只长腿的箱子一个个硬给拴成一串，这才抹抹汗重新数。

睁眼时天已经大亮，睡得踏实。到了码头，看着堆得老高的货物，我心里还记着昨晚数的数。今天卸完货跟工头清点，箱子都老老实实码在原地，报完最后一个数也没跑。]],
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
            desc = "保留历史片段 ID，仅供兜底；七篇整稿各自表达基础结果",
            requiresFacts = { "fx_sleep_improved", "fx_morning_work_ok" },
            coversFacts = { "fx_sleep_improved", "fx_morning_work_ok" },
            overrides = {},
            text = "今天在码头卸货没再出岔子，一起抬箱子的汉克还问我是不是好些了。",
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
            coversFacts = { "fx_sleep_improved", "fx_morning_work_ok" },
            overrides = {},
            text = [[
早上是妹妹找围裙把我弄醒的。她怕吵着我就没点灯，找半天找不到，最后还是我爬起来拿给她。窗外刚有点亮，我这一觉睡得好，身上有劲，便顺手把昨晚剩的汤搁火上热了下肚。

今天在码头卸货没再出岔子，一起抬箱子的汉克还问我是不是好些了。我让他放心抬他的那头，别总打量我。

收工回来正好赶上补鞋铺还没关门。师傅把鞋底拆开，指给我看里面的线都烂透了。我坐在凳子上等，听他絮絮叨叨讲前几天那场大雨，一路听到他把线扎紧断好，我也没打半个瞌睡。

今晚鞋就搁在床边晾着，妹妹端锅过来时，不用再费劲绕开我那双伸在外面的脚了。]],
        },
        {
            id = "frag_pa_dream_mother",
            templateId = "tpl_pa_01",
            kind = "single",
            priority = 30,
            desc = "梦境单效果（B）：短暂梦到母亲，本人愿意",
            requiresFacts = { "fx_dreamt_mother" },
            excludesFacts = { "fx_dreamt_figure_unclear", "fx_mother_memory_faded" },
            coversFacts = { "fx_sleep_improved", "fx_morning_work_ok", "fx_dreamt_mother" },
            overrides = {},
            exclusiveGroup = "pa_dream_outcome",
            text = [[
昨晚又梦见娘在旧桌子旁补衣裳。

我坐在旁边帮她牵着线，她嫌我扯得太紧，伸手在我手背上轻拍了一下。我松了松手，她就接着缝，针尖从磨薄的布里穿过去，又快又密。

早上妹妹叫我时我还记着梦里的事，边穿鞋边跟她讲。妹妹听完笑了，说那件衣裳后来短得露手腕，娘想拆自己的旧袖子给我接长，可她自己的衣裳也是补了又补，最后接上去的布两边颜色都不一样。

说着说着差点耽误她去面包坊，我送她走到巷口才往码头走。今天身上有劲，歇脚时跟同伴说笑几句，心里还记挂着那件双色袖子，想着晚上回去再跟妹妹唠唠。]],
        },
        {
            id = "frag_pa_forget_song",
            templateId = "tpl_pa_01",
            kind = "single",
            priority = 30,
            desc = "遗忘单效果（C）：母亲唱的歌想不起来了；按确认稿不点名歌名",
            bindings = {},
            requiresFacts = { "fx_mother_memory_faded" },
            excludesFacts = { "fx_dreamt_figure_unclear", "fx_self_distressed" },
            coversFacts = { "fx_sleep_improved", "fx_morning_work_ok", "fx_mother_memory_faded" },
            overrides = {},
            text = [[
昨晚躺下没多久就睡过去了。早上听见妹妹在屋里起床的动静，我也跟着起来，就着凉水吃了两口硬面包就去码头。今天搬货顺当，清点箱数也没差错，歇下来时只想找桶水痛快喝几口。

晚饭后妹妹在水盆边洗碗，嘴里哼着娘以前常唱的那段调子。我听着熟，想跟着接两句，可哼到后半截怎么也记不起词，调子也拐不回去。

妹妹以为我没听清，转过头又放慢哼了一遍。我试了两次还是卡在同一个地方，干脆不哼了，拿过干布站在她旁边替她擦碗。

她问我今晚还烤不烤脚，我把鞋底翻过来给她看补好的新线。她摸了摸，叮嘱我明早出门看着点脚下的泥坑，别刚补好又泡烂了。]],
        },
        {
            id = "frag_pa_dream_unclear",
            templateId = "tpl_pa_01",
            kind = "combination",
            priority = 50,
            desc = "梦境×遗忘组合（D）：认不清背影并难受；覆盖 B/C 的相关单效果片段",
            requiresFacts = { "fx_dreamt_figure_unclear" },
            excludesFacts = { "fx_dreamt_mother" },
            coversFacts = { "fx_sleep_improved", "fx_morning_work_ok", "fx_dreamt_figure_unclear", "fx_self_distressed", "fx_mother_memory_faded" },
            overrides = { "frag_pa_dream_mother", "frag_pa_forget_song" },
            exclusiveGroup = "pa_dream_outcome",
            text = [[
今早醒来胳膊腿都不僵了，去码头搬重货时，再没让旁边的汉克照顾我。可歇下来坐在木箱上，心里却总想着昨晚的梦，越琢磨越不是滋味。

昨晚梦里有个人坐在门口，膝盖上摊着件没缝完的衣裳。我走过去，她抬起头看我，好像等着我叫她。我看她面熟得很，可站在那儿愣了半天，张着嘴就是喊不出名字。

早上吃稀饭时我跟妹妹讲起这事，她停下筷子问我是不是梦见娘了。我本想应声，可仔细去想，连梦里那人的脸和说话声都模糊得像隔着雾，心里慌得厉害，只能让妹妹多给我讲讲娘以前的事。

她讲起娘如何在油灯下穿针，讲起那件接长了袖子的旧布衫。这都是梦里的事情，可我自己回想又想不起来。

妹妹收拾碗筷准备走，我还想听她再多说几句，伸手把她手里的空碗接过来清洗，让她坐着讲完再出门。]],
        },
        {
            id = "frag_pa_restless_dreams",
            templateId = "tpl_pa_01",
            kind = "single",
            priority = 20,
            desc = "副作用标签 dream=0.4 的单效果（G2/G3）：零碎多梦，不碍事",
            requiresFacts = { "fx_restless_dreams" },
            excludesFacts = { "fx_dreamt_mother", "fx_dreamt_figure_unclear" },
            coversFacts = { "fx_sleep_improved", "fx_morning_work_ok", "fx_restless_dreams" },
            overrides = {},
            text = [[
昨晚梦里颠颠倒倒的全是鱼。一会儿是在深海里游，一会儿又全排在码头结工钱的木桌前。

最小的那条小杂鱼嫌工头给的铜板少，贴着桌角往前挤，硬是不肯走。工头拍着桌子让它再去搬一箱来，它就在桌沿上猛拍尾巴，拍得上面的铜钱叮当响，撒了一地。我蹲在底下帮着捡铜钱，捡着捡着，手里的硬铜钱又变成了浅水滩里滑溜溜的石子。

早上醒来脑子里就剩下这点零碎片段，跟妹妹说的时候我自己都觉得没头没尾。她笑问我那条小鱼到底领到工钱没有，我说还没等工头数清钱，我就被邻街的鸡叫声吵醒了。

今天搬了一整天货，头一点没昏。中午吃饭时汉克还凑过来，问我今天怎么没犯恶心。]],
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
            -- 仅供旧存档审计，不参与新后续生成，不替换历史保存正文。
            legacy = {
                opening = "店主，还是我，埃利亚斯，又请晨炉面包坊的卢卡替我写几句。",
                closing = "明天还要早起上工，就写到这里吧。\n\n埃利亚斯·沃德",
                baseFragmentIds = { "frag_pa_work_recovered" },
                fragments = {
                ["frag_pa_fish_choir"] = { text = "娘还在梦里当起了码头合唱团的指挥，指挥的是一排鱼，唱得比酒馆还齐。我醒来高兴，讲给妹妹听。她说下次挑一条会唱的回来，我说那可得另算工钱。" },
                ["frag_pa_dream_ledger"] = { text = "我梦见娘拿着账本，叫我查梦里的搬货工钱。每算清一笔，箱子就多出一条腿。娘看得直乐，我醒来也乐了：账目得按规矩来，梦里那些箱子却不肯。" },
                ["frag_pa_work_recovered"] = { text = "昨晚终于睡踏实了，隔壁酒馆什么时候散的，我都不知道。今天搬货，手上也有劲了。" },
                ["frag_pa_sleep_only"] = { text = "今晚妹妹回来，我想早点吃完饭，早点歇着。多谢你。" },
                ["frag_pa_dream_mother"] = { text = "夜里还梦见了我娘，只有短短一会儿。醒来以后，我把这个梦讲给妹妹听，她让我也替她道声谢。" },
                ["frag_pa_forget_song"] = { text = "那些让我难受的事淡了一些。可今天妹妹哼起娘以前常唱的《{{songTitle}}》，我一时想不起后面的调子。她又哼了两遍，我还是没接上。", bindings = { songTitle = { source = "world.npcs", path = "npc_passerby_a.memories.mem_mother.songTitle" } } },
                ["frag_pa_dream_unclear"] = { text = "夜里像是见着一个熟悉的背影。我知道那个人对我很要紧，可转过脸是什么样，醒着想也想不清。妹妹问我梦见了谁，我没答上来。那一整天，心里都像压着块石头。" },
                ["frag_pa_restless_dreams"] = { text = "夜里梦见码头的鱼排队领工钱，最小那条还嫌少。醒来想不起别的，倒记得该给妹妹讲这个笑话。不碍上工。" },
                ["frag_pa_generic"] = { text = "睡是睡到了天亮。别的事我嘴笨，说不清楚，就先这样吧。" },
                },
            },
            opening = "",
            closing = "",
            baseFragmentIds = {},
            fragmentIds = {
                "frag_pa_fish_choir",
                "frag_pa_dream_ledger",
                "frag_pa_sleep_only",
                "frag_pa_dream_mother",
                "frag_pa_forget_song",
                "frag_pa_dream_unclear",
                "frag_pa_restless_dreams",
            },
            fallbackFragmentIds = { "frag_pa_work_recovered", "frag_pa_generic" },
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
