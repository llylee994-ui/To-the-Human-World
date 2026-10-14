-- 普通剧情首发配置。Task 2 辅料改变计算，用新版本/槽保留 Task 1 进度。
return {
    contentVersion = "ordinary-release-v2",
    saveSlotId = "ordinary_release_v2",
    finalDay = 14,
    minThreeStarOrders = 8,
    orderReward = 100,
    requiredOrderIds = {
        "letter_pa_01", "letter_n01", "letter_n02", "letter_n03", "letter_n04",
        "letter_n05", "letter_n06", "letter_n07", "letter_n08", "letter_n09", "letter_n10",
    },
    ticket = { id = "travel_ticket", price = 666, offerStartDay = 1, lastPurchaseDay = 10 },
    -- 复用当前家具商品定义，避免首发目标与商店存在两套 ID/价格。
    homeItems = require "data.furniture",
}
