local UI=require "urhox-libs/UI"
local Widget=require "urhox-libs/UI/Core/Widget"
local Theme=require "urhox-libs/UI/Core/Theme"
local ImageCache=require "urhox-libs/UI/Core/ImageCache"
local Harbor=require "ui.landscape.HarborStyle"
local Paper=require "ui.landscape.LetterPaper"
local Layout=require "ui.landscape.LetterLayout"
local Motion=require "ui.landscape.LetterMotion"
local P={}
function P.DrawPaper(vg,frame,holes)
    -- A single compound path keeps antialiasing at the actual hole edges.
    -- Repainting the entire image through adjacent scissors creates long seams.
    local handle=math.floor(ImageCache.Get(Harbor.paperImage))
    nvgBeginPath(vg);nvgRect(vg,frame.x,frame.y,frame.w,frame.h)
    for _,hole in ipairs(holes) do
        nvgRect(vg,hole.x,hole.y,hole.w,hole.h);nvgPathWinding(vg,NVG_HOLE)
    end
    if handle>0 then nvgFillPaint(vg,nvgImagePattern(vg,frame.x,frame.y,frame.w,frame.h,0,handle,1))
    else nvgFillColor(vg,nvgRGBA(240,222,187,255)) end
    nvgFill(vg)
end
local function stripPath(vg,x,y,w,h)
    nvgBeginPath(vg);nvgMoveTo(vg,x+2,y)
    for dx=10,w-3,10 do nvgLineTo(vg,x+dx,y+(math.floor(dx/10)%2)*1.5) end
    nvgLineTo(vg,x+w-1,y+2);nvgLineTo(vg,x+w,y+h-2)
    for dx=w-8,3,-10 do nvgLineTo(vg,x+dx,y+h-(math.floor(dx/10)%2)*1.5) end
    nvgLineTo(vg,x+1,y+h-2);nvgClosePath(vg)
end
function P.DrawStrip(vg,text,x,y,w,h,opacity)
    local handle=math.floor(ImageCache.Get(Harbor.paperImage))
    stripPath(vg,x+2,y+3,w,h);nvgFillColor(vg,nvgRGBA(34,24,16,math.floor(55*opacity)));nvgFill(vg)
    stripPath(vg,x,y,w,h)
    if handle>0 then nvgFillPaint(vg,nvgImagePattern(vg,x,y,w,h,0,handle,opacity))
    else nvgFillColor(vg,nvgRGBA(240,222,187,math.floor(255*opacity))) end
    nvgFill(vg);nvgStrokeWidth(vg,.7);nvgStrokeColor(vg,nvgRGBA(141,108,68,math.floor(120*opacity)));nvgStroke(vg)
    nvgFontFace(vg,Theme.FontFace("story","normal"));nvgFontSize(vg,Theme.FontSize(18))
    nvgTextAlign(vg,math.floor(NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE))
    nvgFillColor(vg,nvgRGBA(62,49,36,math.floor(255*opacity)));nvgText(vg,x+w/2,y+h/2,text,nil)
end
function P.Card(text,id)
    local root=UI.Panel {id=id,height=44,minWidth=72,alignSelf="flex-start",pointerEvents="none"}
    function root:Render(vg)
        local r=self:GetAbsoluteLayout()
        local width=UI.MeasureTextWidth(text,Theme.FontSize(18),"story")+24
        if self.props.width~=width then Widget.SetStyle(self,{width=width}) end
        P.DrawStrip(vg,text,r.x,r.y,r.w,r.h,1)
    end
    return root
