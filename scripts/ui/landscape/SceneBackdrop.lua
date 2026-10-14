-- Fill the viewport with scene art while the interactive composition stays intact.
local UI=require "urhox-libs/UI"
local G=require "ui.landscape.LayoutGeometry"
local B={}
function B.Draw(vg,path,x,y,w,h)
    local handle=math.floor(require("urhox-libs/UI/Core/ImageCache").Get(path))
    if handle<=0 then return end
    nvgBeginPath(vg);nvgRect(vg,x,y,w,h)
    nvgFillPaint(vg,nvgImagePattern(vg,x,y,w,h,0,handle,1));nvgFill(vg)
end
function B.DrawRoomSides(vg,path,fit,bounds)
    -- Quiet wood beams frame the complete room on wide phones. Do not mirror
    -- the room art: duplicated vases and flowers look like extra furniture.
    local wood=require("ui.landscape.HarborStyle").woodImage
    local Cache=require "urhox-libs/UI/Core/ImageCache"
    local handle=math.floor(Cache.Get(wood));local iw,ih=Cache.GetSize(wood)
    local function side(x,w)
        if w<=0 then return end
        nvgSave(vg);nvgIntersectScissor(vg,x,bounds.y,w,bounds.h)
        nvgBeginPath(vg);nvgRect(vg,x,bounds.y,w,bounds.h)
        nvgFillColor(vg,nvgRGBA(45,29,21,255));nvgFill(vg)
        if handle>0 and iw>0 and ih>0 then
            nvgTranslate(vg,x+w,bounds.y);nvgRotate(vg,math.pi/2)
            local sx,sy=bounds.h/(iw*.98),w/(ih*.13)
            nvgBeginPath(vg);nvgRect(vg,0,0,bounds.h,w)
            nvgFillPaint(vg,nvgImagePattern(vg,-iw*.01*sx,-ih*.21*sy,iw*sx,ih*sy,0,handle,1));nvgFill(vg)
            nvgFillColor(vg,nvgRGBA(25,15,10,75));nvgFill(vg)
        end
        nvgRestore(vg)
    end
    side(bounds.x,fit.x-bounds.x)
    side(fit.x+fit.w,bounds.x+bounds.w-fit.x-fit.w)
end
function B.New(id,path,width,height,foreground)
    local background=UI.Panel {id=id,position="absolute",left=0,top=0,width="100%",height="100%",pointerEvents="none"}
    function background:Render(vg)
        local bounds=self:GetAbsoluteLayout()
        if bounds.w<=0 or bounds.h<=0 then return end
        local fit=G.SceneFit(bounds,{width=width,height=height})
        local scale=math.max(bounds.w/width,bounds.h/height)
        local w,h=width*scale,height*scale
        local x,y=bounds.x+(bounds.w-w)/2,bounds.y+(bounds.h-h)/2
        if bounds.w/bounds.h>=width/height then x,y,w,h=fit.x,fit.y,fit.w,fit.h end
        nvgSave(vg);nvgIntersectScissor(vg,bounds.x,bounds.y,bounds.w,bounds.h)
        B.Draw(vg,path,x,y,w,h)
        if foreground then B.Draw(vg,foreground,fit.x,fit.y,fit.w,fit.h) end
        nvgRestore(vg)
    end
    return background
end
return B
