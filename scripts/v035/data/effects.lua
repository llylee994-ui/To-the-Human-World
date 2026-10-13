-- ============================================================================
-- 效果标签表
--
-- 魔药合成与订单判定只认「标签」，不认具体词条。见开发计划 1.5。
--   词条（words.lua）携带标签  ->  合成规则（synthesis.lua）算出结果  ->  订单按标签比对
--
-- 新增标签：在下方加一条，并在 words.lua / letters.lua 里引用它的 id。
-- 标签是小词表，改动会影响全局，新增前先确认确有必要。
-- ============================================================================

return {
    {
        id = "sleep",
        name = "睡眠",
        category = "睡眠类",
        desc = "让人困倦、入睡或睡得沉",
    },
    {
        id = "dream",
        name = "梦境",
        category = "睡眠类",
        desc = "让人做梦，或影响梦的内容",
    },
    {
        id = "calm",
        name = "镇静",
        category = "情绪类",
        desc = "压低情绪波动与行动欲望，让人安静下来",
    },
    {
        id = "happy",
        name = "愉悦",
        category = "情绪类",
        desc = "提升情绪，让人感到轻快或快乐",
    },
    {
        id = "brave",
        name = "勇气",
        category = "情绪类",
        desc = "降低恐惧感，让人敢做原本不敢做的事",
    },
    {
        id = "forget",
        name = "遗忘",
        category = "记忆类",
        desc = "让某段记忆变淡或想不起来",
    },
    {
        id = "recall",
        name = "忆起",
        category = "记忆类",
        desc = "让模糊的记忆变得清晰",
    },
    {
        id = "appetite",
        name = "食欲",
        category = "身体类",
        desc = "影响饥饿感与进食欲望",
    },
    { id = "steady", name = "稳手", category = "身体类", desc = "减少手部发抖，不自动壮胆、镇静或治好旧伤" },
    { id = "anger", name = "愤怒", category = "情绪类", desc = "增强对眼前不满的表达，不自动攻击别人或等同勇气" },
    { id = "sadness", name = "悲伤", category = "情绪类", desc = "让失落被感知和表达，不自动困倦或遗忘" },
    { id = "confusion", name = "茫然", category = "情绪类", desc = "暂时难以组织思路与选择行动，已有记忆仍可完整" },
    { id = "reason", name = "理性", category = "行为类", desc = "更能核对本人已有的信息，不生成真相或自动消除感情" },
    { id = "relax", name = "放松", category = "身体类", desc = "缓解紧绷，仍能行动；不附加睡意，不等同压低行动欲望的 calm" },
    { id = "fear", name = "恐惧", category = "情绪类", desc = "增强对本单风险的感受，不自动制造危险" },
    { id = "safety", name = "安心", category = "情绪类", desc = "减轻不安感，不改变环境是否真的安全" },
    { id = "trust", name = "信任", category = "关系类", desc = "增强对本单明确对象的信任倾向，不修改事实或对方意图" },
    { id = "suspicion", name = "怀疑", category = "关系类", desc = "更愿意核对本单对象的说法，不生成新的证据" },
    { id = "envy", name = "嫉妒", category = "情绪类", desc = "强化与本单对象的比较心，不自动偷窃或争吵" },
    { id = "curiosity", name = "好奇", category = "行为类", desc = "增加对眼前未知事物的探究欲，不自动获得知识" },
    { id = "pain", name = "痛感", category = "身体类", desc = "增强对身体不适的感受，不治疗、不造成凭空的伤口" },
    { id = "warmth", name = "温暖", category = "身体类", desc = "使身体感到温暖，不改天气、不防烫伤、不产生火焰" },
}
