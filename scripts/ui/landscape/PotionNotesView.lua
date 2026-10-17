-- A read-only bottom sheet; the draft and the workbench geometry never change here.
local UI=require "urhox-libs/UI"
local Widget=require "urhox-libs/UI/Core/Widget"
local H=require "ui.landscape.HarborStyle"
local Notes=require "ui.landscape.PotionNotes"
local Petal=require "ui.landscape.PetalButton"
local Workbench=require "ui.landscape.BrewLayout"
local V={}
local function text(parent,id,value,size,color,props)
    local p={id=id,text=value,fontFamily=H.fontFamily,fontSize=size or 18,fontColor=color or {72,65,45,255},
        lineHeight=1.5,whiteSpace="normal",flexShrink=0,pointerEvents="none"}
    for k,v in pairs(props or {}) do p[k]=v end
    local label=UI.Label(p);parent:AddChild(label);return label
end
function V.Layout(viewport,safe,layout)
    local l=layout or Workbench.Compute(viewport.w,viewport.h,safe)
    local bottom=math.min(viewport.h-safe.bottom-12,l.controls.y+l.controls.h)
    return {x=l.summary.x,y=l.summary.y,w=l.summary.w,h=math.max(1,bottom-l.summary.y)}
end

function V.Update(b,dt,focused)
    local m=b.notesMotion
    if not m then return end
    if focused and dt>=0 and dt<=.5 then m.time=math.min(.22,m.time+dt) end
    local t=m.time/.22;local e=1-(1-t)^3
    Widget.SetStyle(m.paper,{translateY=(1-e)*m.height,opacity=.6+.4*e})
