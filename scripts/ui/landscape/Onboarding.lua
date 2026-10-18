-- 新手引导表现层：只读业务快照，按真实命令成功推进；不重复发送事务。
local UI=require "urhox-libs/UI"
local Widget=require "urhox-libs/UI/Core/Widget"
local EventBus=require "core.EventBus"
local Geometry=require "ui.landscape.LayoutGeometry"
local U=require "core.StateUtil"
local Harbor=require "ui.landscape.HarborStyle"
local Sizing=require "ui.landscape.OnboardingLayout"
local O={}

local NOTE={
    "这里是一间在人间之外的魔药铺。",
    "你因一个尚未完成的愿望来到这里。",
    "海上漂来的瓶子，装着人间某个人的心事。把它们捞起来，读过信，剪下能用的词语，配上原料熬成魔药，再照着地址寄回人间。",
    "网兜挂在门边。先去看看吧。",
}
local STEPS={
    ["intro.paper"]={target="home.letterPaper",text="桌上有一张没有署名的便签。",narration=true},
    ["intro.note"]={note=true},
    ["home.net"]={target="home.net",text="先去海边看看。"},
    ["sea.salvage"]={target="startSalvage",text="捞起这个漂流瓶。"},
    ["sea.read"]={target="readCapturedLetter",text="看看瓶子里写了什么。"},
    ["letter.cut"]={target="letterPaper",text="点亮起的词语，把它剪下来。"},
    ["letter.accept"]={target="acceptOrder",text="准备好了，就接下这份委托。"},
    ["brew.word"]={target="brewWordPanel",fallback="brewWordsHost",text="剪下的词条收在左边。调配时，可以把词条拖进锅里。",know=true,next="brew.book"},
    ["brew.book"]={target="brewBookPanel",fallback="brewJournalHost",text="右边的记录书记着来信与后续故事，可以随时翻看。",know=true,next="brew.ingredient"},
    ["brew.ingredient"]={target="brewShelf",text="中间是原料。不同原料会改变这一锅的药性。",know=true,next="brew.conditions"},
    ["brew.conditions"]={target="brewRecipeDetails",text="“查看药性与条件”会列出委托要求和当前配方的药性。",know=true,next="brew.ready"},
    ["brew.ready"]={target="previewOrder",text="配方满足条件后，点“开始熬制”查看结果。接下来由你自由调配。",know=true,last=true},
    -- Keep old step names readable so saves from the earlier tutorial can finish quietly.
    ["result.explain"]={},["complete"]={},
}

local function snapshot(session)
    return session.state.GetSnapshot()
end
local function currentOrder(data)
    return data and data.currentOrder or false
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

