local UI=require "urhox-libs/UI"
local A=require "ui.landscape.JourneyArt"
local M=require "ui.landscape.SeasideManifest"
local Geometry=require "ui.landscape.LayoutGeometry"
local Salvage=require "ui.landscape.SalvageController"
local Responsive=require "ui.landscape.Responsive"
local V={}
function V.New(ctx)
    local result=ctx.session.queries.GetEpilogueView()
    local ep=result.ok and result.value or {step="prepare",route=false}
    if result.ok and ep.route=="apprentice" and (ep.step=="dawn" or ep.step=="letter") then
        return require("ui.landscape.ApprenticeView").New(ctx,{step=ep.step})
    end
    if result.ok and not ep.needsStoryCompletion and ep.route=="wish" and ep.step~="prepare" then
        return require("ui.landscape.WishPrelude").New(ctx,ep)
    end
    local seaside=ep.route=="wish" and ep.step~="dawn" and ep.step~="prepare"
    local view=A.New(ctx,"epilogueView",seaside and "dock" or false);local r=view.rect
    local m=Responsive.Metrics(ctx.viewport,ctx.safeInsets)
    local function paperProps()
        if m.short then return {position="absolute",left=m.x+8,top=m.y+8,width=m.w-16,
            padding=16,gap=8,backgroundColor=A.cream} end
        return {position="absolute",left="22%",top="20%",width="56%",padding=40,gap=18}
    end
    local revision=ctx.model.Refresh().revision
    local function click(fn) return function() if view.Live() and not view.busy then fn() end end end
    local footer=UI.Panel {position="absolute",left=r.x,right=r.x,bottom=20+((ctx.safeInsets or {}).bottom or 0),
        height=48,flexDirection="row",gap=12,justifyContent="center",pointerEvents="box-none",zIndex=10}
    view.root:AddChild(footer)
    if not result.ok then ctx.model.Notify(result);return view end
    if ep.needsStoryCompletion then
        local p=A.Paper(view.root,paperProps())
        A.Label(p,"还有来信，等你寄出。",nil,25)
        A.Button(p,"restoreBeforeClosing","回到旅程中",click(function() ctx.model.RestoreEndingCheckpoint() end),true)
        return view
    end
    if ep.step=="prepare" then
        local p=A.Paper(view.root,paperProps())
        A.Label(p,"留下一些词语",nil,26)
        A.Label(p,"打开收好的来信，剪下一个词。",nil,18)
        A.Button(p,"prepareWishLetter","打开来信",click(function()
            local w=ctx.session.queries.GetWishView();if not w.ok then ctx.model.Notify(w);return end
            local prep=w.value.preparation;local id=prep.letterInstanceId
            if prep.needsReceive then local received=ctx.model.Receive(prep.letterId);if not received.ok then return end;id=received.value.letterInstanceId end
            ctx.Read(id,true)
        end),true)
    elseif ep.step=="dawn" then
        local p=A.Paper(view.root,m.short and {position="absolute",left=m.x+8,top=m.y+8,width=m.w-16,
            height=m.h-88,padding=16,justifyContent="center",alignItems="center",gap=6,backgroundColor=A.cream}
            or {position="absolute",left=r.x+r.w*.23,top=r.y+r.h*.23,width=r.w*.54,height=r.h*.44,
            padding=32,justifyContent="center",alignItems="center",gap=18})
        A.Label(p,"尾  声","epilogueChapter",14,{fontColor=A.muted})
        A.Label(p,ep.route=="apprentice" and "一封捎来的信" or "一只空白的瓶子","epilogueTitle",m.short and 24 or 32,{textAlign="center"})
        A.Label(p,ep.route=="apprentice" and "商人带来了一封信。" or "海边，又有一只瓶子靠了岸。",nil,17,{textAlign="center"})
        A.Button(footer,"continueEpilogue",ep.route=="apprentice" and "拆开来信" or "去海边",click(function() ctx.model.AdvanceEpilogue("dawn",revision) end),true,{minWidth=200})
    else
        local anim=Salvage.New();local time=0
        if ep.step=="bottle" then anim.letterInstanceId="epilogue-bottle" end
        local art=UI.Panel {id="epilogueBottleArt",position="absolute",left=0,top=0,width="100%",height="100%",pointerEvents="none"}
        view.root:AddChild(art)
        local function fit() return Geometry.SceneFit(view.root:GetAbsoluteLayout(),M) end
        function art:Render(vg)
            local f=fit();local p=anim.Pose();local bob=anim.letterInstanceId and 0 or math.sin(time*1.6)*12
            nvgSave(vg);nvgTranslate(vg,f.x,f.y);nvgScale(vg,f.scale,f.scale)
            A.Sprite(vg,M.ship.path,M.ship.x,M.ship.y+math.sin(time)*8,M.ship.width,M.ship.height,0,1)
            A.Sprite(vg,M.bottle.path,p.bottleX,p.bottleY+bob,M.bottle.width*p.bottleScale,M.bottle.height*p.bottleScale,0,1)
            A.Sprite(vg,M.net.path,p.netX,p.netY,M.net.width,M.net.height,p.netAngle,p.netOpacity)
            nvgRestore(vg)
        end
        local caption=A.Paper(view.root,{position="absolute",left=r.x+12,top=r.y+20,width=300,padding=28,gap=10})
        A.Label(caption,"海边 · 最后一只瓶子",nil,22)
        A.Label(caption,ep.step=="shore" and "照往常那样，撒下网。" or "这一次，纸上留给了你。",nil,17)
        local fish,skip
        fish=A.Button(footer,"catchEpilogueBottle","捞起瓶子",click(function()
            if ctx.model.AdvanceEpilogue("shore",revision).ok then
                view.busy=true;anim.Begin("epilogue-bottle",fit(),time)
                fish:SetVisible(false);skip:SetVisible(true)
            end
        end),true,{minWidth=200,visible=ep.step=="shore"})
        A.Button(footer,"openEpilogueBottle","打开瓶子",click(function() ctx.model.BeginWish() end),true,{minWidth=200,visible=ep.step=="bottle"})
        skip=A.Button(footer,"skipEpilogueSalvage","跳过打捞",function()
            if view.Live() and view.busy then anim.Skip();view.busy=false;ctx.model.dirty=true end
        end,false,{visible=false})
        function view.Update(dt,focused)
            time=time+math.max(0,math.min(dt,.1))
            if anim.active then
                local done=anim.Update(dt,fit(),focused,time)
                if done then view.busy=false;ctx.model.dirty=true end
            end
        end
    end
    A.Button(footer,"epilogueToTitle","回到首页",click(ctx.ShowTitle),false)
    return view
end
return V
