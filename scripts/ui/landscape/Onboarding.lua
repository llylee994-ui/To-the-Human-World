-- 新手引导表现层：只读业务快照，按真实命令成功推进；不重复发送事务。
local UI=require "urhox-libs/UI"
local Widget=require "urhox-libs/UI/Core/Widget"
local EventBus=require "core.EventBus"
local Geometry=require "ui.landscape.LayoutGeometry"
local U=require "core.StateUtil"
local Harbor=require "ui.landscape.HarborStyle"
local O={}

local NOTE={
    "这里是一间在人间之外的魔药铺。",
    "",
    "你因一个尚未完成的愿望来到这里。",
    "",
    "海上漂来的瓶子，装着人间某个人的心事。把它们捞起来，读过信，剪下能用的词语，配上原料熬成魔药，再照着地址寄回人间。",
    "",
    "网兜挂在门边。先去看看吧。",
}
local STEPS={
    ["intro.paper"]={target="home.letterPaper",text="桌上留着一张便签。"},
    ["intro.note"]={note=true},
    ["home.net"]={target="home.net",text="先去海边看看。"},
    ["sea.salvage"]={target="startSalvage",text="捞起这个漂流瓶。"},
    ["sea.read"]={target="readCapturedLetter",text="看看瓶子里写了什么。"},
    ["letter.cut"]={target="letterPaper",text="点亮起的词语，把它剪下来。"},
    ["letter.accept"]={target="acceptOrder",text="准备好了，就接下这份委托。"},
    ["brew.word"]={target="brewWordPanel",fallback="brewWordsHost",text="从信里剪下的词，都收在这里。选一张，拖进锅里。"},
    ["brew.book"]={target="brewBookPanel",fallback="brewJournalHost",text="这里记着人物的来信和已经发生的后续。需要时可以翻看。",know=true,next="brew.ingredient"},
    ["brew.ingredient"]={target="brewShelf",text="原料会改变这一锅的药性。选一种，拖进锅里。"},
    ["brew.conditions"]={target="brewRecipeDetails",text="看看委托需要什么，以及这一锅的药性。"},
    ["brew.ready"]={target="previewOrder",text="条件满足时，就可以开始熬制。"},
    ["result.explain"]={target="resultActions",text="可以确认寄出，或返回调整后再试。",know=true,next="complete"},
    ["complete"]={target="confirmOrder",text="确认寄出第一份魔药。"},
}

local function snapshot(session)
    return session.state.GetSnapshot()
end
local function currentOrder(data)
    return data and data.currentOrder or false
end
local function draftOf(data)
    local order=currentOrder(data)
    return order and order.draft or nil
end
local function hasMain(data)
    local draft=draftOf(data)
    return draft and draft.mainTokenId~=false and draft.mainTokenId~=nil
end
local function hasIngredient(data)
    local draft=draftOf(data)
    return draft and type(draft.ingredients)=="table" and #draft.ingredients>0
end
local function hasCut(data,letterId)
    if not data or not data.live then return false end
    if letterId and data.live.letters.byId["letter:"..letterId] then
        local item=data.live.letters.byId["letter:"..letterId]
        return next(item.cutSpans)~=nil
    end
    for _,item in pairs(data.live.letters.byId) do if next(item.cutSpans) then return true end end
    return false
end
local function receivedLetter(data,letterId)
    if not data or not data.live then return nil end
    if letterId and data.live.letters.byId["letter:"..letterId] then return "letter:"..letterId end
    for id in pairs(data.live.letters.byId) do return id end
    return nil
end
local function deliveredCount(data)
    return data and data.live and data.live.gameFlow.deliveredOrders or 0
end

