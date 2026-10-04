-- 仅本轮原生写入故障验收槽启用。按钮只读观察，不注入失败或业务数据。
local EventBus = require "core.EventBus"
local UI = require "urhox-libs/UI"
local Evidence = {}
local attached = false
---@param slot string
---@param state table
---@param root Widget|nil
function Evidence.Attach(slot, state, root)
    local uncertain = slot == "b6_uncertain_20261004_a"
    if (slot ~= "b6_fault_20261004_a" and not uncertain) or attached then return end
    local parent = root and root:FindById("mainPanel")
    if not parent then return end
    attached = true
    local events = {}
    EventBus.OnAny(function(name)
        events[name] = (events[name] or 0) + 1
    end, "B6FaultEvidence")
    local function capture()
        local actions = {}
        for _, name in ipairs({"NextDay", "CutWord", "Accept", "Preview", "Confirm", "Reset"}) do
            actions[name] = state.CheckAction(name)
        end
        print("[B6FaultEvidence] " .. cjson.encode({slot=slot, snapshot=state.GetSnapshot(),
            status=state.GetStatus(), canMutate=state.CanMutate(), actions=actions, events=events,
            injection=uncertain and require("debug.B6UncertainStorage").Status() or false}))
    end
    parent:AddChild(UI.Button {id="b6FaultCapture", text="验收留证（只读）", minHeight=44,
        fontSize=14, onClick=capture})
    if uncertain then
        local lab = require "debug.B6UncertainStorage"
        local row = UI.Panel {width="100%",flexDirection="row",gap=6}
        row:AddChild(UI.Button {text="启用读回故障",minHeight=44,fontSize=13,onClick=function()
            local data=state.GetSnapshot()
            if state.CanMutate() and data.currentOrder and data.currentOrder.phase=="pending" then lab.Arm() end
            capture()
        end})
        row:AddChild(UI.Button {text="解除故障",minHeight=44,fontSize=13,onClick=function() lab.Release(); capture() end})
        row:AddChild(UI.Button {text="验证锁定",minHeight=44,fontSize=13,onClick=function()
            local before=state.GetSnapshot()
            if state.CanMutate() or not before or not before.currentOrder or not before.currentOrder.pending then return end
            local U=require "core.StateUtil"
            local beforeEvents=U.Copy(events)
            local results={day=state.NextDay(),cut=state.CutWord({}),accept=state.OrderCommand("Accept",{}),
                confirm=state.OrderCommand("Confirm",{})}
            local _,wrong=state.Load("b6_uncertain_other")
            print("[B6UncertainGuard] " .. cjson.encode({results=results,wrongSlot=wrong,
                unchanged=U.Equal(before,state.GetSnapshot()),eventsUnchanged=U.Equal(beforeEvents,events)}))
            capture()
        end})
        parent:AddChild(row)
    end
end
return Evidence
