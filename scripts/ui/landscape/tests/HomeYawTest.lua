local C=require "ui.landscape.HomeYawMotion"
local T={}
function T.Run()
    local checks=0
    local function check(ok,label) checks=checks+1;assert(ok,label) end
    check(math.abs(C.endYaw-math.deg(math.atan(C.pot[1]-C.position[1],C.pot[3]-C.position[3])))<1e-9,"endpoint faces actual pot")
    for _,fps in ipairs({30,60,144}) do
        local s=C.New();check(s.Play(),"first play");local prev=s.yaw
        for _=1,math.ceil(C.duration*fps)+1 do
            local old=s.elapsed
            if s.active then check(not s.Play() and s.elapsed==old,"repeat doesn't rewind") end
            s.Update(1/fps,true)
            check(s.yaw>=prev and s.yaw<=C.endYaw,"monotone without overshoot");prev=s.yaw
        end
        check(not s.active and s.reason=="complete" and s.yaw==C.endYaw,"finish holds endpoint")
        check(s.Play() and s.yaw==0,"replay starts at front")
        s.Update(.2,true);s.Reset();check(not s.active and s.yaw==0,"midplay reset")
        s.Update(.1,true);check(s.yaw==0,"reset has no deferred progress")
        s.Play();s.Update(.26,true);check(not s.active and s.yaw==0,"suspension resets")
        s.Play();s.Update(.01,false);check(not s.active and s.yaw==0,"hidden resets")
    end
    -- Load actual AppView and UI dispatcher, substitute only this new 3D window.
    local Data=require "data.content"
    local fixture=require("debug.fixtures.B5Fixtures").New(Data,{targetSchema=3})
    local U=require "core.StateUtil"
    local flags=require "ui.landscape.DevChecks"
    check(not flags.yawProbe and not flags.yawProbeAuto,"delivered default off")
    local host=require("ui.landscape.tests.ZoomTestHost").New()
    local App=require "ui.landscape.AppView"
    local normal=App.New(fixture.session,Data)
    check(not normal.root:FindById("openHomeYawProbe") and not normal.OpenYawProbe(),"normal entry isolated")
    normal.root:Destroy()
    local updates,closes=0,0
    package.loaded["ui.landscape.HomeYawProbe"]={New=function(_,closed)
        return {Update=function() updates=updates+1 end,Close=function() closes=closes+1;closed() end}
    end}
    flags.yawProbe=true
    local view=App.New(fixture.session,Data);host.Bind(view.root)
    local before,writes=fixture.state.GetSnapshot(),fixture.writes
    check(view.OpenYawProbe() and not view.OpenYawProbe(),"one development window")
    view.model.dirty=false;host.Step(view,.01);check(updates==1,"updates before dirty early return")
    check(not view.BeginHomeZoom(),"probe blocks zoom start")
    view.yawProbe.Close();check(not view.yawProbe,"close clears reference")
    check(view.OpenYawProbe(),"reopen");view.root:Destroy()
    check(closes==2 and not view.yawProbe,"root destruction cleans up")
    check(not view.OpenYawProbe(),"destroyed cannot reopen")
    check(U.Equal(before,fixture.state.GetSnapshot()) and fixture.writes==writes,"no state or save writes")
    flags.yawProbe=false;package.loaded["ui.landscape.HomeYawProbe"]=nil
    print("[HomeYawTest] PASS assertions="..checks.."; headless timing/AppView lifecycle only; no native visual claim")
    return true
end
return T
