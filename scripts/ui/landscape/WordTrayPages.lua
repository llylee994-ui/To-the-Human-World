-- Deterministic shelf packing. Coordinates and page numbers are view state only.
local P={}
function P.Build(cards,width,height,measure)
    local pages={{}};local x,y,rowHeight=0,0,0
    local gap=10
    for _,card in ipairs(cards) do
        local metrics=measure(card)
        local w,h=metrics.width,metrics.height
        if x>0 and x+w>width then x=0;y=y+rowHeight+gap;rowHeight=0 end
        if y+h>height and #pages[#pages]>0 then
            pages[#pages+1]={};x=0;y=0;rowHeight=0
        end
        local page=pages[#pages]
        page[#page+1]={card=card,x=x,y=y,w=w,h=h,metrics=metrics}
        x=x+w+gap;rowHeight=math.max(rowHeight,h)
    end
    return {pages=pages,pageCount=#pages}
end
return P
