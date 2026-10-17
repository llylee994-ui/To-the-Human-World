local UI=require "urhox-libs/UI"
local A=require "ui.landscape.JourneyArt"
local V={}
function V.New(ctx)
    local view=A.New(ctx,"journeyTitle",false)
    local vp=ctx.viewport or {w=1280,h=720}
    local safe=ctx.safeInsets or {left=0,top=0,right=0,bottom=0}
    local sw=math.max(1,vp.w-safe.left-safe.right)
    local sh=math.max(1,vp.h-safe.top-safe.bottom)
    -- Anchor cover-cropping to the left: 4:3 must retain the quiet menu wall.
    local artScale=math.max(vp.w/1672,vp.h/941)
    A.Image(view.root,"image/title-screen-r1/shop-doorway-soft.png",{id="titleBackdrop",left=0,top=(vp.h-941*artScale)/2,
        width=1672*artScale,height=941*artScale,backgroundFit="fill"})
    local result=ctx.session.queries.GetEndingView()
    if not result.ok then ctx.model.Notify(result);return view end
    local saved=result.value
    local compact=sh<540
    local columnWidth=math.min(440,sw*.34)
    local top=safe.top+sh*(compact and .12 or .17)
    local left=UI.Panel {id="titleComposition",position="absolute",left=safe.left+sw*.085,top=top,
        width=columnWidth,height=vp.h-safe.bottom-top-24,gap=compact and 10 or 18,pointerEvents="box-none"}
    view.root:AddChild(left)
    -- Theme.FontSize converts pt to px by 4/3; reserve spacing before fitting four CJK glyphs.
    A.Label(left,"寄往人间","gameTitle",math.min(84,(columnWidth-8)*.18),{width="100%",whiteSpace="nowrap",lineHeight=1.2,
        fontColor={255,240,207,255},letterSpacing=2,textShadow={offsetX=1,offsetY=2,blur=4,color={12,8,5,160}}})
    A.Label(left,"TO THE HUMAN WORLD","titleSubtitle",compact and 10 or 12,{width="100%",whiteSpace="nowrap",letterSpacing=2,
        fontFamily="sans",fontColor={220,199,162,255},lineHeight=1.2})
    local panel=UI.Panel {id="titleMenu",width="100%",flexGrow=1,flexShrink=1,flexBasis=0,minHeight=0,
        marginTop=compact and 12 or 30,pointerEvents="box-none"}
    left:AddChild(panel)
    local body=UI.ScrollView {id="titleMenuScroll",width="100%",height="100%",scrollY=true,showScrollbar=false}
    local stack=UI.Panel {width="100%",gap=compact and 4 or 8,paddingRight=8,flexShrink=0,pointerEvents="box-none"}
    body:AddChild(stack);panel:AddChild(body)
    local cream={246,228,193,255}
    local muted={209,188,154,255}
    local function label(text,id,size,extra)
        local p={fontColor=muted,lineHeight=1.5,width="100%"}
        for k,v in pairs(extra or {}) do p[k]=v end
        return A.Label(stack,text,id,size,p)
    end
    local function button(id,text,fn,primary)
        local node=A.Button(stack,id,"",function() if view.Live() then fn() end end,false,{width="100%",height=48,
            minHeight=48,padding=0,pressedPadding=0,borderWidth=0,borderRadius=0,
            backgroundColor={0,0,0,0},hoverBackgroundColor={229,198,140,22},pressedBackgroundColor={229,198,140,38}})
        A.Label(node,text,id.."Label",compact and 19 or 22,{position="absolute",left=30,right=0,top=0,bottom=0,
            fontColor=cream,verticalAlign="middle",lineHeight=1.2})
        if primary then
            node:AddChild(UI.Panel {position="absolute",left=8,top=20,width=8,height=8,rotate=45,
                borderWidth=1,borderColor={231,188,109,255},backgroundColor={177,129,58,180},pointerEvents="none"})
        end
        return node
    end
    if ctx.panel=="memories" then
        label("旅途留念","titleMenuHeading",25,{fontColor=cream})
        if #saved.memories==0 then label("还没有收好的留念。",nil,16) end
        for i=#saved.memories,1,-1 do
            local row=saved.memories[i]
            button("memory_"..i,row.ending.title,function() ctx.ShowMemory(row.ending) end,false)
        end
        button("backToTitle","回到首页",ctx.ShowTitle,false)
    elseif ctx.newPlaythroughConfirm then
        label("开启新的旅程？","newPlaythroughHeading",25,{fontColor=cream})
        label("当前旅程的进度将被替换。已经收好的结局与愿望拼贴会保留在「旅途留念」里。","newPlaythroughWarning",17)
        button("cancelNewPlaythrough","保留当前旅程",function() ctx.newPlaythroughConfirm=false;ctx.model.dirty=true end,false)
        button("confirmNewPlaythrough","确认开始新游戏",function()
            if ctx.model.StartNewPlaythrough(true).ok then
                ctx.newPlaythroughConfirm=false;ctx.wishUndo={};ctx.wishSelected=false;ctx.ContinueJourney()
            end
        end,true)
    else
        if saved.phase=="ended" then label(saved.ending.title,"titleStatus",15) end
        button(saved.phase=="ended" and "reviewCurrentEnding" or saved.hasProgress and "continueJourney" or "startJourney",
            saved.phase=="ended" and "回顾这次结局" or saved.hasProgress and "继续游戏" or "开始游戏",ctx.ContinueJourney,true)
        if saved.canRestore then
            button("restoreBeforeEnding","回到结局前",function()
                if ctx.model.RestoreEndingCheckpoint().ok then ctx.wishUndo={};ctx.wishSelected=false;ctx.ContinueJourney() end
            end,false)
        end
        if #saved.memories>0 then button("openMemories","旅途留念",function() ctx.panel="memories";ctx.model.dirty=true end,false) end
        if saved.hasProgress then
            button("startNewPlaythrough","新的旅程",function() ctx.newPlaythroughConfirm=true;ctx.model.dirty=true end,false)
        end
    end
    return view
end
return V