end
function V.Render(ctx,b,host,summary,draft)
    if b.selected~="recipe" then b.notesMotion=nil;return end
    local vp=ctx.viewport or {w=1280,h=720}
    local safe=ctx.safeInsets or {left=0,right=0,top=0,bottom=0}
    local r=V.Layout(vp,safe,b.layout)
    local compact=vp.h-safe.top-safe.bottom<620
    local titleSize,statusSize=compact and 17 or 22,compact and 13 or 17
    local bodySize,detailSize=compact and 15 or 19,compact and 14 or 18
    local captionSize=compact and 12 or 15
    local function close() b.selected=false;b.notesNumbers=false;b.notesMotion=nil;ctx.model.dirty=true end
    host:AddChild(UI.Panel {id="brewNotesBackdrop",position="absolute",left=0,top=0,right=0,bottom=0,
        backgroundColor={0,0,0,0},onClick=close})
    local paper=UI.Panel {id="brewDetail",position="absolute",left=r.x,top=r.y,width=r.w,height=r.h,
        backgroundImage=H.paperImage,backgroundFit="cover",backgroundColor={244,233,207,255},
        borderWidth=compact and 2 or 3,borderColor={116,72,35,255},borderRadius=6,padding=compact and {6,16} or {8,20},
        pointerEvents="auto",overflow="hidden",onClick=function() end}
    paper:AddChild(UI.Panel {id="brewNotesFrame",position="absolute",left=4,top=4,right=4,bottom=4,
        borderWidth=1,borderColor={190,148,84,255},borderRadius=3,pointerEvents="none"})
    for _,corner in ipairs({{left=2,top=2},{right=2,top=2},{left=2,bottom=2},{right=2,bottom=2}}) do
        local props={position="absolute",width=compact and 8 or 10,height=compact and 8 or 10,borderRadius=5,borderWidth=1,
            borderColor={111,68,31,255},backgroundColor={218,176,106,255},pointerEvents="none"}
        for k,v in pairs(corner) do props[k]=v end
        paper:AddChild(UI.Panel(props))
    end
    host:AddChild(paper)
    local motion=b.notesMotion or {time=0}
    motion.paper=paper;motion.height=vp.h-r.y;b.notesMotion=motion;V.Update(b,0,false)
    local p=Notes.Project(summary,ctx.content.effects,draft)
    local header=UI.Panel {width="100%",height=44,flexShrink=0,flexDirection="row",alignItems="center",gap=compact and 8 or 12,pointerEvents="box-none"}
    paper:AddChild(header)
    text(header,"brewNotesTitle","药 性 手 札",titleSize,{83,95,74,255},{flexGrow=1,flexBasis=0,minWidth=0})
    text(header,"brewRequirementStatus",p.status,statusSize,p.ready and {83,111,88,255} or {143,108,68,255},
        {width=compact and 88 or 120,height=32,textAlign="right",verticalAlign="middle",whiteSpace="nowrap"})
    if compact then
        local target=UI.Panel {id="brewNotesClose",width=44,height=44,flexShrink=0,onClick=close}
        target:AddChild(H.Button {text="×",position="absolute",left=6,top=6,width=32,height=32,minHeight=32,
            padding=0,fontSize=17,pointerEvents="none"})
        header:AddChild(target)
    else
        header:AddChild(H.Button {id="brewNotesClose",text="×",width=44,height=44,minHeight=44,padding=0,fontSize=22,onClick=close})
    end
    local scroll=UI.ScrollView {id="brewDetailBody",width="100%",flexGrow=1,flexShrink=1,flexBasis=0,minHeight=0,
        scrollY=true,showScrollbar=true,paddingRight=10,pointerEvents="auto"}
    paper:AddChild(scroll)
    local requirement=UI.Panel {width="100%",padding=compact and {3,8} or {4,12},marginBottom=4,gap=compact and 3 or 4,flexShrink=0,
        backgroundColor={181,197,171,48},borderRadius=2,pointerEvents="none"}
    scroll:AddChild(requirement)
    text(requirement,nil,"委托需要",captionSize,{118,132,106,255},{lineHeight=1.3})
    text(requirement,"brewRequirement",p.requirement,bodySize)
    for i,gap in ipairs(p.gaps) do
        text(requirement,"brewRequirementGap_"..i,b.notesNumbers and p.gapDetails[i] or gap,detailSize,{143,108,68,255})
    end
    if p.primary then
        text(scroll,"brewEffectsSummary","当前主导药性  ·  "..p.primary.name.."（"..p.primary.tier.."）",compact and 16 or 20,{83,101,80,255})
        if b.notesNumbers then
            local detail=UI.Panel {id="brewEffectNumbers",width="100%",gap=compact and 5 or 8,paddingTop=compact and 8 or 12,flexShrink=0,pointerEvents="none"}
            scroll:AddChild(detail)
            text(detail,nil,"详细药性 · 当前权重",captionSize,{145,120,91,255})
            for _,effect in ipairs(p.rows) do
                local row=UI.Panel {width="100%",height=compact and 28 or 36,flexDirection="row",alignItems="center",pointerEvents="none"};detail:AddChild(row)
                text(row,nil,effect.name.." · "..effect.tier,detailSize,nil,{flexGrow=1,flexBasis=0,minWidth=0})
                text(row,"brewEffectNumber_"..effect.id,Notes.Number(effect.weight),detailSize,{132,100,73,255},{width=compact and 64 or 80,height=compact and 26 or 32,textAlign="right"})
            end
        end
    else text(scroll,"brewEffectsSummary","投入主词后，这里会记下这一锅的当前药性。",detailSize,{131,120,100,255}) end
    local footer=UI.Panel {id="brewNotesActions",width="100%",height=44,paddingTop=0,flexShrink=0,flexDirection="row",
        justifyContent="space-between",alignItems="center",pointerEvents="box-none"};paper:AddChild(footer)
    footer:AddChild(Petal.New {id="brewToggleNumbers",text=b.notesNumbers and "收起数值" or "查看数值",width=compact and 112 or 140,fontSize=compact and 13 or 17,
        visualScale=compact and .8 or 1,
        disabled=#p.rows==0,onClick=function() b.notesNumbers=not b.notesNumbers;ctx.model.dirty=true end})
    footer:AddChild(Petal.New {id="dismissIngredient",text="收起",width=compact and 80 or 100,fontSize=compact and 13 or 17,
        visualScale=compact and .8 or 1,onClick=close})
end
return V
