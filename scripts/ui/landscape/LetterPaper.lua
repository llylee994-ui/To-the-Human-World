-- A UI component: the framework owns layout, scrolling, fonts and the NVG frame.
-- RichText hardcodes sans and has no persistent cut-out geometry, so the paper
-- provides a measured inline renderer while retaining the normal UI input path.
local UI=require "urhox-libs/UI"
local Widget=require "urhox-libs/UI/Core/Widget"
local Theme=require "urhox-libs/UI/Core/Theme"
local L=require "ui.landscape.LetterLayout"
local Emphasis=require "ui.landscape.LetterEmphasis"
local P={}
local function fontFace(weight)
    return Theme.FontFace(weight=="bold" and "story-strong" or "story","normal")
end
local function wordTrail(vg,x,y,w,h,time,enabled)
    local left,top,bw,bh=x,y+1,math.max(1,w),math.max(1,h-6)
    local perimeter=2*(bw+bh)
    local alpha=enabled and 1 or .35
    local widthScale=2
    local function color(opacity)
        return nvgRGBA(255,255,255,math.floor(opacity*alpha))
    end
    local function point(distance)
        local d=distance%perimeter
        if d<bw then return left+d,top,0,-1
        elseif d<bw+bh then return left+bw,top+d-bw,1,0
        elseif d<2*bw+bh then return left+2*bw+bh-d,top+bh,0,1
        else return left,top+perimeter-d,-1,0 end
    end
    local corners={bw,bw+bh,2*bw+bh,perimeter}
    local function stroke(start,finish,width,opacity)
        local px,py=point(start)
        nvgBeginPath(vg);nvgMoveTo(vg,px,py)
        -- Include every crossed corner so even the fading tail stays rectangular.
        local cycle=math.floor(start/perimeter)
        for turn=cycle,cycle+1 do for _,corner in ipairs(corners) do
            local distance=turn*perimeter+corner
            if distance>start and distance<finish then
                px,py=point(distance);nvgLineTo(vg,px,py)
            end
        end end
        px,py=point(finish);nvgLineTo(vg,px,py)
        nvgStrokeWidth(vg,width*widthScale);nvgStrokeColor(vg,color(opacity));nvgStroke(vg)
    end
    local head=(time/math.pi)*perimeter
    local tail=perimeter*.94
    -- A luminous thread with a fading tail, rather than a permanent box outline.
    stroke(head-tail,head,4,24)
    stroke(head-tail*.85,head,2,40)
    for i=1,20 do
        local strength=i/20
        local fade=math.min(1,strength/.12)
        stroke(head-tail+tail*(i-1)/20,head-tail+tail*strength,.45+.65*strength,255*fade)
    end
    -- Fixed seeds avoid flicker: motes drift and fade before respawning at the tip.
    for i=1,32 do
        local age=(i/32+time*.24)%1
        local px,py,nx,ny=point(head-age*tail)
        local scatter=math.sin(i*2.399)*(.5+age*3)
        px=px+nx*scatter;py=py+ny*scatter
        local radius=(.4+.6*(.5+.5*math.sin(i*4.71)))*(1-age*.3)*math.sqrt(widthScale)
        nvgBeginPath(vg);nvgCircle(vg,px,py,radius)
        local fade=math.min(1,(1-age)/.12)
        nvgFillColor(vg,color(220*fade));nvgFill(vg)
    end
    local hx,hy=point(head)
    nvgBeginPath(vg);nvgCircle(vg,hx,hy,3*widthScale)
    nvgFillColor(vg,color(30));nvgFill(vg)
    nvgBeginPath(vg);nvgCircle(vg,hx,hy,1.25*widthScale)
    nvgFillColor(vg,color(240));nvgFill(vg)
