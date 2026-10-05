-- 显式 B6 验收启动后的只读诊断，不把尺寸或快照当作视觉通过。
local Evidence = {}
---@param slot string
---@param state table
---@param root Widget|nil
function Evidence.Print(slot, state, root)
    if not slot:match("^b6_[%w_]+$") then return end
    local layouts = {}
    if root then
        for _, id in ipairs({"safeArea", "mainPanel", "playPanel", "playScroll", "playLedger", "playMessage"}) do
            local widget = root:FindById(id)
            if widget then
                local width, height = widget:GetComputedSize()
                layouts[id] = {width=width, height=height}
            end
        end
    end
    print("[B6Evidence] " .. require("core.SaveJson").Encode({slot=slot, status=state.GetStatus(),
        snapshot=state.GetSnapshot(), layouts=layouts}))
    require("debug.B6PersistenceProbe").Run(slot, state)
    require("debug.B6FaultEvidence").Attach(slot, state, root)
end
return Evidence
