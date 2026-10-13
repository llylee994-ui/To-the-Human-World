-- Runtime-only navigation animation. Never writes to LayoutManifest or game state.
local Z={version="C-HOME-ZOOM-20261011-r1-v01",target=1.15,duration=.45,
    anchor={x=600,y=540},maxFrameGap=.25}
---@param elapsed number
function Z.ScaleAt(elapsed)
    local t=math.max(0,math.min(1,elapsed/Z.duration)) --[[@as number]]
    return 1+(Z.target-1)*(t*t*(3-2*t)) -- smoothstep: monotone, no overshoot
end
function Z.New()
    local state={active=false --[[@as boolean]],scale=1 --[[@as number]],elapsed=0 --[[@as number]],
        lastTime=0 --[[@as number]],fit={},reason="idle" --[[@as string]]}
    function state.Reset(reason)
        state.active=false;state.scale=1;state.elapsed=0;state.fit={};state.reason=reason or "reset"
    end
    function state.Start(fit,now)
        if state.active or fit.scale<=0 then return false end
        state.active=true;state.elapsed=0;state.scale=1;state.lastTime=now;state.reason="running"
        state.fit={x=fit.x,y=fit.y,w=fit.w,h=fit.h,scale=fit.scale}
        return true
    end
    function state.Update(dt,fit,focused,now)
        if not state.active then return end
        local reason=false --[[@as string|false]]
        if not focused then reason="focus-lost"
        elseif dt<0 or dt>Z.maxFrameGap or now-state.lastTime>Z.maxFrameGap then reason="frame-gap"
        else
            for _,key in ipairs({"x","y","w","h","scale"}) do
                if math.abs(fit[key]-state.fit[key])>.0001 then reason="resize";break end
            end
        end
        if reason then state.Reset(reason);return "cancelled" end
        state.lastTime=now;state.elapsed=math.min(Z.duration,state.elapsed+dt)
        state.scale=Z.ScaleAt(state.elapsed)
        if state.elapsed>=Z.duration then state.active=false;state.reason="complete";return "complete" end
    end
    return state
end
return Z
