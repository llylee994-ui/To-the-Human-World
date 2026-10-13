-- ============================================================================
-- 原料表
--
-- 原料不提供效果标签（那是词条的事），只调整魔药的属性。
-- 属性共 5 项，基础设备只有 2 个原料槽 —— 玩家必须决定控制哪几项，
-- 这就是订单判定的取舍所在（见开发计划 1.5 槽位上限）。
--
-- 字段：
--   id       唯一标识
--   name     显示名
--   desc     图鉴里的说明
--   price    商店售价；0 表示开局自带或不可购买
--   mods     属性修正，可为负。键限定为：
--             intensity  强度     越高药效越强
--             duration   持续时间 越长越持久
--             speed      生效速度 越高发作越快
--             stability  稳定性   低于 0 时有炼制失败风险
--             sideEffect 副作用   正数累积到阈值会附加副作用标签
--   addTags  额外并入的效果标签 -> 权重，可为空表
-- ============================================================================

return {
    {
        id = "ing_sea_salt",
        name = "海盐",
        desc = "最常见的稳定剂，几乎不改变药效本身。",
        price = 5,
        mods = { stability = 1 },
        addTags = {},
    },
    {
        id = "ing_night_dew",
        name = "夜露",
        desc = "让药效更快发作，但会让配方变得不稳。",
        price = 12,
        mods = { speed = 2, stability = -1 },
        addTags = {},
    },
    {
        id = "ing_ashen_herb",
        name = "灰烬草",
        desc = "大幅增强药效，代价是明显的副作用。",
        price = 20,
        mods = { intensity = 2, sideEffect = 2 },
        addTags = {},
    },
    {
        id = "ing_dried_petal",
        name = "干花瓣",
        desc = "让药效持续更久，气味也更好闻。",
        price = 15,
        mods = { duration = 2 },
        addTags = {},
    },
}
