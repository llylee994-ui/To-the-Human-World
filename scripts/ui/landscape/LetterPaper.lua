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
local function halo(vg,x,y,w,h,time,enabled)
    local cx,cy,rx,ry=x+w/2,y+h/2-2,w/2+3,h/2-2
    local alpha=enabled and 1 or .35
    local function arc(start,length,inset,thickness,a)
        nvgBeginPath(vg)
        for i=0,28 do
            local angle=start+length*i/28
            local px,py=cx+(rx+inset)*math.cos(angle),cy+(ry+inset)*math.sin(angle)
            if i==0 then nvgMoveTo(vg,px,py) else nvgLineTo(vg,px,py) end
        end
        nvgStrokeColor(vg,nvgRGBA(211,145,45,math.floor(a*alpha)));nvgStrokeWidth(vg,thickness);nvgStroke(vg)
    end
    arc(0,math.pi*2,0,1,95)
    arc(time*2.2,math.pi*1.4,0,6,42)
    arc(time*2.2,math.pi*1.4,0,2,235)
    arc(-time*1.6+math.pi,math.pi*.85,-3,1.3,190)
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
                    halo(vg,x,y,r.w,r.h,api.time,api.enabled)
                end
                nvgFillColor(vg,nvgRGBA(62,49,36,255));nvgText(vg,x+(r.spanId and 3 or 0),y,r.text,nil)
            end
        end
        nvgRestore(vg)
    end
    return api
end
return P
