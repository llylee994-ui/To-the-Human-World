local P=require "ui.landscape.PanelArt"
local page=P.Page("journal")
local book=P.Layer(page,"journal-book")
local flowers=P.Layer(page,"journal-flowers")
local grass=P.Layer(page,"journal-grass")
local A={bookImage=book.path,flowersImage=flowers.path,grassImage=grass.path,
    tabImage=P.Layer(page,"journal-tab-0").path}
function A.Fit(width,height,responsive)
    local f=P.Fit(width,height)
    local tabs={}
    for _,layer in ipairs(page.layers) do
        if layer.id:match("^journal%-tab%-") then tabs[#tabs+1]=P.Project(f,layer) end
    end
    local result={scale=f.scale,cloth=P.Project(f,P.Asset(page,"panel-asset-cloth")),
        book=P.Project(f,book),flowers=P.Project(f,flowers),grass=P.Project(f,grass),
        lavender=P.Project(f,P.Asset(page,"panel-asset-tray-flowers")),
        content=P.Rect(f,132,218,365,478),title=P.Rect(f,132,169,245,38),
        tabs=P.Rect(f,0,180,112,620),tabSlots=tabs,
        decorationTop=f.y+714*f.scale}
    if responsive then
        result.responsive=true;result.scale=1
        result.cloth.x=0;result.cloth.y=0;result.cloth.w=width;result.cloth.h=height
        result.content={x=86,y=42,w=math.max(1,width-104),h=math.max(44,height-66)}
        result.title={x=86,y=8,w=width-104,h=28}
        result.tabs={x=6,y=42,w=76,h=height-66}
        for i,r in ipairs(result.tabSlots) do r.x=6;r.y=42+(i-1)*55;r.w=76;r.h=48 end
        result.flowers.h=0;result.grass.h=0;result.lavender.h=0
    end
    return result
end
return A