function O.New(ctx)
    local api={}
    local session=ctx.session
    local state=nil
    local active=false
    local step=nil
    local root,shade,tooltip,tooltipLabel,narration,knowButton,skipButton,noteLayer,noteButton,note,noteScroll,noteBody
    local blockers={}
    local interceptor
    local targetRect=nil
    local noteOnly=false
    local noteWasRead=false
    local hintsBefore=false
    local pendingAdvance=nil
    local retryAt=0
    local syncedStep=nil
    local syncAt=0
    local listeners={}
    local destroyed=false
    local lastRect={}
    local paused=false
    local noteLabels={}
    local noteLayoutKey=nil
    local tooltipLayoutKey,tooltipBox
    local narrationLayoutKey,narrationBox
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
            local arrival=step=="intro.paper" and ctx.arrival and ctx.arrival.Presentation()
            local paperAlpha=arrival and arrival.paperAlpha or 1
            local color={11,8,5,158}
            local function rect(x,y,w,h,alpha)
                if w<=0 or h<=0 then return end
                nvgBeginPath(vg);nvgRect(vg,x,y,w,h)
                nvgFillColor(vg,nvgRGBA(color[1],color[2],color[3],alpha or color[4]));nvgFill(vg)
            end
            if hole then
                rect(b.x,b.y,b.w,math.max(0,hole.y-b.y))
                rect(b.x,hole.y+hole.h,b.w,math.max(0,b.y+b.h-hole.y-hole.h))
                rect(b.x,hole.y,math.max(0,hole.x-b.x),hole.h)
                rect(hole.x+hole.w,hole.y,math.max(0,b.x+b.w-hole.x-hole.w),hole.h)
                rect(hole.x,hole.y,hole.w,hole.h,math.floor(color[4]*(1-paperAlpha)))
                nvgBeginPath(vg)
                nvgRoundedRect(vg,hole.x-4,hole.y-4,hole.w+8,hole.h+8,8)
                nvgStrokeColor(vg,nvgRGBA(236,201,133,math.floor(220*paperAlpha)));nvgStrokeWidth(vg,2);nvgStroke(vg)
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
            pointerEvents="box-only",visible=false,onClick=function()
                if ctx.arrival and ctx.arrival.IsActive() then return end
                requestAdvance("intro.note")
            end}
        root:AddChild(interceptor)
        narration=UI.Label {id="onboardingNarration",text=STEPS["intro.paper"].text,position="absolute",
            left=0,top=0,width=1,height=1,zIndex=10,visible=false,fontFamily="story",fontSize=16,
            lineHeight=1.5,whiteSpace="normal",textAlign="center",verticalAlign="top",flexShrink=0,
            fontColor={249,236,207,255},textShadow={offsetX=1,offsetY=2,blur=4,color={8,6,4,230}},pointerEvents="none"}
        root:AddChild(narration)
        tooltip=UI.Panel {id="onboardingTooltip",position="absolute",left=0,top=0,width=1,zIndex=10,
            backgroundColor={246,236,207,248},borderWidth=1,borderColor={174,140,86,220},borderRadius=6,
            padding=12,gap=8,boxShadow={x=0,y=3,blur=8,color={0,0,0,90}},pointerEvents="box-only",onClick=function() end}
        tooltipLabel=UI.Label {id="onboardingText",text="",fontFamily="story",fontSize=15,lineHeight=1.45,
            whiteSpace="normal",fontColor={55,43,30,255},width="100%",flexShrink=0,verticalAlign="top",pointerEvents="none"}
        tooltip:AddChild(tooltipLabel)
        knowButton=Harbor.Button {id="onboardingKnow",text="知道了",width=104,alignSelf="flex-end",
            minHeight=40,height=40,fontSize=14,visible=false,onClick=function()
                local def=step and STEPS[step]
                if pendingAdvance==nil and def and def.know then
                    if def.last then finish() elseif def.next then requestAdvance(def.next) end
                end
            end}
        tooltip:AddChild(knowButton)
        root:AddChild(tooltip)
        skipButton=Harbor.Button {id="onboardingSkip",text="跳过引导",position="absolute",right=12,top=12,width=104,
            height=40,minHeight=40,fontSize=13,zIndex=50,onClick=function() skip() end}
        root:AddChild(skipButton)
        noteLayer=UI.Panel {id="onboardingNoteLayer",position="absolute",left=0,top=0,width="100%",height="100%",
            backgroundColor={8,6,4,190},pointerEvents="box-only",visible=false,onClick=function() end,zIndex=20}
        note=Harbor.Paper {id="onboardingNote",position="absolute",left=0,top=0,width=1,height=1,
            padding=32,gap=12,pointerEvents="box-only"}
        noteScroll=UI.ScrollView {id="onboardingNoteScroll",width="100%",height=1,flexShrink=0,
            scrollY=true,showScrollbar=true,paddingRight=12}
        noteBody=UI.Panel {width="100%",flexShrink=0,gap=14,pointerEvents="box-none"}
        for i,line in ipairs(NOTE) do
            local label=UI.Label {id="onboardingNoteParagraph"..i,text=line,fontFamily="story",fontSize=16,
                lineHeight=1.7,whiteSpace="normal",flexShrink=0,verticalAlign="top",
                width="100%",fontColor={62,48,33,255},pointerEvents="none"}
            noteLabels[i]=label;noteBody:AddChild(label)
        end
        noteScroll:AddChild(noteBody);note:AddChild(noteScroll)
        noteButton=Harbor.Button {id="onboardingNoteDone",text="收好便签",width=150,alignSelf="center",
            minHeight=46,height=46,fontSize=16,
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
        ctx.root:AddChild(root)
    end
    local function layoutNote()
        if not note then return end
        local vp=viewport();local inset=safe()
        local version=UI.GetFontVersion()
        local key=table.concat({vp.w,vp.h,inset.left,inset.right,inset.top,inset.bottom,version},":")
        if key==noteLayoutKey then return end
        noteLayoutKey=key
        local width=math.max(180,math.min(700,vp.w-inset.left-inset.right-48))
        local total=0
        for i,line in ipairs(NOTE) do
            local block=Sizing.Text(line,width-64-12,16,1.7)
            noteLabels[i]:SetText(block.text);Widget.SetStyle(noteLabels[i],{height=block.height})
            total=total+block.height+(i>1 and 14 or 0)
        end
        local height=math.min(vp.h-inset.top-inset.bottom-48,64+12+46+total)
        setRect(note,inset.left+(vp.w-inset.left-inset.right-width)/2,
            inset.top+(vp.h-inset.top-inset.bottom-height)/2,width,height)
        Widget.SetStyle(noteScroll,{height=math.max(1,height-64-12-46)})
        Widget.SetStyle(noteBody,{height=total})
    end
    local function readState()
        local data=snapshot(session)
        return data and data.onboarding or nil,data
    end
    local function finishLocal()
        setVisible(false)
        if noteLayer then noteLayer:SetVisible(false) end
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
            finishLocal()
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
        if step=="letter.cut" then
            local presentation=ctx.readerCache and ctx.readerCache.presentation
            local scroll=ctx.scroll
            local clip=scroll and scroll.GetAbsoluteLayoutForHitTest and scroll:GetAbsoluteLayoutForHitTest()
            return presentation and presentation.paper.FirstAvailableBounds(clip) or nil
        end
        local def=STEPS[step]
        if not def then return nil end
        local rect=targetWidget(def.target)
        if not rect and def.fallback then rect=targetWidget(def.fallback) end
        return rect
    end
    local function applyStep(nextStep)
        step=nextStep
        if narration then narration:SetVisible(step=="intro.paper") end
        if noteLayer then noteLayer:SetVisible(step=="intro.note") end
        if skipButton then skipButton:SetVisible(true) end
        if interceptor then interceptor:SetVisible(step=="intro.paper") end
        if tooltip then
            local def=STEPS[step]
            if def then
                tooltip:SetVisible(def.narration~=true and def.note~=true)
                tooltipLabel:SetText(def.text or "")
                knowButton:SetVisible(def.know==true)
            else
                tooltip:SetVisible(false)
            end
        end
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
        if state.step=="result.explain" or state.step=="complete" then finish();return end
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
    function api.Update()
        if destroyed then return end
        local t=now()
        layoutNote()
        if noteOnly then
            if not noteLayer or noteLayer.props.visible==false then noteOnly=false;setVisible(false) end
            return
        end
        refreshState()
        if not active then return end
        layoutNote()
        local brewing=step and step:sub(1,5)=="brew."
        local shouldPause=presentationPaused() or (brewing and (ctx.scene~="brew" or ctx.panel~=false and ctx.panel~=nil))
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
        else
            targetRect=currentTarget()
        end
        local vp=viewport();local s=safe()
        if skipButton then setRect(skipButton,vp.w-s.right-116,s.top+12,104,40) end
        if narration and step=="intro.paper" then
            local width=math.min(700,vp.w-s.left-s.right-48)
            local key=tostring(width)..":"..UI.GetFontVersion()
            if narrationLayoutKey~=key then
                narrationLayoutKey=key
                narrationBox=Sizing.Text(STEPS["intro.paper"].text,width,16,1.5)
                narration:SetText(narrationBox.text)
            end
            local content=narrationBox
            setRect(narration,s.left+(vp.w-s.left-s.right-width)/2,vp.h-s.bottom-content.height-32,width,content.height)
            local arrival=ctx.arrival and ctx.arrival.Presentation()
            local alpha=arrival and arrival.narrationAlpha or 1
            narration.props.fontColor={249,236,207,math.floor(255*alpha)}
            narration:SetVisible(alpha>0)
        end
        local hole=targetRect
        local b=root and root.GetAbsoluteLayout and root:GetAbsoluteLayout() or nil
        if not b then return end
        local allowWorkbench=brewing or step=="letter.accept" or step=="letter.cut"
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
            if skipButton then skipButton:SetVisible(true) end
            return
        end
        if noteLayer then noteLayer:SetVisible(false) end
        if interceptor then interceptor:SetVisible(step=="intro.paper") end
        if tooltip and step=="intro.paper" then
            tooltip:SetVisible(false)
        elseif tooltip then
            tooltip:SetVisible(true)
            local def=STEPS[step]
            local text=def and def.text or ""
            local showKnow=def and def.know==true or false
            knowButton:SetVisible(showKnow)
            knowButton:SetDisabled(false)
            local key=table.concat({text,vp.w,s.left,s.right,tostring(showKnow),UI.GetFontVersion()},":")
            if key~=tooltipLayoutKey then
                tooltipLayoutKey=key
                tooltipBox=Sizing.Tooltip(text,vp.w-s.left-s.right-24,showKnow)
                tooltipLabel:SetText(tooltipBox.content.text)
                Widget.SetStyle(tooltipLabel,{height=tooltipBox.content.height})
            end
            local box=tooltipBox
            local width,height=box.width,box.height
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
        root=nil;shade=nil;tooltip=nil;noteLayer=nil
    end
    function api.ShowNote()
        ensureRoot()
        noteOnly=true;active=true
        if shade then shade:SetVisible(false) end
        for _,blocker in pairs(blockers) do blocker:SetVisible(false) end
        if interceptor then interceptor:SetVisible(false) end
        if tooltip then tooltip:SetVisible(false) end
        if narration then narration:SetVisible(false) end
        if skipButton then skipButton:SetVisible(false) end
        if noteLayer then noteLayer:SetVisible(true) end
        if root then root:SetVisible(true) end
    end
    function api.GetStep() return step end
    return api
end
return O