function O.New(ctx)
    local api={}
    local session=ctx.session
    local state=nil
    local active=false
    local step=nil
    local root,shade,tooltip,tooltipLabel,knowButton,skipButton,noteLayer,noteButton,completeLayer
    local blockers={}
    local interceptor
    local targetRect=nil
    local conditionsOpened=false
    local noteOnly=false
    local noteWasRead=false
    local hintsBefore=false
    local pendingAdvance=nil
    local retryAt=0
    local syncedStep=nil
    local syncAt=0
    local completionUntil=0
    local listeners={}
    local destroyed=false
    local lastRect={}
    local deliveredDuringStep=false
    local paused=false
    local persist,tryPending,requestAdvance,finish,skip

    local function now()
        local get=rawget(_G,"GetTime")
        if not get then return 0 end
        local t=get()
        return t and t:GetElapsedTime() or 0
    end
    local function setRect(widget,x,y,w,h)
        if not widget then return end
        local p=widget.props
        local key=widget
        local old=lastRect[key]
        if old and old.x==x and old.y==y and old.w==w and old.h==h then return end
        lastRect[key]={x=x,y=y,w=w,h=h}
        Widget.SetStyle(widget,{left=x,top=y,width=w,height=h})
    end
    local function viewport()
        return ctx.viewport or {w=(graphics and graphics.width) or 1280,h=(graphics and graphics.height) or 720}
    end
    local function presentationPaused()
        if ctx.portrait then return true end
        if ctx.settings and ctx.settings.IsOpen and ctx.settings:IsOpen() then return true end
        if ctx.IsInputActive and not ctx.IsInputActive() then return true end
        return false
    end
    local function flightBusy()
        local brew=ctx.brew
        local flight=brew and brew.interaction and brew.interaction.flight
        return flight and flight.accepted==true
    end
    local function safe()
        return ctx.safeInsets or {left=0,top=0,right=0,bottom=0}
    end
    local function setVisible(value)
        active=value
        if root then root:SetVisible(value) end
        if not value then targetRect=nil end
    end
    local function ensureRoot()
        if root then return end
        root=UI.Panel {id="onboardingRoot",position="absolute",left=0,top=0,width="100%",height="100%",
            zIndex=1800,pointerEvents="box-none",visible=false}
        shade=UI.Panel {id="onboardingShade",position="absolute",left=0,top=0,width="100%",height="100%",
            pointerEvents="none"}
        function shade:Render(vg)
            local b=self:GetAbsoluteLayout()
            if b.w<=0 or b.h<=0 then return end
            local hole=targetRect
            local color={11,8,5,158}
            local function rect(x,y,w,h)
                if w<=0 or h<=0 then return end
                nvgBeginPath(vg);nvgRect(vg,x,y,w,h)
                nvgFillColor(vg,nvgRGBA(color[1],color[2],color[3],color[4]));nvgFill(vg)
            end
            if hole then
                rect(b.x,b.y,b.w,math.max(0,hole.y-b.y))
                rect(b.x,hole.y+hole.h,b.w,math.max(0,b.y+b.h-hole.y-hole.h))
                rect(b.x,hole.y,math.max(0,hole.x-b.x),hole.h)
                rect(hole.x+hole.w,hole.y,math.max(0,b.x+b.w-hole.x-hole.w),hole.h)
                nvgBeginPath(vg)
                nvgRoundedRect(vg,hole.x-4,hole.y-4,hole.w+8,hole.h+8,8)
                nvgStrokeColor(vg,nvgRGBA(236,201,133,220));nvgStrokeWidth(vg,2);nvgStroke(vg)
            else
                rect(b.x,b.y,b.w,b.h)
            end
        end
        root:AddChild(shade)
        local names={"top","bottom","left","right"}
        for _,name in ipairs(names) do
            local blocker=UI.Panel {id="onboardingBlocker_"..name,position="absolute",left=0,top=0,width=0,height=0,
                pointerEvents="box-only",onClick=function() end,onPointerDown=function() end}
            blockers[name]=blocker;root:AddChild(blocker)
        end
        interceptor=UI.Panel {id="onboardingTarget",position="absolute",left=0,top=0,width=0,height=0,zIndex=2,
            pointerEvents="box-only",visible=false,onClick=function() requestAdvance("intro.note") end}
        root:AddChild(interceptor)
        tooltip=UI.Panel {id="onboardingTooltip",position="absolute",left=0,top=0,width=320,zIndex=10,
            backgroundColor={246,236,207,248},borderWidth=1,borderColor={174,140,86,220},borderRadius=6,
            padding=14,gap=8,boxShadow={x=0,y=3,blur=8,color={0,0,0,90}},pointerEvents="box-only",onClick=function() end}
        tooltipLabel=UI.Label {id="onboardingText",text="",fontFamily="story",fontSize=15,lineHeight=1.45,
            whiteSpace="normal",fontColor={55,43,30,255},width="100%",pointerEvents="none"}
        tooltip:AddChild(tooltipLabel)
        knowButton=UI.Button {id="onboardingKnow",text="知道了",minHeight=40,height=40,fontSize=14,
            fontFamily="story",backgroundColor={174,129,65,255},textColor={32,26,18,255},borderRadius=5,
            visible=false,onClick=function() if pendingAdvance==nil and step and STEPS[step] and STEPS[step].next then
                requestAdvance(STEPS[step].next) end end}
        tooltip:AddChild(knowButton)
        root:AddChild(tooltip)
        skipButton=UI.Button {id="onboardingSkip",text="跳过引导",position="absolute",right=12,top=12,width=104,
            height=40,minHeight=40,fontSize=13,fontFamily="story",backgroundColor={33,26,19,190},
            textColor={235,220,190,255},borderColor={174,140,86,180},borderWidth=1,borderRadius=5,zIndex=50,
            onClick=function() skip() end}
        root:AddChild(skipButton)
        noteLayer=UI.Panel {id="onboardingNoteLayer",position="absolute",left=0,top=0,width="100%",height="100%",
            backgroundColor={8,6,4,190},pointerEvents="box-only",visible=false,onClick=function() end,zIndex=20}
        local note=Harbor.Paper {id="onboardingNote",position="absolute",left="18%",right="18%",top="12%",bottom="12%",
            padding=30,gap=12,pointerEvents="box-only"}
        note:AddChild(UI.Label {text="一张没有署名的便签",fontFamily="story-strong",fontSize=20,
            fontColor={62,48,33,255},textAlign="center",lineHeight=1.3,pointerEvents="none"})
        local scroll=UI.ScrollView {id="onboardingNoteScroll",width="100%",flexGrow=1,flexShrink=1,flexBasis=0,
            scrollY=true,showScrollbar=true,paddingRight=12}
        local body=UI.Panel {width="100%",flexShrink=0,gap=8,pointerEvents="box-none"}
        for _,line in ipairs(NOTE) do
            body:AddChild(UI.Label {text=line,fontFamily="story",fontSize=16,lineHeight=1.7,whiteSpace="normal",
                width="100%",fontColor={62,48,33,255},pointerEvents="none"})
        end
        scroll:AddChild(body);note:AddChild(scroll)
        noteButton=UI.Button {id="onboardingNoteDone",text="收好便签",minHeight=46,height=46,fontSize=16,
            fontFamily="story",backgroundColor={174,129,65,255},textColor={32,26,18,255},borderRadius=6,
            onClick=function()
                if noteOnly then
                    noteOnly=false
                    paused=false
                    if noteLayer then noteLayer:SetVisible(false) end
                    setVisible(false)
                    return
                end
                noteWasRead=true
                if noteLayer then noteLayer:SetVisible(false) end
                requestAdvance("home.net")
            end}
        note:AddChild(noteButton)
        noteLayer:AddChild(note);root:AddChild(noteLayer)
        completeLayer=UI.Panel {id="onboardingComplete",position="absolute",left=0,top=0,width="100%",height="100%",
            backgroundColor={8,6,4,120},alignItems="center",justifyContent="center",visible=false,
            pointerEvents="box-only",zIndex=30,onClick=function() end}
        local done=Harbor.Paper {width="62%",maxWidth=560,padding=26,alignItems="center",gap=12}
        done:AddChild(UI.Label {text="第一份魔药已经寄出。",fontFamily="story-strong",fontSize=22,
            fontColor={62,48,33,255},textAlign="center",lineHeight=1.3,pointerEvents="none"})
        done:AddChild(UI.Label {text="药铺交给你了。",fontFamily="story",fontSize=17,fontColor={62,48,33,255},
            textAlign="center",lineHeight=1.5,pointerEvents="none"})
        completeLayer:AddChild(done);root:AddChild(completeLayer)
        ctx.root:AddChild(root)
    end
    local function readState()
        local data=snapshot(session)
        return data and data.onboarding or nil,data
    end
    local function finishLocal()
        setVisible(false)
        if noteLayer then noteLayer:SetVisible(false) end
        if completeLayer then completeLayer:SetVisible(false) end
        if ctx.home and ctx.home.ShowHints then ctx.home.ShowHints(hintsBefore) end
    end
    persist=function(nextState)
        local result=session.state.SetOnboarding(nextState)
        if result and result.ok then
            state=U.Copy(nextState)
            return true
        end
        local code=result and result.error and result.error.code
        if result and code~="STATE_LOCKED" and code~="COMMAND_BUSY" then ctx.model.Notify(result) end
        return false
    end
    tryPending=function()
        if not pendingAdvance or destroyed then return end
        local nextState=U.Copy(state)
        nextState.step=pendingAdvance
        nextState.noteRead=noteWasRead or nextState.noteRead
        if persist(nextState) then pendingAdvance=nil end
    end
    requestAdvance=function(nextStep)
        if not state or state.completed or state.skipped then return end
        if not STEPS[nextStep] then return end
        if pendingAdvance==nextStep then return end
        pendingAdvance=nextStep
        tryPending()
        retryAt=now()+0.1
    end
    finish=function()
        local nextState=U.Copy(state)
        nextState.completed=true;nextState.step="complete";nextState.noteRead=true
        if persist(nextState) then
            pendingAdvance=nil
            active=false
            if shade then shade:SetVisible(false) end
            for _,blocker in pairs(blockers) do blocker:SetVisible(false) end
            if interceptor then interceptor:SetVisible(false) end
            if tooltip then tooltip:SetVisible(false) end
            if skipButton then skipButton:SetVisible(false) end
            if noteLayer then noteLayer:SetVisible(false) end
            if completeLayer then completeLayer:SetVisible(true) end
            if root then root:SetVisible(true) end
            completionUntil=now()+3.2
            if ctx.home and ctx.home.ShowHints then ctx.home.ShowHints(hintsBefore) end
        end
    end
    skip=function()
        if not state or state.completed then return end
        local nextState=U.Copy(state)
        nextState.skipped=true;nextState.step="complete"
        persist(nextState)
        pendingAdvance=nil
        finishLocal()
    end
    local function targetWidget(id)
        if not id then return nil end
        local widget=ctx.root and ctx.root:FindById(id)
        if not widget or not widget.GetAbsoluteLayout then return nil end
        local r=widget:GetAbsoluteLayout()
        if not r or r.w<=0 or r.h<=0 then return nil end
        return {x=r.x,y=r.y,w=r.w,h=r.h}
    end
    local function visibleWidget(id)
        local widget=ctx.root and ctx.root:FindById(id)
        if not widget or widget.props.visible==false then return nil end
        return targetWidget(id)
    end
    local function homeRect(id)
        local home=ctx.home
        if not home or not home.manifest or not home.Fit or not home.root or not home.root.GetAbsoluteLayout then return nil end
        local manifest=home.manifest
        local object
        for _,row in ipairs(manifest.objects) do if row.id==id then object=row;break end end
        if not object then return nil end
        local layer=manifest.layers[object.layer]
        local region=object.regions[1]
        if not layer or not region then return nil end
        local fit=home.Fit()
        if not fit or fit.scale<=0 then return nil end
        local x,y=Geometry.ToScreen(layer,fit,region.cx,region.cy)
        local r=Geometry.ObjectRegion(layer,object,fit,1)
        local w,h=r.w*fit.scale,r.h*fit.scale
        return {x=x-w/2,y=y-h/2,w=w,h=h}
    end
    local function currentTarget()
        if not step then return nil end
        if step=="intro.paper" then return homeRect("home.letterPaper") end
        if step=="home.net" then return homeRect("home.net") end
        if step=="sea.read" then
            if ctx.panel=="letters" then
                local id=ctx.model and ctx.model.selectedLetter
                local rect
                if id then rect=targetWidget("read_"..id) end
                return rect or targetWidget("letterDrawerCards")
            end
            return visibleWidget("readCapturedLetter")
        end
        local def=STEPS[step]
        if not def then return nil end
        local rect=targetWidget(def.target)
        if not rect and def.fallback then rect=targetWidget(def.fallback) end
        return rect
    end
    local function applyStep(nextStep)
        step=nextStep
        if noteLayer then noteLayer:SetVisible(step=="intro.note") end
        if completeLayer then completeLayer:SetVisible(false) end
        if skipButton then skipButton:SetVisible(true) end
        if interceptor then interceptor:SetVisible(step=="intro.paper") end
        if tooltip then
            local def=STEPS[step]
            if def then
                tooltip:SetVisible(true)
                tooltipLabel:SetText(def.text or "")
                knowButton:SetVisible(def.know==true)
            else
                tooltip:SetVisible(false)
            end
        end
        conditionsOpened=false
        deliveredDuringStep=false
        syncedStep=nil
        targetRect=nil
    end
    local function syncScene()
        if not step then return end
        local t=now()
        if syncedStep==step and t-syncAt<1.0 then return end
        syncAt=t;syncedStep=step
        if ctx.atTitle then return end
        local data=snapshot(session)
        if step=="intro.paper" or step=="home.net" then
            if ctx.scene~="home" and not ctx.panel then ctx.Navigate("home") end
        elseif step=="sea.salvage" then
            if ctx.scene~="seaside" and not ctx.panel then ctx.Navigate("seaside") end
        elseif step=="sea.read" then
            if ctx.scene~="seaside" and not ctx.panel then ctx.Navigate("seaside") end
            if not visibleWidget("readCapturedLetter") and ctx.panel~="reader" and ctx.panel~="letters" then
                local id=ctx.model.selectedLetter
                if not id then
                    local first=receivedLetter(data)
                    if first then id=first end
                end
                if id then ctx.model.selectedLetter=id;ctx.Open("letters") end
            end
        elseif step=="letter.cut" or step=="letter.accept" then
            if ctx.panel~="reader" then
                local id=ctx.model.selectedLetter
                if not id then
                    local first=receivedLetter(data)
                    if first then id=first end
                end
                if id then ctx.Read(id,true) end
            end
        elseif step=="brew.word" or step=="brew.book" or step=="brew.ingredient" or step=="brew.conditions" or step=="brew.ready" then
            if ctx.scene~="brew" and not ctx.panel then ctx.Navigate("brew") end
        elseif step=="result.explain" or step=="complete" then
            if currentOrder(data) and ctx.panel~="result" and ctx.panel~="attempt" then ctx.Open("result") end
        end
    end
    local function syncProgress()
        if not step or pendingAdvance then return end
        local data=snapshot(session)
        if step=="home.net" and ctx.scene=="seaside" then requestAdvance("sea.salvage")
        elseif step=="sea.salvage" then
            local id=receivedLetter(data)
            if id and not ctx.salvage.active and (ctx.salvage.letterInstanceId or ctx.model.selectedLetter or id) then requestAdvance("sea.read") end
        elseif step=="sea.read" then
            local cache=ctx.readerCache
            local busy=cache and cache.presentation and (cache.presentation.motion.opening or cache.presentation.motion.flight)
            if ctx.panel=="reader" and not busy then requestAdvance("letter.cut") end
        elseif step=="letter.cut" then
            local cache=ctx.readerCache
            local busy=cache and cache.presentation and (cache.presentation.motion.opening or cache.presentation.motion.flight)
            if hasCut(data) and not busy then requestAdvance("letter.accept") end
        elseif step=="letter.accept" then
            if currentOrder(data) then requestAdvance("brew.word") end
        elseif step=="brew.word" then
            if hasMain(data) and not flightBusy() then requestAdvance("brew.book") end
        elseif step=="brew.ingredient" then
            if hasIngredient(data) and not flightBusy() then requestAdvance("brew.conditions") end
        elseif step=="brew.conditions" then
            local open=ctx.brew and ctx.brew.selected=="recipe"
            if open then conditionsOpened=true
            elseif conditionsOpened then requestAdvance("brew.ready") end
        elseif step=="brew.ready" then
            local order=currentOrder(data)
            if order and order.pending then requestAdvance("result.explain") end
        elseif step=="result.explain" then
            local order=currentOrder(data)
            if (not order or not order.pending) and ctx.panel~="result" then requestAdvance("brew.ready") end
        elseif step=="complete" then
            if deliveredDuringStep or (not currentOrder(data) and deliveredCount(data)>0) then finish()
            elseif currentOrder(data) and not currentOrder(data).pending then requestAdvance("brew.ready") end
        end
    end
    local function refreshState()
        if noteOnly then return end
        local data
        state,data=readState()
        noteWasRead=state and state.noteRead==true
        if not state or state.completed or state.skipped then
            if active then finishLocal() end
            return
        end
        if ctx.atTitle then
            if active then setVisible(false) end
            return
        end
        if not active then
            ensureRoot()
            if shade then shade:SetVisible(true) end
            for _,blocker in pairs(blockers) do blocker:SetVisible(true);lastRect[blocker]=nil end
            if tooltip then tooltip:SetVisible(true) end
            if skipButton then skipButton:SetVisible(true) end
            if completeLayer then completeLayer:SetVisible(false) end
            hintsBefore=ctx.home and ctx.home.HintsVisible and ctx.home.HintsVisible() or false
            if ctx.home and ctx.home.ShowHints then ctx.home.ShowHints(false) end
            setVisible(true)
        end
        if step~=state.step then applyStep(state.step) end
        if noteLayer and state.step=="intro.note" then noteLayer:SetVisible(true) end
        if state.step=="intro.paper" and interceptor then interceptor:SetVisible(true) end
    end
    local function listener(name,fn)
        listeners[#listeners+1]={name=name,id=EventBus.On(name,fn,0,"onboarding")}
    end
    listener("OrderAccepted",function()
        if step=="letter.accept" then requestAdvance("brew.word") end
    end)
    listener("DeliveryPreviewReady",function()
        if step=="brew.ready" then requestAdvance("result.explain") end
    end)
    listener("PotionDelivered",function()
        if step=="complete" or step=="result.explain" then deliveredDuringStep=true end
    end)
    function api.Update()
        if destroyed then return end
        local t=now()
        if noteOnly then
            if not noteLayer or noteLayer.props.visible==false then noteOnly=false;setVisible(false) end
            return
        end
        refreshState()
        if not active then
            if completeLayer and completionUntil>0 and t>=completionUntil then
                completionUntil=0;completeLayer:SetVisible(false)
                if root then root:SetVisible(false) end
            end
            return
        end
        local shouldPause=presentationPaused()
        if shouldPause~=paused then
            paused=shouldPause
            if paused then
                if root then root:SetVisible(false) end
                targetRect=nil
            else
                syncedStep=nil;syncAt=0;targetRect=nil;lastRect={}
                if root then root:SetVisible(true) end
                retryAt=now()+0.1
            end
        end
        if paused then return end
        if pendingAdvance and t>=retryAt then tryPending();retryAt=t+0.6 end
        if deliveredDuringStep and (step=="complete" or step=="result.explain") then
            if t>=retryAt then finish();retryAt=t+0.8 end
            return
        end
        if not pendingAdvance then syncScene() end
        syncProgress()
        if pendingAdvance then return end
        if step=="intro.paper" then
            local rect=homeRect("home.letterPaper")
            targetRect=rect
            if interceptor and rect then setRect(interceptor,rect.x,rect.y,rect.w,rect.h) end
            if rect then targetRect=rect end
        elseif step=="intro.note" then
            targetRect=nil
        elseif step=="brew.conditions" and ctx.brew and ctx.brew.selected=="recipe" then
            targetRect=targetWidget("brewNotesClose") or targetWidget("brewNotesHost")
        else
            targetRect=currentTarget()
        end
        local vp=viewport();local s=safe()
        local hole=targetRect
        local b=root and root.GetAbsoluteLayout and root:GetAbsoluteLayout() or nil
        if not b then return end
        local preview=ctx.root and ctx.root:FindById("previewOrder")
        local notesOpen=ctx.brew and ctx.brew.selected=="recipe"
        local allowWorkbench=step=="brew.word" or step=="brew.ingredient"
            or step=="letter.accept" or step=="result.explain" or step=="complete"
            or (step=="brew.ready" and preview and preview.props.disabled==true)
            or (step=="brew.conditions" and notesOpen)
        if allowWorkbench then
            setRect(blockers.top,b.x,b.y,0,0)
            setRect(blockers.bottom,b.x,b.y,0,0)
            setRect(blockers.left,b.x,b.y,0,0)
            setRect(blockers.right,b.x,b.y,0,0)
        elseif hole then
            setRect(blockers.top,b.x,b.y,b.w,math.max(0,hole.y-b.y))
            setRect(blockers.bottom,b.x,hole.y+hole.h,b.w,math.max(0,b.y+b.h-hole.y-hole.h))
            setRect(blockers.left,b.x,hole.y,math.max(0,hole.x-b.x),hole.h)
            setRect(blockers.right,hole.x+hole.w,hole.y,math.max(0,b.x+b.w-hole.x-hole.w),hole.h)
        else
            setRect(blockers.top,b.x,b.y,b.w,b.h)
            setRect(blockers.bottom,b.x,b.y,0,0)
            setRect(blockers.left,b.x,b.y,0,0)
            setRect(blockers.right,b.x,b.y,0,0)
        end
        if step=="intro.note" then
            if tooltip then tooltip:SetVisible(false) end
            if noteLayer then noteLayer:SetVisible(true) end
            if skipButton then skipButton:SetVisible(true);setRect(skipButton,vp.w-s.right-116,s.top+12,104,40) end
            return
        end
        if noteLayer then noteLayer:SetVisible(false) end
        if interceptor then interceptor:SetVisible(step=="intro.paper") end
        if tooltip then
            tooltip:SetVisible(true)
            local def=STEPS[step]
            local text=def and def.text or ""
            if step=="brew.conditions" and notesOpen then text="看完后，点手札上的关闭按钮收起。"
            elseif step=="brew.ready" and preview and preview.props.disabled==true then
                text="条件还没满足。先调整词条或原料，满足后就能开始熬制。"
            end
            tooltipLabel:SetText(text)
            local resultMotion=ctx.resultMotion
            local resultReady=ctx.panel=="result" and not (resultMotion and resultMotion.motion and resultMotion.motion.opening)
            local showKnow=def and def.know==true or false
            local knowEnabled=showKnow and (step~="result.explain" or resultReady)
            knowButton:SetVisible(showKnow)
            knowButton:SetDisabled(not knowEnabled)
            local width=math.min(340,math.max(220,vp.w*.26))
            local height=showKnow and 132 or 92
            local x,y
            if hole then
                x=hole.x+hole.w/2-width/2
                y=hole.y+hole.h+14
                if y+height>vp.h-s.bottom-12 then y=hole.y-height-14 end
            else
                x=(vp.w-width)/2;y=(vp.h-height)/2
            end
            x=math.max(s.left+12,math.min(vp.w-s.right-width-12,x))
            y=math.max(s.top+60,math.min(vp.h-s.bottom-height-12,y))
            setRect(tooltip,x,y,width,height)
            if skipButton then setRect(skipButton,vp.w-s.right-116,s.top+12,104,40) end
        end
        if interceptor and step=="intro.paper" and targetRect then
            setRect(interceptor,targetRect.x,targetRect.y,targetRect.w,targetRect.h)
        end
    end
    function api.Destroy()
        if destroyed then return end
        destroyed=true
        for _,row in ipairs(listeners) do EventBus.Off(row.name,row.id) end
        listeners={}
        if root then root:Destroy() end
        root=nil;shade=nil;tooltip=nil;noteLayer=nil;completeLayer=nil
    end
    function api.ShowNote()
        ensureRoot()
        noteOnly=true;active=true
        if shade then shade:SetVisible(false) end
        for _,blocker in pairs(blockers) do blocker:SetVisible(false) end
        if interceptor then interceptor:SetVisible(false) end
        if tooltip then tooltip:SetVisible(false) end
        if skipButton then skipButton:SetVisible(false) end
        if completeLayer then completeLayer:SetVisible(false) end
        if noteLayer then noteLayer:SetVisible(true) end
        if root then root:SetVisible(true) end
    end
    function api.GetStep() return step end
    return api
end
return O
