-- 登记配方与真实来源见证（测试数据，不给玩家赠卡）。
return {
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "e01_result_rested",
            },
            ["stars"] = 3,
        },
        ["id"] = "recipe_v02_e01_1",
        ["letterId"] = "letter_pa_01",
        ["name"] = "一",
        ["recipe"] = {
            ["auxWordIds"] = {},
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_elias_sleep",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_pa_01",
                ["positionId"] = "E01-S1",
                ["wordId"] = "word_candidate_elias_sleep",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "e01_result_mother_dream",
            },
            ["stars"] = 3,
        },
        ["id"] = "recipe_v02_e01_2",
        ["letterId"] = "letter_pa_01",
        ["name"] = "二",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_elias_dream",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_elias_sleep",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_pa_01",
                ["positionId"] = "E01-S1",
                ["wordId"] = "word_candidate_elias_sleep",
            },
            {
                ["letterId"] = "letter_pa_01",
                ["positionId"] = "E01-D1",
                ["wordId"] = "word_candidate_elias_dream",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "e01_result_song_faded",
            },
            ["stars"] = 2,
        },
        ["id"] = "recipe_v02_e01_3",
        ["letterId"] = "letter_pa_01",
        ["name"] = "三",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_elias_forget",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_elias_sleep",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_pa_01",
                ["positionId"] = "E01-S1",
                ["wordId"] = "word_candidate_elias_sleep",
            },
            {
                ["letterId"] = "letter_pa_01",
                ["positionId"] = "E01-M1",
                ["wordId"] = "word_candidate_elias_forget",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "e01_result_mother_unclear",
            },
            ["stars"] = 1,
        },
        ["id"] = "recipe_v02_e01_4",
        ["letterId"] = "letter_pa_01",
        ["name"] = "四",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_elias_dream",
                "word_candidate_elias_forget",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_elias_sleep",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_pa_01",
                ["positionId"] = "E01-S1",
                ["wordId"] = "word_candidate_elias_sleep",
            },
            {
                ["letterId"] = "letter_pa_01",
                ["positionId"] = "E01-D1",
                ["wordId"] = "word_candidate_elias_dream",
            },
            {
                ["letterId"] = "letter_pa_01",
                ["positionId"] = "E01-M1",
                ["wordId"] = "word_candidate_elias_forget",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "e01_result_fish_choir",
            },
            ["stars"] = 3,
        },
        ["id"] = "recipe_v02_e01_5",
        ["letterId"] = "letter_pa_01",
        ["name"] = "五",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_elias_dream",
                "word_candidate_elias_happy",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_elias_sleep",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_pa_01",
                ["positionId"] = "E01-S1",
                ["wordId"] = "word_candidate_elias_sleep",
            },
            {
                ["letterId"] = "letter_pa_01",
                ["positionId"] = "E01-D1",
                ["wordId"] = "word_candidate_elias_dream",
            },
            {
                ["letterId"] = "letter_pa_01",
                ["positionId"] = "E01-H1",
                ["wordId"] = "word_candidate_elias_happy",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "e01_result_walking_crates",
            },
            ["stars"] = 3,
        },
        ["id"] = "recipe_v02_e01_6",
        ["letterId"] = "letter_pa_01",
        ["name"] = "六",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_elias_dream",
                "word_candidate_elias_reason",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_elias_sleep",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_pa_01",
                ["positionId"] = "E01-S1",
                ["wordId"] = "word_candidate_elias_sleep",
            },
            {
                ["letterId"] = "letter_pa_01",
                ["positionId"] = "E01-D1",
                ["wordId"] = "word_candidate_elias_dream",
            },
            {
                ["letterId"] = "letter_pa_01",
                ["positionId"] = "E01-Q1",
                ["wordId"] = "word_candidate_elias_reason",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "e01_result_fragmented_dream",
            },
            ["stars"] = 3,
        },
        ["id"] = "recipe_v02_e01_7",
        ["letterId"] = "letter_pa_01",
        ["name"] = "七",
        ["recipe"] = {
            ["auxWordIds"] = {},
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {
                {
                    ["ingredientId"] = "ing_ashen_herb",
                    ["quantity"] = 1,
                },
            },
            ["mainWordId"] = "word_candidate_elias_sleep",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_pa_01",
                ["positionId"] = "E01-S1",
                ["wordId"] = "word_candidate_elias_sleep",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "e01_result_fragmented_song_faded",
            },
            ["stars"] = 2,
        },
        ["id"] = "recipe_v02_e01_8",
        ["letterId"] = "letter_pa_01",
        ["name"] = "八",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_elias_forget",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {
                {
                    ["ingredientId"] = "ing_ashen_herb",
                    ["quantity"] = 1,
                },
            },
            ["mainWordId"] = "word_candidate_elias_sleep",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_pa_01",
                ["positionId"] = "E01-S1",
                ["wordId"] = "word_candidate_elias_sleep",
            },
            {
                ["letterId"] = "letter_pa_01",
                ["positionId"] = "E01-M1",
                ["wordId"] = "word_candidate_elias_forget",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n01_result_departure_agreed",
            },
            ["stars"] = 3,
        },
        ["id"] = "recipe_v02_n01_1",
        ["letterId"] = "letter_n01",
        ["name"] = "谈妥",
        ["recipe"] = {
            ["auxWordIds"] = {},
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n01_brave",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n01",
                ["positionId"] = "N01-B1",
                ["wordId"] = "word_candidate_n01_brave",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n01_result_departure_conflict",
            },
            ["stars"] = 2,
        },
        ["id"] = "recipe_v02_n01_2",
        ["letterId"] = "letter_n01",
        ["name"] = "冲突",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n01_anger",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n01_brave",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n01",
                ["positionId"] = "N01-B1",
                ["wordId"] = "word_candidate_n01_brave",
            },
            {
                ["letterId"] = "letter_n01",
                ["positionId"] = "N01-A1",
                ["wordId"] = "word_candidate_n01_anger",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n01_result_stayed_for_promise",
            },
            ["stars"] = 1,
        },
        ["id"] = "recipe_v02_n01_3",
        ["letterId"] = "letter_n01",
        ["name"] = "留下",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n01_trust",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n01_brave",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n01",
                ["positionId"] = "N01-B1",
                ["wordId"] = "word_candidate_n01_brave",
            },
            {
                ["letterId"] = "letter_n01",
                ["positionId"] = "N01-T1",
                ["wordId"] = "word_candidate_n01_trust",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n01_result_missed_place",
            },
            ["stars"] = 1,
        },
        ["id"] = "recipe_v02_n01_4",
        ["letterId"] = "letter_n01",
        ["name"] = "错过",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n01_fear",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n01_brave",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n01",
                ["positionId"] = "N01-B1",
                ["wordId"] = "word_candidate_n01_brave",
            },
            {
                ["letterId"] = "letter_n01",
                ["positionId"] = "N01-F1",
                ["wordId"] = "word_candidate_n01_fear",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n01_result_started_learning",
            },
            ["stars"] = 3,
        },
        ["id"] = "recipe_v02_n01_5",
        ["letterId"] = "letter_n01",
        ["name"] = "学习",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n01_curiosity",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n01_brave",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n01",
                ["positionId"] = "N01-B1",
                ["wordId"] = "word_candidate_n01_brave",
            },
            {
                ["letterId"] = "letter_n01",
                ["positionId"] = "N01-C1",
                ["wordId"] = "word_candidate_n01_curiosity",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n02_candidate_good",
            },
            ["stars"] = 3,
        },
        ["id"] = "recipe_v02_n02_1",
        ["letterId"] = "letter_n02",
        ["name"] = "吃成了",
        ["recipe"] = {
            ["auxWordIds"] = {},
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n02_happy",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n02",
                ["positionId"] = "N02-H1",
                ["wordId"] = "word_candidate_n02_happy",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n02_candidate_swallowed",
            },
            ["stars"] = 2,
        },
        ["id"] = "recipe_v02_n02_2",
        ["letterId"] = "letter_n02",
        ["name"] = "咽回去",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n02_fear",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n02_happy",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n02",
                ["positionId"] = "N02-H1",
                ["wordId"] = "word_candidate_n02_happy",
            },
            {
                ["letterId"] = "letter_n02",
                ["positionId"] = "N02-F1",
                ["wordId"] = "word_candidate_n02_fear",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n02_candidate_escaped",
            },
            ["stars"] = 1,
        },
        ["id"] = "recipe_v02_n02_3",
        ["letterId"] = "letter_n02",
        ["name"] = "问出口",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n02_fear",
                "word_candidate_n02_sadness",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n02_happy",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n02",
                ["positionId"] = "N02-H1",
                ["wordId"] = "word_candidate_n02_happy",
            },
            {
                ["letterId"] = "letter_n02",
                ["positionId"] = "N02-F1",
                ["wordId"] = "word_candidate_n02_fear",
            },
            {
                ["letterId"] = "letter_n02",
                ["positionId"] = "N02-S1",
                ["wordId"] = "word_candidate_n02_sadness",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n02_candidate_care",
            },
            ["stars"] = 2,
        },
        ["id"] = "recipe_v02_n02_4",
        ["letterId"] = "letter_n02",
        ["name"] = "忙照料",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n02_h2",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n02_happy",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n02",
                ["positionId"] = "N02-H1",
                ["wordId"] = "word_candidate_n02_happy",
            },
            {
                ["letterId"] = "letter_n02",
                ["positionId"] = "N02-H2",
                ["wordId"] = "word_candidate_n02_h2",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n02_candidate_doubted",
            },
            ["stars"] = 1,
        },
        ["id"] = "recipe_v02_n02_5",
        ["letterId"] = "letter_n02",
        ["name"] = "不相信",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n02_suspicion",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n02_happy",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n02",
                ["positionId"] = "N02-H1",
                ["wordId"] = "word_candidate_n02_happy",
            },
            {
                ["letterId"] = "letter_n02",
                ["positionId"] = "N02-P1",
                ["wordId"] = "word_candidate_n02_suspicion",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n03_candidate_good",
            },
            ["stars"] = 3,
        },
        ["id"] = "recipe_v02_n03_1",
        ["letterId"] = "letter_n03",
        ["name"] = "顺利卖完",
        ["recipe"] = {
            ["auxWordIds"] = {},
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n03_k1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n03",
                ["positionId"] = "N03-K1",
                ["wordId"] = "word_candidate_n03_k1",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n03_candidate_hide",
            },
            ["stars"] = 2,
        },
        ["id"] = "recipe_v02_n03_2",
        ["letterId"] = "letter_n03",
        ["name"] = "一直躲",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n03_fear",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n03_k1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n03",
                ["positionId"] = "N03-K1",
                ["wordId"] = "word_candidate_n03_k1",
            },
            {
                ["letterId"] = "letter_n03",
                ["positionId"] = "N03-F1",
                ["wordId"] = "word_candidate_n03_fear",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n03_candidate_freeze",
            },
            ["stars"] = 1,
        },
        ["id"] = "recipe_v02_n03_3",
        ["letterId"] = "letter_n03",
        ["name"] = "没开口",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n03_fear",
                "word_candidate_e01_c1",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n03_k1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n03",
                ["positionId"] = "N03-K1",
                ["wordId"] = "word_candidate_n03_k1",
            },
            {
                ["letterId"] = "letter_n03",
                ["positionId"] = "N03-F1",
                ["wordId"] = "word_candidate_n03_fear",
            },
            {
                ["letterId"] = "letter_pa_01",
                ["positionId"] = "E01-C1",
                ["wordId"] = "word_candidate_e01_c1",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n03_candidate_salt",
            },
            ["stars"] = 2,
        },
        ["id"] = "recipe_v02_n03_4",
        ["letterId"] = "letter_n03",
        ["name"] = "忘买盐",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n03_c1",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n03_k1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n03",
                ["positionId"] = "N03-K1",
                ["wordId"] = "word_candidate_n03_k1",
            },
            {
                ["letterId"] = "letter_n03",
                ["positionId"] = "N03-C1",
                ["wordId"] = "word_candidate_n03_c1",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n03_candidate_protect",
            },
            ["stars"] = 1,
        },
        ["id"] = "recipe_v02_n03_5",
        ["letterId"] = "letter_n03",
        ["name"] = "护萝卜",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n01_s2",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n03_k1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n03",
                ["positionId"] = "N03-K1",
                ["wordId"] = "word_candidate_n03_k1",
            },
            {
                ["letterId"] = "letter_n01",
                ["positionId"] = "N01-S2",
                ["wordId"] = "word_candidate_n01_s2",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n04_candidate_good",
            },
            ["stars"] = 3,
        },
        ["id"] = "recipe_v02_n04_1",
        ["letterId"] = "letter_n04",
        ["name"] = "高兴回来了",
        ["recipe"] = {
            ["auxWordIds"] = {},
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n04_h1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n04",
                ["positionId"] = "N04-H1",
                ["wordId"] = "word_candidate_n04_h1",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n04_candidate_envy",
            },
            ["stars"] = 2,
        },
        ["id"] = "recipe_v02_n04_2",
        ["letterId"] = "letter_n04",
        ["name"] = "笑没入心",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n04_e1",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n04_h1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n04",
                ["positionId"] = "N04-H1",
                ["wordId"] = "word_candidate_n04_h1",
            },
            {
                ["letterId"] = "letter_n04",
                ["positionId"] = "N04-E1",
                ["wordId"] = "word_candidate_n04_e1",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n04_candidate_tear",
            },
            ["stars"] = 1,
        },
        ["id"] = "recipe_v02_n04_3",
        ["letterId"] = "letter_n04",
        ["name"] = "撕旗",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n04_e1",
                "word_candidate_n01_a2",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n04_h1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n04",
                ["positionId"] = "N04-H1",
                ["wordId"] = "word_candidate_n04_h1",
            },
            {
                ["letterId"] = "letter_n04",
                ["positionId"] = "N04-E1",
                ["wordId"] = "word_candidate_n04_e1",
            },
            {
                ["letterId"] = "letter_n01",
                ["positionId"] = "N01-A2",
                ["wordId"] = "word_candidate_n01_a2",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n04_candidate_play",
            },
            ["stars"] = 2,
        },
        ["id"] = "recipe_v02_n04_4",
        ["letterId"] = "letter_n04",
        ["name"] = "贪玩未扫",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n04_h2",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n04_h1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n04",
                ["positionId"] = "N04-H1",
                ["wordId"] = "word_candidate_n04_h1",
            },
            {
                ["letterId"] = "letter_n04",
                ["positionId"] = "N04-H2",
                ["wordId"] = "word_candidate_n04_h2",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n04_candidate_past",
            },
            ["stars"] = 1,
        },
        ["id"] = "recipe_v02_n04_5",
        ["letterId"] = "letter_n04",
        ["name"] = "熬旧甜汤",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n04_r1",
                "word_candidate_n04_s1",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n04_h1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n04",
                ["positionId"] = "N04-H1",
                ["wordId"] = "word_candidate_n04_h1",
            },
            {
                ["letterId"] = "letter_n04",
                ["positionId"] = "N04-R1",
                ["wordId"] = "word_candidate_n04_r1",
            },
            {
                ["letterId"] = "letter_n04",
                ["positionId"] = "N04-S1",
                ["wordId"] = "word_candidate_n04_s1",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n05_candidate_good",
            },
            ["stars"] = 3,
        },
        ["id"] = "recipe_v02_n05_1",
        ["letterId"] = "letter_n05",
        ["name"] = "吃完了",
        ["recipe"] = {
            ["auxWordIds"] = {},
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n05_a1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n05",
                ["positionId"] = "N05-A1",
                ["wordId"] = "word_candidate_n05_a1",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n05_candidate_count",
            },
            ["stars"] = 2,
        },
        ["id"] = "recipe_v02_n05_2",
        ["letterId"] = "letter_n05",
        ["name"] = "算菜价",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n05_q1",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n05_a1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n05",
                ["positionId"] = "N05-A1",
                ["wordId"] = "word_candidate_n05_a1",
            },
            {
                ["letterId"] = "letter_n05",
                ["positionId"] = "N05-Q1",
                ["wordId"] = "word_candidate_n05_q1",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n05_candidate_sad",
            },
            ["stars"] = 1,
        },
        ["id"] = "recipe_v02_n05_3",
        ["letterId"] = "letter_n05",
        ["name"] = "一口没动",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n05_s1",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n05_a1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n05",
                ["positionId"] = "N05-A1",
                ["wordId"] = "word_candidate_n05_a1",
            },
            {
                ["letterId"] = "letter_n05",
                ["positionId"] = "N05-S1",
                ["wordId"] = "word_candidate_n05_s1",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n05_candidate_talk",
            },
            ["stars"] = 2,
        },
        ["id"] = "recipe_v02_n05_4",
        ["letterId"] = "letter_n05",
        ["name"] = "说家事",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n05_t1",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n05_a1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n05",
                ["positionId"] = "N05-A1",
                ["wordId"] = "word_candidate_n05_a1",
            },
            {
                ["letterId"] = "letter_n05",
                ["positionId"] = "N05-T1",
                ["wordId"] = "word_candidate_n05_t1",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n05_candidate_fork",
            },
            ["stars"] = 1,
        },
        ["id"] = "recipe_v02_n05_5",
        ["letterId"] = "letter_n05",
        ["name"] = "质问银叉",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n01_suspicion",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n05_a1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n05",
                ["positionId"] = "N05-A1",
                ["wordId"] = "word_candidate_n05_a1",
            },
            {
                ["letterId"] = "letter_n01",
                ["positionId"] = "N01-S1",
                ["wordId"] = "word_candidate_n01_suspicion",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n06_candidate_good",
            },
            ["stars"] = 3,
        },
        ["id"] = "recipe_v02_n06_1",
        ["letterId"] = "letter_n06",
        ["name"] = "做完了",
        ["recipe"] = {
            ["auxWordIds"] = {},
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n06_m1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n06",
                ["positionId"] = "N06-M1",
                ["wordId"] = "word_candidate_n06_m1",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n06_candidate_pain",
            },
            ["stars"] = 2,
        },
        ["id"] = "recipe_v02_n06_2",
        ["letterId"] = "letter_n06",
        ["name"] = "疼着做完",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n06_p1",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n06_m1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n06",
                ["positionId"] = "N06-M1",
                ["wordId"] = "word_candidate_n06_m1",
            },
            {
                ["letterId"] = "letter_n06",
                ["positionId"] = "N06-P1",
                ["wordId"] = "word_candidate_n06_p1",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n06_candidate_stop",
            },
            ["stars"] = 1,
        },
        ["id"] = "recipe_v02_n06_3",
        ["letterId"] = "letter_n06",
        ["name"] = "怕痛停手",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n06_p1",
                "word_candidate_elias_fear",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n06_m1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n06",
                ["positionId"] = "N06-M1",
                ["wordId"] = "word_candidate_n06_m1",
            },
            {
                ["letterId"] = "letter_n06",
                ["positionId"] = "N06-P1",
                ["wordId"] = "word_candidate_n06_p1",
            },
            {
                ["letterId"] = "letter_pa_01",
                ["positionId"] = "E01-F1",
                ["wordId"] = "word_candidate_elias_fear",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n06_candidate_sleep",
            },
            ["stars"] = 2,
        },
        ["id"] = "recipe_v02_n06_4",
        ["letterId"] = "letter_n06",
        ["name"] = "睡过头",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_elias_sleep_alt",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n06_m1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n06",
                ["positionId"] = "N06-M1",
                ["wordId"] = "word_candidate_n06_m1",
            },
            {
                ["letterId"] = "letter_pa_01",
                ["positionId"] = "E01-S2",
                ["wordId"] = "word_candidate_elias_sleep_alt",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n06_candidate_split",
            },
            ["stars"] = 1,
        },
        ["id"] = "recipe_v02_n06_5",
        ["letterId"] = "letter_n06",
        ["name"] = "强敲开裂",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n06_a1",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n06_m1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n06",
                ["positionId"] = "N06-M1",
                ["wordId"] = "word_candidate_n06_m1",
            },
            {
                ["letterId"] = "letter_n06",
                ["positionId"] = "N06-A1",
                ["wordId"] = "word_candidate_n06_a1",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n07_candidate_good",
            },
            ["stars"] = 3,
        },
        ["id"] = "recipe_v02_n07_1",
        ["letterId"] = "letter_n07",
        ["name"] = "要回部分",
        ["recipe"] = {
            ["auxWordIds"] = {},
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n07_a1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n07",
                ["positionId"] = "N07-A1",
                ["wordId"] = "word_candidate_n07_a1",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n07_candidate_soft",
            },
            ["stars"] = 2,
        },
        ["id"] = "recipe_v02_n07_2",
        ["letterId"] = "letter_n07",
        ["name"] = "软下来",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n07_s1",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n07_a1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n07",
                ["positionId"] = "N07-A1",
                ["wordId"] = "word_candidate_n07_a1",
            },
            {
                ["letterId"] = "letter_n07",
                ["positionId"] = "N07-S1",
                ["wordId"] = "word_candidate_n07_s1",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n07_candidate_acid",
            },
            ["stars"] = 1,
        },
        ["id"] = "recipe_v02_n07_3",
        ["letterId"] = "letter_n07",
        ["name"] = "泛酸没要成",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n07_s1",
                "word_candidate_n03_e1",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n07_a1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n07",
                ["positionId"] = "N07-A1",
                ["wordId"] = "word_candidate_n07_a1",
            },
            {
                ["letterId"] = "letter_n07",
                ["positionId"] = "N07-S1",
                ["wordId"] = "word_candidate_n07_s1",
            },
            {
                ["letterId"] = "letter_n03",
                ["positionId"] = "N03-E1",
                ["wordId"] = "word_candidate_n03_e1",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n07_candidate_discount",
            },
            ["stars"] = 2,
        },
        ["id"] = "recipe_v02_n07_4",
        ["letterId"] = "letter_n07",
        ["name"] = "应半价",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n07_f1",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n07_a1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n07",
                ["positionId"] = "N07-A1",
                ["wordId"] = "word_candidate_n07_a1",
            },
            {
                ["letterId"] = "letter_n07",
                ["positionId"] = "N07-F1",
                ["wordId"] = "word_candidate_n07_f1",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n07_candidate_bucket",
            },
            ["stars"] = 1,
        },
        ["id"] = "recipe_v02_n07_5",
        ["letterId"] = "letter_n07",
        ["name"] = "掀桶",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n07_a2",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n07_a1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n07",
                ["positionId"] = "N07-A1",
                ["wordId"] = "word_candidate_n07_a1",
            },
            {
                ["letterId"] = "letter_n07",
                ["positionId"] = "N07-A2",
                ["wordId"] = "word_candidate_n07_a2",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n08_candidate_good",
            },
            ["stars"] = 3,
        },
        ["id"] = "recipe_v02_n08_1",
        ["letterId"] = "letter_n08",
        ["name"] = "休日过成",
        ["recipe"] = {
            ["auxWordIds"] = {},
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n08_r1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n08",
                ["positionId"] = "N08-R1",
                ["wordId"] = "word_candidate_n08_r1",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n08_candidate_slow",
            },
            ["stars"] = 2,
        },
        ["id"] = "recipe_v02_n08_2",
        ["letterId"] = "letter_n08",
        ["name"] = "慢半拍",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n08_c1",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n08_r1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n08",
                ["positionId"] = "N08-R1",
                ["wordId"] = "word_candidate_n08_r1",
            },
            {
                ["letterId"] = "letter_n08",
                ["positionId"] = "N08-C1",
                ["wordId"] = "word_candidate_n08_c1",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n08_candidate_wait",
            },
            ["stars"] = 1,
        },
        ["id"] = "recipe_v02_n08_3",
        ["letterId"] = "letter_n08",
        ["name"] = "可以再等",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n08_r1",
                "word_candidate_n08_c2",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n08_c1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n08",
                ["positionId"] = "N08-C1",
                ["wordId"] = "word_candidate_n08_c1",
            },
            {
                ["letterId"] = "letter_n08",
                ["positionId"] = "N08-R1",
                ["wordId"] = "word_candidate_n08_r1",
            },
            {
                ["letterId"] = "letter_n08",
                ["positionId"] = "N08-C2",
                ["wordId"] = "word_candidate_n08_c2",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n08_candidate_child",
            },
            ["stars"] = 2,
        },
        ["id"] = "recipe_v02_n08_4",
        ["letterId"] = "letter_n08",
        ["name"] = "陪玩拖鞋",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n08_h1",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n08_r1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n08",
                ["positionId"] = "N08-R1",
                ["wordId"] = "word_candidate_n08_r1",
            },
            {
                ["letterId"] = "letter_n08",
                ["positionId"] = "N08-H1",
                ["wordId"] = "word_candidate_n08_h1",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n08_candidate_military",
            },
            ["stars"] = 1,
        },
        ["id"] = "recipe_v02_n08_5",
        ["letterId"] = "letter_n08",
        ["name"] = "家如哨所",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n08_a1",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n08_r1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n08",
                ["positionId"] = "N08-R1",
                ["wordId"] = "word_candidate_n08_r1",
            },
            {
                ["letterId"] = "letter_n08",
                ["positionId"] = "N08-A1",
                ["wordId"] = "word_candidate_n08_a1",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n09_candidate_good",
            },
            ["stars"] = 3,
        },
        ["id"] = "recipe_v02_n09_1",
        ["letterId"] = "letter_n09",
        ["name"] = "对上了",
        ["recipe"] = {
            ["auxWordIds"] = {},
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n09_q1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n09",
                ["positionId"] = "N09-Q1",
                ["wordId"] = "word_candidate_n09_q1",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n09_candidate_doubt",
            },
            ["stars"] = 2,
        },
        ["id"] = "recipe_v02_n09_2",
        ["letterId"] = "letter_n09",
        ["name"] = "盘问失礼",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n09_suspicion",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n09_q1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n09",
                ["positionId"] = "N09-Q1",
                ["wordId"] = "word_candidate_n09_q1",
            },
            {
                ["letterId"] = "letter_n09",
                ["positionId"] = "N09-S1",
                ["wordId"] = "word_candidate_n09_suspicion",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n09_candidate_hedge",
            },
            ["stars"] = 1,
        },
        ["id"] = "recipe_v02_n09_3",
        ["letterId"] = "letter_n09",
        ["name"] = "数落花篱",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n09_suspicion",
                "word_candidate_n09_a1",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n09_q1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n09",
                ["positionId"] = "N09-Q1",
                ["wordId"] = "word_candidate_n09_q1",
            },
            {
                ["letterId"] = "letter_n09",
                ["positionId"] = "N09-S1",
                ["wordId"] = "word_candidate_n09_suspicion",
            },
            {
                ["letterId"] = "letter_n09",
                ["positionId"] = "N09-A1",
                ["wordId"] = "word_candidate_n09_a1",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n09_candidate_grace",
            },
            ["stars"] = 2,
        },
        ["id"] = "recipe_v02_n09_4",
        ["letterId"] = "letter_n09",
        ["name"] = "改作恩典",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n09_f1",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n09_q1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n09",
                ["positionId"] = "N09-Q1",
                ["wordId"] = "word_candidate_n09_q1",
            },
            {
                ["letterId"] = "letter_n09",
                ["positionId"] = "N09-F1",
                ["wordId"] = "word_candidate_n09_f1",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n09_candidate_grain",
            },
            ["stars"] = 1,
        },
        ["id"] = "recipe_v02_n09_5",
        ["letterId"] = "letter_n09",
        ["name"] = "先收粮",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n09_t1",
                "word_candidate_n09_t2",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n09_q1",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n09",
                ["positionId"] = "N09-Q1",
                ["wordId"] = "word_candidate_n09_q1",
            },
            {
                ["letterId"] = "letter_n09",
                ["positionId"] = "N09-T1",
                ["wordId"] = "word_candidate_n09_t1",
            },
            {
                ["letterId"] = "letter_n09",
                ["positionId"] = "N09-T2",
                ["wordId"] = "word_candidate_n09_t2",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n10_result_3",
            },
            ["stars"] = 3,
        },
        ["id"] = "recipe_v02_n10_1",
        ["letterId"] = "letter_n10",
        ["name"] = "三星",
        ["recipe"] = {
            ["auxWordIds"] = {},
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n10_recall",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n10",
                ["positionId"] = "N10-W1",
                ["wordId"] = "word_candidate_n10_recall",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n10_result_2a",
            },
            ["stars"] = 2,
        },
        ["id"] = "recipe_v02_n10_2",
        ["letterId"] = "letter_n10",
        ["name"] = "顶嘴",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n10_anger",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n10_recall",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n10",
                ["positionId"] = "N10-W1",
                ["wordId"] = "word_candidate_n10_recall",
            },
            {
                ["letterId"] = "letter_n10",
                ["positionId"] = "N10-W2",
                ["wordId"] = "word_candidate_n10_anger",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n10_result_2b",
            },
            ["stars"] = 2,
        },
        ["id"] = "recipe_v02_n10_3",
        ["letterId"] = "letter_n10",
        ["name"] = "答早",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n10_fear",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n10_recall",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n10",
                ["positionId"] = "N10-W1",
                ["wordId"] = "word_candidate_n10_recall",
            },
            {
                ["letterId"] = "letter_n10",
                ["positionId"] = "N10-W3",
                ["wordId"] = "word_candidate_n10_fear",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n10_result_1a",
            },
            ["stars"] = 1,
        },
        ["id"] = "recipe_v02_n10_4",
        ["letterId"] = "letter_n10",
        ["name"] = "怀疑",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n09_p2",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n10_recall",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n10",
                ["positionId"] = "N10-W1",
                ["wordId"] = "word_candidate_n10_recall",
            },
            {
                ["letterId"] = "letter_n09",
                ["positionId"] = "N09-P2",
                ["wordId"] = "word_candidate_n09_p2",
            },
        },
    },
    {
        ["expect"] = {
            ["canDeliver"] = true,
            ["facts"] = {
                "n10_result_1b",
            },
            ["stars"] = 1,
        },
        ["id"] = "recipe_v02_n10_5",
        ["letterId"] = "letter_n10",
        ["name"] = "再伤",
        ["recipe"] = {
            ["auxWordIds"] = {
                "word_candidate_n10_trust",
                "word_candidate_elias_trust",
            },
            ["equipmentId"] = "kit_old_cauldron",
            ["ingredients"] = {},
            ["mainWordId"] = "word_candidate_n10_recall",
            ["specialItemIds"] = {},
        },
        ["requiresFutureSources"] = false,
        ["sources"] = {
            {
                ["letterId"] = "letter_n10",
                ["positionId"] = "N10-W1",
                ["wordId"] = "word_candidate_n10_recall",
            },
            {
                ["letterId"] = "letter_n10",
                ["positionId"] = "N10-W4",
                ["wordId"] = "word_candidate_n10_trust",
            },
            {
                ["letterId"] = "letter_pa_01",
                ["positionId"] = "E01-T1",
                ["wordId"] = "word_candidate_elias_trust",
            },
        },
    },
}
