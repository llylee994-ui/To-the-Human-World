-- Presentation only. No save, inventory or completion callbacks.
local M={openDuration=.4,cutDuration=1.0}
local function ease(t) t=math.max(0,math.min(1,t));return t*t*(3-2*t) end
function M.New()
    local m={opening=true --[[@as boolean]],openTime=0 --[[@as number]],flight=false --[[@as table|false]]}
    function m.Cancel() m.opening=false;m.openTime=M.openDuration;m.flight=false end
    function m.Start(source,target)
        if m.opening or m.flight then return false end
        m.flight={source=source,target=target,time=0};return true
    end
    function m.Update(dt,focused)
        if not focused or dt<0 or dt>.5 then m.Cancel();return end
        if m.opening then
            m.openTime=math.min(M.openDuration,m.openTime+dt)
            if m.openTime>=M.openDuration-1e-9 then m.opening=false end
        end
        if m.flight then
            m.flight.time=m.flight.time+dt
            if m.flight.time>=M.cutDuration then m.flight=false end
        end
    end
    function m.OpenPose()
        local t=ease(m.openTime/M.openDuration)
        return {scale=.94+.06*t,opacity=.15+.85*t,translateY=18*(1-t),fold=1-t}
    end
    function m.Pose()
        if not m.flight then return nil end
        local f=m.flight;local t=f.time
        local u=ease((t-.32)/.68)
        return {phase=t<.32 and "snip" or "fly",text=f.source.text,spanId=f.source.spanId,
            x=f.source.x+(f.target.x-f.source.x)*u,
            y=f.source.y+(f.target.y-f.source.y)*u-45*math.sin(math.pi*u),
            w=f.source.w,h=f.source.h,scale=1-.15*u,angle=math.sin(math.pi*u)*-.13,
            opacity=t>.86 and (1-t)/.14 or 1,snip=t/.32}
    end
    return m
end
return M
