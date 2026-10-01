-- ============================================================================
-- 魔药合成规则
--
-- 魔药不查配方表，而是按下面这套规则由「主词条 + 辅助词条 + 原料」算出来。
-- 手写量因此是线性的（词条表 + 本文件的规则 + 原料表），而可产生的魔药
-- 结果是组合级的。见开发计划 1.5。
--
-- 求值顺序（阶段 1 的 Potion 模块必须按此实现）：
--   1. 取主词条的 effects，作为效果主轴
--   2. 逐个并入辅助词条的 effects：乘以 auxWeight；
--      若该标签已存在于主轴，额外加上 sameTagBonus
--   3. 并入原料的 addTags（同样乘 auxWeight）
--   4. 累加原料的 mods，得到属性总修正
--   5. 用 intensity 修正缩放主轴各标签的最终权重
--   6. 按 intensityTiers 给每个标签定强度分级
--   7. 按 sideEffectRules 判定是否附加副作用标签
--   8. 稳定性低于 unstableThreshold 时标记为「可能炼制失败」
--
-- 数值全部是待调平衡的占位值，阶段 1 试玩后统一校准。
-- ============================================================================

return {
    version = 1,

    -- 辅助词条 / 原料附带的标签并入主轴时的权重系数
    auxWeight = 0.6,

    -- 辅助词条的标签与主轴已有标签相同时，额外叠加的权重
    sameTagBonus = 0.4,

    -- 强度分级：按标签的最终权重落在哪个区间。max 为区间上界。
    intensityTiers = {
        { max = 0.6, label = "微弱" },
        { max = 1.2, label = "明显" },
        { max = 2.2, label = "强烈" },
        { max = 99.0, label = "过强" },
    },

    -- 强度修正对最终权重的换算系数：乘以 (1 + intensity * intensityScale)
    intensityScale = 0.25,

    -- 副作用规则：原料 sideEffect 累计达到 minSideEffect 时附加标签
    sideEffectRules = {
        { minSideEffect = 2, addTags = { dream = 0.4 }, note = "药效过于浓烈，夜里容易多梦" },
    },

    -- 稳定性低于该值时，炼药标记为「可能失败」（阶段 1 先只做提示）
    unstableThreshold = 0,
}
