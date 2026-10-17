-- Saved paper coordinates are normalized; this module owns ordering and validation.
local U=require "core.StateUtil"
local G=require "systems.CalculationGuard"
local C={}
local function finite(n) return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge end
function C.Id(row) return row.sourceTokenId or row.instanceId end
function C.Depth(row,index) return row.z or index or 1 end
function C.Order(placements)
    local rows={}
    for _,row in ipairs(placements) do if row.sourceTokenId then rows[#rows+1]=U.Copy(row) end end
    -- Soft rows make tiny decorative offsets independent of reading order.
    table.sort(rows,function(a,b)
        local ay,by=math.floor(a.y*100+.5),math.floor(b.y*100+.5)
        if ay~=by then return ay<by end
        if a.x~=b.x then return a.x<b.x end
        return a.sourceTokenId<b.sourceTokenId
    end)
    local ids={};for _,row in ipairs(rows) do ids[#ids+1]=row.sourceTokenId end
    return ids
end
function C.FromIds(ids)
    local rows={}
    local gap=math.min(.10,.58/math.max(1,math.ceil(#ids/3)-1))
    for i,id in ipairs(ids) do
        rows[i]={sourceTokenId=id,x=.18+((i-1)%3)*.29,y=.29+math.floor((i-1)/3)*gap,angle=0}
    end
    return rows
end
function C.Validate(placements,known)
    return G.Run(function()
        G.Array(placements,"placements");local seen={}
        G.Need(#placements<=128,"COLLAGE_FULL","placements","纸上的词条已放满。")
        for _,row in ipairs(placements) do
            G.Keys(row,{sourceTokenId=true,decorationId=true,instanceId=true,x=true,y=true,angle=true,scale=true,z=true,locked=true},"placement")
            if row.sourceTokenId~=nil then
                G.Need(U.String(row.sourceTokenId) and known[row.sourceTokenId] and row.decorationId==nil and row.instanceId==nil,
                    "SOURCE_INVALID","placement.sourceTokenId","只能使用已获得的词条。")
            else
                G.Need(U.String(row.decorationId) and require("data.wish_decorations").byId[row.decorationId]
                    and U.String(row.instanceId) and row.instanceId:match("^decor:%d+$"),"SOURCE_INVALID","placement.decorationId","请选择托盘中的装饰。")
            end
            local id=C.Id(row)
            G.Need(not seen[id],"SOURCE_INVALID","placement","同一张词条或装饰实例不能重复。")
            G.Need(finite(row.x) and finite(row.y) and row.x>=.03 and row.x<=.97 and row.y>=.18 and row.y<=.94,
                "COLLAGE_BOUNDS","placement","请把词条放在信纸内。")
            G.Need(finite(row.angle) and math.abs(row.angle)<=360,"COLLAGE_ANGLE","placement.angle","纸条旋转角度超出范围。")
            G.Need(row.scale==nil or finite(row.scale) and row.scale>=.25 and row.scale<=3,"COLLAGE_SCALE","placement.scale","缩放大小超出范围。")
            G.Need(row.z==nil or finite(row.z) and math.abs(row.z)<=1000000,"COLLAGE_LAYER","placement.z","层级超出范围。")
            G.Need(row.locked==nil or type(row.locked)=="boolean","COLLAGE_LOCK","placement.locked","锁定状态无效。")
            seen[id]=true
        end
        return U.Copy(placements)
    end)
end
function C.Get(data)
    return U.Copy(data.chapter.wishLayout or C.FromIds(data.chapter.wishDraftSourceIds))
end
function C.Freeze(data,samples)
    local words={}
    for _,sample in ipairs(samples) do words[sample.sourceTokenId]=sample.text end
    local placements=C.Get(data);local selected={}
    for _,row in ipairs(placements) do if row.sourceTokenId then selected[row.sourceTokenId]=words[row.sourceTokenId] end end
    return {placements=placements,words=selected}
end
function C.ValidateFrozen(collage,ids,text)
    return G.Run(function()
        G.Keys(collage,{placements=true,words=true},"collage","STATE_INVALID")
        G.Need(type(collage.words)=="table","STATE_INVALID","collage.words","缺少冻结词条")
        local count=0
        for id,word in pairs(collage.words) do
            G.Need(U.String(id) and U.String(word) and utf8.len(word),"STATE_INVALID","collage.words","词条正文不合法")
            count=count+1
        end
        local rows=G.Value(C.Validate(collage.placements,collage.words));local ordered=C.Order(rows)
        G.Need(count==#ordered and U.Equal(ordered,ids),"STATE_INVALID","collage","纸面与原句来源不符")
        local pieces={};for _,id in ipairs(ids) do pieces[#pieces+1]=collage.words[id] end
        G.Need(text=="我想"..table.concat(pieces),"STATE_INVALID","collage.text","纸面与原句不符")
        return true
    end)
end
return C
