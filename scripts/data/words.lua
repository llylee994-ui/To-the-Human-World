-- ============================================================================
-- 词条表
--
-- 玩家不能自己写字，只能从信件里「剪」下词。本表是全部可剪词的词库。
--
-- 字段：
--   id           唯一标识，全项目引用它
--   displayText  显示文本，必须与信件正文里 {{}} 标记的内容完全一致
--   category     词条分类，供词条库存界面分组（身体类 / 情绪类 / 感知类 /
--                行为类 / 记忆类 / 关系类 / 睡眠类 / 欲望类）
--   effects      携带的效果标签 -> 权重。权重越高，合成后在魔药里占比越大
--   reusable     被用于炼制后是否可重复使用；false 表示消耗掉
--
-- 在信件正文里用 {{词}} 标记可剪位置，例如「我最近真的很{{累}}。」
-- 同一个词可以在多封信里出现，玩家剪到的是不同来源的同一个词。
-- ============================================================================

return {
    {
        id = "word_sleep",
        displayText = "睡觉",
        category = "睡眠类",
        reusable = true,
        effects = { sleep = 1.0 },
    },
    {
        id = "word_dream",
        displayText = "梦",
        category = "睡眠类",
        reusable = true,
        effects = { dream = 1.0, sleep = 0.4 },
    },
    {
        id = "word_quiet",
        displayText = "安静",
        category = "情绪类",
        reusable = true,
        effects = { calm = 1.0 },
    },
    {
        id = "word_happy",
        displayText = "快乐",
        category = "情绪类",
        reusable = true,
        effects = { happy = 1.0 },
    },
    {
        id = "word_brave",
        displayText = "勇敢",
        category = "情绪类",
        reusable = true,
        effects = { brave = 1.0 },
    },
    {
        id = "word_forget",
        displayText = "忘记",
        category = "记忆类",
        reusable = true,
        effects = { forget = 1.0 },
    },
    {
        id = "word_tired",
        displayText = "累",
        category = "身体类",
        reusable = true,
        effects = { calm = 0.6, sleep = 0.6 },
    },
    {
        id = "word_hungry",
        displayText = "饿",
        category = "身体类",
        reusable = true,
        effects = { appetite = 1.0 },
    },
}
