local P=require "ui.landscape.PanelArt"
local page=P.Page("journal")
local book=P.Layer(page,"journal-book")
local flowers=P.Layer(page,"journal-flowers")
local grass=P.Layer(page,"journal-grass")
local A={bookImage=book.path,flowersImage=flowers.path,grassImage=grass.path,
    tabImage=P.Layer(page,"journal-tab-0").path}
function A.Fit(width,height)
    local f=P.Fit(width,height)
    local tabs={}
    for _,layer in ipairs(page.layers) do
        if layer.id:match("^journal%-tab%-") then tabs[#tabs+1]=P.Project(f,layer) end
    end
    return {scale=f.scale,cloth=P.Project(f,P.Asset(page,"panel-asset-cloth")),
        book=P.Project(f,book),flowers=P.Project(f,flowers),grass=P.Project(f,grass),
        lavender=P.Project(f,P.Asset(page,"panel-asset-tray-flowers")),
        content=P.Rect(f,132,218,365,478),title=P.Rect(f,132,169,245,38),
        tabs=P.Rect(f,0,180,112,620),tabSlots=tabs,
        decorationTop=f.y+714*f.scale}
end
return A
