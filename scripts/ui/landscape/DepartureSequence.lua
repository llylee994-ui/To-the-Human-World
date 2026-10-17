-- Presentation only: no save, purchase, ending or navigation commands.
local S={}
function S.Pages(text)
    local pages={}
    text=(text or ""):gsub("\r\n","\n")
    for part in (text.."\n\n"):gmatch("(.-)\n%s*\n") do
        part=part:gsub("^%s+",""):gsub("%s+$","")
        if part~="" then pages[#pages+1]=part end
    end
    if #pages==0 then pages[1]=text end
    return pages
end
local durations={enter=.65,out=.16,["in"]=.24,textOut=.25,dim=1.5,reveal=.6,hold=.3}
local function ease(t) return t*t*(3-2*t) end
function S.New(count,enterDark)
    enterDark=enterDark==nil and 1 or enterDark
    local state={phase="enter" --[[@as string]],index=1,age=0,total=0,
        textAlpha=0,darkAlpha=enterDark,titleAlpha=0,musicGain=1,done=false --[[@as boolean]],dead=false --[[@as boolean]]}
    local function phase(name) state.phase=name;state.age=0 end
    function state.CanAdvance() return not state.dead and state.phase=="read" and state.age>=.25 end
    function state.Advance()
        if not state.CanAdvance() then return false end
        phase(state.index<count and "out" or "textOut")
        return true
    end
    function state.Update(dt,focused)
        if state.dead or not focused then return end
        dt=math.max(0,math.min(dt,.1));state.age=state.age+dt;state.total=state.total+dt
        local name=state.phase;local duration=durations[name]
        if not duration then return end
        local t=math.min(1,state.age/duration);local a=ease(t)
        if name=="enter" then state.darkAlpha=enterDark*(1-a);state.textAlpha=a
        elseif name=="out" or name=="textOut" then state.textAlpha=1-a
        elseif name=="in" then state.textAlpha=a
        elseif name=="dim" then state.darkAlpha=.9*a;state.musicGain=1-a
        elseif name=="reveal" then state.titleAlpha=a end
        if t<1 then return end
        if name=="enter" or name=="in" then phase("read")
        elseif name=="out" then state.index=state.index+1;phase("in")
        elseif name=="textOut" then phase("dim")
        elseif name=="dim" then phase("reveal")
        elseif name=="reveal" then phase("hold")
        elseif name=="hold" then phase("done");state.done=true end
    end
    function state.Destroy() state.dead=true end
    return state
end
return S
