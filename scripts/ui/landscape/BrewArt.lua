-- Approved concept extracted as transparent PNGs; source alpha is preserved.
local UI=require "urhox-libs/UI"
local Images=require "urhox-libs/UI/Core/ImageCache"
local Goods=require "ui.landscape.MerchandiseArt"
local A={
    pot={path="image/brew-topdown/cauldron-v01.png",width=1448,height=1086,x=97,y=37,w=1255,h=1017},
    tray={path="image/brew-topdown/four-cell-tray-v01.png",width=2087,height=753,x=27,y=122,w=2034,h=483},
}
function A.Draw(vg,frame,r,alpha,tint)
    local handle=math.floor(Images.Get(frame.path));if handle<=0 then return end
    local sx,sy=r.w/frame.w,r.h/frame.h
    nvgBeginPath(vg);nvgRect(vg,r.x,r.y,r.w,r.h)
    local paint=tint and nvgImagePatternTinted(vg,r.x-frame.x*sx,r.y-frame.y*sy,frame.width*sx,frame.height*sy,0,handle,
        nvgRGBA(tint[1],tint[2],tint[3],math.floor((alpha or 1)*255))) or
        nvgImagePattern(vg,r.x-frame.x*sx,r.y-frame.y*sy,frame.width*sx,frame.height*sy,0,handle,alpha or 1)
    nvgFillPaint(vg,paint);nvgFill(vg)
end
function A.Panel(frame,props)
    local panel=UI.Panel(props)
    function panel:Render(vg) A.Draw(vg,frame,self:GetAbsoluteLayout()) end
    return panel
end
function A.DrawIngredient(vg,id,x,y,size,alpha)
    local frame=Goods.Frame(id);if not frame then return end
    local fitted=Goods.Fit({x=x-size/2,y=y-size/2,w=size,h=size},frame)
    if fitted then A.Draw(vg,frame,fitted,alpha) end
end
return A
