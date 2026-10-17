-- Explicit headless base-coordinate adapter. Native hit testing has a separate probe.
local I={}
---@return any
function I.Event(x,y,pointer)
    return {x=x,y=y,pointerId=pointer or 1,pointerType="touch",isPrimary=true,IsPrimaryAction=function() return true end,StopPropagation=function() end}
end
function I.Select(view,id)
    local paper=view.journeyView.paper;local card=assert(paper.cards[id],id);local r=paper.rect
    local e=I.Event(r.x+card.display.x*r.w,r.y+card.display.y*r.h)
    card.root.props.onPointerDown(e);card.root.props.onPointerUp(e)
end
function I.Source(view,node,x,y)
    local rect=view.journeyView.paper.rect
    local old=node.GetAbsoluteLayout
    node.GetAbsoluteLayout=function() return {x=40,y=110,w=160,h=60} end
    node.props.onPointerDown(I.Event(120,140))
    node.props.onPointerMove(I.Event(x or rect.x+rect.w*.55,y or rect.y+rect.h*.55))
    node.props.onPointerUp(I.Event(x or rect.x+rect.w*.55,y or rect.y+rect.h*.55))
    node.GetAbsoluteLayout=old
end
function I.Transform(view,id,mode,value)
    I.Select(view,id)
    local paper=view.journeyView.paper;local card=paper.cards[id];local rect=paper.rect
    local cx,cy=rect.x+card.display.x*rect.w,rect.y+card.display.y*rect.h
    local node=assert(view.root:FindById("wishHandle_"..mode)) --[[@as table]]
    node.props.onPointerDown(I.Event(cx+80,cy))
    local x,y
    if mode=="scale" then x,y=cx+80*value,cy else x,y=cx+math.cos(math.rad(value))*80,cy+math.sin(math.rad(value))*80 end
    node.props.onPointerMove(I.Event(x,y));node.props.onPointerUp(I.Event(x,y))
end
return I
