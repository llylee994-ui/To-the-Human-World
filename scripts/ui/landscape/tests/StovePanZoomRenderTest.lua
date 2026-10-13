-- Record actual HomeView / backdrop draw matrices; this is NOT native visual evidence.
local T={}
function T.Run()
    local G=require "ui.landscape.LayoutGeometry"
    local M=require "ui.landscape.LayoutManifest"
    local P=require "ui.landscape.StovePanZoom"
    local H=require "ui.landscape.HomeView"
    local old,stack,images={}, {}, {}
    local matrix={1,0,0,1,0,0} ---@type [number,number,number,number,number,number]
    local checks=0
    local function check(v,msg) checks=checks+1;assert(v,msg) end
    local function install(name,fn) old[name]={fn=rawget(_G,name)};_G[name]=fn end
    local function point(x,y) return matrix[1]*x+matrix[3]*y+matrix[5],matrix[2]*x+matrix[4]*y+matrix[6] end
    install("nvgSave",function() stack[#stack+1]={table.unpack(matrix)} end)
    install("nvgRestore",function() matrix=assert(table.remove(stack)) end)
    install("nvgTranslate",function(_,x,y) matrix[5],matrix[6]=point(x,y) end)
    install("nvgScale",function(_,x,y) matrix={matrix[1]*x,matrix[2]*x,matrix[3]*y,matrix[4]*y,matrix[5],matrix[6]} end)
    install("nvgRotate",function(_,a)
        local c,s=math.cos(a),math.sin(a)
        matrix={matrix[1]*c+matrix[3]*s,matrix[2]*c+matrix[4]*s,
            -matrix[1]*s+matrix[3]*c,-matrix[2]*s+matrix[4]*c,matrix[5],matrix[6]}
    end)
    for _,name in ipairs({"nvgBeginPath","nvgRect","nvgFillPaint","nvgFill","nvgIntersectScissor"}) do install(name,function() end) end
    install("nvgImagePattern",function(_,x,y,w,h,_,image)
        local x1,y1=point(x,y);local x2,y2=point(x+w,y+h)
        images[#images+1]={image=image,x1=x1,y1=y1,x2=x2,y2=y2};return 1
    end)
    local cache=package.loaded["urhox-libs/UI/Core/ImageCache"]
    local handles={}
    package.loaded["urhox-libs/UI/Core/ImageCache"]={Get=function(path)
        if not handles[path] then handles[path]=#handles+1;handles[#handles+1]=path end
        return handles[path]
    end}
    local home=H.New(function() end,false)
    local bounds={x=24,y=8,w=1280,h=720}
    home.root.GetAbsoluteLayout=function() return bounds end
    home.background.GetAbsoluteLayout=function() return bounds end
    local vg={} --[[@as any]] -- Recorder token, never passed to a native API.
    local function draw()
        images={};home.background:Render(vg);home.art:Render(vg)
        check(#stack==0 and matrix[1]==1 and matrix[4]==1 and matrix[5]==0 and matrix[6]==0,"render restores transform for HUD/siblings")
        return images
    end
    local endpoints={}
    for _,size in ipairs({{1280,720},{1560,720},{1600,720},{1024,768},{640,360}}) do
        bounds.w,bounds.h=size[1],size[2]
        home.SetPanZoom(false);local initial=draw()
        local fit=G.SceneFit(bounds,M) --[[@as {x:number,y:number,w:number,h:number,scale:number}]]
        local p=P.Plan(M,fit,bounds)
        endpoints[#endpoints+1]={width=bounds.w,height=bounds.h,panX=p.panX,panY=p.panY,
            finalX=bounds.x+1.5*(p.subjectX-bounds.x)+p.panX,finalY=bounds.y+1.5*(p.subjectY-bounds.y)+p.panY}
        for _,progress in ipairs({.1,.5,.99,1}) do
            local s=1+.5*progress;local dx,dy=p.panX*progress,p.panY*progress
            home.SetPanZoom(s,dx,dy);local moved=draw()
            check(#initial==13 and #moved==#initial,"backdrop, sea, all 11 layers drawn")
            for i,before in ipairs(initial) do
                local after=assert(moved[i])
                check(after.image==before.image,"same assets/order")
                for _,pair in ipairs({{"x1","y1"},{"x2","y2"}}) do
                    local x,y=pair[1],pair[2]
                    check(math.abs(after[x]-(bounds.x+s*(before[x]-bounds.x)+dx))<.001
                        and math.abs(after[y]-(bounds.y+s*(before[y]-bounds.y)+dy))<.001,"all art shares uniform transform")
                end
            end
        end
        home.SetPanZoom(false);local reset=draw()
        check(cjson.encode(initial)==cjson.encode(reset),"exact original draw after reset")
    end
    for name,entry in pairs(old) do _G[name]=entry.fn end
    package.loaded["urhox-libs/UI/Core/ImageCache"]=cache
    print("[StovePanZoomRenderTest] ENDPOINTS "..cjson.encode(endpoints))
    print("[StovePanZoomRenderTest] PASS assertions="..checks.."; recorded draw calls, not rendered visual acceptance")
end
return T
