local UI=require "urhox-libs/UI"
local H=require "ui.landscape.HarborStyle"
local Notes=require "ui.landscape.PotionNotes"
local Petal=require "ui.landscape.PetalButton"
local V={}
local function text(parent,id,value,size,color,props)
    local p={id=id,text=value,fontFamily=H.fontFamily,fontSize=size or 13,fontColor=color or {72,65,45,255},
        lineHeight=1.35,whiteSpace="normal",flexShrink=0,pointerEvents="none"}
    for k,v in pairs(props or {}) do p[k]=v end
    local label=UI.Label(p);parent:AddChild(label);return label
end
function V.Render(ctx,b,center,summary,draft)
    local l=b.layout
    local earliest=l.wish.y+l.wish.h+8
    local height=math.min(320,math.max(120,l.summary.y-earliest-8))
    local paper=H.Paper {id="brewDetail",position="absolute",left=l.center.x,top=math.max(earliest,l.summary.y-height-8),
        width=l.center.w,height=height,compact=true,padding={14,22},zIndex=7,onClick=function() end}
    center:AddChild(paper)
    local p=Notes.Project(summary,ctx.content.effects,draft)
    local header=UI.Panel {width="100%",height=34,flexShrink=0,flexDirection="row",alignItems="center",gap=12,pointerEvents="none"}
    paper:AddChild(header)
    text(header,"brewNotesTitle","药 性 手 札",16,{83,95,74,255},{flexGrow=1,flexBasis=0,minWidth=0})
    text(header,"brewRequirementStatus",p.status,12,p.ready and {83,111,88,255} or {143,108,68,255},
        {width=112,height=26,textAlign="right",verticalAlign="middle",whiteSpace="nowrap"})
    local scroll=UI.ScrollView {id="brewDetailBody",width="100%",flexGrow=1,flexShrink=1,flexBasis=0,minHeight=0,
        scrollY=true,showScrollbar=true,paddingRight=10,pointerEvents="auto"}
    paper:AddChild(scroll)
    local requirement=UI.Panel {width="100%",padding={10,14},marginBottom=12,gap=4,flexShrink=0,
        backgroundColor={181,197,171,48},borderRadius=2,pointerEvents="none"}
    scroll:AddChild(requirement)
    text(requirement,nil,"委托需要",11,{118,132,106,255})
    text(requirement,"brewRequirement",p.requirement,13)
    for i,gap in ipairs(p.gaps) do
        text(requirement,"brewRequirementGap_"..i,b.notesNumbers and p.gapDetails[i] or gap,12,{143,108,68,255})
    end
    if p.primary then
        if b.notesNumbers then
            local detail=UI.Panel {id="brewEffectNumbers",width="100%",gap=6,paddingTop=8,flexShrink=0,pointerEvents="none"}
            scroll:AddChild(detail)
            text(detail,nil,"详细药性 · 当前权重",11,{145,120,91,255})
            for _,effect in ipairs(p.rows) do
                local row=UI.Panel {width="100%",height=28,flexDirection="row",alignItems="center",pointerEvents="none"};detail:AddChild(row)
                text(row,nil,effect.name.." · "..effect.tier,12,nil,{flexGrow=1,flexBasis=0,minWidth=0})
                text(row,"brewEffectNumber_"..effect.id,Notes.Number(effect.weight),12,{132,100,73,255},{width=72,height=26,textAlign="right"})
            end
        else
            text(scroll,"brewEffectsSummary","主导药性  ·  "..p.primary.name.."（"..p.primary.tier.."）",15,{83,101,80,255})
            if p.primary.desc~="" then text(scroll,"brewMainEffectMeaning",p.primary.desc,12,{127,116,94,255},{marginTop=4,marginBottom=10}) end
            if #p.companions>0 then
                local parts={};for _,effect in ipairs(p.companions) do parts[#parts+1]=effect.name.."（"..effect.tier.."）" end
                text(scroll,"brewCompanionEffects","伴随倾向  ·  "..table.concat(parts,"、"),12,{112,102,86,255},{marginBottom=10})
            end
        end
    else text(scroll,"brewEffectsSummary",summary.pending and "这锅的结果已保存，可查看后续故事。" or "投入主词后，这里会记下这一锅的药性。",13,{131,120,100,255}) end
    local footer=UI.Panel {id="brewNotesActions",width="100%",height=48,paddingTop=4,flexShrink=0,flexDirection="row",
        justifyContent="space-between",alignItems="center",pointerEvents="box-none"};paper:AddChild(footer)
    footer:AddChild(Petal.New {id="brewToggleNumbers",text=b.notesNumbers and "收起数值" or "查看数值",width=118,
        disabled=#p.rows==0,onClick=function() b.notesNumbers=not b.notesNumbers;ctx.model.dirty=true end})
    footer:AddChild(Petal.New {id="dismissIngredient",text="收起",width=80,
        onClick=function() b.selected=false;b.notesNumbers=false;ctx.model.dirty=true end})
end
return V
