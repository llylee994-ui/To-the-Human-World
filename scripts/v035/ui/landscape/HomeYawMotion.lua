-- Isolated development probe. Metres, degrees, Y-up / +Z forward / +X right.
local M={position={0,1.65,0},pot={3.2,1.15,2.8},pitch=8,roll=0,fov=50,aspect=16/9,
    startYaw=0,endYaw=math.deg(math.atan(3.2,2.8)),duration=1.2}
function M.New()
    local s={active=false --[[@as boolean]],elapsed=0 --[[@as number]],yaw=M.startYaw --[[@as number]],reason="ready" --[[@as string]]}
    function s.Reset(reason)
        s.active=false;s.elapsed=0;s.yaw=M.startYaw;s.reason=reason or "reset"
    end
    function s.Play()
        if s.active then return false end
        s.Reset("playing");s.active=true;return true
    end
    function s.Update(dt,focused)
        if not s.active then return false end
        -- Do not jump to the end after suspension; a fresh play is explicit.
        if not focused or dt<0 or dt>.25 then s.Reset("interrupted");return true end
        s.elapsed=math.min(M.duration,s.elapsed+dt)
        local t=s.elapsed/M.duration
        s.yaw=M.startYaw+(M.endYaw-M.startYaw)*t*t*(3-2*t)
        if s.elapsed>=M.duration then s.active=false;s.reason="complete" end
        return true
    end
    return s
end
return M
