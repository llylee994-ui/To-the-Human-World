-- All coordinates refer to the approved square cutout. No room backdrop is baked in.
local ImageCache=require "urhox-libs/UI/Core/ImageCache"
local A={path="image/calendar-r1/blank.png"}
---@param viewport? {w:number,h:number}
---@param safe? {left?:number,right?:number,top?:number,bottom?:number}
function A.Layout(viewport,safe)
    viewport=viewport or {w=1280,h=720};safe=safe or {}
    local l,r,t,b=safe.left or 0,safe.right or 0,safe.top or 0,safe.bottom or 0
    local w,h=viewport.w-l-r,viewport.h-t-b
    local size=math.max(1,math.min(680,w-24,h-72))
    return {x=l+(w-size)/2-size*.015,y=t+8,w=size,h=size,
        noteX=l+12,noteY=t+size+12,noteW=math.max(1,w-24),noteH=math.max(36,h-size-20)}
end
local function paperPath(vg,r)
    -- Below the perforation: the brass clip and wooden stand remain stationary.
    nvgBeginPath(vg)
    nvgMoveTo(vg,r.x+r.w*.230,r.y+r.h*.225)
    for i=1,36 do
        local t=i/36
        nvgLineTo(vg,r.x+r.w*(.230+.597*t),r.y+r.h*(.225+(i%2)*.002))
    end
    nvgLineTo(vg,r.x+r.w*.923,r.y+r.h*.862)
    nvgLineTo(vg,r.x+r.w*.291,r.y+r.h*.886)
    nvgLineTo(vg,r.x+r.w*.266,r.y+r.h*.863)
    nvgClosePath(vg)
end
function A.Paper(vg,r)
    local handle=math.floor(ImageCache.Get(A.path));if handle<=0 then return end
    paperPath(vg,r)
    nvgFillPaint(vg,nvgImagePattern(vg,r.x,r.y,r.w,r.h,0,handle,1));nvgFill(vg)
end
function A.Stamp(vg,r)
    local cx,cy,rad=r.x+r.w/2,r.y+r.h/2,math.min(r.w,r.h)*.44
    nvgBeginPath(vg);nvgCircle(vg,cx,cy,rad);nvgCircle(vg,cx,cy,rad*.89)
    nvgStrokeColor(vg,nvgRGBA(163,53,35,210));nvgStrokeWidth(vg,math.max(1,r.w*.012));nvgStroke(vg)
    nvgBeginPath(vg)
    for _,dy in ipairs({-.24,.24}) do
        nvgMoveTo(vg,cx-rad*.92,cy+rad*dy);nvgLineTo(vg,cx+rad*.92,cy+rad*dy)
    end
    nvgStrokeWidth(vg,math.max(1,r.w*.008));nvgStroke(vg)
end
-- Continuous bend approximated by affine horizontal bands. Render the actual UI
-- subtree in the same transform so its date and stamp follow the paper.
function A.Tear(vg,r,pose,drawLeaf)
    if pose.leafAlpha<=0 then return end
    nvgSave(vg)
    local px,py=r.x+r.w*.53,r.y+r.h*.225
    nvgTranslate(vg,px+r.w*.78*pose.fly,py+r.h*.64*pose.fly*pose.fly)
    nvgRotate(vg,.34*pose.fly);nvgTranslate(vg,-px,-py)
    nvgGlobalAlpha(vg,pose.alpha*pose.leafAlpha)
    local top,height=r.y+r.h*.225,r.h*.663
    for i=0,17 do
        local a,b=i/18,(i+1)/18
        local ya,yb=top+height*a,top+height*b
        local dxA,dxB=r.w*.12*pose.lift*a*a,r.w*.12*pose.lift*b*b
        local dyA,dyB=-r.h*.13*pose.lift*a*a,-r.h*.13*pose.lift*b*b
        local shear=(dxB-dxA)/(yb-ya);local scaleY=1+(dyB-dyA)/(yb-ya)
        nvgSave(vg)
        nvgTransform(vg,1,0,shear,scaleY,dxA-shear*ya,dyA-(scaleY-1)*ya)
        -- A subpixel overlap prevents cracks between adjacent transformed clips.
        nvgIntersectScissor(vg,r.x+r.w*.225,ya-.3,r.w*.71,yb-ya+.6)
        drawLeaf(vg)
        nvgRestore(vg)
    end
    nvgRestore(vg)
end
return A
