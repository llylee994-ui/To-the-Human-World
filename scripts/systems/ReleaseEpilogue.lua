-- Route selection belongs to the backend. The view only receives its next scene.
local U=require "core.StateUtil"
local G=require "systems.CalculationGuard"
local E={}
function E.Get(data,content)
    local c=data.chapter
    if c.epilogue then return U.Copy(c.epilogue) end
    if c.phase=="operating" then return {route=false,step="operating"} end
    if c.phase=="ended" then return {route=c.ending.kind,step="ended"} end
    -- Preserve a legacy saved wish already in progress, never replace its draft.
    if c.phase=="wish" then return {route="wish",step="compose"} end
    local p=G.Value(require("systems.ReleaseEndings").New(content).GetProgress(data))
    return {route=p.canApprentice and "apprentice" or "wish",step=c.phase=="closing_prepare" and "prepare" or "dawn"}
end
function E.Begin(data,content)
    local p=G.Value(require("systems.ReleaseEndings").New(content).GetProgress(data))
    return {route=p.canApprentice and "apprentice" or "wish",step="dawn"}
end
function E.Validate(data,content)
    return G.Run(function()
        local c=data.chapter;local e=c.epilogue
        if e==nil then return true end
        G.Keys(e,{route=true,step=true},"epilogue","STATE_INVALID")
        G.Need(c.phase~="operating" and (e.route=="apprentice" or e.route=="wish"),"STATE_INVALID","epilogue.route","尾声路线不合法")
        local allowed=c.phase=="closing" and ({dawn=true,letter=e.route=="apprentice",shore=e.route=="wish",bottle=e.route=="wish"})
            or c.phase=="closing_prepare" and {prepare=true} or c.phase=="wish" and {compose=true} or c.phase=="ended" and {ended=true} or {}
        G.Need(allowed[e.step],"STATE_INVALID","epilogue.step","尾声步骤与当前阶段不符")
        if e.route=="apprentice" then
            local p=G.Value(require("systems.ReleaseEndings").New(content).GetProgress(data))
            G.Need(p.canApprentice and c.phase~="wish","STATE_INVALID","epilogue.route","尾声路线与正式进度不符")
        end
        if c.phase=="ended" then G.Need(e.route==c.ending.kind,"STATE_INVALID","epilogue.route","路线与结局不符") end
        return true
    end)
end
return E
