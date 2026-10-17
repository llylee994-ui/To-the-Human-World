-- Special-bottle narration; existing backend epilogue steps remain the save boundaries.
local UI=require "urhox-libs/UI"
local A=require "ui.landscape.JourneyArt"
local Pointer=require "ui.landscape.EpiloguePointer"
local Story=require "ui.landscape.StoryStyle"
local M=require "ui.landscape.SeasideManifest"
local Geometry=require "ui.landscape.LayoutGeometry"
local Salvage=require "ui.landscape.SalvageController"
local V={}
V.pages={
    "瓶子里的信没有署名，也没有地址。纸上只有一句：“我想……”",
    "看着眼熟的字迹，你突然想起，自己的愿望是什么。",
    "把这封信补全吧。把你的愿望拼贴到信纸上，再送回大海。",
    "以后也许会有人看见它，知晓这是某人的一个心愿。",
}
function V.New(ctx,ep)
    local view=A.New(ctx,"epilogueView","dock")
    local vp=ctx.viewport or {w=1280,h=720};local safe=ctx.safeInsets or {left=0,top=0,right=0,bottom=0}
    local sw,sh=vp.w-safe.left-safe.right,vp.h-safe.top-safe.bottom
    local age,index,focused,leaving=0,1,true,false
    local revision=ctx.model.Refresh().revision
    local anim=Salvage.New();local time=0
    if ep.step=="bottle" then anim.letterInstanceId="epilogue-bottle" end
    local art=UI.Panel {id="epilogueBottleArt",position="absolute",left=0,top=0,width="100%",height="100%",pointerEvents="none"}
    view.root:AddChild(art)
    local function fit() return Geometry.SceneFit(view.root:GetAbsoluteLayout(),M) end
    function art:Render(vg)
        if ep.step=="dawn" then return end
        local f=fit();local p=anim.Pose();local bob=anim.letterInstanceId and 0 or math.sin(time*1.6)*12
        nvgSave(vg);nvgTranslate(vg,f.x,f.y);nvgScale(vg,f.scale,f.scale)
        A.Sprite(vg,M.bottle.path,p.bottleX,p.bottleY+bob,M.bottle.width*p.bottleScale,M.bottle.height*p.bottleScale,0,1)
        if ep.step=="shore" then A.Sprite(vg,M.net.path,p.netX,p.netY,M.net.width,M.net.height,p.netAngle,1) end
        nvgRestore(vg)
    end
    local text=ep.step=="dawn" and "结束了一天的忙碌，你又来到海边。海面上漂着一只瓶子，看起来和往常有些不同。"
        or ep.step=="shore" and "你把捞网伸向那只瓶子。" or V.pages[1]
    local gradient=UI.Panel {position="absolute",left=0,bottom=0,width="100%",height=sh*.36+safe.bottom,
        backgroundGradient={type="linear",direction="to-bottom",from={0,0,0,0},to={0,0,0,225}},pointerEvents="none"}
    view.root:AddChild(gradient)
    local label=A.Label(view.root,text,"wishPreludeText",sh<480 and 18 or 20,{position="absolute",left=safe.left+sw*.065,
        bottom=safe.bottom+68,width=sw*.87,height=math.max(75,sh*.17),lineHeight=1.6,fontColor={244,238,227,255}})
    local cue=A.Label(view.root,"轻点继续","wishPreludeHint",12,{position="absolute",right=safe.right+sw*.065,bottom=safe.bottom+20,
        height=24,fontColor={211,188,150,255},whiteSpace="nowrap"})
    local tap=UI.Panel {id=ep.step=="dawn" and "continueEpilogue" or "openEpilogueBottle",position="absolute",left=0,top=0,
        width="100%",height="100%",visible=ep.step~="shore",zIndex=15}
    view.root:AddChild(tap)
    local cancel=Pointer.Bind(tap,function() return view.Live() and focused and not leaving and age>=.7 end,function()
        if ep.step=="dawn" then
            if ctx.model.AdvanceEpilogue("dawn",revision).ok then leaving=true end
        elseif index<#V.pages then index=index+1;label:SetText(V.pages[index]);age=0
        elseif ctx.model.BeginWish().ok then leaving=true end
    end)
    local catch --[[@as Button]]
    catch=Story.Button {id="catchEpilogueBottle",text="捞起瓶子",position="absolute",left=safe.left+(sw-220)/2,bottom=safe.bottom+20,
        width=220,height=50,fontSize=18,visible=ep.step=="shore",onClick=function()
            if not view.Live() or view.busy or leaving or not focused then return end
            if ctx.model.AdvanceEpilogue("shore",revision).ok then
                anim.Begin("epilogue-bottle",fit(),time);view.busy=true;catch:SetVisible(false)
            end
        end}
    view.root:AddChild(catch)
    function view.Update(dt,hasFocus)
        if not view.Live() then return end
        focused=hasFocus;if not focused then cancel() end
        if focused then age=age+math.max(0,math.min(.1,dt));time=time+math.max(0,math.min(.1,dt)) end
        label.props.opacity=math.min(1,age/.45)
        cue.props.opacity=age>=.7 and 1 or 0
        cue:SetText(ep.step=="bottle" and index==#V.pages and "轻点展开信纸" or "轻点继续")
        cue:SetVisible(ep.step~="shore")
        if anim.active then
            if anim.Update(dt,fit(),focused,time) then view.busy=false;ctx.model.dirty=true end
        end
    end
    function view.Destroy() cancel();view.dead=true;view.busy=false end
    return view
end
return V
