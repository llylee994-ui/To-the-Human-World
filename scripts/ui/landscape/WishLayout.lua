-- One fitted canvas for editing, preview and frozen keepsakes.
local L={}
local Responsive=require "ui.landscape.Responsive"
function L.Fit(area,aspect)
    local w=math.min(area.w,area.h*aspect);local h=w/aspect
    return {x=area.x+(area.w-w)/2,y=area.y+(area.h-h)/2,w=w,h=h}
end
function L.Compute(vp,safe,preview,aspect,menu,drawerVisible)
    local tray=(preview or drawerVisible==false) and 0 or Responsive.SideWidth(vp,safe)
    local left=safe.left+(tray>0 and tray+14 or 12)
    local right=vp.w-safe.right-12
    local top=safe.top+10
    local reserve=menu and menu.left*vp.w-10 or right
    local actionsRight=math.min(right,math.max(math.min(right,left+240),reserve))
    local actionsWidth=math.min(450,actionsRight-left)
    local actions={x=left+(actionsRight-left-actionsWidth)/2,y=top+25,w=actionsWidth,h=44}
    local area={x=left,y=actions.y+actions.h+8,w=right-left,h=vp.h-safe.bottom-10-(actions.y+actions.h+8)}
    return {paper=L.Fit(area,aspect or 2),area=area,
        workspace={x=left,y=top,w=right-left,h=vp.h-safe.bottom-10-top},
        actions=actions,title={x=left,y=top,w=right-left,h=22},trayWidth=tray}
end
function L.Handle(bounds,rect,mode,size)
    size=size or 52
    local x=mode=="rotate" and bounds.x+bounds.w/2-size/2 or bounds.x+bounds.w+12
    local y=mode=="rotate" and bounds.y-size-12 or bounds.y+bounds.h+12
    return {x=math.max(rect.x+4,math.min(rect.x+rect.w-size-4,x)),
        y=math.max(rect.y+4,math.min(rect.y+rect.h-size-4,y)),w=size,h=size}
end
local function overlap(a,b)
    return math.max(0,math.min(a.x+a.w,b.x+b.w)-math.max(a.x,b.x))*math.max(0,math.min(a.y+a.h,b.y+b.h)-math.max(a.y,b.y))
end
function L.Tools(bounds,rect,width,height)
    width=math.min(width or 368,rect.w-12);height=height or 48
    local center=bounds.x+bounds.w/2-width/2
    local above,below=bounds.y-height-76,bounds.y+bounds.h+76
    local candidates={{center,above},{center,below},{rect.x+6,above},{rect.x+rect.w-width-6,above},
        {rect.x+6,below},{rect.x+rect.w-width-6,below},{bounds.x-width-16,bounds.y},{bounds.x+bounds.w+16,bounds.y}}
    local rotate,scale=L.Handle(bounds,rect,"rotate"),L.Handle(bounds,rect,"scale")
    local top=rect.y+math.max(6,rect.h*.19) -- Keep the fixed “我想……” inscription clear.
    local best,cost
    for _,point in ipairs(candidates) do
        local r={x=math.max(rect.x+6,math.min(rect.x+rect.w-width-6,point[1])),
            y=math.max(top,math.min(rect.y+rect.h-height-6,point[2])),w=width,h=height}
        local score=overlap(r,bounds)*2+(overlap(r,rotate)+overlap(r,scale))*50+math.abs(r.x-center)*.01+math.abs(r.y-above)*.001
        if not cost or score<cost then best=r;cost=score end
    end
    return best
end
return L
