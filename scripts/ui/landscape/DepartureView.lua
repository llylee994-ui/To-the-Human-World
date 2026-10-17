local UI=require "urhox-libs/UI"
local A=require "ui.landscape.JourneyArt"
local Sequence=require "ui.landscape.DepartureSequence"
local V={}
local function primary(event)
    if not event then return true end
    if event.IsPrimaryAction then return event:IsPrimaryAction() end
    return event.button==nil or event.button==MOUSEB_LEFT
end
-- The app root already spans the full screen; safe insets must not move its center axis.
function V.Layout(vp,safe)
    local width=math.min(260,math.max(44,vp.w-2*math.max(safe.left,safe.right)-24))
    return {heading={x=0,y=vp.h*.40,w=vp.w,h=64},subtitle={x=0,y=vp.h*.50,w=vp.w,h=44},
        button={x=(vp.w-width)/2,y=math.max(safe.top,math.min(vp.h*.68,vp.h-safe.bottom-64)),w=width,h=64}}
end
function V.New(ctx,ending,review,presentation)
    presentation=presentation or {}
    local view=A.New(ctx,"endingView",false)
    view.room=presentation.room
    local music=presentation.music or ctx.SetDepartureMusic
    local vp=ctx.viewport or {w=1280,h=720}
    local safe=ctx.safeInsets or {left=0,top=0,right=0,bottom=0}
    local layout=V.Layout(vp,safe)
    local sw=math.max(1,vp.w-safe.left-safe.right)
    local sh=math.max(1,vp.h-safe.top-safe.bottom)
    local pages=presentation.pages or Sequence.Pages(ending.text)
    local seq=Sequence.New(#pages,presentation.room and 0 or 1)
    view.sequence=seq;view.pages=pages;view.busy=true
    local bw,bh=presentation.backgroundWidth or 1672,presentation.backgroundHeight or 941
    local artScale=math.max(vp.w/bw,vp.h/bh)
    local art=not presentation.room and A.Image(view.root,presentation.background or "image/departure-ending-r1/background.png",{id="departureBackdrop",backgroundFit="fill",zIndex=3,
        left=(vp.w-bw*artScale)/2,top=(vp.h-bh*artScale)/2,width=bw*artScale,height=bh*artScale})
    local gradient=UI.Panel {id="departureTextBackdrop",position="absolute",left=0,bottom=0,width="100%",
        height=math.max(160,sh*.32)+safe.bottom,pointerEvents="none",zIndex=4,
        backgroundGradient={type="linear",direction="to-bottom",from={0,0,0,0},to={0,0,0,218}}}
    view.root:AddChild(gradient)
    local shade=UI.Panel {id="departureDim",position="absolute",left=0,top=0,width="100%",height="100%",
        backgroundColor={7,11,17,255},pointerEvents="none",zIndex=5}
    view.root:AddChild(shade)
    local armed=false --[[@as boolean]]
    local armedIndex=0
    local pointer=false --[[@as number|false]]
    local released=false --[[@as boolean]]
    local px,py=0,0
    local focused=true --[[@as boolean]]
    local function cancel() armed=false;pointer=false;released=false end
    local function owns(event) return pointer~=false and pointer==(event and event.pointerId or 0) end
    local function down(event)
        if not view.Live() or not focused or not primary(event) then return end
        -- The adapter's primary flag is reliable at touch-down; later touch-up
        -- flags can differ, so retain ownership of this accepted pointer.
        if event and event.isPrimary==false then return end
        if pointer~=false and not released then return end
        armed=seq.CanAdvance();armedIndex=seq.index
        pointer=event and event.pointerId or 0
        released=false
        px,py=event and event.x or 0,event and event.y or 0
    end
    local function cancelPointer(event) if owns(event) then cancel() end end
    local function move(event)
        if owns(event) and (math.abs((event.x or 0)-px)+math.abs((event.y or 0)-py))>8 then armed=false end
    end
    local tap=UI.Panel {id="departureAdvance",position="absolute",left=0,top=0,width="100%",height="100%",zIndex=10,
        onPointerDown=down,
        onPointerUp=function(event) if owns(event) then released=true end end,
        onPointerCancel=cancelPointer,onPointerMove=move,
        onClick=function(_,event)
            if event and event.StopPropagation then event:StopPropagation() end
            if not owns(event) then return end
            local allowed=armed and view.Live() and focused and primary(event) and armedIndex==seq.index
            cancel()
            if allowed and seq.Advance() then view.busy=true end
        end}
    view.root:AddChild(tap)
    local textHeight=math.max(122,sh*.28)-42
    local scroll=UI.ScrollView {id="departureNarrationScroll",position="absolute",left=safe.left+sw*.065,
        bottom=safe.bottom+46,width=sw*.87,height=textHeight,scrollY=true,showScrollbar=false,pointerEvents="auto",
        onPointerCancel=cancelPointer}
    -- ScrollView consumes moves and cancellation instead of bubbling them.
    local scrollMove=scroll.OnPointerMove
    function scroll:OnPointerMove(event)
        move(event)
        if scrollMove then return scrollMove(self,event) end
    end
    tap:AddChild(scroll)
    local body=UI.Panel {width="100%",flexShrink=0,pointerEvents="box-none"}
    scroll:AddChild(body)
    local label=A.Label(body,pages[1],"releaseEndingText",sh<480 and 18 or 20,
        {width="100%",lineHeight=1.55,fontColor={244,238,227,0}})
    local cue=A.Label(tap,"轻点继续","departureContinueHint",12,{position="absolute",right=safe.right+sw*.065,
        bottom=safe.bottom+12,height=24,fontColor={211,188,150,0},whiteSpace="nowrap"})
    local heading=A.Label(view.root,presentation.heading or "旅人","releaseEndingTitle",32,{position="absolute",left=layout.heading.x,top=layout.heading.y,
        width=layout.heading.w,height=64,textAlign="center",lineHeight=1.2,fontColor={246,233,208,0},zIndex=12})
    local subtitle=A.Label(view.root,presentation.subtitle or ending.title:gsub("^.-｜",""),"departureSubtitle",20,{position="absolute",
        left=layout.subtitle.x,top=layout.subtitle.y,width=layout.subtitle.w,height=44,textAlign="center",lineHeight=1.2,fontColor={246,233,208,0},zIndex=12})
    local button=A.Button(view.root,review and "backToMemories" or "endGame",review and "返回留念" or "返回首页",function()
        if not view.Live() or not seq.done then return end
        if review then ctx.panel="memories";ctx.model.dirty=true else ctx.ShowTitle() end
    end,false,{position="absolute",left=layout.button.x,top=layout.button.y,width=layout.button.w,height=layout.button.h,
        fontSize=22,minHeight=48,padding=0,pressedPadding=0,visible=false,zIndex=13,
        backgroundColor={0,0,0,0},hoverBackgroundColor={232,200,143,15},pressedBackgroundColor={232,200,143,30},
        textColor={246,233,208,255},borderWidth=0,borderRadius=0})
    for _,edge in ipairs({"left","right"}) do
        local props={position="absolute",top=32,width=44,height=1,backgroundColor={193,146,75,230},pointerEvents="none"}
        props[edge]=0;button:AddChild(UI.Panel(props))
    end
    button:AddChild(UI.Panel {position="absolute",left=layout.button.w/2-5,top=-6,width=10,height=10,rotate=45,
        borderWidth=1,borderColor={211,165,89,255},backgroundColor={0,0,0,0},pointerEvents="none"})
    local shownIndex=1
    local function sync()
        view.busy=seq.phase~="read" and not seq.done
        if shownIndex~=seq.index then
            shownIndex=seq.index;label:SetText(pages[shownIndex]);scroll:ScrollToTop()
        end
        -- Render-only properties: avoid invalidating Yoga on every animation frame.
        label.props.fontColor={244,238,227,math.floor(255*seq.textAlpha)}
        cue.props.fontColor={211,188,150,seq.CanAdvance() and 220 or 0}
        shade.props.backgroundColor={7,11,17,math.floor(255*seq.darkAlpha)}
        local color={246,233,208,math.floor(255*seq.titleAlpha)}
        heading.props.fontColor=color;subtitle.props.fontColor=color
        button:SetVisible(seq.done)
        if art then art.props.scale=1.012+.008*math.min(1,seq.total/120) end
        if music then music(seq.musicGain) end
    end
    function view.Update(dt,hasFocus)
        if not view.Live() then return end
        focused=hasFocus
        if not focused then cancel() end
        seq.Update(dt,hasFocus);sync()
    end
    function view.Destroy()
        if view.dead then return end
        cancel();seq.Destroy();view.dead=true;view.busy=false
        if music then music(nil) end
    end
    sync()
    return view
end
return V
