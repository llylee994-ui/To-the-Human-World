-- Transient presentation only. The caller commits NextDay before Begin.
local M={}
local function clamp(t) return math.max(0,math.min(1,t)) end
local function smooth(t) t=clamp(t);return t*t*(3-2*t) end
function M.Pose(elapsed,kind)
    if kind=="closing" then
        local t=smooth((elapsed-.18)/.92)
        return {lift=0,fly=0,leafAlpha=1,alpha=1-t,drop=.48*t,scale=1-.09*t}
    end
    local fly=smooth((elapsed-.20)/.90)
    return {lift=math.sin(math.pi*clamp(elapsed/1.1)),fly=fly,
        leafAlpha=1-smooth((elapsed-.88)/.28),alpha=1-smooth((elapsed-1.28)/.27),drop=0,scale=1}
end
function M.New()
    local m={active=false --[[@as boolean]],elapsed=0 --[[@as number]],kind="next" --[[@as string]],duration=1.55}
    function m.Begin(kind)
        if m.active then return false end
        m.kind=kind;m.elapsed=0;m.duration=kind=="closing" and 1.1 or 1.55;m.active=true
        return true
    end
    function m.Update(dt,focused)
        if not m.active then return false end
        -- Losing the window completes only the presentation, never replays the command.
        m.elapsed=focused==false and m.duration or math.min(m.duration,m.elapsed+math.max(0,dt or 0))
        if m.elapsed>=m.duration then m.active=false;return true end
        return false
    end
    function m.Pose() return M.Pose(m.elapsed,m.kind) end
    return m
end
return M
