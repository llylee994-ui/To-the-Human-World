local P=require "ui.landscape.PanelArt"
local page=P.Page("tray")
local A={}
function A.Fit(width,height,responsive)
    local f=P.Fit(width,height)
    local categories={}
    for _,layer in ipairs(page.layers) do
        if layer.id:match("^tray%-category%-") then categories[#categories+1]=P.Project(f,layer) end
    end
    table.sort(categories,function(a,b) return a.y<b.y end)
    local tray=P.Project(f,P.Layer(page,"tray-frame"))
    local title={x=math.max(12,f.x+12*f.scale),y=math.max(60,tray.y+18*f.scale),w=72,h=20}
    local cards=P.Rect(f,10,155,378,555)
    local bottom=cards.y+cards.h
    cards.y=math.max(cards.y,title.y+title.h+10);cards.h=math.max(0,bottom-cards.y)
    local pager={x=cards.x,y=bottom-44+24,w=cards.w,h=44}
    cards.h=math.max(0,cards.h-48)
    local result={scale=f.scale,cloth=P.Project(f,P.Asset(page,"panel-asset-cloth")),title=title,pager=pager,
        tray=P.Project(f,P.Layer(page,"tray-frame")),
        flowers=P.Project(f,P.Asset(page,"panel-asset-flowers")),
        lavender=P.Project(f,P.Layer(page,"tray-botanical")),
        categories=categories,cards=cards,tabs=P.Rect(f,431,150,80,570),
        slipWidth=162*f.scale,slipHeight=54*f.scale,rowStep=86*f.scale,
        footer=P.Rect(f,12,975,480,60),decorationTop=f.y+730*f.scale}
    if responsive then
        -- Reflow controls independently of the tall decorative editor canvas.
        result.responsive=true
        result.cloth.x=0;result.cloth.y=0;result.cloth.w=width;result.cloth.h=height
        result.title={x=12,y=8,w=88,h=24}
        result.cards={x=12,y=42,w=math.max(1,width-96),h=math.max(44,height-182)}
        result.pager={x=12,y=height-136,w=result.cards.w,h=44}
        result.tabs={x=width-72,y=38,w=64,h=height-48}
        for _,r in ipairs(result.categories) do r.x=result.tabs.x;r.w=64;r.h=44 end
        result.flowers.h=0;result.lavender.h=0
    end
    return result
end
return A
