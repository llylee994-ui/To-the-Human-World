local UI=require "urhox-libs/UI"
local Model=require "ui.PlayModel"
local Home=require "ui.landscape.HomeView"
local Panels=require "ui.landscape.Panels"
local Zoom=require "ui.landscape.HomeZoom"
local StovePanZoom=require "ui.landscape.StovePanZoom"
local Seaside=require "ui.landscape.SeasideView"
local Salvage=require "ui.landscape.SalvageController"
local Harbor=require "ui.landscape.HarborStyle"
local Messages=require "ui.landscape.MessagePresenter"
local HudLayout=require "ui.landscape.HudLayout"
local Widget=require "urhox-libs/UI/Core/Widget"
local Theme=require "urhox-libs/UI/Core/Theme"
local SeaArt=require "ui.landscape.SeaArt"
local Shop=require "ui.landscape.ShopView"
local TicketView=require "ui.landscape.TravelTicketView"
local WordTray=require "ui.landscape.WordTrayDrawer"
local JournalBook=require "ui.landscape.JournalBook"
local Brew=require "ui.landscape.BrewView"
local ResultView=require "ui.landscape.ResultView"
local BrewFeedback=require "ui.landscape.BrewFeedback"
local LetterDrawer=require "ui.landscape.LetterDrawer"
local Closing=require "ui.landscape.ReleaseClosingView"
local Wish=require "ui.landscape.WishView"
local Ending=require "ui.landscape.EndingView"
local SceneMusic=require "ui.landscape.SceneMusic"
local ObjectSounds=require "ui.landscape.ObjectSounds"
local MusicSettings=require "core.MusicSettings"
local SoundSettings=require "core.SoundSettings"
local MusicSettingsView=require "ui.landscape.MusicSettingsView"
local Calendar=require "ui.landscape.CalendarView"
local Title=require "ui.landscape.TitleView"
local A={}
local side={words="left",journal="right"}
local titles={letters="来信抽屉",reader="阅读信件",words="词条栏",journal="故事记录",attempt="试做记录",shop="商队商店",case="案件板",day="结束当天",result="试做结果"}
local clickPanels={day=true,shop=true,result=true,attempt=true,case=true}
local function clock()
    local get=rawget(_G,"GetTime")
    if not get then return 0,0 end
    local time=get();return time:GetElapsedTime(),time:GetTimeStep()
end
local function clear(parent)
    for i=parent:GetNumChildren(),1,-1 do local child=parent:GetChildAt(i); if child then child:Destroy() end end
end
local function setStyle(widget,style)
    for key,value in pairs(style) do
        if widget.props[key]~=value then Widget.SetStyle(widget,style);return end
    end
end
local function bodyIn(parent,id)
    local scroll=UI.ScrollView {id=id,width="100%",flexGrow=1,flexShrink=1,flexBasis=0,scrollY=true,showScrollbar=true}
    local body=UI.Panel {alignSelf="stretch",flexShrink=0,padding=18,paddingRight=24,gap=10,pointerEvents="box-none"}
    scroll:AddChild(body); parent:AddChild(scroll); return body,scroll
