-- Pure presentation state. The caller has already saved Receive before Begin.
-- Captured IDs survive completion/cancellation until the caller acknowledges Read.
local S={duration=2.4,maxFrameGap=.25}
local fitKeys={"x","y","w","h","scale"}
local function finite(value)
    return type(value)=="number" and value==value and value~=math.huge and value~=-math.huge
end
local function ease(t)
    t=math.max(0,math.min(1,t))
    return t*t*(3-2*t)
end
local function mix(a,b,t) return a+(b-a)*t end
function S.New()
    local state={active=false --[[@as boolean]],elapsed=0 --[[@as number]],
        letterInstanceId=false --[[@as string|false]],lastTime=0 --[[@as number]],
        fit={} --[[@as table<string,number>]],reason="idle" --[[@as string]]}
    function state.Begin(id,fit,now)
        if state.active or state.letterInstanceId or type(id)~="string" or id==""
            or type(fit)~="table" or not finite(fit.scale) or fit.scale<=0 or not finite(now) then return false end
        state.fit={}
        for _,key in ipairs(fitKeys) do state.fit[key]=fit[key] end
        state.active=true;state.elapsed=0;state.letterInstanceId=id;state.lastTime=now;state.reason="running"
        return true
    end
    function state.Cancel(reason)
        state.active=false;state.reason=reason or "cancelled"
    end
    function state.Update(dt,fit,focused,now)
        if not state.active then return end
        local reason=false --[[@as string|false]]
        if not focused then reason="focus-lost"
        elseif not finite(dt) or dt<0 or dt>S.maxFrameGap or not finite(now)
            or now<state.lastTime or now-state.lastTime>S.maxFrameGap then reason="frame-gap"
        elseif type(fit)~="table" or not finite(fit.scale) or fit.scale<=0 then reason="resize"
        else
            for _,key in ipairs(fitKeys) do
                local a,b=fit[key],state.fit[key]
                if a~=b and (not finite(a) or not finite(b) or math.abs(a-b)>.0001) then reason="resize";break end
            end
        end
        if reason then state.Cancel(reason);return "interrupted" end
        state.lastTime=now;state.elapsed=math.min(S.duration,state.elapsed+dt)
        if state.elapsed>=S.duration-1e-9 then
            state.elapsed=S.duration;state.active=false;state.reason="complete";return "complete"
        end
    end
    function state.Skip()
        if not state.active then return end
        state.elapsed=S.duration;state.active=false;state.reason="complete";return "complete"
    end
    function state.Acknowledge(id)
        if state.active or not state.letterInstanceId or id~=state.letterInstanceId then return false end
        state.letterInstanceId=false;state.elapsed=0;state.reason="idle"
        return true
    end
    function state.Pose()
        local p={phase="idle",netOpacity=0,netX=905,netY=960,netAngle=55,
            bottleX=1110,bottleY=815,bottleScale=1,bottleOpacity=1,splash=0}
        if not state.letterInstanceId then return p end
        if not state.active then
            p.phase="received";p.netX=845;p.netY=745;p.bottleX=1050;p.bottleY=540;p.bottleScale=1.9
            return p
        end
        local t=state.elapsed
        if t<.8 then
            local a=ease(t/.8)
            p.phase="lowering";p.netOpacity=a;p.netX=mix(-180,905,a);p.netY=mix(1350,960,a)
            p.splash=math.sin(math.pi*math.max(0,math.min(1,(t-.5)/.3)))
        elseif t<1.7 then
            local a=ease((t-.8)/.9)
            p.phase="lifting";p.netOpacity=1;p.netX=mix(905,845,a);p.netY=mix(960,745,a)
            p.bottleX=mix(1110,1050,a);p.bottleY=mix(815,600,a)
            p.splash=math.sin(math.pi*math.min(1,(t-.8)/.35))*(1-a)
        else
            local a=ease((t-1.7)/.7)
            p.phase="reveal";p.netOpacity=1-a;p.netX=845;p.netY=745
            p.bottleX=1050;p.bottleY=mix(600,540,a);p.bottleScale=mix(1,1.9,a)
        end
        return p
    end
    return state
end
return S
