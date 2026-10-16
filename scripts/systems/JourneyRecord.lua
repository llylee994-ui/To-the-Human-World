-- Frozen keepsakes live in the same atomic save as the current journey.
local U=require "core.StateUtil"
local G=require "systems.CalculationGuard"
local C=require "systems.WishCollage"
local J={}
function J.List(data) return U.Copy(data.chapter.memories or {}) end
function J.Remember(data)
    local rows=J.List(data);local c=data.chapter
    if c.phase~="ended" then return rows end
    for _,row in ipairs(rows) do if row.id==c.endingTransactionId then return rows end end
    rows[#rows+1]={id=c.endingTransactionId,day=data.live.gameFlow.day,ending=U.Copy(c.ending)}
    return rows
end
function J.ValidateEnding(e)
    G.Keys(e,{kind=true,title=true,text=true,wishText=true,sourceTokenIds=true,allThreeStar=true,collage=true},"memory.ending","STATE_INVALID")
    G.Need(({departure=true,apprentice=true,wish=true})[e.kind] and U.String(e.title) and U.String(e.text)
        and utf8.len(e.title) and utf8.len(e.text) and type(e.allThreeStar)=="boolean","STATE_INVALID","memory.ending","留念正文不合法")
    G.Array(e.sourceTokenIds,"memory.sources","STATE_INVALID")
    local seen={};for _,id in ipairs(e.sourceTokenIds) do
        G.Need(U.String(id) and not seen[id],"STATE_INVALID","memory.sources","来源重复或不合法");seen[id]=true
    end
    if e.kind=="wish" then
        G.Need(#e.sourceTokenIds>0 and U.String(e.wishText) and e.text:sub(-#e.wishText)==e.wishText,"STATE_INVALID","memory.wish","愿望原句不完整")
        if e.collage then G.Value(C.ValidateFrozen(e.collage,e.sourceTokenIds,e.wishText)) end
    else G.Need(e.wishText==false and #e.sourceTokenIds==0 and e.collage==nil,"STATE_INVALID","memory.wish","该结局不应包含拼贴") end
end
function J.Validate(data)
    return G.Run(function()
        local rows=data.chapter.memories
        if rows==nil then return true end
        G.Array(rows,"memories","STATE_INVALID");local seen={}
        for _,row in ipairs(rows) do
            G.Keys(row,{id=true,day=true,ending=true},"memory","STATE_INVALID")
            G.Need(U.String(row.id) and U.Integer(row.day,1) and not seen[row.id],"STATE_INVALID","memory","留念标记或日期不合法")
            J.ValidateEnding(row.ending)
            local rev=row.id:match("^ending:"..row.ending.kind..":(%d+)$")
            G.Need(rev and tonumber(rev)<=data.revision,"STATE_INVALID","memory.id","留念版本超出当前存档")
            seen[row.id]=true
        end
        return true
    end)
end
return J
