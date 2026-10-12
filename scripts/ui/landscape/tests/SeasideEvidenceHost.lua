-- Simulated clock/layout and isolated saves, NOT a native capture.
local T={}
function T.Run()
    package.loaded["debug.DeveloperMode"]=false
    package.loaded["ui.landscape.DevChecks"]={hotspots=false,nativeProbe=false,hitFeedback=false}
    local Data=require "data.content"
    local F=require "debug.fixtures.B5Fixtures"
    local View=require "ui.PlayView"
    for _,size in ipairs({{1280,720},{1560,720},{1600,720},{1024,768},{800,360}}) do
        local host=require("ui.landscape.tests.ZoomTestHost").New()
        host.width,host.height=size[1],size[2]
        local x=F.New(Data,{targetSchema=3})
        local view=View.New(x.session,Data)
        host.Bind(view.root);view.Navigate("seaside");view.Update();host.Bind(view.root)
        local function capture(name)
            local sink=rawget(_G,"SEASIDE_EVIDENCE")
            if sink then sink(size[1],size[2],name,host.now,view,x.state.GetSnapshot()) end
        end
        capture("idle");assert(view.StartSalvage().ok);view.Update();capture("start")
        for i=1,143 do
            host.Step(view,1/60)
            if i==24 then capture("lowering")
            elseif i==48 then capture("net-in-water")
            elseif i==78 then capture("lifting")
            elseif i==108 then capture("reveal")
            elseif i==143 then capture("bottle-closeup") end
        end
        host.Step(view,1/60);capture("reader")
        assert(view.panel=="reader")
        view.root:FindById("closePanel"):GetProps().onClick();view.Update();capture("exhausted")
        view.root:Destroy()
    end
    return true
end
return T
