local R=require "debug.fixtures.ReleaseFixtures"
local E=require "debug.fixtures.ReleaseEndingFixtures"
local T={}
function T.Run()
    local x=E.New();E.Day14(x)
    local model=require("ui.PlayModel").New(x.session,x.content)
    E.Must(model.NextDay())
    assert(x.state.GetSnapshot().live.gameFlow.day==14 and model.message:find("收尾",1,true),"D14 frontend must report closing, not a new day")
    assert(not model.Action("NextDay").enabled and not model.Action("Shop").enabled)
    print("[ReleaseClosingIntegration] PASS actual model reports D14 closing and disables business")
    return true
end
return T
