local UI=require "urhox-libs/UI"
local Manifest=require "ui.landscape.LayoutManifest"
local Geometry=require "ui.landscape.LayoutGeometry"
local H={}
function H.New(onOpen,developer)
    local root=UI.Panel {id="homeView",position="absolute",left=0,top=0,width="100%",height="100%",pointerEvents="box-none"}
    local art=UI.Panel {id="homeArt",position="absolute",left=0,top=0,width="100%",height="100%",pointerEvents="none"}
    root:AddChild(art)
    local api={root=root,art=art,inspect=false --[[@as boolean]],lastHit="" --[[@as string]],
        pressed=false --[[@as string|false]],manifest=Manifest}
    function api.Fit()
        local bounds=root:GetAbsoluteLayout()
        return Geometry.Fit({x=bounds.x,y=bounds.y,w=bounds.w,h=bounds.h},Manifest)
    end
    function api.SetInspect(value) api.inspect=developer and value or false end
    local function outline(vg,object,fit)
        local layer=assert(Manifest.layers[object.layer])
        nvgSave(vg)
        nvgTranslate(vg,fit.x+layer.x*fit.scale,fit.y+layer.y*fit.scale)
        nvgRotate(vg,math.rad(layer.rotation)); nvgScale(vg,fit.scale,fit.scale)
        for i,region in ipairs(object.regions) do
            local r=Geometry.Region(layer,region,fit,i==1 and object.minTouch or 0)
            nvgSave(vg); nvgTranslate(vg,r.x,r.y); nvgRotate(vg,math.rad(r.rotation))
            nvgBeginPath(vg)
            if r.kind=="ellipse" then nvgEllipse(vg,0,0,r.w/2,r.h/2) else nvgRect(vg,-r.w/2,-r.h/2,r.w,r.h) end
            nvgFillColor(vg,nvgRGBA(255,216,143,api.pressed==object.id and 65 or 20)); nvgFill(vg)
            nvgStrokeColor(vg,nvgRGBA(255,225,150,235)); nvgStrokeWidth(vg,2/fit.scale); nvgStroke(vg)
            nvgRestore(vg)
        end
        nvgRestore(vg)
        if api.inspect then
            local r=object.regions[1]; local x,y=Geometry.ToScreen(layer,fit,r.cx,r.cy)
            nvgFontFace(vg,"sans"); nvgFontSize(vg,13); nvgTextAlign(vg,math.floor(NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE))
            nvgBeginPath(vg); nvgRoundedRect(vg,x-76,y-10,152,20,3)
            nvgFillColor(vg,nvgRGBA(24,32,28,235)); nvgFill(vg)
            nvgFillColor(vg,nvgRGBA(255,245,217,255)); nvgText(vg,x,y,object.id,nil)
        end
    end
    function art:Render(vg)
        local fit=api.Fit()
        if fit.scale<=0 then return end
        local cache=require "urhox-libs/UI/Core/ImageCache"
        nvgSave(vg); nvgIntersectScissor(vg,fit.x,fit.y,fit.w,fit.h)
        nvgBeginPath(vg); nvgRect(vg,fit.x,fit.y,fit.w,fit.h)
        nvgFillColor(vg,nvgRGBA(245,240,231,255)); nvgFill(vg)
        for _,layer in ipairs(Manifest.layers) do if layer.visible then
            local handle=math.floor(cache.Get(layer.path))
            if handle>0 then
                nvgSave(vg)
                nvgTranslate(vg,fit.x+layer.x*fit.scale,fit.y+layer.y*fit.scale)
                nvgRotate(vg,math.rad(layer.rotation))
                local w,h=layer.width*fit.scale,layer.height*fit.scale
                nvgBeginPath(vg); nvgRect(vg,-w/2,-h/2,w,h)
                nvgFillPaint(vg,nvgImagePattern(vg,-w/2,-h/2,w,h,0,handle,1)); nvgFill(vg)
                nvgRestore(vg)
            end
        end end
        for _,object in ipairs(Manifest.objects) do if api.inspect or api.pressed==object.id then outline(vg,object,fit) end end
        nvgRestore(vg)
    end
    for _,object in ipairs(Manifest.objects) do
        local hot=UI.Panel {id=object.id,position="absolute",left=0,top=0,width="100%",height="100%",
            onPointerDown=function(event) if event.button==MOUSEB_LEFT then api.pressed=object.id end end,
            onPointerUp=function() api.pressed=false end,onPointerCancel=function() api.pressed=false end,
            onPointerLeave=function() api.pressed=false end,
            onClick=function(_,event)
                if event and event.button~=MOUSEB_LEFT then return end
                api.lastHit=object.id; api.pressed=false; onOpen(object.target)
            end}
        function hot:HitTest(x,y) return Geometry.HitObject(Manifest,object,api.Fit(),x,y) end
        root:AddChild(hot)
    end
    return api
end
return H
