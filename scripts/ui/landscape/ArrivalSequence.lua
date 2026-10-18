-- Pure presentation time: no saves, scene commands, wall clock or rendering.
local S={}
local duration={out=.4,room=.7,paper=.3,narration=.35}
local following={out="room",room="paper",paper="narration",narration="done"}
local function ease(value)
    local t=math.max(0,math.min(1,value));return t*t*(3-2*t)
end
function S.New()
    local s={active=false,phase="idle",elapsed=0}
    function s.Begin()
        if s.active then return false end
        s.active=true;s.phase="out";s.elapsed=0;return true
    end
    function s.Update(dt,focused,roomReady)
        if not s.active or not focused then return nil end
        if s.phase=="room" and not roomReady then return nil end
        if type(dt)~="number" or dt~=dt or dt<=0 then return nil end
        s.elapsed=math.min(duration[s.phase],s.elapsed+math.min(dt,.1))
        if s.elapsed+1e-6<duration[s.phase] then return nil end
        local before=s.phase
        s.phase=following[s.phase];s.elapsed=0
        if s.phase=="done" then s.active=false end
        return before=="out" and "enter" or nil
    end
    function s.Presentation()
        local t=duration[s.phase] and ease(s.elapsed/duration[s.phase]) or 1
        if s.phase=="out" then return {blackAlpha=t,paperAlpha=0,narrationAlpha=0} end
        if s.phase=="room" then return {blackAlpha=1-t,paperAlpha=0,narrationAlpha=0} end
        if s.phase=="paper" then return {blackAlpha=0,paperAlpha=t,narrationAlpha=0} end
        if s.phase=="narration" then return {blackAlpha=0,paperAlpha=1,narrationAlpha=t} end
        return {blackAlpha=0,paperAlpha=1,narrationAlpha=1}
    end
    function s.Cancel() s.active=false;s.phase="idle";s.elapsed=0 end
    return s
end
return S
