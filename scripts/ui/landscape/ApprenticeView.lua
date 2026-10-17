local UI=require "urhox-libs/UI"
local A=require "ui.landscape.JourneyArt"
local Text=require "ui.landscape.ApprenticeText"
local Pointer=require "ui.landscape.EpiloguePointer"
local V={}
function V.Narration(ctx,ending,review)
    local text=Text.Read(ending.text)
    return require("ui.landscape.DepartureView").New(ctx,ending,review,{room=true,pages=text.pages,
        heading="学徒",subtitle=ending.title:gsub("^.-｜",""),music=ctx.SetApprenticeMusic})
end
function V.New(ctx,options)
    local view=A.New(ctx,options.ending and "endingView" or "epilogueView",false)
    view.room=true
    local replay=options.ending~=nil
    local definition=options.ending or ctx.content.releaseEndings.apprentice
    local text=definition.text
    if not replay then
        local p=ctx.session.queries.GetReleaseProgress()
        if p.ok and p.value.completedCount==p.value.requiredCount and p.value.threeStarCount==p.value.requiredCount
            and definition.allThreeStarText then text=text.."\n\n"..definition.allThreeStarText end
    end
    local prose=Text.Read(text)
    local phase=options.step=="letter" and "open" or "intro"
    local age=0
    local leaving=false --[[@as boolean]]
    local focused=true --[[@as boolean]]
    local post=false --[[@as table|false]]
    local vp=ctx.viewport or {w=1280,h=720}
    local safe=ctx.safeInsets or {left=0,top=0,right=0,bottom=0}
    local sw,sh=vp.w-safe.left-safe.right,vp.h-safe.top-safe.bottom
    local revision=ctx.model.Refresh().revision
    local shade=UI.Panel {id="apprenticeRoomFade",position="absolute",left=0,top=0,width="100%",height="100%",
        backgroundColor={16,11,8,255},pointerEvents="none",zIndex=3}
    view.root:AddChild(shade)
    local intro=UI.Panel {id="continueEpilogue",position="absolute",left=0,top=0,width="100%",height="100%",zIndex=10}
    view.root:AddChild(intro)
    intro:AddChild(UI.Panel {position="absolute",left=0,bottom=0,width="100%",height=math.max(160,sh*.32)+safe.bottom,
        backgroundGradient={type="linear",direction="to-bottom",from={0,0,0,0},to={0,0,0,218}},pointerEvents="none"})
    A.Label(intro,prose.intro,"apprenticeIntro",sh<480 and 18 or 20,{position="absolute",left=safe.left+sw*.065,
        bottom=safe.bottom+54,width=sw*.87,height=math.max(90,sh*.18),lineHeight=1.55,fontColor={244,238,227,255}})
    local cue=A.Label(intro,"轻点继续",nil,12,{position="absolute",right=safe.right+sw*.065,bottom=safe.bottom+12,
        height=24,fontColor={211,188,150,0},whiteSpace="nowrap"})
    local function ready() return view.Live() and focused and not leaving and phase=="intro" and age>=.95 end
    local cancelIntro=Pointer.Bind(intro,ready,function()
        if replay then phase="open";age=0
        elseif ctx.model.AdvanceEpilogue("dawn",revision).ok then leaving=true end
    end)
    local letter=require("ui.landscape.ApprenticeLetter").New(ctx,view.root,prose.letter,function() end)
    local cancelCollect=Pointer.Bind(letter.button,function()
        return view.Live() and focused and not leaving and phase=="letter"
    end,function()
        if not replay then
            if not ctx.model.ConfirmEnding("apprentice",revision).ok then return end
            ctx.endingEntrance="apprentice"
        end
        phase="close";age=0;view.busy=true
        if ctx.PlayObjectSound then ctx.PlayObjectSound("ui_confirm") end
    end,true)
    local function sync()
        intro:SetVisible(phase=="intro")
        letter.root:SetVisible(phase=="open" or phase=="letter" or phase=="close")
        letter.button:SetDisabled(phase~="letter")
        cue.props.fontColor={211,188,150,ready() and 220 or 0}
        local t=math.min(1,age/(phase=="close" and .35 or .65));local a=t*t*(3-2*t)
        shade.props.backgroundColor={16,11,8,phase=="intro" and math.floor(255*(1-a)) or 0}
        intro.props.opacity=a
        letter.root.props.opacity=phase=="open" and a or phase=="close" and 1-a or 1
        letter.sheet.props.scale=phase=="open" and .94+.06*a or phase=="close" and 1-.04*a or 1
        view.busy=phase=="open" or phase=="close" or (phase=="intro" and age<.95)
        if ctx.SetApprenticeMusic then ctx.SetApprenticeMusic(1) end
    end
    function view.Update(dt,hasFocus)
        if not view.Live() then return end
        focused=hasFocus;if not focused then cancelIntro();cancelCollect() end
        if post then post.Update(dt,hasFocus);view.busy=post.busy;return end
        if hasFocus then age=age+math.max(0,math.min(.1,dt)) end
        if phase=="open" and age>=.9 then phase="letter";age=0 end
        if phase=="close" and age>=.35 then
            if replay then
                phase="post";sync()
                for _,child in ipairs(view.root.children) do child:SetVisible(false) end
                post=V.Narration(ctx,options.ending,options.review)
                view.root:AddChild(post.root);post.root.props.zIndex=20;view.busy=post.busy
            else leaving=true;view.busy=false end
            return
        end
        if not leaving then sync() end
    end
    function view.Destroy()
        if view.dead then return end
        cancelIntro();cancelCollect();view.dead=true;view.busy=false
        if post then post.Destroy() end
        if ctx.SetApprenticeMusic then ctx.SetApprenticeMusic(nil) end
    end
    sync();return view
end
return V
