-- ============================================================================
-- 人物表
--
-- 信件里要求「自我介绍」包含姓名 / 职业 / 家庭关系 / 身份背景，本表是这些
-- 信息的单一来源，信件正文里不要重复写出这些字段，只在行文里自然带过。
--
-- 字段：
--   id          唯一标识
--   name        称呼
--   occupation  职业
--   family      家庭关系
--   background  身份背景，供档案桌与人物页显示
--   address     详细地址。地址既承担寄送功能也承担推理功能，
--               同一栋建筑下的多个人物是重要的推理线索
--   inCase      是否属于主线案件角色；普通订单用 false
--   notes       开发备注，不显示给玩家
--
--   initialState       可保存的人物初始状态（纯值；由 WorldState 读取并复制）
--   initialStateSchema 初始状态字段的类型与允许值（程序校验用，含ValidateStage1）
--
-- 一致性要求：family 与首信自我介绍必须一致（首信写明与妹妹两人同住），
-- 不得再出现「独居」表述；私人记忆对象是本单遗忘唯一允许作用的对象集合。
-- ============================================================================

return {
    {
        id = "npc_passerby_a",
        name = "埃利亚斯·沃德",
        occupation = "码头搬运工",
        family = "与妹妹两人同住（妹妹在面包坊帮工）；母亲已故，兄妹俩相依为命",
        background = "在灰港码头搬了十几年货，肩膀常年有旧伤。不识字，信是托人代写的。",
        address = "灰港 铁锚巷 12 号 二楼",
        inCase = false,
        notes = "阶段 1 的示范 NPC，只用于验证核心闭环，与主线案件无关。",

        -- 人物初态（B1 队友交付 C3）：睡眠/工作/私人记忆与本人认知的初始值。
        -- 遗忘只作用于这里声明的记忆对象；药效结束后已形成的「变淡」状态仍保留。
        initialState = {
            -- 睡眠状况：normal 如常 / troubled 睡不好 / improved 明显改善
            sleepState = "normal",
            -- 工作状态：normal 如常 / exhausted 没劲 / recovered 有力气
            workState = "normal",
            -- 私人记忆对象：键为对象 ID，被事实规则与回信填充值引用
            memories = {
                mem_mother = {
                    label = "母亲",
                    -- 母亲常唱的歌（回信片段 frag_pa_forget_song 的填充值来源）
                    songTitle = "摇橹调",
                    -- 记忆状态：intact 完好 / faded 变淡 / lost 遗失
                    state = "intact",
                },
            },
        },

        initialStateSchema = {
            sleepState = { type = "enum", values = { "normal", "troubled", "improved" }, desc = "睡眠状况" },
            workState = { type = "enum", values = { "normal", "exhausted", "recovered" }, desc = "工作状态" },
            memories = {
                type = "map",
                desc = "私人记忆对象；本包只声明 mem_mother",
                keys = { "mem_mother" },
                entry = {
                    label = { type = "text", desc = "显示用称呼" },
                    songTitle = { type = "text", desc = "填充值：母亲常唱的歌名" },
                    state = { type = "enum", values = { "intact", "faded", "lost" }, desc = "记忆状态" },
                },
            },
        },
    },
}
