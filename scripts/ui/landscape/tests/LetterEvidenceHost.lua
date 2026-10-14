-- Explicit offline font/layout host. Exports production geometry and motion;
-- does not claim native Yoga layout, rendering, touch or a phone screenshot.
local UI=require("urhox-libs/UI") --[[@as table]]
local Data=require "data.content"
local F=require "debug.fixtures.B5Fixtures"
local View=require "ui.PlayView"
local Theme=require "urhox-libs/UI/Core/Theme"
local T={}
function T.Run()
    package.loaded["debug.DeveloperMode"]=false
    local host=require("ui.landscape.tests.ZoomTestHost").New()
    local x=F.New(Data,{targetSchema=3});local view=View.New(x.session,Data)
    local id=assert(view.model.Receive(assert(x.session.queries.GetSalvageView().value).availableLetterIds[1]).value).letterInstanceId
    assert(view.Read(id).ok);view.Update()
    local oldMeasure,oldVersion=UI.MeasureTextWidth,UI.GetFontVersion
    UI.MeasureTextWidth=assert(rawget(_G,"LETTER_FONT_WIDTH"))
    UI.GetFontVersion=function() return 1 end
    for _,size in ipairs({{1140,510},{800,360},{1280,720},{1024,768}}) do
        view.readerCache.presentation.Cancel();view.Close();view.Update();assert(view.Read(id).ok);view.Update()
        local presentation=view.readerCache.presentation
        local paper=presentation.paper
        local panel=assert(view.root:FindById("activePanel"))
        local scroll=assert(view.root:FindById("playScroll"))
        local width,height=size[1],size[2]
        local frame={x=width*.04,y=height*.03,w=width*.92,h=height*.94}
        local clip={x=frame.x+32,y=frame.y+82,w=frame.w-64,h=frame.h-150}
        local sourceY=clip.y+110
        panel.GetAbsoluteLayout=function() return frame end
        scroll.GetAbsoluteLayoutForHitTest=function() return clip end
        paper.root.GetAbsoluteLayout=function() return {x=clip.x+18,y=sourceY,w=clip.w-42,h=paper.root.props.height} end
        paper.root.GetAbsoluteLayoutForHitTest=paper.root.GetAbsoluteLayout
        local layout=paper.EnsureLayout()
        local definition=assert(Data.GetLetter(presentation.view.letterId))
        local capture=assert(rawget(_G,"LETTER_EVIDENCE"))
        presentation.motion.Cancel()
        -- Choose an uncut real source; later viewport captures use another span.
        local span
        for _,s in ipairs(presentation.view.spans) do if not s.cut then span=s;break end end
        assert(span,"evidence fixture ran out of uncut spans")
        local target=assert(paper.Bounds(span.spanId))
        local function export(label)
            capture(width,height,label,definition,presentation.view,layout,frame,clip,
                paper.root:GetAbsoluteLayout(),paper.Holes(),presentation.motion.Pose(),Theme.FontSize(18),Theme.FontSize(18)*1.55)
        end
        export("before")
        assert(presentation.Cut(span.spanId).ok)
        presentation.motion.Update(.18,true);export("snip")
        presentation.motion.Update(.32,true);export("flight")
        presentation.motion.Update(.5,true);export("after")
        assert(target.spanId==span.spanId)
    end
    UI.MeasureTextWidth,UI.GetFontVersion=oldMeasure,oldVersion
    print("[LetterEvidence] exported 16 frames from production layout/motion + explicit Pillow font/viewport adapter; OFFLINE ONLY")
    return true
end
return T
