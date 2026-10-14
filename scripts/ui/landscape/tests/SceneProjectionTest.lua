-- The complete composition and its input projection survive every aspect ratio.
local G=require "ui.landscape.LayoutGeometry"
local M=require "ui.landscape.LayoutManifest"
local T={}
function T.Run()
    assert(G.SceneFit,"responsive scene projection missing")
    local n=0
    local function check(v,msg) n=n+1;assert(v,msg) end
    for _,bounds in ipairs({{x=0,y=0,w=1280,h=720},{x=0,y=0,w=1560,h=720},{x=0,y=0,w=1600,h=720},{x=24,y=8,w=1480,h=690}}) do
        local fit=G.RoomFit(bounds,M)
        check(fit.x>=bounds.x-.01 and fit.y>=bounds.y-.01,"room top/left must not be cropped on wide phones")
        check(fit.x+fit.w<=bounds.x+bounds.w+.01 and fit.y+fit.h<=bounds.y+bounds.h+.01,"complete room fits the viewport")
        check(math.abs(fit.w/fit.h-M.width/M.height)<.001,"room proportions remain unchanged")
        for _,obj in ipairs(M.objects) do
            local r=obj.regions[1];local x,y=G.ToScreen(M.layers[obj.layer],fit,r.cx,r.cy)
            check(x>=bounds.x and x<=bounds.x+bounds.w and y>=bounds.y and y<=bounds.y+bounds.h,"interactive subject remains visible "..obj.id)
            check(G.HitObject(M,obj,fit,x,y),"same projection drives hit area "..obj.id)
        end
    end
    local bounds={x=0,y=0,w=1024,h=768}
    local fit=G.RoomFit(bounds,M)
    check(fit.w<=bounds.w and fit.h<=bounds.h,"narrow tablet preserves all interactive composition")
    check(G.SceneFit({x=0,y=0,w=1600,h=720},M).w==1600,"existing dock/sea projection is retained")
    print("[SceneProjectionTest] "..n.." checks passed")
    return n
end
return T
