-- ============================================================================
-- 设备表
--
-- 设备决定炼药时的槽位上限。槽位是魔药系统的核心平衡手段（见开发计划 1.5）：
-- 原料负责 5 个属性，而基础设备只有 2 个原料槽，玩家无法同时控制全部属性，
-- 必须按订单实际需要取舍；设备升级则带来更多槽位。
--
-- 字段：
--   id        唯一标识
--   name      显示名
--   desc      商店里的说明
--   price     售价；0 表示开局自带
--   slots     槽位上限
--               mainWord    主词条槽，固定 1，决定效果主轴
--               auxWord     辅助词条槽，改变效果方向或叠加
--               ingredient  原料槽，调整属性
--               specialItem 特殊物品槽，仅当该信件附带物品时可用
--   owned     开局是否已拥有
-- ============================================================================

return {
    {
        id = "kit_old_cauldron",
        name = "旧炼药锅",
        desc = "上一任店主留下的旧锅，锅底有洗不掉的痕迹。勉强够用。",
        price = 0,
        owned = true,
        slots = { mainWord = 1, auxWord = 2, ingredient = 2, specialItem = 1 },
    },
    {
        id = "kit_copper_cauldron",
        name = "铜制炼药锅",
        desc = "受热更均匀，可以多放一味辅助词条。",
        price = 120,
        owned = false,
        slots = { mainWord = 1, auxWord = 3, ingredient = 2, specialItem = 1 },
    },
}
