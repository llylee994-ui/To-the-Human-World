-- Targeted r1 regression: real Lua pointer dispatch with explicit layout/NVG adapters.
-- Native rendering, OS mouse and phone acceptance are recorded separately.
local G=require "ui.landscape.LayoutGeometry"
local M=require "ui.landscape.LayoutManifest"
local H=require "ui.landscape.HomeView"
local T={}
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
---@param dx? number
---@param dy? number
local function point(layer,fit,r,dx,dy)
    local x,y=G.Rotate(dx or 0,dy or 0,r.rotation)
    local worldX,worldY=G.Rotate(r.x+x,r.y+y,layer.rotation)
    return fit.x+(layer.x+worldX)*fit.scale,fit.y+(layer.y+worldY)*fit.scale
end
function T.Run()
    MOUSEB_LEFT,MOUSEB_MIDDLE,MOUSEB_RIGHT=0,1,2 -- Isolated enum adapters only.
    local Engine=require "urhox-libs/UI/Core/UI"
    local Widget=require "urhox-libs/UI/Core/Widget"
    local Event=require "urhox-libs/UI/Core/PointerEvent"
    local calls,targets={},{}
    local home=H.New(function(target) targets[#targets+1]=target end,false)
    local bounds={x=0,y=48,w=1280,h=636}
    local function bind(w,layout)
        w.renderProps_={};w.testLayout=layout or bounds
        function w:IsVisible() return self.props.visible~=false end
        function w:GetRenderChildren() return self.children end
        function w:GetAbsoluteLayout() return self.testLayout end
        w.GetAbsoluteLayoutForHitTest=w.GetAbsoluteLayout
        w.HitTest=w.HitTest or Widget.HitTest
        for _,name in ipairs({"OnClick","OnPointerDown","OnPointerUp","OnPointerMove","OnPointerCancel","OnPointerEnter","OnPointerLeave"}) do w[name]=Widget[name] end
        w.OnMouseDown=function() end;w.OnMouseUp=function() end
        w.OnMouseEnter=function() end;w.OnMouseLeave=function() end
        w.OnBlur=function() end;w.OnFocus=function() end
        for _,child in ipairs(w.children) do bind(child,layout) end
    end
    bind(home.root);Engine.SetRoot(home.root)
    local old={}
    for _,name in ipairs({"nvgSave","nvgRestore","nvgTranslate","nvgRotate","nvgScale","nvgBeginPath","nvgRect","nvgEllipse","nvgRoundedRect","nvgFillColor","nvgFill","nvgStrokeColor","nvgStrokeWidth","nvgStroke","nvgFontFace","nvgFontSize","nvgTextAlign","nvgText","nvgIntersectScissor","nvgFillPaint","nvgImagePattern","nvgRGBA"}) do
        old[name]=rawget(_G,name)
        _G[name]=function(...) calls[#calls+1]={name,...};return name end
    end
    local oldCache=package.loaded["urhox-libs/UI/Core/ImageCache"]
    package.loaded["urhox-libs/UI/Core/ImageCache"]={Get=function() return 1 end}
    NVG_ALIGN_CENTER,NVG_ALIGN_MIDDLE=1,2
    local vg={} --[[@as NVGContextWrapper]] -- Only used by the NVG call recorder above.
    local function render()
        calls={};home.art:Render(vg)
        return cjson.encode(calls)
    end
    local function event(kind,x,y)
        Engine["Handle"..kind](Event.new(kind,{x=x,y=y,button=MOUSEB_LEFT,pointerType="mouse"}))
    end
    local normal=render()
    home.SetInspect(true);check(not home.inspect,"normal entry rejects inspect")
    for _,o in ipairs(M.objects) do
        local r=G.ObjectRegion(M.layers[o.layer],o,home.Fit(),1)
        local x,y=point(M.layers[o.layer],home.Fit(),r)
        check(assert(Engine.FindWidgetAt(x,y)).props.id==o.id,"wrong hit "..o.id)
        event("PointerMove",x,y);check(render()==normal,"hover draws debug "..o.id)
        local before=#targets
        event("PointerDown",x,y);check(home.pressed==o.id,"down not delivered "..o.id)
        check(render()==normal,"held frame draws debug "..o.id)
        event("PointerUp",x,y);check(not home.pressed,"up not cleared")
        check(render()==normal,"released frame draws debug")
        check(#targets==before+1 and targets[#targets]==o.target,"single correct navigation "..o.id)
    end
    print("[HitFeedbackTest] PASS eight normal hover/down/held-render/up frames, identical draw trace, exactly one correct target")
    local drawer=assert(M.objects[1]);local layer=M.layers[drawer.layer]
    local oldRegions={{kind="ellipse",cx=.581,cy=.840,w=.040,h=.048},{kind="ellipse",cx=.684,cy=.944,w=.045,h=.053}}
    for _,size in ipairs({{1280,720},{1560,720},{1600,720},{1024,768},{800,360},{640,360}}) do
        -- UI.Scale.DEFAULT at desktop DPR=1 (Core/UI.lua): hit geometry uses base units.
        local uiScale=math.max(.625,math.min(math.sqrt(math.min(size[1],size[2])/720),1))
        bounds={x=0,y=48,w=size[1]/uiScale,h=size[2]/uiScale-84};bind(home.root)
        local fit=home.Fit()
        for i,source in ipairs(oldRegions) do
            local before=G.Region(layer,source,fit,i==1 and 44 or 0)
            local after=G.ObjectRegion(layer,drawer,fit,i)
            check(after.w*fit.scale>=55-.001 and after.h*fit.scale>=55-.001,"both handles protect 55 base pixels")
            local cx,cy=point(layer,fit,after)
            check(cx-after.w*fit.scale/2>=fit.x-.001 and cx+after.w*fit.scale/2<=fit.x+fit.w+.001,"horizontal clipping")
            check(cy-after.h*fit.scale/2>=fit.y-.001 and cy+after.h*fit.scale/2<=fit.y+fit.h+.001,"vertical clipping")
            -- Cardinal edges and the entire original effective ellipse remain reachable.
            for step=0,71 do
                local a=math.rad(step*5)
                local x,y=point(layer,fit,before,math.cos(a)*before.w*.499,math.sin(a)*before.h*.499)
                check(G.HitObject(M,drawer,fit,x,y),"old handle area lost")
            end
            for _,d in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
                local x,y=point(layer,fit,after,d[1]*after.w*.495,d[2]*after.h*.495)
                check(assert(Engine.FindWidgetAt(x,y)).props.id==drawer.id,"new edge blocked")
                local n=#targets;event("PointerDown",x,y);event("PointerUp",x,y)
                check(#targets==n+1 and targets[#targets]=="letters","handle edge not single letters navigation")
            end
            print(string.format("[HitFeedbackTest] %dx%d handle%d physical old=%.2fx%.2f new=%.2fx%.2f center=(%.2f,%.2f), UI scale=%.4f",size[1],size[2],i,before.w*fit.scale*uiScale,before.h*fit.scale*uiScale,after.w*fit.scale*uiScale,after.h*fit.scale*uiScale,cx*uiScale,cy*uiScale,uiScale))
        end
        -- Pixel samples around both expanded regions: no competing object or outside leak.
        for _,o in ipairs(M.objects) do if o.id~=drawer.id then
            for i,source in ipairs(o.regions) do
                local r=G.ObjectRegion(M.layers[o.layer],o,fit,i)
                local unchanged=G.Region(M.layers[o.layer],source,fit,i==1 and o.minTouch or 0)
                check(cjson.encode(r)==cjson.encode(unchanged),"other object's region changed: "..o.id)
            end
        end end
        for i=1,2 do
            local r=G.ObjectRegion(layer,drawer,fit,i);local cx,cy=point(layer,fit,r)
            for y=math.floor(cy-r.h*fit.scale/2)-2,math.ceil(cy+r.h*fit.scale/2)+2 do
                for x=math.floor(cx-r.w*fit.scale/2)-2,math.ceil(cx+r.w*fit.scale/2)+2 do
                    if G.HitObject(M,drawer,fit,x,y) then
                        for _,o in ipairs(M.objects) do if o.id~=drawer.id then check(not G.HitObject(M,o,fit,x,y),"drawer overlaps "..o.id) end end
                    end
                end
            end
            -- Probe the outer union edge, away from the other handle's valid area.
            local x,y=point(layer,fit,r,(i==1 and -1 or 1)*(r.w/2+2/fit.scale),0)
            check(not G.HitObject(M,drawer,fit,x,y),"outside drawer leaks")
        end
    end
    -- Down/cancel and normal entry even when its public inspect field is accidentally set.
    bounds={x=0,y=48,w=1280,h=636};bind(home.root)
    local x,y=point(layer,home.Fit(),G.ObjectRegion(layer,drawer,home.Fit(),2))
    local n=#targets;event("PointerDown",x,y);event("PointerCancel",x,y)
    check(not home.pressed and #targets==n,"cancel should not navigate")
    home.inspect=true;check(render()==normal,"developer authorization required")
    local dev=H.New(function() end,true);bind(dev.root);dev.SetInspect(true);calls={};dev.art:Render(vg)
    local strokes,texts=0,0
    for _,call in ipairs(calls) do if call[1]=="nvgStroke" then strokes=strokes+1 elseif call[1]=="nvgText" then texts=texts+1 end end
    check(strokes>0 and texts==8,"explicit dev inspection must remain available")
    for name,value in pairs(old) do _G[name]=value end
    package.loaded["urhox-libs/UI/Core/ImageCache"]=oldCache
    print("[HitFeedbackTest] PASS assertions="..checks.."; six window geometries; both old/new handle edges; no neighbor overlap; explicit debug retained")
    return true
end
return T
