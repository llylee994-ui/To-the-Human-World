local R=require "debug.fixtures.ReleaseFixtures"
local E=require "debug.fixtures.ReleaseEndingFixtures"
local T={}
function T.Run()
    local x=E.SmallComplete();local day=x.state.GetSnapshot().live.gameFlow.day
    local model=require("ui.PlayModel").New(x.session,x.content)
    E.Must(model.NextDay())
    assert(x.state.GetSnapshot().live.gameFlow.day==day and model.message:find("收尾",1,true),"completed story must report closing, not a new day")
    assert(not model.Action("NextDay").enabled and not model.Action("Shop").enabled)
    print("[ReleaseClosingIntegration] PASS actual model reports completion-based closing and disables business")
    return true
end
return T
