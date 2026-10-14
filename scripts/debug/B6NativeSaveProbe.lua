-- 实际 cjson 下复现存档精度；文件介质与事件隔离，不写玩家档。
local T={}
function T.Run()
    require("debug.SaveJsonTest").Run()
    local F=require "debug.fixtures.B5Fixtures"
    local U=require "core.StateUtil"
    for _,id in ipairs({"A","B","C","D","G1","G2","G3"}) do
        local x=F.New(); x.Prepare(); x.Pending(id)
        local pending=x.state.GetSnapshot()
        assert(x.Reload(),"pending reload " .. id)
        assert(U.Equal(x.state.GetSnapshot(),pending),"pending exact " .. id)
        F.Must(x.Confirm())
        local confirmed=x.state.GetSnapshot()
        assert(x.Reload(),"confirmed reload " .. id)
        assert(U.Equal(x.state.GetSnapshot(),confirmed),"confirmed exact " .. id)
        local events=#x.events
        F.Must(x.Confirm())
        assert(#x.events==events and U.Equal(x.state.GetSnapshot(),confirmed),"idempotent " .. id)
        print("[B6NativeSaveProbe] PASS " .. id .. " pending+confirmed exact reload+idempotent")
    end
    return true
end
return T
