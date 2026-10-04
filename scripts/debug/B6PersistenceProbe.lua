-- Explicit local persistence acceptance only. Calls the public retry path; never seeds state.
local U = require "core.StateUtil"
local EventBus = require "core.EventBus"
local Probe = {}
---@param slot string
---@param state table
function Probe.Run(slot, state)
    if slot ~= "b6_persist_20261004_a" and slot ~= "b6_fault_20261004_a"
        and slot ~= "b6_uncertain_20261004_a" then return end
    local before = state.GetSnapshot()
    if before.currentOrder ~= false then return end
    local ids = {}
    for id in pairs(before.live.orders.confirmedById) do ids[#ids + 1] = id end
    table.sort(ids)
    if #ids == 0 then return end
    local events = 0
    local listener = EventBus.OnAny(function() events = events + 1 end, "B6PersistenceProbe")
    local results = {}
    for _, id in ipairs(ids) do
        local record = before.live.orders.confirmedById[id]
        for _ = 1, 2 do
            local result = state.OrderCommand("Confirm", {orderId=id, transactionId=record.transactionId})
            results[#results + 1] = {ok=result.ok, alreadyConfirmed=result.ok and result.value.alreadyConfirmed == true}
        end
    end
    EventBus.Off("*", listener)
    local unchanged = U.Equal(before, state.GetSnapshot())
    local passed = unchanged and events == 0
    for _, result in ipairs(results) do passed = passed and result.ok == true and result.alreadyConfirmed == true end
    print("[B6PersistenceRetry] " .. cjson.encode({slot=slot,passed=passed,unchanged=unchanged,events=events,results=results,revision=before.revision}))
end
return Probe
