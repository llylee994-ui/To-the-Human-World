local UI=require "urhox-libs/UI"
local Manifest=require "ui.landscape.LayoutManifest"
local Geometry=require "ui.landscape.LayoutGeometry"
local Zoom=require "ui.landscape.HomeZoom"
local Harbor=require "ui.landscape.HarborStyle"
local Backdrop=require "ui.landscape.SceneBackdrop"
local SeaArt=require "ui.landscape.SeaArt"
local H={}
function H.New(onOpen,developer)
    local root=UI.Panel {id="homeView",position="absolute",left=0,top=0,width="100%",height="100%",pointerEvents="box-none"}
    -- Same outer camera for backdrop and all room layers; labels remain UI siblings.
    local panZoom=false --[[@as table|false]]
    local function applyPanZoom(vg,bounds)
        if not panZoom then return end
        nvgTranslate(vg,bounds.x+panZoom.x,bounds.y+panZoom.y)
        nvgScale(vg,panZoom.scale,panZoom.scale);nvgTranslate(vg,-bounds.x,-bounds.y)
    end
    local background=Backdrop.New("homeBackdrop",SeaArt.background,Manifest.width,Manifest.height,nil,applyPanZoom)
    root:AddChild(background)
    local art=UI.Panel {id="homeArt",position="absolute",left=0,top=0,width="100%",height="100%",pointerEvents="none"}
    root:AddChild(art)
    local api={root=root,art=art,background=background,inspect=false --[[@as boolean]],lastHit="" --[[@as string]],
        pressed=false --[[@as string|false]],manifest=Manifest,zoom=1 --[[@as number]],blocked=false --[[@as boolean]],
        hintTime=3 --[[@as number]],hintsOpen=false --[[@as boolean]],panelOpen=false --[[@as boolean]],feedbackId=false --[[@as string|false]],feedbackTime=0 --[[@as number]]}
    function api.Fit()
        local bounds=root:GetAbsoluteLayout()
        return Geometry.RoomFit({x=bounds.x,y=bounds.y,w=bounds.w,h=bounds.h},Manifest)
    end
    function api.SetInspect(value) api.inspect=developer and value or false end
    function api.SetZoom(value) api.zoom=value end
    function api.SetPanZoom(scale,x,y)
        panZoom=scale and {scale=scale,x=x,y=y} or false
    end
    function api.SetBlocked(value) api.blocked=value;api.pressed=false end
    function api.SetPanelOpen(value) api.panelOpen=value end
    local renderSurround=background.Render
    function background:Render(vg)
        renderSurround(self,vg)
        Backdrop.DrawRoomSides(vg,SeaArt.homeForeground,api.Fit(),root:GetAbsoluteLayout())
    end
    local hintLayer=UI.Panel {id="homeHints",position="absolute",left=0,top=0,width="100%",height="100%",pointerEvents="none"}
    local intro=Harbor.Tag {id="homeHintIntro",text="点物件，看看有什么",position="absolute",left=12,bottom=12}
    local feedback=Harbor.Tag {id="homeObjectFeedback",position="absolute",visible=false}
    local tags={}
    function api.HintsVisible() return not api.blocked and not api.panelOpen and (api.hintsOpen or api.hintTime>0) end
    function api.ShowHints(value) api.hintsOpen=value;api.hintTime=0 end
    function api.SetFeedback(id) api.feedbackId=id;api.feedbackTime=1.3 end
    function api.Update(dt)
        dt=math.max(0,math.min(dt or 0,.25))
        api.hintTime=math.max(0,api.hintTime-dt);api.feedbackTime=math.max(0,api.feedbackTime-dt)
        hintLayer:SetVisible(api.HintsVisible());feedback:SetVisible(not api.blocked and not api.panelOpen and api.feedbackTime>0)
        intro:SetVisible(not api.blocked and not api.panelOpen and api.hintTime>0)
        if not root.GetAbsoluteLayout then return end -- explicit headless adapters bind after construction
        local fit=api.Fit();if fit.scale<=0 then return end
        local bounds=root:GetAbsoluteLayout()
        for _,obj in ipairs(Manifest.objects) do
            local layer=Manifest.layers[obj.layer];local region=obj.regions[1]
            local x,y=Geometry.ToScreen(layer,fit,region.cx,region.cy)
            -- Tags sit below each subject, independently of the minimum touch region.
            -- 12pt handwriting is 16 base pixels; labels stay compact and
            -- reserve their actual glyph width plus padding.
            local w=math.max(88,utf8.len(obj.label)*16+24)
            local left=math.max(fit.x,math.min(fit.x+fit.w-w,x-w/2))-bounds.x
            local top=math.max(bounds.y+56,math.min(bounds.y+bounds.h-48,y+region.h*layer.height*fit.scale*.5+4))-bounds.y
            local tag=tags[obj.id]
            if tag.SetStyle then tag:SetStyle({left=left,top=top,width=w}) else tag.props.left=left;tag.props.top=top;tag.props.width=w end
            if obj.id==api.feedbackId then
                feedback:SetText(obj.label)
                if feedback.SetStyle then feedback:SetStyle({left=left,top=top,width=w}) end
            end
        end
    end
    local function outline(vg,object,fit)
        local layer=assert(Manifest.layers[object.layer])
        nvgSave(vg)
        nvgTranslate(vg,fit.x+layer.x*fit.scale,fit.y+layer.y*fit.scale)
        nvgRotate(vg,math.rad(layer.rotation)); nvgScale(vg,fit.scale,fit.scale)
        for i in ipairs(object.regions) do
            local r=Geometry.ObjectRegion(layer,object,fit,i)
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
        local bounds=root:GetAbsoluteLayout()
        nvgSave(vg); nvgIntersectScissor(vg,bounds.x,bounds.y,bounds.w,bounds.h)
        -- Clip remains stationary. Stove moves all art; net keeps its original anchor.
        if panZoom then applyPanZoom(vg,bounds)
        else
            local ax,ay=fit.x+Zoom.anchor.x*fit.scale,fit.y+Zoom.anchor.y*fit.scale
            nvgTranslate(vg,ax,ay);nvgScale(vg,api.zoom,api.zoom);nvgTranslate(vg,-ax,-ay)
        end
        local sea=SeaArt.homeSea
        Backdrop.Draw(vg,SeaArt.background,fit.x+sea.x*fit.scale,fit.y+sea.y*fit.scale,sea.w*fit.scale,sea.h*fit.scale)
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
        if developer and api.inspect then
            for _,object in ipairs(Manifest.objects) do outline(vg,object,fit) end
        end
        nvgRestore(vg)
    end
    for _,object in ipairs(Manifest.objects) do
        local hot=UI.Panel {id=object.id,position="absolute",left=0,top=0,width="100%",height="100%",
            onPointerDown=function(event) if not api.blocked and event.button==MOUSEB_LEFT then api.pressed=object.id;api.SetFeedback(object.id) end end,
            onPointerUp=function() api.pressed=false end,onPointerCancel=function() api.pressed=false end,
            onPointerLeave=function() api.pressed=false end,
            onClick=function(_,event)
                if api.blocked then return end
                if event and event.button~=MOUSEB_LEFT then return end
                api.lastHit=object.id; api.pressed=false;api.SetFeedback(object.id);onOpen(object.target,object.id)
            end}
        function hot:HitTest(x,y) return not api.blocked and Geometry.HitObject(Manifest,object,api.Fit(),x,y) end
        root:AddChild(hot)
        local tag=Harbor.Tag {id="hint_"..object.id,text=object.label,position="absolute"}
        tags[object.id]=tag;hintLayer:AddChild(tag)
    end
    root:AddChild(hintLayer);root:AddChild(intro);root:AddChild(feedback)
    api.Update(0)
    return api
end
return H