end
---@class LetterPaperWidget: Panel
---@field GetText fun(self: LetterPaperWidget): string
function P.New(view,onCut)
    ---@type LetterPaperWidget
    local root=UI.Panel({id="letterPaper",alignSelf="stretch",minWidth=0,height=40,flexShrink=0,
        fontSize=18,pointerEvents="auto"}) --[[@as LetterPaperWidget]]
    local api={root=root,view=view,layout=false --[[@as table|false]],lastWidth=-1,lastFont=-1,enabled=true --[[@as boolean]],time=0}
    function api.Update(dt,focused)
        if focused and dt>0 then api.time=(api.time+math.min(dt,.1))%(math.pi*20) end
    end
    function api.SetView(value)
        api.view=value
        local cut={};for _,s in ipairs(value.spans or {}) do cut[s.spanId]=s.cut end
        if api.layout then for _,r in ipairs(api.layout.runs) do r.cut=cut[r.spanId] or false end end
    end
    function root:GetText()
        local text={}
        for _,s in ipairs(api.view.segments) do text[#text+1]=s.cut and string.rep("　",utf8.len(s.text) or 1) or s.text end
        return table.concat(text)
    end
    function api.EnsureLayout()
        local rect=root:GetAbsoluteLayout()
        local width=math.max(1,rect.w-8)
        local version=UI.GetFontVersion()
        if width~=api.lastWidth or version~=api.lastFont then
            local size=Theme.FontSize(18)
            api.layout=L.Layout(Emphasis.Segments(api.view),width,size*1.55,function(text,weight)
                return UI.MeasureTextWidth(text,size,fontFace(weight))
            end)
            api.lastWidth=width;api.lastFont=version
            Widget.SetStyle(root,{height=api.layout.height+8})
        end
        return api.layout
    end
    function api.Bounds(spanId)
        if not api.layout or not root.GetAbsoluteLayoutForHitTest then return nil end
        local rect=root:GetAbsoluteLayoutForHitTest()
        for _,r in ipairs(api.layout.runs) do if r.spanId==spanId then
            return {x=rect.x+4+r.x,y=rect.y+4+r.y,w=r.w,h=r.h,text=r.text,spanId=spanId}
        end end
    end
    function api.FirstAvailableBounds(clip)
        if not clip or clip.w<=0 or clip.h<=0 or not api.enabled then return nil end
        local rect=root:GetAbsoluteLayoutForHitTest()
        if rect.w<=8 then return nil end
        api.EnsureLayout()
        local available={}
        for _,span in ipairs(api.view.spans or {}) do
            if span.canCut and not span.cut then available[span.spanId]=true end
        end
        for _,run in ipairs(api.layout.runs) do
            if available[run.spanId] and not run.cut then
                local bounds={x=rect.x+4+run.x,y=rect.y+4+run.y,w=run.w,h=run.h}
                local visible=L.Intersection(bounds,clip)
                if visible and visible.h>=run.h*.75 then return visible end
            end
        end
        return nil
    end
    function api.Holes()
        local holes={}
        if not api.layout or not root.GetAbsoluteLayoutForHitTest then return holes end
        local rect=root:GetAbsoluteLayoutForHitTest()
        for _,r in ipairs(api.layout.runs) do if r.cut then
            holes[#holes+1]={x=rect.x+4+r.x,y=rect.y+6+r.y,w=r.w,h=r.h-5}
        end end
        return holes
    end
    function api.SpanAt(x,y)
        if not api.layout or not api.enabled then return nil end
        local rect=root:GetAbsoluteLayoutForHitTest()
        for _,r in ipairs(api.layout.runs) do
            if r.spanId and not r.cut and x>=rect.x+4+r.x and x<=rect.x+4+r.x+r.w
                and y>=rect.y+4+r.y and y<=rect.y+4+r.y+r.h then return r.spanId end
        end
        return nil
    end
    root.props.onClick=function(_,event)
        if event and event.button==MOUSEB_LEFT then
            local id=api.SpanAt(event.x,event.y);if id then onCut(id) end
        end
    end
    function root:Render(vg)
        local layout=api.EnsureLayout();local rect=self:GetAbsoluteLayout()
        nvgSave(vg);nvgIntersectScissor(vg,rect.x,rect.y,rect.w,rect.h)
        nvgFontFace(vg,Theme.FontFace("story","normal"));nvgFontSize(vg,Theme.FontSize(18))
        nvgTextAlign(vg,math.floor(NVG_ALIGN_LEFT+NVG_ALIGN_TOP))
        for _,r in ipairs(layout.runs) do
            local x,y=rect.x+4+r.x,rect.y+4+r.y
            if r.cut then
                -- Fine paper rim and a small top/left inner shadow. The real
                -- opening is removed from the parent paper, never painted black.
                nvgBeginPath(vg);nvgRect(vg,x+.7,y+2.7,r.w-1.4,r.h-6.4)
                nvgStrokeColor(vg,nvgRGBA(118,89,56,155));nvgStrokeWidth(vg,1);nvgStroke(vg)
                nvgBeginPath(vg);nvgMoveTo(vg,x+1,y+3);nvgLineTo(vg,x+r.w-1,y+3)
                nvgStrokeColor(vg,nvgRGBA(38,25,17,125));nvgStrokeWidth(vg,2);nvgStroke(vg)
            else
                nvgFontFace(vg,fontFace(r.fontWeight))
                if r.spanId then
                    local time=api.time+(r.x+r.y)*.015+math.pi/2
                    wordTrail(vg,x,y,r.w,r.h,time,api.enabled)
                end
                nvgFillColor(vg,nvgRGBA(62,49,36,255));nvgText(vg,x+(r.spanId and 3 or 0),y,r.text,nil)
            end
        end
        nvgRestore(vg)
    end
    return api
end
return P
