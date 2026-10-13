-- Fill the viewport with scene art while the interactive composition stays intact.
local UI=require "urhox-libs/UI"
local G=require "v035.ui.landscape.LayoutGeometry"
local B={}
function B.Draw(vg,path,x,y,w,h)
    local handle=math.floor(require("urhox-libs/UI/Core/ImageCache").Get(path))
    if handle<=0 then return end
    nvgBeginPath(vg);nvgRect(vg,x,y,w,h)
    nvgFillPaint(vg,nvgImagePattern(vg,x,y,w,h,0,handle,1));nvgFill(vg)
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
