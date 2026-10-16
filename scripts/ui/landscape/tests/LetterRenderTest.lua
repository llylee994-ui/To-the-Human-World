-- Render-method smoke test with explicit NVG/font adapters, not native output.
local UI=require("urhox-libs/UI") --[[@as table]]
local Cache=require "urhox-libs/UI/Core/ImageCache"
local Paper=require "ui.landscape.LetterPaper"
local Presentation=require "ui.landscape.LetterPresentation"
local T={}
function T.Run()
    local calls={};local n=0
    local function check(ok,msg) n=n+1;assert(ok,msg) end
    local oldMeasure,oldVersion,oldImage=UI.MeasureTextWidth,UI.GetFontVersion,Cache.Get
    UI.MeasureTextWidth=function(text,size,face) check(face=="story" or face=="story-strong","measurement uses a registered handwriting face");return utf8.len(text)*size end
    UI.GetFontVersion=function() return 1 end
    Cache.Get=function() return 1 end
    local saved={}
    local names={"nvgSave","nvgRestore","nvgIntersectScissor","nvgFontFace","nvgFontSize","nvgTextAlign","nvgFillColor","nvgText","nvgBeginPath","nvgRect","nvgCircle","nvgStrokeColor","nvgStrokeWidth","nvgStroke","nvgMoveTo","nvgLineTo","nvgClosePath","nvgFill","nvgFillPaint","nvgTranslate","nvgScale","nvgRotate","nvgPathWinding"}
    for _,name in ipairs(names) do
        saved[name]=rawget(_G,name)
        _G[name]=function(_,...) calls[#calls+1]={name=name,args={...}} end
    end
    local rgba,pattern=rawget(_G,"nvgRGBA"),rawget(_G,"nvgImagePattern")
    local function colorAdapter(...) return {...} --[[@as NVGcolor]] end
    local function paintAdapter(...) return {...} --[[@as NVGpaint]] end
    -- Dynamic injection keeps test adapters out of the workspace's global
    -- binding type inference (the native bindings remain NVGcolor/NVGpaint).
    rawset(_G,"nvgRGBA",colorAdapter);rawset(_G,"nvgImagePattern",paintAdapter)
    local left,top,center,middle,right=NVG_ALIGN_LEFT,NVG_ALIGN_TOP,NVG_ALIGN_CENTER,NVG_ALIGN_MIDDLE,NVG_ALIGN_RIGHT
    NVG_ALIGN_LEFT=1;NVG_ALIGN_TOP=8;NVG_ALIGN_CENTER=2;NVG_ALIGN_MIDDLE=16;NVG_ALIGN_RIGHT=4
    local spans={{kind="word",text="睡着",spanId="first",cut=false,canCut=true},{kind="word",text="睡着",spanId="second",cut=false,canCut=true}}
    local view={spans=spans,segments={{kind="text",text="前文"},spans[1],{kind="text",text="，后文。\n另一处"},spans[2]}}
    local clicked=false --[[@as string|false]]
    local paper=Paper.New(view,function(id) clicked=id end)
    local vg=1 --[[@as NVGContextWrapper]] -- Explicit render-call adapter; never a native context.
    paper.root.GetAbsoluteLayout=function() return {x=100,y=200,w=280,h=paper.root.props.height} end
    paper.root.GetAbsoluteLayoutForHitTest=function() return {x=100,y=120,w=280,h=paper.root.props.height} end
    paper.root:Render(vg);paper.root:Render(vg)
    check(paper.root.props.height>40,"measured multiline content expands before scrolling")
    local bounds=assert(paper.Bounds("second"))
    paper.root.props.onClick(paper.root,{x=bounds.x+bounds.w/2,y=bounds.y+bounds.h/2,button=MOUSEB_LEFT} --[[@as PointerEvent]])
    check(clicked=="second","scroll-aware click resolves the correct equal-text span")
    clicked=false;paper.root.props.onClick(paper.root,{x=100,y=120,button=MOUSEB_LEFT} --[[@as PointerEvent]])
    check(not clicked,"plain text is never implicitly cut")
    local previous=paper.layout
    spans[1].cut=true;paper.SetView(view);calls={};paper.root:Render(vg)
    check(paper.layout==previous,"saved cuts reuse the measured layout without reflow")
    local holes=paper.Holes();check(#holes==1 and holes[1].y<200,"hole follows the scrolling screen position")
    local text="";for _,call in ipairs(calls) do if call.name=="nvgText" then text=text..call.args[3] end end
    check(text=="前文，后文。另一处睡着","only the cut word disappears; equal-text second word remains")
    for _,call in ipairs(calls) do if call.name=="nvgFontFace" then check(call.args[1]=="story","drawing uses exactly the measured font") end end
    calls={};Presentation.DrawStrip(1,"睡着",10,20,80,38,1)
    check(#calls>0,"textured cut strip draws through the real presentation renderer")
    calls={};Presentation.DrawPaper(vg,{x=0,y=0,w=800,h=400},{{x=100,y=150,w=60,h=25},{x=300,y=200,w=80,h=25}})
    local fills,clips,winding=0,0,0
    for _,c in ipairs(calls) do
        if c.name=="nvgFill" then fills=fills+1 end
        if c.name=="nvgIntersectScissor" then clips=clips+1 end
        if c.name=="nvgPathWinding" then winding=winding+1 end
    end
    check(fills==1 and clips==0 and winding==2,"cut paper uses a single image fill with two local holes, no full-row scissor seams")
    paper.enabled=true;calls={};paper.root:Render(vg)
    local first=cjson.encode(calls);paper.Update(.2,true);calls={};paper.root:Render(vg)
    check(cjson.encode(calls)~=first,"uncut words have animated rotating halo geometry")
    local lightHeads=0;for _,c in ipairs(calls) do if c.name=="nvgCircle" then lightHeads=lightHeads+1 end end
    check(lightHeads>0,"remaining uncut word has a visible moving light head, not just a faint outline")
    spans[2].cut=true;paper.SetView(view);calls={};paper.root:Render(vg)
    local cutHeads=0;for _,c in ipairs(calls) do if c.name=="nvgCircle" then cutHeads=cutHeads+1 end end
    check(cutHeads==0,"collected words have no magical marker left on their holes")
    spans[2].cut=false;paper.SetView(view)
    local marker=Paper.New({spans={},segments={{kind="word",text="忘记",spanId="forgot",cut=false}}},function() end)
    marker.root.GetAbsoluteLayout=function() return {x=0,y=0,w=180,h=marker.root.props.height} end
    calls={};marker.root:Render(vg)
    local particles,last=0,false --[[@as table|false]]
    for _,c in ipairs(calls) do
        if c.name=="nvgCircle" then particles=particles+1
        elseif c.name=="nvgMoveTo" then last=c.args
        elseif c.name=="nvgLineTo" then
            check(not last or math.abs(c.args[1]-last[1])<1e-8 or math.abs(c.args[2]-last[2])<1e-8,"word trail follows square corners instead of an ellipse")
            last=c.args
        elseif c.name=="nvgStrokeColor" then
            local rgb=c.args[1]
            check(rgb[1]==255 and rgb[2]==255 and rgb[3]==255,"only the white trail remains")
        end
    end
    check(particles>10,"word marker contains scattered particles behind the moving tip")
    local wish=require("ui.landscape.LetterEmphasis").Phrases.letter_pa_01
    local emphasized=Paper.New({letterId="letter_pa_01",spans={},segments={{kind="text",text="正文\n"..wish.."\n落款"}}},function() end)
    emphasized.root.GetAbsoluteLayout=function() return {x=0,y=0,w=280,h=emphasized.root.props.height} end
    calls={};emphasized.root:Render(vg)
    local face,strong,ordinary="",{},{}
    for _,call in ipairs(calls) do
        if call.name=="nvgFontFace" then face=call.args[1]
        elseif call.name=="nvgText" then
            local target=face=="story-strong" and strong or ordinary
            target[#target+1]=call.args[3]
        end
    end
    check(table.concat(strong)==wish,"the actual renderer uses the stronger face for every wish glyph")
    check(table.concat(ordinary)=="正文落款","normal body and signature retain their original face")
    local capture=rawget(_G,"LETTER_RENDER_EVIDENCE")
    if capture then capture(view,paper.layout,calls) end
    for name,value in pairs(saved) do _G[name]=value end
    rawset(_G,"nvgRGBA",rgba);rawset(_G,"nvgImagePattern",pattern)
    NVG_ALIGN_LEFT,NVG_ALIGN_TOP,NVG_ALIGN_CENTER,NVG_ALIGN_MIDDLE,NVG_ALIGN_RIGHT=left,top,center,middle,right
    UI.MeasureTextWidth,UI.GetFontVersion,Cache.Get=oldMeasure,oldVersion,oldImage
    print("[LetterRenderTest] PASS assertions="..n.."; actual NVG render methods/font identity/scroll-aware span clicks; NOT native evidence")
    return n
end
return T
