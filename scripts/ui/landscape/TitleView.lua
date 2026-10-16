local UI=require "urhox-libs/UI"
local A=require "ui.landscape.JourneyArt"
local V={}
function V.New(ctx)
    local view=A.New(ctx,"journeyTitle","sea");local r=view.rect
    local result=ctx.session.queries.GetEndingView()
    if not result.ok then ctx.model.Notify(result);return view end
    local saved=result.value
    view.root:AddChild(UI.Panel {position="absolute",left=0,top=0,width="100%",height="100%",backgroundColor={21,35,33,95},pointerEvents="none"})
    local left=UI.Panel {position="absolute",left=r.x+r.w*.08,top=r.y+r.h*.19,width=r.w*.40,gap=18,pointerEvents="none"}
    view.root:AddChild(left)
    A.Label(left,"一间海边的小店 · 十一封远方来信",nil,15,{fontColor={225,219,191,255}})
    A.Label(left,"寄往人间","gameTitle",math.min(64,r.w*.055),{fontColor={255,245,216,255}})
    A.Label(left,"把别人的故事收好，\n也留一点位置，给自己的愿望。",nil,18,{fontColor={233,228,203,255},lineHeight=1.9})
    A.Image(view.root,"image/界面_记录书_麦穗干草_透明_v01.png",{left=r.x+r.w*.10,bottom=12,width=r.w*.24,height=r.h*.27,rotate=-8})
    local menuHeight=math.min(r.h*.82,(ctx.panel=="memories" or ctx.newPlaythroughConfirm or saved.phase=="ended") and 510 or saved.hasProgress and 400 or 330)
    local panel=A.Paper(view.root,{id="titleMenu",position="absolute",left=r.x+r.w*.55,top=r.y+(r.h-menuHeight)/2,
        width=r.w*.37,height=menuHeight,padding=36,gap=12})
    local body=UI.ScrollView {width="100%",flexGrow=1,flexShrink=1,flexBasis=0,scrollY=true,showScrollbar=true}
    local stack=UI.Panel {width="100%",gap=10,padding=2,flexShrink=0,pointerEvents="box-none"}
    body:AddChild(stack);panel:AddChild(body)
    local function button(id,text,fn,primary)
        return A.Button(stack,id,text,function() if view.Live() then fn() end end,primary,{width="100%"})
    end
    if ctx.panel=="memories" then
        A.Label(stack,"旅途留念","titleMenuHeading",25)
        A.Label(stack,"每次抵达，都在这里留下一页。",nil,14,{fontColor=A.muted})
        if #saved.memories==0 then A.Label(stack,"还没有收好的留念。",nil,16) end
        for i=#saved.memories,1,-1 do
            local row=saved.memories[i]
            button("memory_"..i,row.ending.title,function() ctx.ShowMemory(row.ending) end,false)
        end
        button("backToTitle","回到首页",ctx.ShowTitle,false)
    elseif ctx.newPlaythroughConfirm then
        A.Label(stack,"开启新的旅程？","newPlaythroughHeading",25)
        A.Label(stack,"当前旅程的进度将被替换。已经收好的结局与愿望拼贴会保留在「旅途留念」里。","newPlaythroughWarning",17)
        button("cancelNewPlaythrough","保留当前旅程",function() ctx.newPlaythroughConfirm=false;ctx.model.dirty=true end,false)
        button("confirmNewPlaythrough","确认开始新游戏",function()
            if ctx.model.StartNewPlaythrough(true).ok then
                ctx.newPlaythroughConfirm=false;ctx.wishUndo={};ctx.wishSelected=false;ctx.ContinueJourney()
            end
        end,true)
    else
        A.Label(stack,saved.phase=="ended" and "一段旅程，已经收好" or "海风还在等你","titleMenuHeading",23)
        A.Label(stack,saved.phase=="ended" and saved.ending.title or (saved.hasProgress and "继续未写完的故事。" or "从第一封来信开始。"),"titleStatus",15,{fontColor=A.muted})
        button(saved.phase=="ended" and "reviewCurrentEnding" or saved.hasProgress and "continueJourney" or "startJourney",
            saved.phase=="ended" and "回顾这次结局" or saved.hasProgress and "继续游戏" or "开始游戏",ctx.ContinueJourney,true)
        if saved.canRestore then
            button("restoreBeforeEnding","回到结局前",function()
                if ctx.model.RestoreEndingCheckpoint().ok then ctx.wishUndo={};ctx.wishSelected=false;ctx.ContinueJourney() end
            end,false)
        end
        if #saved.memories>0 then button("openMemories","旅途留念",function() ctx.panel="memories";ctx.model.dirty=true end,false) end
        if saved.hasProgress then
            button("startNewPlaythrough","开始新游戏",function() ctx.newPlaythroughConfirm=true;ctx.model.dirty=true end,false)
        end
    end
    A.Label(panel,"寄出的故事，都曾在这里停留。",nil,13,{fontColor=A.muted,marginTop=8,textAlign="center"})
    return view
end
return V
