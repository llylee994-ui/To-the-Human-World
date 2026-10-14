-- Display source regions, preserving original alpha PNGs and their remote mappings.
-- UI already owns DPR/frame transforms; these coordinates are UI base pixels.
local UI=require "urhox-libs/UI"
local A={}
local atlas="image/shop-art-r2/tablecloth-chair-lamp.png"
local frames={
    ing_sea_salt={path="image/原料_海盐_透明_v01_20261013032602.png",width=1024,height=1024,x=118,y=224,w=796,h=646},
    ing_night_dew={path="image/原料_夜露_透明_v01_20261013032602.png",width=1024,height=1024,x=268,y=84,w=486,h=870},
    ing_ashen_herb={path="image/原料_灰烬草_透明_v01_20261013032602.png",width=1024,height=1024,x=197,y=29,w=722,h=939},
    ing_dried_petal={path="image/原料_干花瓣_透明_v01_20261013032602.png",width=1024,height=1024,x=158,y=90,w=752,h=858},
    travel_ticket={path="image/商品_人间单程船票_透明_v01_20261013040555.png",width=1152,height=768,x=53,y=163,w=1054,h=419},
    decor_tablecloth={path=atlas,width=2172,height=724,x=10,y=100,w=902,h=598},
    decor_chair={path=atlas,width=2172,height=724,x=919,y=0,w=503,h=724},
    decor_lamp={path=atlas,width=2172,height=724,x=1680,y=0,w=376,h=724},
    decor_bookshelf={path="image/家具_书架_透明_v01_20261013070534.png",width=768,height=1152,x=16,y=91,w=735,h=994},
}
function A.Get(id) return frames[id] and frames[id].path end
function A.Frame(id) return frames[id] end
function A.Fit(bounds,frame)
    if not frame or bounds.w<=0 or bounds.h<=0 then return nil end
    local scale=math.min(bounds.w/frame.w,bounds.h/frame.h)
    local w,h=frame.w*scale,frame.h*scale
    local x,y=bounds.x+(bounds.w-w)/2,bounds.y+(bounds.h-h)/2
    return {x=x,y=y,w=w,h=h,imageX=x-frame.x*scale,imageY=y-frame.y*scale,imageW=frame.width*scale,imageH=frame.height*scale}
end
function A.Panel(id,props)
    local frame=frames[id]
    local options={backgroundImage=frame and frame.path,backgroundFit="contain",pointerEvents="none",flexShrink=0,sourceFrame=frame} --[[@as table]]
    for key,value in pairs(props or {}) do options[key]=value end
    local panel=UI.Panel(options)
    function panel:Render(vg)
        if not frame then return end
        local fit=A.Fit(self:GetAbsoluteLayout(),frame)
        if not fit then return end
        local handle=math.floor(require("urhox-libs/UI/Core/ImageCache").Get(frame.path))
        if handle<=0 then return end
        nvgSave(vg)
        -- Only the chosen source frame may draw: adjacent atlas goods cannot
        -- leak into the unused margins of a wide image slot.
        nvgBeginPath(vg);nvgRect(vg,fit.x,fit.y,fit.w,fit.h)
        local tint=self.props.imageTint
        local paint=tint and nvgImagePatternTinted(vg,fit.imageX,fit.imageY,fit.imageW,fit.imageH,0,handle,nvgRGBA(tint[1],tint[2],tint[3],tint[4] or 255))
            or nvgImagePattern(vg,fit.imageX,fit.imageY,fit.imageW,fit.imageH,0,handle,1)
        nvgFillPaint(vg,paint);nvgFill(vg);nvgRestore(vg)
    end
    return panel
end
return A
