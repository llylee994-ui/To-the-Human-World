local UI=require "urhox-libs/UI"
local A=require "ui.landscape.JourneyArt"
local Paper=require "ui.landscape.WishPaper"
local M=require "ui.landscape.SeasideManifest"
local V={}
function V.New(ctx)
    local query=ctx.session.queries.GetEndingView()
    local ending=ctx.panel=="memoryReview" and ctx.reviewEnding or query.ok and query.value.ending
    local kind=ending and ending.kind
    if kind=="departure" then
        ctx.endingEntrance=false
        return require("ui.landscape.DepartureView").New(ctx,ending,ctx.panel=="memoryReview")
    end
    if kind=="apprentice" then
        local fresh=ctx.endingEntrance=="apprentice" and ctx.panel~="memoryReview"
        ctx.endingEntrance=false
        local Apprentice=require "ui.landscape.ApprenticeView"
        if fresh then return Apprentice.Narration(ctx,ending,false) end
        return Apprentice.New(ctx,{ending=ending,review=ctx.panel=="memoryReview"})
    end
    if kind=="wish" then
        ctx.endingEntrance=false
        return require("ui.landscape.WishEnding").New(ctx,ending,ctx.panel=="memoryReview")
    end
    local view=A.New(ctx,"endingView",kind~="apprentice" and "sea" or false);local r=view.rect
    if not ending then if not query.ok then ctx.model.Notify(query) end;return view end
    local review=ctx.panel=="memoryReview"
    local entrance=not review and ctx.endingEntrance==kind
    ctx.endingEntrance=false;view.busy=entrance
    local time=0
    local showCollage=ctx.endingShowCollage and ending.collage
    local sheet=UI.Panel {id="endingSheet",position="absolute",left=0,top=0,width="100%",height="100%",visible=not entrance,pointerEvents="box-none"}
    view.root:AddChild(sheet)
    if showCollage then
        local ph=math.min(r.h-80,r.w/1.45);local pw=ph*1.45
        Paper.New(sheet,{x=r.x+(r.w-pw)/2,y=r.y+(r.h-80-ph)/2,w=pw,h=ph},ending.collage)
    else
        local paper=A.Paper(sheet,{id="endingPaper",position="absolute",left=r.x+r.w*.15,top=r.y+4,width=r.w*.70,height=r.h-76,padding=40,gap=14})
        A.Label(paper,"旅  程  留  念",nil,13,{fontColor=A.muted,textAlign="center"})
        A.Label(paper,ending.title,"releaseEndingTitle",30,{textAlign="center"})
        local scroll=UI.ScrollView {id="endingTextScroll",width="100%",flexGrow=1,flexShrink=1,flexBasis=0,scrollY=true,showScrollbar=true}
        local body=UI.Panel {width="100%",paddingRight=18,flexShrink=0,pointerEvents="box-none"};scroll:AddChild(body);paper:AddChild(scroll)
        A.Label(body,ending.text,"releaseEndingText",19,{lineHeight=1.85})
    end
    local footer=UI.Panel {position="absolute",left=r.x,right=r.x,bottom=20+((ctx.safeInsets or {}).bottom or 0),height=48,
        flexDirection="row",justifyContent="center",gap=12,pointerEvents="box-none"};sheet:AddChild(footer)
    if ending.collage then
        A.Button(footer,"viewEndingCollage",showCollage and "回看结局" or "展开愿望信纸",function()
            if view.Live() and not view.busy then ctx.endingShowCollage=not showCollage;ctx.model.dirty=true end
        end,false)
    end
    A.Button(footer,review and "backToMemories" or "endGame",review and "收回留念" or "结束游戏",function()
        if not view.Live() or view.busy then return end
        ctx.endingShowCollage=false
        if review then ctx.panel="memories";ctx.model.dirty=true else ctx.ShowTitle() end
    end,true,{minWidth=180})
    if entrance then
        local film=UI.Panel {id="endingTransition",position="absolute",left=0,top=0,width="100%",height="100%",onClick=function() end}
        view.root:AddChild(film)
        function film:Render(vg)
            local b=self:GetAbsoluteLayout();local t=math.min(1,time/2.7)
            if kind=="wish" then
                A.Sprite(vg,M.bottle.path,b.x+b.w*(.51+.10*t),b.y+b.h*(.69-.23*t),b.w*.22*(1-.78*t),b.w*.22*(1-.78*t),-12+math.sin(t*9)*6,1-t*.65)
            else
                nvgBeginPath(vg);nvgRect(vg,b.x,b.y,b.w,b.h);nvgFillColor(vg,nvgRGBA(235,217,171,math.floor((1-t)*65)));nvgFill(vg)
            end
        end
        local caption=A.Paper(film,{position="absolute",left="32%",top="17%",width="36%",height=86,padding=20,justifyContent="center"})
        A.Label(caption,kind=="departure" and "船已启程" or kind=="wish" and "愿望，正在远行" or "把信，收进抽屉",nil,24,{textAlign="center"})
        local function finish() if not view.Live() then return end;view.busy=false;film:SetVisible(false);sheet:SetVisible(true) end
        A.Button(film,"skipEndingTransition","继续",finish,false,{position="absolute",bottom=24,right=r.x})
        function view.Update(dt,focused)
            if not view.busy then return end
            if not focused then finish();return end
            time=time+math.max(0,math.min(dt,.1));if time>=2.7 then finish() end
        end
    end
    return view
end
return V
