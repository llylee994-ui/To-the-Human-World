-- Presentation slices only. The original ending remains frozen in the save.
local T={}
function T.Read(text)
    local parts=require("ui.landscape.DepartureSequence").Pages(text)
    local letter,pages={},{}
    local intro=false --[[@as string|false]]
    for _,part in ipairs(parts) do
        local quoted=false --[[@as boolean]]
        for quote in part:gmatch("“(.-)”") do letter[#letter+1]=quote;quoted=true end
        if not quoted and part~="信的末尾还有一行字：" then
            if not intro then intro=part else pages[#pages+1]=part end
        end
    end
    if #letter==0 then
        -- Legacy/fixture prose without quoted correspondence is never replaced.
        return {intro="",letter=text or "",pages=parts}
    end
    return {intro=intro or "",letter=table.concat(letter,"\n\n"),pages=pages}
end
return T
