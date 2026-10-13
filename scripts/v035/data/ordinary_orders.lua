-- 正式普通订单：字面合规后解析事实，确认才提交人物状态与评价。
-- when 全部满足；unless 任一满足即排除。严格小于使用 lte + ne，避免边界缝隙。

return {
    followupTemplates = {
        {
            baseFragmentIds = { "frag_n01_hands_steady" },
            opening = "店主：",
            letterId = "letter_n01_followup",
            closing = [=[
就写到这里。

卢卡]=],
            id = "tpl_n01",
            fallbackFragmentIds = { "frag_n01_generic" },
            fragmentIds = { "frag_n01_kept_promise", "frag_n01_spoke_too_sharply", "frag_n01_missed_promise_unaware", "frag_n01_hurt_customer_noticed", "frag_n01_action_dulled", "frag_n01_market_memory_faded", "frag_n01_promise_recalled", "frag_n01_memory_contested", "frag_n01_bread_parade", "frag_n01_loaf_interview", "frag_n01_angry_buns", "frag_n01_confused_change", "frag_n01_fear_coin" },
        },
        {
            baseFragmentIds = { "frag_n02_mood_lightened" },
            opening = "店主：",
            letterId = "letter_n02_followup",
            closing = [=[
就写到这里。

诺拉]=],
            id = "tpl_n02",
            fallbackFragmentIds = { "frag_n02_generic" },
            fragmentIds = { "frag_n02_promise_kept", "frag_n02_old_arrangement_repeated", "frag_n02_overstepped_apologized", "frag_n02_forced_future_hurt", "frag_n02_response_dulled", "frag_n02_argument_memory_faded", "frag_n02_shared_appetite", "frag_n02_listened_patiently", "frag_n02_home_recalled", "frag_n02_soup_audit", "frag_n02_porcelain_cat", "frag_n02_warm_bowl", "frag_n02_sad_smile" },
        },
    },
    orderRatings = {
        {
            feedback = "手稳了，答应的面包也交到了人手里。正是我想要的。",
            priority = 20,
            excludesFacts = { "n01_spoke_too_sharply", "n01_action_dulled", "n01_hurt_customer_noticed", "n01_memory_contested", "n01_confused_change", "n01_fear_coin" },
            requiresFacts = { "n01_kept_promise" },
            id = "rating_n01_plain",
            stars = 3,
            ratingSetId = "rating_n01",
        },
        {
            feedback = "今天客人就是客人，我不用再怕那次笑声了。明天还能看柜台。",
            priority = 20,
            excludesFacts = { "n01_action_dulled", "n01_hurt_customer_noticed", "n01_memory_contested", "n01_confused_change", "n01_fear_coin" },
            requiresFacts = { "n01_missed_promise_unaware" },
            id = "rating_n01_unaware",
            stars = 3,
            ratingSetId = "rating_n01",
        },
        {
            feedback = "手不抖是好事，可嘴也得学会等别人说完。",
            priority = 20,
            excludesFacts = { "n01_action_dulled", "n01_memory_contested" },
            requiresFacts = { "n01_spoke_too_sharply" },
            id = "rating_n01_sharp",
            stars = 2,
            ratingSetId = "rating_n01",
        },
        {
            feedback = "手稳了，却当面伤了人，我不喜欢这样的自己。",
            priority = 20,
            excludesFacts = {},
            requiresFacts = { "n01_hurt_customer_noticed" },
            id = "rating_n01_hurt_customer_noticed",
            stars = 1,
            ratingSetId = "rating_n01",
        },
        {
            feedback = "钱没撒，可客人也没留下。这不是我想要的从容。",
            priority = 20,
            excludesFacts = {},
            requiresFacts = { "n01_action_dulled" },
            id = "rating_n01_action_dulled",
            stars = 1,
            ratingSetId = "rating_n01",
        },
        {
            feedback = "承诺一会儿在一会儿不在，我没能把话接下去。",
            priority = 20,
            excludesFacts = {},
            requiresFacts = { "n01_memory_contested" },
            id = "rating_n01_memory_contested",
            stars = 1,
            ratingSetId = "rating_n01",
        },
        {
            feedback = "笑得出来，也记得答应过什么。我们好好吃了顿饭。",
            priority = 20,
            excludesFacts = { "n02_response_dulled", "n02_forced_future_hurt", "n02_old_arrangement_repeated", "n02_overstepped_apologized" },
            requiresFacts = { "n02_promise_kept" },
            id = "rating_n02_plain",
            stars = 3,
            ratingSetId = "rating_n02",
        },
        {
            feedback = "今晚轻快了，可我连答应他的事也记不清。要是留下那句就好了。",
            priority = 20,
            excludesFacts = { "n02_response_dulled", "n02_forced_future_hurt" },
            requiresFacts = { "n02_old_arrangement_repeated" },
            id = "rating_n02_forgot",
            stars = 2,
            ratingSetId = "rating_n02",
        },
        {
            feedback = "幸好还能及时道歉。下次先把我的安排收好。",
            priority = 20,
            excludesFacts = { "n02_response_dulled", "n02_forced_future_hurt" },
            requiresFacts = { "n02_overstepped_apologized" },
            id = "rating_n02_apology",
            stars = 2,
            ratingSetId = "rating_n02",
        },
        {
            feedback = "我笑着把他又推远了一次。这种轻快，我不喜欢。",
            priority = 20,
            excludesFacts = {},
            requiresFacts = { "n02_forced_future_hurt" },
            id = "rating_n02_hurt",
            stars = 1,
            ratingSetId = "rating_n02",
        },
        {
            feedback = "没有板着脸，也没有好好回答他。我想吃饭，不想当摆设。",
            priority = 20,
            excludesFacts = {},
            requiresFacts = { "n02_response_dulled" },
            id = "rating_n02_dulled",
            stars = 1,
            ratingSetId = "rating_n02",
        },
        {
            feedback = "手很稳，可我数一枚铜币竟让客人等那么久。下次脑子也得跟上。",
            priority = 20,
            excludesFacts = { "n01_action_dulled", "n01_hurt_customer_noticed", "n01_memory_contested" },
            requiresFacts = { "n01_hands_steady", "n01_confused_change" },
            id = "rating_n01_confused",
            stars = 2,
            ratingSetId = "rating_n01",
        },
        {
            feedback = "没撒钱是好，可我紧张得让客人等了三遍数钱。",
            priority = 20,
            excludesFacts = { "n01_action_dulled", "n01_hurt_customer_noticed", "n01_memory_contested" },
            requiresFacts = { "n01_hands_steady", "n01_fear_coin" },
            id = "rating_n01_fear",
            stars = 2,
            ratingSetId = "rating_n01",
        },
    },
    fragments = {
        {
            kind = "key",
            priority = 20,
            text = "我的手今天没抖，铜币总算肯留在柜台上了。心里还是会一跳，手却没有跟着跳。",
            overrides = {},
            templateId = "tpl_n01",
            id = "frag_n01_hands_steady",
            coversFacts = { "n01_hands_steady" },
            requiresFacts = { "n01_hands_steady" },
        },
        {
            kind = "single",
            priority = 20,
            text = "我把留好的面包交给补衣裳的老太太。她说，这回看着像面包，上回更像门挡。我也笑了，零钱倒一枚没撒。",
            overrides = {},
            templateId = "tpl_n01",
            id = "frag_n01_kept_promise",
            coversFacts = { "n01_kept_promise" },
            requiresFacts = { "n01_kept_promise" },
        },
        {
            kind = "single",
            priority = 20,
            text = "有人问是不是刚出炉，我竟叫他自己摸烤盘。他缩回了手，我才明白他只是问价。手稳了，嘴却抢跑；我补了一句对不起。",
            overrides = {},
            templateId = "tpl_n01",
            id = "frag_n01_spoke_too_sharply",
            coversFacts = { "n01_spoke_too_sharply" },
            requiresFacts = { "n01_spoke_too_sharply" },
        },
        {
            kind = "single",
            priority = 20,
            text = "有位老太太说来拿我答应留的东西。我不记得，问她是不是找错伙计。她走后，我还当她记错了日子。今天倒第一次觉得，明天也能看柜台。",
            overrides = {},
            templateId = "tpl_n01",
            id = "frag_n01_missed_promise_unaware",
            coversFacts = { "n01_missed_promise_unaware" },
            requiresFacts = { "n01_missed_promise_unaware" },
        },
        {
            kind = "combination",
            priority = 50,
            text = "老太太来问预留的面包。我说，谁都拿一句答应来换，我还做不做生意。她拿出了我写的纸条。我认得字，却想不起承诺；这句话说得太伤人，我想收回来。",
            overrides = {},
            templateId = "tpl_n01",
            id = "frag_n01_hurt_customer_noticed",
            coversFacts = { "n01_hurt_customer_noticed" },
            requiresFacts = { "n01_hurt_customer_noticed" },
        },
        {
            kind = "single",
            priority = 20,
            text = "客人等着找钱，我觉得可以再等一会儿。等老板回来，面包没卖完，袋子倒折了一排。我只是想手别抖，不是想把柜台守成一场静物展。",
            overrides = {},
            templateId = "tpl_n01",
            id = "frag_n01_action_dulled",
            coversFacts = { "n01_action_dulled" },
            requiresFacts = { "n01_action_dulled" },
        },
        {
            kind = "single",
            priority = 20,
            text = "那次焦面包惹出的笑声，连同当时许的承诺，已经想不清了。交班时，我把价牌收进抽屉，又把明天要用的纸袋数了一遍。",
            overrides = {},
            templateId = "tpl_n01",
            id = "frag_n01_market_memory_faded",
            coversFacts = { "n01_market_memory_faded" },
            requiresFacts = { "n01_market_memory_faded" },
        },
        {
            kind = "single",
            priority = 20,
            text = "我清楚记起她替我解围时还攥着焦面包。这回留好的，不只是为了把钱账补平。",
            overrides = {},
            templateId = "tpl_n01",
            id = "frag_n01_promise_recalled",
            coversFacts = { "n01_promise_recalled" },
            requiresFacts = { "n01_promise_recalled" },
        },
        {
            kind = "combination",
            priority = 50,
            text = "那张纸条上的承诺一会儿清楚，一会儿空白。我拿着袋子，却接不上话，最后没能把留好的面包交出去。她问我是不是在练习忘词。我也希望只是那样。",
            overrides = {},
            templateId = "tpl_n01",
            id = "frag_n01_memory_contested",
            coversFacts = { "n01_memory_contested" },
            requiresFacts = { "n01_memory_contested" },
        },
        {
            kind = "key",
            priority = 20,
            text = "艾文说椅子太小。我看了看他，这两年他宽了一圈，便也笑了。心里轻快了，椅子还是得换一把。",
            overrides = {},
            templateId = "tpl_n02",
            id = "frag_n02_mood_lightened",
            coversFacts = { "n02_mood_lightened" },
            requiresFacts = { "n02_mood_lightened" },
        },
        {
            kind = "single",
            priority = 20,
            text = "他说船上的床窄，翻身时整排木板会响。我没问他挣多少，也没安排下一趟的事。汤喝完，他洗了两只碗，说下次还想来。我说，你来就做。",
            overrides = {},
            templateId = "tpl_n02",
            id = "frag_n02_promise_kept",
            coversFacts = { "n02_promise_kept" },
            requiresFacts = { "n02_promise_kept" },
        },
        {
            kind = "single",
            priority = 20,
            text = "我又说起替他找的活。他提醒我，下次回来只吃饭。我想不起那句承诺，只能先把话停住。饭吃完了，可我知道自己少记了一句要紧的话。",
            overrides = {},
            templateId = "tpl_n02",
            id = "frag_n02_old_arrangement_repeated",
            coversFacts = { "n02_old_arrangement_repeated" },
            requiresFacts = { "n02_old_arrangement_repeated" },
        },
        {
            kind = "single",
            priority = 20,
            text = "我一口气安排到了他明天该见谁。他问，还记不记得只吃饭。我想起来，赶紧道歉，说方才那些打算撤回。他没走，可开头还是被我搅了一下。",
            overrides = {},
            templateId = "tpl_n02",
            id = "frag_n02_overstepped_apologized",
            coversFacts = { "n02_overstepped_apologized" },
            requiresFacts = { "n02_overstepped_apologized" },
        },
        {
            kind = "combination",
            priority = 50,
            text = "我笑着坚持叫他留城，他把旧信放到汤碗边：下次回来，只吃饭。我认得自己的字，却想不起为什么答应。他提前走了。我看见了，这顿饭不是我想要的样子。",
            overrides = {},
            templateId = "tpl_n02",
            id = "frag_n02_forced_future_hurt",
            coversFacts = { "n02_forced_future_hurt" },
            requiresFacts = { "n02_forced_future_hurt" },
        },
        {
            kind = "single",
            priority = 20,
            text = "他问汤里放什么，我笑着点头；问窗口要不要修，我还是点头。直到他告别，我才发现自己像桌上第三个碗，只负责摆着。这不是我想要的休息。",
            overrides = {},
            templateId = "tpl_n02",
            id = "frag_n02_response_dulled",
            coversFacts = { "n02_response_dulled" },
            requiresFacts = { "n02_response_dulled" },
        },
        {
            kind = "single",
            priority = 20,
            text = "那次争吵和当时说过的承诺淡了。我还认得儿子，也还会炖汤，却没能留住那句话。",
            overrides = {},
            templateId = "tpl_n02",
            id = "frag_n02_argument_memory_faded",
            coversFacts = { "n02_argument_memory_faded" },
            requiresFacts = { "n02_argument_memory_faded" },
        },
        {
            kind = "single",
            priority = 20,
            text = "我坐下来把自己的汤喝完，还多吃一块面包。不是光顾着看他吃，原来我的碗也有事可做。",
            overrides = {},
            templateId = "tpl_n02",
            id = "frag_n02_shared_appetite",
            coversFacts = { "n02_shared_appetite" },
            requiresFacts = { "n02_shared_appetite" },
        },
        {
            kind = "single",
            priority = 20,
            text = "他说话时，我总算能等最后半句。听完以后要不要照做，仍是我自己的选择。",
            overrides = {},
            templateId = "tpl_n02",
            id = "frag_n02_listened_patiently",
            coversFacts = { "n02_listened_patiently" },
            requiresFacts = { "n02_listened_patiently" },
        },
        {
            kind = "single",
            priority = 20,
            text = "我想起他小时候听见勺子响就搬椅子，椅子比人还大。如今他一坐下，膝盖就快抵到桌沿了。",
            overrides = {},
            templateId = "tpl_n02",
            id = "frag_n02_home_recalled",
            coversFacts = { "n02_home_recalled" },
            requiresFacts = { "n02_home_recalled" },
        },
        {
            kind = "combination",
            priority = 50,
            text = "闻着面包香，我忍不住给新出炉的一排起了名字，还用稳稳的手给它们办了欢迎仪式。最小那块叫男爵，正式受封后，仪式便结束了——我把它吃了。",
            overrides = {},
            templateId = "tpl_n01",
            id = "frag_n01_bread_parade",
            coversFacts = { "n01_bread_parade" },
            requiresFacts = { "n01_bread_parade" },
        },
        {
            kind = "combination",
            priority = 50,
            text = "交班后，我严肃地问一排面包：谁先变硬，为什么？它们全不回答。我只好把烤炉时辰记成一张表。老板说，终于有了能管的事，可别再给面包做笔录。",
            overrides = {},
            templateId = "tpl_n01",
            id = "frag_n01_loaf_interview",
            coversFacts = { "n01_loaf_interview" },
            requiresFacts = { "n01_loaf_interview" },
        },
        {
            kind = "combination",
            priority = 50,
            text = "我给自己每一勺汤编号，郑重核对碗里还剩几勺。艾文说碗可没有少盛。我这才发现，每回核对完，证据都被我吃掉了。",
            overrides = {},
            templateId = "tpl_n02",
            id = "frag_n02_soup_audit",
            coversFacts = { "n02_soup_audit" },
            requiresFacts = { "n02_soup_audit" },
        },
        {
            kind = "combination",
            priority = 50,
            text = "饭后我忽然好奇那只缺耳瓷猫为何总显得不高兴，把它转向空碗，又转向窗外。我一点也不急，研究半天，发现只是脸画歪了。我拿针比了比，还是放下了。缝衣裳的针，补不好它这张脸。",
            overrides = {},
            templateId = "tpl_n02",
            id = "frag_n02_porcelain_cat",
            coversFacts = { "n02_porcelain_cat" },
            requiresFacts = { "n02_porcelain_cat" },
        },
        {
            kind = "combination",
            priority = 50,
            text = "今天身上暖，汤又香，我把空碗抱在手里多坐了一会儿，像捧着一只安静的小猫。抱到碗沿都干了，才想起它不用哄睡。",
            overrides = {},
            templateId = "tpl_n02",
            id = "frag_n02_warm_bowl",
            coversFacts = { "n02_warm_bowl" },
            requiresFacts = { "n02_warm_bowl" },
        },
        {
            kind = "combination",
            priority = 50,
            text = "我冲着老往架子外滚的圆面包喊：站好了！正伸手的客人以为是在说他，也站直了。我赶紧道歉，又给面包扶正。手稳得很好，只是嗓门得自己管。",
            overrides = {},
            templateId = "tpl_n01",
            id = "frag_n01_angry_buns",
            coversFacts = { "n01_angry_buns" },
            requiresFacts = { "n01_angry_buns" },
        },
        {
            kind = "single",
            priority = 20,
            text = "有一阵我盯着铜币，不知道该先数还是先装袋。手倒很稳，把同一枚翻来覆去，像在审一位不会说话的客人。等我弄清该干什么，人家已经等了好一会儿。",
            overrides = {},
            templateId = "tpl_n01",
            id = "frag_n01_confused_change",
            coversFacts = { "n01_confused_change" },
            requiresFacts = { "n01_confused_change" },
        },
        {
            kind = "single",
            priority = 20,
            text = "我怕又撒零钱，索性把铜币数了三遍。它们听话得很，一枚也没跳。第三遍时客人问，我是不是还在等它们自己报数。我确实让他等久了。",
            overrides = {},
            templateId = "tpl_n01",
            id = "frag_n01_fear_coin",
            coversFacts = { "n01_fear_coin" },
            requiresFacts = { "n01_fear_coin" },
        },
        {
            kind = "single",
            priority = 20,
            text = "轻快和难过竟然都在。我想起这两年的空椅子，笑着掉了两滴泪。艾文把手帕递来，我说不是汤咸，别冤枉锅。哭完舒服一点。",
            overrides = {},
            templateId = "tpl_n02",
            id = "frag_n02_sad_smile",
            coversFacts = { "n02_sad_smile" },
            requiresFacts = { "n02_sad_smile" },
        },
        {
            kind = "generic",
            priority = 0,
            text = "这一回的药效我已经写在前面了。多谢你看完。",
            overrides = {},
            templateId = "tpl_n01",
            id = "frag_n01_generic",
            coversFacts = {},
            requiresFacts = {},
        },
        {
            kind = "generic",
            priority = 0,
            text = "这一回的药效我已经写在前面了。多谢你看完。",
            overrides = {},
            templateId = "tpl_n02",
            id = "frag_n02_generic",
            coversFacts = {},
            requiresFacts = {},
        },
    },
    factExclusionGroups = {
        {
            factIds = { "n01_action_dulled", "n01_spoke_too_sharply", "n01_missed_promise_unaware", "n01_hurt_customer_noticed", "n01_memory_contested" },
            id = "xgroup_n01_action",
        },
        {
            factIds = { "n02_promise_kept", "n02_old_arrangement_repeated", "n02_overstepped_apologized", "n02_forced_future_hurt", "n02_response_dulled" },
            id = "xgroup_n02_action",
        },
    },
    directRules = {
        {
            priority = 20,
            ruleSetId = "rules_n01",
            facts = {
                { value = true, id = "n01_hands_steady", important = true, subjectId = "npc_luca" },
            },
            id = "rule_n01_hands_steady",
            when = {
                { path = "steady", value = 0.8, op = "gte", source = "potion.effects" },
            },
            changes = {},
        },
        {
            priority = 20,
            ruleSetId = "rules_n01",
            facts = {
                { subjectId = "npc_luca", objectId = "mem_market_mistake", id = "n01_memory_contested", important = true, value = true },
            },
            id = "rule_n01_memory_contested",
            when = {
                { path = "steady", value = 0.8, op = "gte", source = "potion.effects" },
                { path = "recall", value = 0.6, op = "gte", source = "potion.effects" },
                { path = "forget", value = 0.6, op = "gte", source = "potion.effects" },
            },
            changes = {},
        },
        {
            priority = 20,
            ruleSetId = "rules_n01",
            unless = {
                { path = "recall", value = 0.6, op = "gte", source = "potion.effects" },
            },
            facts = {
                { subjectId = "npc_luca", objectId = "mem_market_mistake", id = "n01_market_memory_faded", important = true, value = true },
            },
            id = "rule_n01_market_memory_faded",
            when = {
                { path = "steady", value = 0.8, op = "gte", source = "potion.effects" },
                { path = "forget", value = 0.6, op = "gte", source = "potion.effects" },
            },
            changes = {
                { path = "world.npcs.npc_luca.memories.mem_market_mistake.state", value = "faded", op = "set" },
            },
        },
        {
            priority = 20,
            ruleSetId = "rules_n01",
            facts = {
                { value = true, id = "n01_action_dulled", important = true, subjectId = "npc_luca" },
            },
            id = "rule_n01_action_dulled",
            when = {
                { path = "steady", value = 0.8, op = "gte", source = "potion.effects" },
                { path = "calm", value = 2.2, op = "gte", source = "potion.effects" },
                { path = "recall", value = 0.6, op = "lte", source = "potion.effects" },
                { path = "recall", value = 0.6, op = "ne", source = "potion.effects" },
            },
            changes = {},
        },
        {
            priority = 20,
            ruleSetId = "rules_n01",
            facts = {
                { value = true, id = "n01_action_dulled", important = true, subjectId = "npc_luca" },
            },
            id = "rule_n01_action_dulled_recalled",
            when = {
                { path = "steady", value = 0.8, op = "gte", source = "potion.effects" },
                { path = "calm", value = 2.2, op = "gte", source = "potion.effects" },
                { path = "recall", value = 0.6, op = "gte", source = "potion.effects" },
                { path = "forget", value = 0.6, op = "lte", source = "potion.effects" },
                { path = "forget", value = 0.6, op = "ne", source = "potion.effects" },
            },
            changes = {},
        },
        {
            priority = 20,
            ruleSetId = "rules_n01",
            unless = {
                { path = "forget", value = 0.6, op = "gte", source = "potion.effects" },
            },
            facts = {
                { value = true, id = "n01_kept_promise", important = true, subjectId = "npc_luca" },
            },
            id = "rule_n01_kept_promise",
            when = {
                { path = "steady", value = 0.8, op = "gte", source = "potion.effects" },
                { path = "calm", value = 2.2, op = "lte", source = "potion.effects" },
                { path = "calm", value = 2.2, op = "ne", source = "potion.effects" },
            },
            changes = {},
        },
        {
            priority = 20,
            ruleSetId = "rules_n01",
            unless = {
                { path = "forget", value = 0.6, op = "gte", source = "potion.effects" },
            },
            facts = {
                { value = true, id = "n01_spoke_too_sharply", important = true, subjectId = "npc_luca" },
            },
            id = "rule_n01_spoke_too_sharply",
            when = {
                { path = "steady", value = 0.8, op = "gte", source = "potion.effects" },
                { path = "brave", value = 0.6, op = "gte", source = "potion.effects" },
                { path = "calm", value = 2.2, op = "lte", source = "potion.effects" },
                { path = "calm", value = 2.2, op = "ne", source = "potion.effects" },
            },
            changes = {},
        },
        {
            priority = 20,
            ruleSetId = "rules_n01",
            unless = {
                { path = "recall", value = 0.6, op = "gte", source = "potion.effects" },
            },
            facts = {
                { value = true, id = "n01_missed_promise_unaware", important = true, subjectId = "npc_luca" },
            },
            id = "rule_n01_missed_promise_unaware",
            when = {
                { path = "steady", value = 0.8, op = "gte", source = "potion.effects" },
                { path = "forget", value = 0.6, op = "gte", source = "potion.effects" },
                { path = "brave", value = 0.6, op = "lte", source = "potion.effects" },
                { path = "brave", value = 0.6, op = "ne", source = "potion.effects" },
                { path = "calm", value = 2.2, op = "lte", source = "potion.effects" },
                { path = "calm", value = 2.2, op = "ne", source = "potion.effects" },
            },
            changes = {},
        },
        {
            priority = 20,
            ruleSetId = "rules_n01",
            unless = {
                { path = "recall", value = 0.6, op = "gte", source = "potion.effects" },
            },
            facts = {
                { value = true, id = "n01_hurt_customer_noticed", important = true, subjectId = "npc_luca" },
            },
            id = "rule_n01_hurt_customer_noticed",
            when = {
                { path = "steady", value = 0.8, op = "gte", source = "potion.effects" },
                { path = "brave", value = 0.6, op = "gte", source = "potion.effects" },
                { path = "forget", value = 0.6, op = "gte", source = "potion.effects" },
                { path = "calm", value = 2.2, op = "lte", source = "potion.effects" },
                { path = "calm", value = 2.2, op = "ne", source = "potion.effects" },
            },
            changes = {},
        },
        {
            priority = 20,
            ruleSetId = "rules_n01",
            unless = {
                { path = "forget", value = 0.6, op = "gte", source = "potion.effects" },
            },
            facts = {
                { subjectId = "npc_luca", objectId = "mem_market_mistake", id = "n01_promise_recalled", important = true, value = true },
            },
            id = "rule_n01_promise_recalled",
            when = {
                { path = "steady", value = 0.8, op = "gte", source = "potion.effects" },
                { path = "recall", value = 0.6, op = "gte", source = "potion.effects" },
            },
            changes = {},
        },
        {
            priority = 20,
            ruleSetId = "rules_n02",
            facts = {
                { value = true, id = "n02_mood_lightened", important = true, subjectId = "npc_nora" },
            },
            id = "rule_n02_mood_lightened",
            when = {
                { path = "happy", value = 0.8, op = "gte", source = "potion.effects" },
            },
            changes = {},
        },
        {
            priority = 20,
            ruleSetId = "rules_n02",
            facts = {
                { subjectId = "npc_nora", objectId = "mem_last_argument", id = "n02_argument_memory_faded", important = true, value = true },
            },
            id = "rule_n02_argument_memory_faded",
            when = {
                { path = "happy", value = 0.8, op = "gte", source = "potion.effects" },
                { path = "forget", value = 0.6, op = "gte", source = "potion.effects" },
            },
            changes = {
                { path = "world.npcs.npc_nora.memories.mem_last_argument.state", value = "faded", op = "set" },
            },
        },
        {
            priority = 20,
            ruleSetId = "rules_n02",
            facts = {
                { value = true, id = "n02_response_dulled", important = true, subjectId = "npc_nora" },
            },
            id = "rule_n02_response_dulled",
            when = {
                { path = "happy", value = 0.8, op = "gte", source = "potion.effects" },
                { path = "calm", value = 2.2, op = "gte", source = "potion.effects" },
            },
            changes = {},
        },
        {
            priority = 20,
            ruleSetId = "rules_n02",
            unless = {
                { path = "forget", value = 0.6, op = "gte", source = "potion.effects" },
            },
            facts = {
                { value = true, id = "n02_promise_kept", important = true, subjectId = "npc_nora" },
            },
            id = "rule_n02_promise_kept",
            when = {
                { path = "happy", value = 0.8, op = "gte", source = "potion.effects" },
                { path = "calm", value = 2.2, op = "lte", source = "potion.effects" },
                { path = "calm", value = 2.2, op = "ne", source = "potion.effects" },
                { path = "brave", value = 0.6, op = "lte", source = "potion.effects" },
                { path = "brave", value = 0.6, op = "ne", source = "potion.effects" },
            },
            changes = {},
        },
        {
            priority = 20,
            ruleSetId = "rules_n02",
            facts = {
                { value = true, id = "n02_old_arrangement_repeated", important = true, subjectId = "npc_nora" },
            },
            id = "rule_n02_old_arrangement_repeated",
            when = {
                { path = "happy", value = 0.8, op = "gte", source = "potion.effects" },
                { path = "forget", value = 0.6, op = "gte", source = "potion.effects" },
                { path = "calm", value = 2.2, op = "lte", source = "potion.effects" },
                { path = "calm", value = 2.2, op = "ne", source = "potion.effects" },
                { path = "brave", value = 0.6, op = "lte", source = "potion.effects" },
                { path = "brave", value = 0.6, op = "ne", source = "potion.effects" },
            },
            changes = {},
        },
        {
            priority = 20,
            ruleSetId = "rules_n02",
            unless = {
                { path = "forget", value = 0.6, op = "gte", source = "potion.effects" },
            },
            facts = {
                { value = true, id = "n02_overstepped_apologized", important = true, subjectId = "npc_nora" },
            },
            id = "rule_n02_overstepped_apologized",
            when = {
                { path = "happy", value = 0.8, op = "gte", source = "potion.effects" },
                { path = "brave", value = 0.6, op = "gte", source = "potion.effects" },
                { path = "calm", value = 2.2, op = "lte", source = "potion.effects" },
                { path = "calm", value = 2.2, op = "ne", source = "potion.effects" },
            },
            changes = {},
        },
        {
            priority = 20,
            ruleSetId = "rules_n02",
            facts = {
                { value = true, id = "n02_forced_future_hurt", important = true, subjectId = "npc_nora" },
            },
            id = "rule_n02_forced_future_hurt",
            when = {
                { path = "happy", value = 0.8, op = "gte", source = "potion.effects" },
                { path = "forget", value = 0.6, op = "gte", source = "potion.effects" },
                { path = "brave", value = 0.6, op = "gte", source = "potion.effects" },
                { path = "calm", value = 2.2, op = "lte", source = "potion.effects" },
                { path = "calm", value = 2.2, op = "ne", source = "potion.effects" },
            },
            changes = {},
        },
        {
            priority = 20,
            ruleSetId = "rules_n02",
            facts = {
                { value = true, id = "n02_shared_appetite", important = true, subjectId = "npc_nora" },
            },
            id = "rule_n02_shared_appetite",
            when = {
                { path = "happy", value = 0.8, op = "gte", source = "potion.effects" },
                { path = "appetite", value = 0.6, op = "gte", source = "potion.effects" },
            },
            changes = {},
        },
        {
            priority = 20,
            ruleSetId = "rules_n02",
            unless = {
                { path = "calm", value = 2.2, op = "gte", source = "potion.effects" },
            },
            facts = {
                { value = true, id = "n02_listened_patiently", important = true, subjectId = "npc_nora" },
            },
            id = "rule_n02_listened_patiently",
            when = {
                { path = "happy", value = 0.8, op = "gte", source = "potion.effects" },
                { path = "calm", value = 0.6, op = "gte", source = "potion.effects" },
            },
            changes = {},
        },
        {
            priority = 20,
            ruleSetId = "rules_n02",
            facts = {
                { subjectId = "npc_nora", objectId = "mem_home_table", id = "n02_home_recalled", important = true, value = true },
            },
            id = "rule_n02_home_recalled",
            when = {
                { path = "happy", value = 0.8, op = "gte", source = "potion.effects" },
                { path = "recall", value = 0.3, op = "gte", source = "potion.effects" },
            },
            changes = {},
        },
        {
            priority = 20,
            ruleSetId = "rules_n01",
            facts = {
                { value = true, id = "n01_bread_parade", important = true, subjectId = "npc_luca" },
            },
            id = "rule_n01_bread_parade",
            when = {
                { path = "steady", value = 0.8, op = "gte", source = "potion.effects" },
                { path = "happy", value = 0.6, op = "gte", source = "potion.effects" },
                { path = "appetite", value = 0.6, op = "gte", source = "potion.effects" },
            },
            changes = {},
        },
        {
            priority = 20,
            ruleSetId = "rules_n01",
            facts = {
                { value = true, id = "n01_loaf_interview", important = true, subjectId = "npc_luca" },
            },
            id = "rule_n01_loaf_interview",
            when = {
                { path = "steady", value = 0.8, op = "gte", source = "potion.effects" },
                { path = "reason", value = 0.6, op = "gte", source = "potion.effects" },
                { path = "curiosity", value = 0.6, op = "gte", source = "potion.effects" },
            },
            changes = {},
        },
        {
            priority = 20,
            ruleSetId = "rules_n02",
            facts = {
                { value = true, id = "n02_soup_audit", important = true, subjectId = "npc_nora" },
            },
            id = "rule_n02_soup_audit",
            when = {
                { path = "happy", value = 0.8, op = "gte", source = "potion.effects" },
                { path = "reason", value = 0.6, op = "gte", source = "potion.effects" },
                { path = "appetite", value = 0.6, op = "gte", source = "potion.effects" },
            },
            changes = {},
        },
        {
            priority = 20,
            ruleSetId = "rules_n02",
            facts = {
                { value = true, id = "n02_porcelain_cat", important = true, subjectId = "npc_nora" },
            },
            id = "rule_n02_porcelain_cat",
            when = {
                { path = "happy", value = 0.8, op = "gte", source = "potion.effects" },
                { path = "curiosity", value = 0.6, op = "gte", source = "potion.effects" },
                { path = "relax", value = 0.6, op = "gte", source = "potion.effects" },
            },
            changes = {},
        },
        {
            priority = 20,
            ruleSetId = "rules_n02",
            facts = {
                { value = true, id = "n02_warm_bowl", important = true, subjectId = "npc_nora" },
            },
            id = "rule_n02_warm_bowl",
            when = {
                { path = "happy", value = 0.8, op = "gte", source = "potion.effects" },
                { path = "warmth", value = 0.6, op = "gte", source = "potion.effects" },
                { path = "appetite", value = 0.6, op = "gte", source = "potion.effects" },
            },
            changes = {},
        },
        {
            priority = 20,
            ruleSetId = "rules_n01",
            facts = {
                { value = true, id = "n01_angry_buns", important = true, subjectId = "npc_luca" },
            },
            id = "rule_n01_angry_buns",
            when = {
                { path = "steady", value = 0.8, op = "gte", source = "potion.effects" },
                { path = "anger", value = 0.6, op = "gte", source = "potion.effects" },
                { path = "brave", value = 0.6, op = "gte", source = "potion.effects" },
            },
            changes = {},
        },
        {
            priority = 20,
            ruleSetId = "rules_n01",
            facts = {
                { value = true, id = "n01_confused_change", important = true, subjectId = "npc_luca" },
            },
            id = "rule_n01_confused_change",
            when = {
                { path = "steady", value = 0.8, op = "gte", source = "potion.effects" },
                { path = "confusion", value = 0.6, op = "gte", source = "potion.effects" },
            },
            changes = {},
        },
        {
            priority = 20,
            ruleSetId = "rules_n01",
            facts = {
                { value = true, id = "n01_fear_coin", important = true, subjectId = "npc_luca" },
            },
            id = "rule_n01_fear_coin",
            when = {
                { path = "steady", value = 0.8, op = "gte", source = "potion.effects" },
                { path = "fear", value = 0.6, op = "gte", source = "potion.effects" },
            },
            changes = {},
        },
        {
            priority = 20,
            ruleSetId = "rules_n02",
            facts = {
                { value = true, id = "n02_sad_smile", important = true, subjectId = "npc_nora" },
            },
            id = "rule_n02_sad_smile",
            when = {
                { path = "happy", value = 0.8, op = "gte", source = "potion.effects" },
                { path = "sadness", value = 0.6, op = "gte", source = "potion.effects" },
            },
            changes = {},
        },
    },
    letters = {
        {
            appearCondition = { dayMin = 2 },
            selfIntro = "我叫卢卡，在铁锚巷的晨炉面包坊做伙计。平时和面、搬盘子，有人要给家里写信，也会来找我。前两天我替一个码头搬货的人写过信，不知道有没有到你手上。这回轮到我自己求你了。",
            requirement = {
                desc = "一小时内手不再发抖，稳手持续两到四小时；睡眠强度不得超过 0.4",
                tags = { steady = 0.8 },
                conditions = {
                    { kind = "duration", id = "n01_duration", minHours = 2, maxHours = 4 },
                    { kind = "onset", id = "n01_onset", maxDelayHours = 1 },
                    { kind = "forbiddenEffect", id = "n01_sleep", maxWeight = 0.4, effectId = "sleep" },
                },
                forbiddenEffects = {},
            },
            body = [=[
海边的店主：

老板明天中午要去看牙，让我独自守一小时柜台。他说，只是把{{面包}}递出去，把钱收回来，有什么好怕的。我也是这么想的，直到有个人站到柜台前。

上回我把烤焦的面包装给一位补衣裳的老太太。旁边的人笑起来，说会写字的伙计原来也认不出一块焦面包。她没骂我，只说家里有人爱吃脆的。我{{答应}}下次给她留一块好的，钱就不用再付了。可那天之后，我连看她一眼都不敢。

给别人写信时，我总劝人把头抬起来。轮到自己，却连{{抬头}}看看对方都难。一有人问价，手就开始抖，零钱越数越乱。

能不能让我{{手稳}}一点？撑过明天柜台前那阵忙乱就好。心里还会害怕也没关系，至少别再把找回去的铜币撒到地上。

下午我还要看烤炉，不能用叫人睡着的办法。要是睡意也跟着来，我就不敢喝。

明天我会早点起来，把那块好的面包留出来。这件事，我想记得。

卢卡]=],
            ratingSetId = "rating_n01",
            id = "letter_n01",
            followupTemplateId = "tpl_n01",
            bottleType = "normal",
            kind = "order",
            reward = { currency = 80 },
            attachments = {},
            senderId = "npc_luca",
            cuttable = true,
            directRuleSetId = "rules_n01",
            title = "柜台前的一小时",
            address = "灰港 铁锚巷 8 号 晨炉面包坊 后门收。不要放到隔壁酒馆；早班伙计会把瓶子放进干净的空面粉桶。",
        },
        {
            id = "letter_n01_followup",
            kind = "direct_followup",
            followupTemplateId = "tpl_n01",
            attachments = {},
            senderId = "npc_luca",
            cuttable = false,
            bottleType = "normal",
            title = "卢卡的回信",
            address = "灰港 铁锚巷 8 号 晨炉面包坊 后门收。不要放到隔壁酒馆；早班伙计会把瓶子放进干净的空面粉桶。",
        },
        {
            appearCondition = { dayMin = 4 },
            selfIntro = "我叫诺拉，在铁锚巷补衣裳。窗口上放着一只缺耳朵的瓷猫，找得到猫，就找得到我。儿子叫艾文，在船上做木工，明晚靠港。我已经把他从前那把椅子擦过两遍了。",
            requirement = {
                desc = "一小时内轻快起来，愉悦持续两到四小时；睡眠强度不得超过 0.4",
                tags = { happy = 0.8 },
                conditions = {
                    { kind = "duration", id = "n02_duration", minHours = 2, maxHours = 4 },
                    { kind = "onset", id = "n02_onset", maxDelayHours = 1 },
                    { kind = "forbiddenEffect", id = "n02_sleep", maxWeight = 0.4, effectId = "sleep" },
                },
                forbiddenEffects = {},
            },
            body = [=[
店主：

我不常求这些东西。针断了换一根，衣服小了放一道边，总有手上能做的事。

可两个人隔着桌子坐下来，有些话就不知道从哪里拆起。

艾文明晚{{回家}}。两年前他走的时候，我们吵得很难看。我总说城里有份正经活，他总问，为什么他想去的地方就不正经。最后我答应他，下次回来，只吃饭，不替他安排。话是我自己说的，这两年却总在心里反悔。

我想明晚能对他{{笑}}一笑。不是把两年前说成没有发生，只是别等他还没坐下，就先摆出一张讨债的脸。

我已经买了面包，准备炖一锅{{汤}}。他小时候等饭会喊饿，我那时嫌吵，现在倒希望门外再有人喊一声。

邻居说，孩子回来了，过去的事能忘记就忘记。我没接话，只把多余的一把椅子搬进去了。

我想在他敲门前，心里先轻快一点，够我们慢慢把晚饭吃完。锅还得有人看着，可别让我打瞌睡。

要是吃饭的时候能{{等}}他把话说完，不急着问他挣多少、几时回来，就更好了。

我不知道现在的他还爱不爱喝那种汤。先少放一点盐吧。

诺拉]=],
            ratingSetId = "rating_n02",
            id = "letter_n02",
            followupTemplateId = "tpl_n02",
            bottleType = "normal",
            kind = "order",
            reward = { currency = 80 },
            attachments = {},
            senderId = "npc_nora",
            cuttable = true,
            directRuleSetId = "rules_n02",
            title = "两个人的晚饭",
            address = "灰港 铁锚巷 14 号 一层 临街补衣窗口收。窗口关了就从门缝塞一张收货条，不要把瓶子留在门口台阶上。",
        },
        {
            id = "letter_n02_followup",
            kind = "direct_followup",
            followupTemplateId = "tpl_n02",
            attachments = {},
            senderId = "npc_nora",
            cuttable = false,
            bottleType = "normal",
            title = "诺拉的回信",
            address = "灰港 铁锚巷 14 号 一层 临街补衣窗口收。窗口关了就从门缝塞一张收货条，不要把瓶子留在门口台阶上。",
        },
    },
    npcs = {
        {
            background = "平民雇工，会读写；是埃利亚斯的代笔人，递袋时紧张",
            notes = "正式普通订单；不会因此拥有主线案件知识",
            id = "npc_luca",
            family = "与同城的姐姐来往；借住面包坊后屋",
            age = 22,
            initialState = {
                memories = {
                    mem_market_mistake = { state = "intact", label = "焦面包与补偿承诺" },
                },
            },
            initialStateSchema = {
                memories = {
                    keys = { "mem_market_mistake" },
                    entry = {
                        state = {
                            values = { "intact", "faded", "lost" },
                            type = "enum",
                        },
                        label = { type = "text" },
                    },
                    type = "map",
                },
            },
            name = "卢卡",
            inCase = false,
            occupation = "晨炉面包坊伙计兼代笔人",
            gender = "男",
            address = "灰港 铁锚巷 8 号 晨炉面包坊 后门收",
        },
        {
            background = "平民劳动者，能读写简单收条；习惯把关心说成安排",
            notes = "正式普通订单；不会因此拥有主线案件知识",
            id = "npc_nora",
            family = "儿子艾文在船上做木工，明晚按约回港吃饭",
            age = 63,
            initialState = {
                memories = {
                    mem_home_table = { state = "intact", label = "儿时等汤与搬椅子" },
                    mem_last_argument = { state = "intact", label = "两年前争吵与只吃饭的承诺" },
                },
            },
            initialStateSchema = {
                memories = {
                    keys = { "mem_last_argument", "mem_home_table" },
                    entry = {
                        state = {
                            values = { "intact", "faded", "lost" },
                            type = "enum",
                        },
                        label = { type = "text" },
                    },
                    type = "map",
                },
            },
            name = "诺拉",
            inCase = false,
            occupation = "补衣工",
            gender = "女",
            address = "灰港 铁锚巷 14 号 一层 临街补衣窗口收",
        },
    },
}