end
---@return table Session-bound view with navigation, scene controllers and lifecycle methods.
function A.New(session,content,enabled)
    local model=Model.New(session,content,enabled)
    local music=SceneMusic.New()
    local objectSounds=ObjectSounds.New()
    local objectOpen=false --[[@as string|false]]
    local preferences=MusicSettings.New()
    local function applyMusicSettings(value) music.SetOptions(value.enabled,value.volume) end
    applyMusicSettings(preferences.Get())
    local soundPreferences=SoundSettings.New()
    local function applySoundSettings(value) objectSounds.SetOptions(value.enabled,value.volume) end
    applySoundSettings(soundPreferences.Get())
    local settings=MusicSettingsView.New(preferences,applyMusicSettings,soundPreferences,applySoundSettings)
    local nativeProbe=require("ui.landscape.DevChecks").nativeProbe and require("ui.landscape.tests.NativeProbe").New() or nil
    local yawEnabled=require("ui.landscape.DevChecks").yawProbe
    local yawAuto=yawEnabled and require("ui.landscape.DevChecks").yawProbeAuto and require("ui.landscape.tests.YawNativeProbe").New() or nil
    local stoveAuto=require("ui.landscape.DevChecks").stoveYawAuto and require("ui.landscape.tests.StoveYawNativeProbe").New() or nil
    local panZoomAuto=require("ui.landscape.DevChecks").stovePanZoomAuto and require("ui.landscape.tests.StovePanZoomNativeProbe").New() or nil
    local brewProbe=require("ui.landscape.DevChecks").brewWorkbenchProbe and require("ui.landscape.tests.BrewNativeProbe").New() or nil
    local firstBatchProbe=require("ui.landscape.DevChecks").firstBatchProbe and require("ui.landscape.tests.FirstBatchNativeProbe").New() or nil
    local readingProbe=require("ui.landscape.DevChecks").readingProbe and require("ui.landscape.tests.ReadingNativeProbe").New() or nil
    local apprenticeProbe=require("ui.landscape.DevChecks").apprenticeProbe and require("ui.landscape.tests.ApprenticeNativeProbe").New() or nil
    local wishProbe=require("ui.landscape.DevChecks").wishProbe and require("ui.landscape.tests.WishNativeProbe").New() or nil
    local mobileBrewProbe=require("ui.landscape.DevChecks").mobileBrewProbe and require("ui.landscape.tests.MobileBrewNativeProbe").New() or nil
    local developer=(require("debug.DeveloperMode") or require("ui.landscape.DevChecks").hotspots) --[[@as boolean]]
    -- The stage fills the viewport; each control group applies its own safe area.
    -- UpdateChrome extends this surface through main's SafeAreaView insets.
    local root=UI.Panel {id="playPanel",position="absolute",left=0,top=0,width="100%",height="100%",
        backgroundColor={48,42,34,255},pointerEvents="box-none",overflow="hidden"}
    local hud=UI.Panel {id="homeHud",position="absolute",top=8,left=0,width="100%",height=48,flexShrink=0,
        flexDirection="row",alignItems="center",gap=8,paddingLeft=12,paddingRight=12,pointerEvents="box-none"}
    local ledger=UI.Label {id="playLedger",fontSize=13,fontFamily=Harbor.fontFamily,fontColor={65,46,28,255},minWidth=0,pointerEvents="none"}
    local ledgerCard=Harbor.Paper {id="ledgerCard",width=184,height=32,padding={6,16},justifyContent="center",children={ledger}}
    hud:AddChild(ledgerCard);hud:AddChild(UI.Panel {flexGrow=1,minWidth=0,pointerEvents="none"})
    local stage=UI.Panel {id="homeStage",width="100%",flexGrow=1,flexShrink=1,flexBasis=0,minHeight=0,pointerEvents="box-none"}
    root:AddChild(stage)
    local notice=UI.Label {id="playMessage",fontSize=14,fontFamily=Harbor.fontFamily,fontColor={65,46,28,255},whiteSpace="normal",flexShrink=0,pointerEvents="none"}
    local noticeArea=UI.ScrollView(Harbor.PaperProps {id="playMessageArea",position="absolute",left=14,bottom=12,width="70%",maxWidth=680,
        minHeight=44,maxHeight=96,visible=false,scrollY=true,padding=12,pointerEvents="box-none",
        children={notice}}) --[[@as Widget]]
    root:AddChild(noticeArea)
    local ctx={root=root,model=model,session=session,content=content,
        scene="home" --[[@as string]],panel=false --[[@as string|false]],stack={},
        storyId=false --[[@as string|false]],shopSelectedId=false --[[@as string|false]],readerCache=false --[[@as table|false]],choosingLetter=false --[[@as boolean]],
        wordTray=false --[[@as table|false]],
        ticketConfirm=false --[[@as boolean]],ticketQuote=false --[[@as table|false]],ticketEnding=false --[[@as table|false]],
        releasePhase=false --[[@as string|false]],newPlaythroughConfirm=false --[[@as boolean]],
        atTitle=false --[[@as boolean]],journeyView=false --[[@as table|false]],
        endingEntrance=false --[[@as string|false]],endingShowCollage=false --[[@as boolean]],
        reviewEnding=false --[[@as table|false]],wishSelected=false --[[@as string|false]],wishUndo={},
        panelNotice=false --[[@as Label|false]],panelNoticeArea=false --[[@as ScrollView|false]],
        panelHeader=false --[[@as Widget|false]],
        resultMotion=false --[[@as table|false]],
        calendar=false --[[@as table|false]],
        zoom=Zoom.New(),salvage=Salvage.New(),destroyed=false --[[@as boolean]],portrait=false --[[@as boolean]],
        yawProbe=false --[[@as table|false]],
        messages=Messages.New(session.state.GetStatus().migrationNotice),importantMessage=false --[[@as string|false]]}
    local departureMusic=false --[[@as boolean]]
    function ctx.SetDepartureMusic(value)
        departureMusic=value~=nil
        music.Sync(ctx.scene,departureMusic and "departure" or ctx.panel)
        music.SetPresentationGain(value or 1)
    end
    function ctx.SetApprenticeMusic(value)
        music.Sync(value~=nil and "home" or ctx.scene,value==nil and ctx.panel or false)
        music.SetPresentationGain(value or 1)
    end
    function ctx.PlayObjectSound(id)
        if not ctx.destroyed then return objectSounds.Play(id) end
        return false
    end
    local notify=model.Notify
    function model.Notify(result,message)
        local r=notify(result,message)
        ctx.importantMessage=(not result.ok or (result.value and result.value.notificationErrors)) and model.message or false
        ctx.messages:Observe(model.message,clock(),ctx.importantMessage==model.message,true)
        return r
    end
    local home=Home.New(function(target,id)
        if id=="home.net" then ctx.BeginHomeZoom()
        elseif id=="home.stove" then ctx.BeginHomeZoom("stove")
        else ctx.Open(target) end
    end,developer,content.release~=nil); stage:AddChild(home.root); ctx.home=home
    home.SetInspect(require("ui.landscape.DevChecks").hotspots)
    local scene=Harbor.Paper {id="functionalScene",position="absolute",left=0,top=0,width="100%",height="100%",padding=0,paddingTop=64,visible=false}
    stage:AddChild(scene)
    local seaside=Seaside.New(ctx);stage:AddChild(seaside.root);ctx.seaside=seaside
    ctx.brew=Brew.New(ctx);stage:AddChild(ctx.brew.root)
    root:AddChild(hud)
    ctx.feedback=BrewFeedback.New(ctx,ledger)
    -- Explicit order: equal-z siblings are not stably sorted by the UI library.
    local overlay=UI.Panel {id="overlayHost",position="absolute",left=0,top=0,width="100%",height="100%",zIndex=100,pointerEvents="box-none"}
    root:AddChild(overlay)
    root:AddChild(settings.root)
    -- Stable topmost blocker: blocks HUD and all room inputs without rebuilding the tree.
    local zoomBlocker=UI.Panel {id="homeZoomBlocker",position="absolute",left=0,top=0,width="100%",height="100%",
        zIndex=1000,visible=false,pointerEvents="box-only",onClick=function() end}
    root:AddChild(zoomBlocker)
    local salvageBlocker=UI.Panel {id="salvageBlocker",position="absolute",left=0,top=0,width="100%",height="100%",
        zIndex=1001,visible=false,onClick=function() end}
    salvageBlocker:AddChild(Harbor.Button {id="skipSalvage",text="跳过演出",position="absolute",right=14,bottom=46,
        width=116,minHeight=48,fontSize=15,onClick=function() ctx.SkipSalvage() end})
    root:AddChild(salvageBlocker)
    local rotateGuard=UI.Panel {id="rotateGuard",position="absolute",left=0,top=0,width="100%",height="100%",
        visible=false,zIndex=2002,backgroundColor={48,42,34,248},alignItems="center",justifyContent="center",onClick=function() end,
        children={Harbor.Tag {text="横过手机，走进小屋",fontSize=19,minHeight=60,padding=18}}}
    root:AddChild(rotateGuard)
    ---@type Widget|nil
    local pending
    function ctx.UpdateChrome()
        if not root.GetAbsoluteLayout then return end
        local bounds=root:GetAbsoluteLayout()
        local viewport,safe,menu=HudLayout.ReadHost(UI,bounds)
        local vw,vh=viewport.w,viewport.h
        if vw<=0 or vh<=0 then return end
        local oldViewport,oldSafe=ctx.viewport,ctx.safeInsets
        local changed=not oldViewport or oldViewport.w~=vw or oldViewport.h~=vh or not oldSafe
            or oldSafe.left~=safe.left or oldSafe.top~=safe.top or oldSafe.right~=safe.right or oldSafe.bottom~=safe.bottom
        local oldMenu=ctx.menuRect
        if (oldMenu==nil)~=(menu==nil) then changed=true
        elseif oldMenu and menu then
            for _,key in ipairs({"left","top","right","bottom"}) do if oldMenu[key]~=menu[key] then changed=true end end
        end
        ctx.safeInsets=safe;ctx.viewport=viewport
        ctx.menuRect=menu and {left=menu.left,top=menu.top,right=menu.right,bottom=menu.bottom} or nil
        home.SetPanelOpen(ctx.panel~=false or settings.IsOpen())
        settings.SetInsets(safe,viewport,menu)
        hud:SetVisible(not ctx.panel and (not ctx.releasePhase or ctx.releasePhase=="operating"))
        local label=ledger:GetText()
        local measured=UI.MeasureTextWidth and UI.MeasureTextWidth(label,Theme.FontSize(13),Harbor.fontFamily) or (utf8.len(label) or 0)*10
        local ledgerWidth=math.max(144,measured+36)
        setStyle(ledgerCard,{width=ledgerWidth})
        if changed and ctx.panel then model.dirty=true end
        local parent=root.parent
        if parent and parent.GetAbsoluteLayout then
            local p=parent:GetAbsoluteLayout()
            local style=root.props
            if style.left~=-p.x or style.top~=-p.y or style.width~=vw or style.height~=vh then
                setStyle(root,{left=-p.x,top=-p.y,width=vw,height=vh})
            end
        end
        local viewportRoot=UI.GetRoot()
        if viewportRoot and viewportRoot.SetBackgroundImage then
            if ctx.scene=="brew" then
                if viewportRoot.props.backgroundImage~=false then
                    Widget.SetStyle(viewportRoot,{backgroundImage=false,backgroundColor={238,228,203,255}})
                end
            else
                local background=SeaArt.background
                if viewportRoot.props.backgroundImage~=background then viewportRoot:SetBackgroundImage(background) end
            end
        end
        local required=ledgerWidth+12+108+72+80+24+(ctx.scene~="home" and 114 or 0)+(pending and pending.props.visible and 122 or 0)
        local finish=hud:FindById("finishJourney")
        if finish and finish.props.visible then required=required+116 end
        local safeWidth=math.max(0,vw-safe.left-safe.right)
        local offsets=HudLayout.Compute({x=safe.left,y=safe.top+8,w=safeWidth,h=48},viewport,menu,required)
        local p=hud.props
        if p.left~=safe.left or p.width~=safeWidth or p.top~=safe.top+8+offsets.top or p.paddingRight~=offsets.right then
            setStyle(hud,{left=safe.left,width=safeWidth,top=safe.top+8+offsets.top,paddingRight=offsets.right})
        end
        local contentTop=64+safe.top+offsets.top
        if scene.props.paddingTop~=contentTop then
            setStyle(scene,{paddingTop=contentTop})
        end
        setStyle(scene,{paddingLeft=safe.left+32,paddingRight=safe.right+32,paddingBottom=safe.bottom+32})
        seaside.SetInsets(safe)
        setStyle(assert(salvageBlocker:FindById("skipSalvage")),{right=safe.right+14,bottom=safe.bottom+46})
        if ctx.panelHeader and ctx.panelHeader.GetAbsoluteLayout then
            local header=ctx.panelHeader
            local r=header:GetAbsoluteLayout()
            -- Compute from the unshifted position so a fallback margin cannot
            -- alternate between clearing the capsule and undoing itself.
            local shop=ctx.panel=="shop" and not ctx.ticketConfirm
            local clearance=HudLayout.Compute({x=r.x,y=r.y-(header.props.marginTop or 0),w=r.w,h=r.h},viewport,menu,shop and 534+safe.left or 250)
            local pad=shop and (vh-safe.top-safe.bottom<540 and 12 or 24) or 16
            local right=math.max(clearance.right,shop and safe.right+pad or 12)
            if header.props.paddingRight~=right or header.props.marginTop~=clearance.top then
                setStyle(header,{paddingRight=right,marginTop=clearance.top})
            end
            if shop then setStyle(header,{paddingLeft=pad+safe.left,paddingTop=8+safe.top}) end
        end
        local portrait=vw<vh
        if ctx.portrait~=portrait then
            ctx.portrait=portrait;rotateGuard:SetVisible(portrait)
            if portrait then ctx.CancelHomeZoom("portrait");ctx.CancelSalvage("portrait");ctx.brew.Cancel() end
        end
        local now=clock()
        ctx.messages:Observe(model.message,now,ctx.importantMessage==model.message)
        local current=ctx.messages:Current(now)
        notice:SetText(current.text);noticeArea:SetVisible(current.visible and not ctx.panel and not ctx.salvage.active and ctx.scene~="brew")
        local bottom=ctx.scene=="seaside" and 86 or 12
        setStyle(noticeArea,{left=14+safe.left,bottom=bottom+safe.bottom})
        if ctx.panelNotice then ctx.panelNotice:SetText(current.text) end
        if ctx.panelNoticeArea then
            local story=ctx.panel=="result" or ctx.panel=="attempt"
            ctx.panelNoticeArea:SetVisible(current.visible and ctx.panel~="reader" and (not story or current.persistent) and (not ctx.journeyView or ctx.importantMessage~=false))
        end
    end
    function ctx.CancelSalvage(reason)
        local active=ctx.salvage.active
        ctx.salvage.Cancel(reason);salvageBlocker:SetVisible(false)
        if active then
            model.dirty=true
            if ctx.salvage.letterInstanceId then model.message="信已收好，可继续阅读，也可从药铺抽屉查看。" end
        end
    end
    function ctx.OpenCapturedLetter(userInitiated)
        if ctx.destroyed or ctx.salvage.active or ctx.panel or ctx.scene~="seaside" then return false end
        local id=ctx.salvage.letterInstanceId;if not id then return false end
        local result=ctx.Read(id,userInitiated)
        model.dirty=true;return result
    end
    function ctx.SkipSalvage()
        if ctx.destroyed or not ctx.salvage.active then return false end
        ctx.salvage.Skip();salvageBlocker:SetVisible(false);return ctx.OpenCapturedLetter()
    end
    function ctx.StartSalvage()
        if ctx.destroyed or ctx.portrait or ctx.scene~="seaside" or ctx.panel or ctx.zoom.active or ctx.salvage.active or ctx.salvage.letterInstanceId then return false end
        local fit=seaside.Fit();if fit.scale<=0 then return false end
        local current=session.queries.GetSalvageView()
        if not current.ok then return model.Notify(current) end
        local id=current.value.availableLetterIds[1]
        if not current.value.enabled or not id then
            model.message=current.value.message or "目前没有可捕捞信件。";model.dirty=true;return false
        end
        local result=model.Receive(id)
        if result.ok then
            ctx.salvage.Begin(result.value.letterInstanceId,fit,GetTime():GetElapsedTime())
            salvageBlocker:SetVisible(true);model.message="信已收好，正在收起漂流瓶…";model.dirty=true
        end
        return result
    end
    function ctx.CancelHomeZoom(reason)
        ctx.zoom.Reset(reason);home.SetZoom(1);home.SetPanZoom(false);home.SetBlocked(false);zoomBlocker:SetVisible(false)
    end
    function ctx.BeginHomeZoom(kind)
        if ctx.destroyed or ctx.yawProbe or ctx.portrait or ctx.scene~="home" or (ctx.panel and not side[ctx.panel]) then return false end
        local fit=home.Fit()
        if fit.scale<=0 then return false end
        local profile=kind=="stove" and StovePanZoom.Plan(home.manifest,fit,home.root:GetAbsoluteLayout()) or nil
        if not ctx.zoom.Start(fit,GetTime():GetElapsedTime(),profile) then return false end
        if profile then home.SetPanZoom(1,0,0) end
        home.SetBlocked(true);zoomBlocker:SetVisible(true)
        if ctx.panel then ctx.panel=false;ctx.stack={};model.dirty=true end
        return true
    end
    local destroyRoot=root.Destroy
    function root:Destroy()
        if ctx.destroyed then return end
        if settings.IsOpen() then settings.Save() end
        music.Destroy()
        objectSounds.Destroy()
        if ctx.journeyView then ctx.journeyView.Destroy() end
        if ctx.readerCache and ctx.readerCache.presentation then ctx.readerCache.presentation.Cancel() end
        WordTray.Reset(ctx);JournalBook.Reset(ctx);LetterDrawer.Reset(ctx)
        ctx.destroyed=true
        ctx.brew.Leave()
        if ctx.yawProbe then ctx.yawProbe.Close() end
        ctx.CancelHomeZoom("destroyed");ctx.CancelSalvage("destroyed");destroyRoot(self)
    end
    function ctx.OpenYawProbe()
        if not yawEnabled or ctx.destroyed or ctx.portrait or ctx.yawProbe or ctx.zoom.active or ctx.salvage.active or ctx.panel or ctx.scene~="home" then return false end
        ctx.yawProbe=require("ui.landscape.HomeYawProbe").New(root,function() ctx.yawProbe=false end)
        return true
    end
    function ctx.Navigate(target)
        if ctx.atTitle or (ctx.journeyView and ctx.journeyView.busy) then return end
        if ctx.calendar and ctx.calendar.motion.active then return end
        if ctx.destroyed or ctx.salvage.active or ctx.ticketEnding then return end
        if ctx.releasePhase and ctx.releasePhase~="operating" then return end
        ctx.resultMotion=false
        ctx.feedback.Cancel()
        if target~="brew" then ctx.brew.Leave() else ctx.brew.Cancel();ctx.brew.Enter() end
        objectOpen=false
        if ctx.yawProbe then ctx.yawProbe.Close("navigate") end
        if ctx.readerCache and ctx.readerCache.presentation then ctx.readerCache.presentation.Cancel() end
        WordTray.Reset(ctx);JournalBook.Reset(ctx);LetterDrawer.Reset(ctx)
        ctx.CancelHomeZoom("navigate")
        ctx.scene=target; ctx.panel=false; ctx.stack={}; ctx.readerCache=false; ctx.choosingLetter=false;ctx.ticketConfirm=false;ctx.ticketQuote=false
        if target=="home" then model.ReturnHome() else model.Navigate(target) end
        model.dirty=true
    end
    function ctx.Push(kind)
        if ctx.atTitle or (ctx.journeyView and ctx.journeyView.busy) then return end
        if ctx.calendar and ctx.calendar.motion.active then return end
        if ctx.destroyed or ctx.portrait or ctx.zoom.active or ctx.salvage.active or ctx.yawProbe then return end
        if ctx.brew.interaction.active then return end
        ctx.brew.interaction.CancelDrag()
        objectOpen=false
        if ctx.readerCache and ctx.readerCache.presentation then ctx.readerCache.presentation.Cancel() end
        WordTray.Reset(ctx);JournalBook.Reset(ctx);LetterDrawer.Reset(ctx)
        ctx.stack[#ctx.stack+1]=ctx.panel or false; ctx.panel=kind; ctx.readerCache=false; model.dirty=true
    end
    function ctx.Close(confirmed)
        if ctx.atTitle or (ctx.journeyView and ctx.journeyView.busy) then return end
        if ctx.calendar and ctx.calendar.motion.active then return end
        if ctx.destroyed or ctx.zoom.active or ctx.salvage.active or ctx.ticketEnding or ctx.yawProbe then return end
        ctx.resultMotion=false
        local previous=ctx.panel
        objectOpen=false
        if ctx.releasePhase and ctx.releasePhase~="operating" then
            ctx.panel=ctx.releasePhase=="wish" and "wish" or "closing";ctx.stack={};model.dirty=true;return
        end
        if ctx.readerCache and ctx.readerCache.presentation then ctx.readerCache.presentation.Cancel() end
        WordTray.Reset(ctx);JournalBook.Reset(ctx);LetterDrawer.Reset(ctx)
        ctx.ticketConfirm=false;ctx.ticketQuote=false
        if ctx.panel=="journal" then ctx.storyId=false end
        ctx.panel=table.remove(ctx.stack) or false; ctx.readerCache=false
        model.Navigate(ctx.panel=="reader" and "letter" or ctx.scene)
        if confirmed~=true and clickPanels[previous] and previous~=ctx.panel then ctx.PlayObjectSound("ui_click_01") end
    end
    function ctx.Read(id,userInitiated)
        if ctx.atTitle or (ctx.journeyView and ctx.journeyView.busy) then return end
        if ctx.calendar and ctx.calendar.motion.active then return end
        if ctx.destroyed or ctx.zoom.active or ctx.salvage.active or ctx.yawProbe then return end
        local entering=ctx.panel~="reader" or model.selectedLetter~=id
        local result=model.Read(id)
        if result.ok then
            ctx.salvage.Acknowledge(id)
            ctx.Push("reader");ctx.choosingLetter=false
            if userInitiated and entering and not ctx.portrait and ctx.panel=="reader" then ctx.PlayObjectSound("letter_pick") end
        end
        return result
    end
    function ctx.OpenPaper()
        if ctx.atTitle or (ctx.journeyView and ctx.journeyView.busy) then return end
        if ctx.calendar and ctx.calendar.motion.active then return end
        local result=session.queries.GetLetters()
        if not result.ok then model.Notify(result); return end
        local known={}; for _,row in ipairs(result.value) do known[row.letterInstanceId]=true end
        local id=known[model.selectedLetter] and model.selectedLetter or false
        local data=model.Refresh(); local order=data and data.currentOrder
        if not id and order and known[order.letterInstanceId] then id=order.letterInstanceId end
        if id then ctx.Read(id,true)
        else
            if ctx.panel~="letters" then objectOpen="letters" end
            ctx.panel="letters"; ctx.stack={}; ctx.choosingLetter=true; model.dirty=true
        end
    end
    function ctx.Open(kind)
        if ctx.atTitle or (ctx.journeyView and ctx.journeyView.busy) then return end
        if ctx.calendar and ctx.calendar.motion.active then return end
        if ctx.destroyed or ctx.portrait or ctx.zoom.active or ctx.salvage.active or ctx.yawProbe then return end
        if ctx.brew.interaction.active then return end
        ctx.brew.interaction.CancelDrag()
        if kind=="case" and content.release and not developer then return end
        if ctx.releasePhase and ctx.releasePhase~="operating" then
            if ctx.releasePhase=="ended" and kind~="ending" then return end
            if ctx.releasePhase=="closing_prepare" and kind~="closing" then return end
            if ctx.releasePhase=="closing" and kind~="closing" and kind~="wish" then return end
            if ctx.releasePhase=="wish" and kind~="wish" and kind~="wishPreview" and kind~="closing" then return end
        end
        if ctx.ticketEnding and kind~="ticketEnding" then return end
        if ctx.panel~=kind then objectOpen=kind end
        if ctx.readerCache and ctx.readerCache.presentation then ctx.readerCache.presentation.Cancel() end
        WordTray.Reset(ctx);JournalBook.Reset(ctx);LetterDrawer.Reset(ctx)
        ctx.ticketConfirm=false;ctx.ticketQuote=false
        if kind=="paper" then ctx.OpenPaper(); return end
        if kind=="home" or kind=="brew" or kind=="seaside" then ctx.Navigate(kind); return end
        if kind=="journal" and ctx.scene=="brew" then
            -- The workbench already owns this drawer. Reuse it after shipping.
            ctx.brew.OpenJournal(ctx.storyId)
            ctx.panel=false;ctx.stack={};ctx.readerCache=false;ctx.resultMotion=false;ctx.choosingLetter=false
            model.dirty=true;return
        end
        if ctx.journeyView then ctx.journeyView.Destroy();ctx.journeyView=false end
        ctx.panel=kind; ctx.stack={}; ctx.readerCache=false; ctx.choosingLetter=false; model.dirty=true
    end
    function ctx.OpenSettings()
        if ctx.atTitle or (ctx.journeyView and ctx.journeyView.busy) then return end
        if ctx.calendar and ctx.calendar.motion.active then return end
        if ctx.destroyed or ctx.portrait or ctx.zoom.active or ctx.salvage.active or ctx.yawProbe then return end
        if settings.IsOpen() then return end
        settings.Open()
        ctx.PlayObjectSound("ui_click_01")
    end
    local function leaveJourneyView()
        if ctx.journeyView then ctx.journeyView.Destroy();ctx.journeyView=false end
        if ctx.readerCache and ctx.readerCache.presentation then ctx.readerCache.presentation.Cancel() end
        WordTray.Reset(ctx);JournalBook.Reset(ctx);LetterDrawer.Reset(ctx)
        ctx.brew.Leave();ctx.resultMotion=false;ctx.feedback.Cancel();objectOpen=false
        ctx.CancelHomeZoom("title");ctx.CancelSalvage("title")
        ctx.stack={};ctx.readerCache=false;ctx.ticketConfirm=false;ctx.ticketQuote=false
    end
    function ctx.ShowTitle()
        if ctx.destroyed or (ctx.calendar and ctx.calendar.motion.active) or (ctx.journeyView and ctx.journeyView.busy) then return false end
        if not rawget(session.queries,"GetEndingView") then return false end
        leaveJourneyView();ctx.atTitle=true;ctx.scene="home";ctx.panel="title"
        ctx.newPlaythroughConfirm=false;ctx.endingShowCollage=false;ctx.reviewEnding=false;model.dirty=true
        return true
    end
    function ctx.ContinueJourney()
        if ctx.destroyed then return false end
        local saved=session.queries.GetEndingView()
        if not saved.ok then model.Notify(saved);return false end
        if not saved.value.hasProgress and not model.StartJourney().ok then return false end
        leaveJourneyView();ctx.atTitle=false;ctx.scene="home";ctx.endingShowCollage=false
        local phase=saved.value.phase
        ctx.panel=phase=="ended" and "ending" or phase=="wish" and "wish" or phase~="operating" and "closing" or false
        model.dirty=true;return true
    end
    function ctx.ShowMemory(ending)
        if ctx.destroyed or not ctx.atTitle then return false end
        leaveJourneyView();ctx.reviewEnding=require("core.StateUtil").Copy(ending);ctx.endingShowCollage=false
        ctx.panel="memoryReview";model.dirty=true;return true
    end
    local back=Harbor.Button {id="returnHome",text="返回主页",width=106,minHeight=44,visible=false,onClick=function() ctx.Navigate("home") end}
    hud:AddChild(back)
    pending=Harbor.Button {id="resumePending",text="待处理结果",width=114,minHeight=44,visible=false,onClick=function() ctx.Open("result") end}
    hud:AddChild(pending)
    hud:AddChild(Harbor.Button {id="openSettings",text="设置",width=72,minHeight=44,onClick=ctx.OpenSettings})
    hud:AddChild(Harbor.Button {id="toggleHomeHints",text="提示",width=72,minHeight=44,onClick=function()
        if not ctx.destroyed and not ctx.portrait and not ctx.panel and not settings.IsOpen()
            and ctx.scene=="home" and not ctx.zoom.active and not ctx.salvage.active then
            local before=home.HintsVisible();home.ShowHints(not before)
            if home.HintsVisible()~=before then ctx.PlayObjectSound("ui_click_01") end
        end
    end})
    hud:AddChild(Harbor.Button {id="nextDay",text="结束当天",width=108,minHeight=44,fontSize=15,onClick=function() ctx.Open("day") end})
    hud:AddChild(Harbor.Button {id="titleHome",text="首页",width=72,minHeight=44,fontSize=15,onClick=ctx.ShowTitle})
    if yawEnabled then
        hud:AddChild(Harbor.Button {id="openHomeYawProbe",text="转头验证",width=106,minHeight=44,onClick=ctx.OpenYawProbe})
    end
    if developer then
        hud:AddChild(Harbor.Button {id="toggleHomeHotspots",text="热区检查",width=98,minHeight=44,onClick=function()
            if ctx.zoom.active or ctx.yawProbe then return end
            home.SetInspect(not home.inspect); model.dirty=true
        end})
    end
    local function renderPanel()
        if ctx.journeyView then ctx.journeyView.Destroy();ctx.journeyView=false end
        if ctx.readerCache and ctx.readerCache.presentation then ctx.readerCache.presentation.Cancel() end
        clear(overlay); ctx.readerCache=false; ctx.panelNotice=false;ctx.panelNoticeArea=false;ctx.panelHeader=false
        if not ctx.panel then return end
        local kind=ctx.panel; local location=side[kind]
        if not location then
            -- Keep the blocker through pointer-up; only rebuild on Update.
            local blocker=UI.Panel {id="modalBlocker",position="absolute",left=0,top=0,width="100%",height="100%",
                backgroundColor=kind=="day" and {24,22,18,105} or {18,24,20,190},onClick=function() end}
            -- 抽屉跟侧栏一样先滑回去再关；其它面板保持吞掉点击。
            if kind=="letters" then blocker.props.onClick=function() LetterDrawer.RequestClose(ctx) end end
            overlay:AddChild(blocker)
        end
        local audible=objectOpen==kind;objectOpen=false
        if audible and clickPanels[kind] then ctx.PlayObjectSound("ui_click_01") end
        if kind=="day" then overlay:AddChild(Calendar.New(ctx).root);return end
        if kind=="shop" then Shop.Render(ctx,overlay);return end
        if kind=="words" then WordTray.Open(ctx,audible);WordTray.Render(ctx,overlay);return end
        if kind=="journal" then JournalBook.Open(ctx,audible);JournalBook.Render(ctx,overlay);return end
        if kind=="letters" then LetterDrawer.Open(ctx,audible);LetterDrawer.Render(ctx,overlay);return end
        if kind=="result" or kind=="attempt" then ResultView.Render(ctx,overlay,kind=="attempt");return end
        if kind=="ticketEnding" then TicketView.Ending(ctx,overlay);return end
        if kind=="closing" or kind=="wish" or kind=="wishPreview" or kind=="ending" or kind=="title" or kind=="memories" or kind=="memoryReview" then
            local module=(kind=="title" or kind=="memories") and Title or kind=="closing" and Closing or (kind=="ending" or kind=="memoryReview") and Ending or Wish
            local view=module.New(ctx)
            if view.room then
                local blocker=overlay:FindById("modalBlocker")
                if blocker then blocker.props.backgroundColor={0,0,0,0} end
            end
            ctx.journeyView=view;overlay:AddChild(view.root);return
        end
        local safe=ctx.safeInsets or {left=0,top=0,right=0,bottom=0}
        local viewport=ctx.viewport
        local panelProps={id="activePanel",position="absolute",top=location and 0 or "3%",bottom=location and 0 or "3%",
            width=location and "38%" or "92%",minWidth=location and 260 or nil,maxWidth=location and "85%" or nil,
            padding=32,overflow="hidden",onClick=function() end} --[[@as PanelProps]]
        if location=="right" then panelProps.right=0 else panelProps.left=location and 0 or "4%" end
        if viewport then
            panelProps.top=location=="right" and HudLayout.SidePanelTop(viewport,safe,ctx.menuRect) or safe.top+(location and 12 or viewport.h*.03)
            panelProps.bottom=safe.bottom+(location and 12 or viewport.h*.03)
            if location=="right" then panelProps.right=safe.right+12
            else panelProps.left=safe.left+(location and 12 or (viewport.w-safe.left-safe.right)*.04) end
            if not location then panelProps.width=(viewport.w-safe.left-safe.right)*.92 end
        end
        if kind=="reader" then
            -- The paper's torn alpha edge extends beyond the old 18px slices.
            -- Inset the entire header/scroll frame, not just the scroll content:
            -- inner padding alone would still clip scrolling text at the paper edge.
            panelProps.padding=32
            panelProps.paddingBottom=68
            panelProps.backgroundSlice={32,32,32,32}
        end
        local panel=Harbor.Paper(panelProps)
        overlay:AddChild(panel)
        local bar=UI.Panel {id="panelHeader",width="100%",height=50,flexShrink=0,flexDirection="row",alignItems="center",paddingLeft=16,paddingRight=12,gap=8,pointerEvents="box-none"}
        ctx.panelHeader=bar
        bar:AddChild(UI.Label {text=titles[kind] or "",fontSize=16,fontFamily=Harbor.fontFamily,flexGrow=1,minWidth=0,fontColor={55,48,36,255}})
        bar:AddChild(Harbor.Button {id="closePanel",text=#ctx.stack>0 and "返回" or "关闭",width=76,minHeight=44,onClick=ctx.Close})
        panel:AddChild(bar)
        local current=ctx.messages:Current(clock())
        local panelNotice=UI.Label {id="panelMessage",text=current.text,fontSize=14,fontFamily=Harbor.fontFamily,fontColor={108,53,30,255},whiteSpace="normal",flexShrink=0,pointerEvents="none"}
        local panelNoticeArea=UI.ScrollView {width="100%",height=44,visible=current.visible and kind~="reader",flexShrink=0,scrollY=true,paddingLeft=16,paddingRight=16,children={panelNotice}}
        panel:AddChild(panelNoticeArea);ctx.panelNoticeArea=panelNoticeArea
        ctx.panelNotice=panelNotice
        local body,scroll=bodyIn(panel,"playScroll"); ctx.scroll=scroll
        assert(Panels.Renderers[kind])(ctx,body)
    end
    local function syncSavedTicketEnding()
        local endingQuery=rawget(session.queries,"GetEndingView")
        if endingQuery then
            local saved=endingQuery()
            if not saved.ok then model.Notify(saved);return end
            local phase=saved.value.phase
            local changed=phase~=ctx.releasePhase
            ctx.releasePhase=phase
            if ctx.atTitle then return end
            if changed then
                if ctx.readerCache and ctx.readerCache.presentation then ctx.readerCache.presentation.Cancel() end
                WordTray.Reset(ctx);JournalBook.Reset(ctx);LetterDrawer.Reset(ctx);ctx.brew.Leave();ctx.CancelHomeZoom("releasePhase");ctx.CancelSalvage("releasePhase")
                ctx.stack={};ctx.readerCache=false;ctx.ticketEnding=false;ctx.ticketConfirm=false;ctx.ticketQuote=false
                ctx.newPlaythroughConfirm=false;ctx.scene="home"
                ctx.panel=phase=="ended" and "ending" or phase=="wish" and "wish" or phase~="operating" and "closing" or false
            end
            if phase=="ended" then ctx.panel="ending"
            elseif phase=="closing_prepare" and ctx.panel~="reader" then ctx.panel="closing"
            elseif phase=="closing" and ctx.panel~="closing" then ctx.panel="closing"
            elseif phase=="wish" and ctx.panel~="wish" and ctx.panel~="wishPreview" and ctx.panel~="closing" then ctx.panel="wish" end
            return
        end
        local query=rawget(session.queries,"GetTravelTicketView")
        if not query then return end
        local saved=query()
        local value=saved.ok and saved.value
        if value and value.departed==true and type(value.ending)=="table" and type(value.ending.title)=="string" and type(value.ending.text)=="string" then
            ctx.ticketEnding=value.ending;ctx.panel="ticketEnding";ctx.stack={};ctx.ticketConfirm=false;ctx.ticketQuote=false
        end
    end
    function ctx.Update()
        if ctx.destroyed then return end
        settings.Update()
        if ctx.yawProbe then ctx.yawProbe.Update() end
        if yawAuto then yawAuto(ctx) end
        if stoveAuto then stoveAuto(ctx) end
        if panZoomAuto then panZoomAuto(ctx) end
        if brewProbe then brewProbe(ctx) end
        if firstBatchProbe then firstBatchProbe(ctx) end
        if readingProbe then readingProbe(ctx) end
        if apprenticeProbe then apprenticeProbe(ctx) end
        if wishProbe then wishProbe(ctx) end
        if mobileBrewProbe then mobileBrewProbe(ctx) end
        local now,dt=clock();home.Update(dt)
        ctx.UpdateChrome()
        if ctx.scene=="brew" then ctx.brew.Update(dt,input:HasFocus() and not input:IsMinimized()) end
        if ctx.resultMotion then ResultView.Update(ctx,dt,input:HasFocus() and not input:IsMinimized()) end
        ctx.feedback.Update(dt)
        if ctx.journeyView and ctx.journeyView.Update then
            ctx.journeyView.Update(dt,not ctx.portrait and input:HasFocus() and not input:IsMinimized())
            if ctx.journeyView.busy then return end
        end
        -- Retain the old sheet after the save. Defer phase routing and dirty-tree
        -- rebuilds until its visual transition ends; Update never calls NextDay.
        if ctx.calendar and ctx.calendar.motion.active then
            local done=ctx.calendar.Update(dt,not ctx.portrait and input:HasFocus() and not input:IsMinimized())
            if not done then return end
            ctx.panel=false;ctx.stack={};model.dirty=true
        end
        if ctx.readerCache and ctx.readerCache.presentation then
            ctx.readerCache.presentation.Update(dt,input:HasFocus() and not input:IsMinimized())
        end
        WordTray.Update(ctx,dt);JournalBook.Update(ctx,dt);LetterDrawer.Update(ctx,dt)
        if ctx.scene=="seaside" then seaside.Update(GetTime():GetTimeStep()) end
        if ctx.salvage.active then
            local clock=GetTime()
            local previousPhase=ctx.salvage.Pose().phase
            local result=ctx.salvage.Update(clock:GetTimeStep(),seaside.Fit(),input:HasFocus() and not input:IsMinimized(),clock:GetElapsedTime())
            if ctx.salvage.active and previousPhase~="lifting" and ctx.salvage.Pose().phase=="lifting" then
                ctx.PlayObjectSound("bottle_lift")
            end
            if result then
                salvageBlocker:SetVisible(false);model.dirty=true
                if result=="complete" then ctx.OpenCapturedLetter()
                else model.message="信已收好，可继续阅读，也可从药铺抽屉查看。" end
            end
        end
        -- main already calls this every Update. Advance BEFORE the business dirty guard.
        if ctx.zoom.active then
            local clock=GetTime()
            local destination=ctx.zoom.profile and ctx.zoom.profile.destination or "seaside"
            local result=ctx.zoom.Update(clock:GetTimeStep(),home.Fit(),input:HasFocus() and not input:IsMinimized(),clock:GetElapsedTime(),home.root:GetAbsoluteLayout())
            home.SetZoom(ctx.zoom.scale)
            if ctx.zoom.profile then home.SetPanZoom(ctx.zoom.scale,ctx.zoom.panX,ctx.zoom.panY) end
            if result=="complete" then ctx.Navigate(destination)
            elseif result=="cancelled" then ctx.CancelHomeZoom(ctx.zoom.reason) end
        end
        if nativeProbe then nativeProbe(ctx) end
        if not model.dirty then return end
        -- The draft is already persisted. Keep the landing's first frames free
        -- of rebuilding both drawers and the recipe; consume dirty after landing.
        local flight=ctx.brew.interaction.flight
        if ctx.scene=="brew" and not ctx.panel and flight and flight.accepted then return end
        model.dirty=false
        local data=model.Refresh()
        ctx.messages:Observe(model.message,now,ctx.importantMessage==model.message)
        if not data then return end
        syncSavedTicketEnding()
        music.Sync(ctx.scene,departureMusic and "departure" or ctx.panel)
        ledger:SetText(string.format("金币 %d   ·   第 %d 天",ctx.feedback.Currency(data.live.economy.currency,data.live.gameFlow.day),data.live.gameFlow.day))
        pending:SetVisible(ctx.scene~="brew" and not ctx.ticketEnding and not not (data.currentOrder and data.currentOrder.pending))
        local hints=hud:FindById("toggleHomeHints")
        if hints then hints:SetVisible(ctx.scene=="home") end
        back:SetVisible(not ctx.ticketEnding and ctx.scene~="home")
        local dayButton=hud:FindById("nextDay")
        if dayButton then dayButton:SetVisible(not ctx.ticketEnding) end
        local finishButton=hud:FindById("finishJourney")
        if finishButton then
            local query=rawget(session.queries,"GetReleaseProgress")
            local progress=query and query()
            finishButton:SetVisible(progress and progress.ok and progress.value.canClose and ctx.releasePhase=="operating" or false)
        end
        if developer and home.inspect then notice:SetText("热区检查 · "..(home.lastHit~="" and home.lastHit or "点击主体查看命中")) end
        if model.letterEdited and ctx.panel=="reader" and Panels.RefreshReader(ctx) then model.letterEdited=false; return end
        model.letterEdited=false
        home.root:SetVisible(ctx.scene=="home");seaside.root:SetVisible(ctx.scene=="seaside")
        ctx.brew.root:SetVisible(ctx.scene=="brew")
        scene:SetVisible(ctx.scene~="home" and ctx.scene~="seaside" and ctx.scene~="brew")
        seaside.Refresh()
        clear(scene)
        if ctx.scene=="brew" then ctx.brew.Refresh()
        elseif ctx.scene~="home" and ctx.scene~="seaside" then local body=bodyIn(scene,"sceneScroll"); assert(Panels.Renderers[ctx.scene])(ctx,body) end
        renderPanel()
        ctx.UpdateChrome()
    end
    function ctx.Refresh() model.dirty=true end
    -- Saved pending results stay accessible in HUD; entering does not consume them.
    model.ReturnHome(); ctx.Update()
    return ctx
end
return A