end
function P.New(ctx,body,view)
    local panel=body.parent.parent
    local api={motion=Motion.New(),view=view,collected=0,lastWidth=-1,lastHeight=-1}
    local function fail(message) return {ok=false,error={code="PRESENTATION_BUSY",message=message}} end
    local function syncInput()
        local action=ctx.model.Action("CutWord")
        local busy=api.motion.opening or api.motion.flight~=false
        api.paper.enabled=action.enabled and not busy
    end
    function api.Cut(id)
        if api.motion.opening or api.motion.flight then return fail("请稍候，纸条正在收好。") end
        local source
        for _,s in ipairs(api.view.spans) do if s.spanId==id then source=s;break end end
        if not source or source.cut or not source.canCut then return fail("这处词条已经收取。") end
        local result=ctx.model.Cut(id)
        if result.ok then
            local bounds=api.paper.Bounds(id)
            local r=panel.GetAbsoluteLayout and panel:GetAbsoluteLayout() or {x=0,y=0,w=800,h=400}
            bounds=bounds or {x=r.x+50,y=r.y+80,w=72,h=34}
            bounds.text=source.text;bounds.spanId=id
            api.motion.Start(bounds,{x=r.x+r.w-150,y=r.y+r.h-57})
            api.collected=api.collected+1
            api.Refresh(assert(ctx.session.modules.letters.GetView(ctx.model.selectedLetter)).value)
        end
        return result
    end
    api.paper=Paper.New(view,function(id) api.Cut(id) end)
    body:AddChild(api.paper.root)
    function api.Refresh(value) api.view=value;api.paper.SetView(value);syncInput() end
    function panel:Render(vg)
        local frame=self:GetAbsoluteLayout()
        local scroll=ctx.scroll
        local viewport=scroll and scroll.GetAbsoluteLayoutForHitTest and scroll:GetAbsoluteLayoutForHitTest()
        local holes={}
        for _,hole in ipairs(api.paper.Holes()) do
            local clipped=viewport and Layout.Intersection(viewport,hole)
            if clipped then holes[#holes+1]=clipped end
        end
        P.DrawPaper(vg,frame,holes)
        local fold=api.motion.OpenPose().fold
        if fold>0 then
            nvgBeginPath(vg);nvgRect(vg,frame.x+frame.w*.5-2,frame.y+32,4,math.max(0,frame.h-64))
            nvgFillColor(vg,nvgRGBA(91,68,42,math.floor(80*fold)));nvgFill(vg)
        end
    end
    local fx=UI.Panel {id="letterCollection",position="absolute",left=0,top=0,width="100%",height="100%",pointerEvents="none"}
    panel:AddChild(fx)
    function fx:Render(vg)
        local r=panel:GetAbsoluteLayout()
        nvgFontFace(vg,"story");nvgFontSize(vg,Theme.FontSize(13));nvgTextAlign(vg,math.floor(NVG_ALIGN_RIGHT+NVG_ALIGN_TOP))
        local message=ctx.messages and ctx.messages:Current(0)
        local failure=ctx.importantMessage and message and message.text
        nvgFillColor(vg,nvgRGBA(93,71,46,210));nvgText(vg,r.x+r.w-38,r.y+r.h-52,failure or ("词条托盘"..(api.collected>0 and " · +"..api.collected or "")),nil)
        local pose=api.motion.Pose();if not pose then return end
        nvgSave(vg);nvgTranslate(vg,pose.x,pose.y);nvgScale(vg,pose.scale,pose.scale);nvgRotate(vg,pose.angle)
        P.DrawStrip(vg,pose.text,0,0,pose.w,pose.h,pose.opacity)
        if pose.phase=="snip" then
            local scissors=math.floor(ImageCache.Get("image/letter-scissors.png"))
            if scissors>0 then
                nvgSave(vg);nvgTranslate(vg,pose.w*math.min(1,pose.snip),-20)
                nvgRotate(vg,.6+math.sin(pose.snip*math.pi*6)*.1)
                nvgBeginPath(vg);nvgRect(vg,-22,-18,112,75)
                nvgFillPaint(vg,nvgImagePattern(vg,-22,-18,112,75,0,scissors,1));nvgFill(vg);nvgRestore(vg)
            end
        end
        nvgRestore(vg)
    end
    function api.Cancel()
        api.motion.Cancel();Widget.SetStyle(panel,{scale=1,opacity=1,translateY=0});syncInput()
    end
    function api.Update(dt,focused)
        if panel.GetAbsoluteLayout then
            local r=panel:GetAbsoluteLayout()
            if api.lastWidth>=0 and (r.w~=api.lastWidth or r.h~=api.lastHeight) then api.motion.Cancel() end
            api.lastWidth=r.w;api.lastHeight=r.h
        end
        local busy=api.motion.opening or api.motion.flight~=false
        api.motion.Update(dt,focused)
        api.paper.Update(dt,focused)
        local p=api.motion.OpenPose()
        if panel.props.opacity~=p.opacity or panel.props.scale~=p.scale or panel.props.translateY~=p.translateY then
            Widget.SetStyle(panel,{scale=p.scale,opacity=p.opacity,translateY=p.translateY})
        end
        if busy and not api.motion.opening and not api.motion.flight then syncInput() end
    end
    return api
end
return P
