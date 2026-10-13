-- Runtime camera over the existing 2D room; no layout or business writes.
local G=require "ui.landscape.LayoutGeometry"
local P={version="C-STOVE-PANZOOM-20261012-r1-v01",target=1.5,duration=.6}
---@param value number
---@param low number
---@param high number
---@return number
local function clamp(value,low,high) return math.max(low,math.min(high,value)) end
---@param fit table SceneFit projection (the existing API returns an untyped table).
---@param bounds table Widget absolute layout in base pixels.
function P.Plan(manifest,fit,bounds)
    ---@cast fit {x:number,y:number,w:number,h:number,scale:number}
    ---@cast bounds {x:number,y:number,w:number,h:number}
    local stove ---@type HomeObject|nil
    for _,object in ipairs(manifest.objects) do if object.id=="home.stove" then stove=object;break end end
    assert(stove,"stove subject missing")
    local r=assert(stove.regions[1])
    local x,y=G.ToScreen(manifest.layers[stove.layer],fit,r.cx,r.cy)
    -- Transform is bounds.origin + scale * (point - bounds.origin) + pan.
    -- Cover the original visible room, including existing backdrop-filled margins.
    -- Since scale and pan share the same easing, endpoint coverage implies coverage
    -- at every intermediate time (all four edge inequalities are linear).
    local s=P.target
    local left,top=math.max(bounds.x,fit.x),math.max(bounds.y,fit.y)
    local right,bottom=math.min(bounds.x+bounds.w,fit.x+fit.w),math.min(bounds.y+bounds.h,fit.y+fit.h)
    local dx=clamp(bounds.w/2-s*(x-bounds.x),right-bounds.x-s*(fit.x+fit.w-bounds.x),left-bounds.x-s*(fit.x-bounds.x)) --[[@as number]]
    local dy=clamp(bounds.h/2-s*(y-bounds.y),bottom-bounds.y-s*(fit.y+fit.h-bounds.y),top-bounds.y-s*(fit.y-bounds.y)) --[[@as number]]
    -- The cover backdrop originally contains the viewport. Keep it covering it too.
    dx=clamp(dx,(1-s)*bounds.w,0);dy=clamp(dy,(1-s)*bounds.h,0)
    return {kind="stove",destination="brew",target=s,duration=P.duration,
        panX=dx,panY=dy,subjectX=x,subjectY=y,
        bounds={x=bounds.x,y=bounds.y,w=bounds.w,h=bounds.h}}
end
return P
