local P=require "ui.landscape.PanelArt"
local page=P.Page("tray")
local A={}
function A.Fit(width,height)
    local f=P.Fit(width,height)
    local categories={}
    for _,layer in ipairs(page.layers) do
        if layer.id:match("^tray%-category%-") then categories[#categories+1]=P.Project(f,layer) end
    end
    table.sort(categories,function(a,b) return a.y<b.y end)
    return {scale=f.scale,cloth=P.Project(f,P.Asset(page,"panel-asset-cloth")),
        tray=P.Project(f,P.Layer(page,"tray-frame")),
        flowers=P.Project(f,P.Asset(page,"panel-asset-flowers")),
        lavender=P.Project(f,P.Layer(page,"tray-botanical")),
        categories=categories,cards=P.Rect(f,10,155,378,555),tabs=P.Rect(f,431,150,80,570),
        slipWidth=162*f.scale,slipHeight=54*f.scale,rowStep=86*f.scale,
        footer=P.Rect(f,12,975,480,60),decorationTop=f.y+730*f.scale}
end
return A
