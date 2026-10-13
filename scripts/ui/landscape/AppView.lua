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
local SeaArt=require "ui.landscape.SeaArt"
local A={}
local side={words="left",journal="right"}
local titles={letters="来信抽屉",reader="阅读信件",words="词条栏",journal="故事记录",attempt="试做记录",shop="商队商店",case="案件板",day="结束当天",result="试做结果"}
local function clock()
    local get=rawget(_G,"GetTime")
    if not get then return 0,0 end
    local time=get();return time:GetElapsedTime(),time:GetTimeStep()
end
local function clear(parent)
    for i=parent:GetNumChildren(),1,-1 do local child=parent:GetChildAt(i); if child then child:Destroy() end end
end
local function bodyIn(parent,id)
    local scroll=UI.ScrollView {id=id,width="100%",flexGrow=1,flexShrink=1,flexBasis=0,scrollY=true,showScrollbar=true}
    local body=UI.Panel {alignSelf="stretch",flexShrink=0,padding=18,paddingRight=24,gap=10,pointerEvents="box-none"}
    scroll:AddChild(body); parent:AddChild(scroll); return body,scroll
end
function A.New(session,content,enabled)
    local model=Model.New(session,content,enabled)
    local nativeProbe=require("ui.landscape.DevChecks").nativeProbe and require("ui.landscape.tests.NativeProbe").New() or nil
    local yawEnabled=require("ui.landscape.DevChecks").yawProbe
    local yawAuto=yawEnabled and require("ui.landscape.DevChecks").yawProbeAuto and require("ui.landscape.tests.YawNativeProbe").New() or nil
    local stoveAuto=require("ui.landscape.DevChecks").stoveYawAuto and require("ui.landscape.tests.StoveYawNativeProbe").New() or nil
    local panZoomAuto=require("ui.landscape.DevChecks").stovePanZoomAuto and require("ui.landscape.tests.StovePanZoomNativeProbe").New() or nil
    local developer=(require("debug.DeveloperMode") or require("ui.landscape.DevChecks").hotspots) --[[@as boolean]]
    -- main owns SafeAreaView; fill its mainPanel without shrinking under old headings.
    local root=UI.Panel {id="playPanel",position="absolute",left=0,top=0,width="100%",height="100%",
        backgroundColor={48,42,34,255},pointerEvents="box-none",overflow="hidden"}
    local hud=UI.Panel {id="homeHud",position="absolute",top=8,left=0,width="100%",height=48,flexShrink=0,
        flexDirection="row",alignItems="center",gap=8,paddingLeft=12,paddingRight=12,pointerEvents="box-none"}
    local ledger=UI.Label {id="playLedger",fontSize=16,fontColor={65,46,28,255},minWidth=0,pointerEvents="none"}
    local ledgerCard=Harbor.Paper {width=236,height=44,justifyContent="center",children={ledger}}
    hud:AddChild(ledgerCard);hud:AddChild(UI.Panel {flexGrow=1,minWidth=0,pointerEvents="none"})
    local stage=UI.Panel {id="homeStage",width="100%",flexGrow=1,flexShrink=1,flexBasis=0,minHeight=0,pointerEvents="box-none"}
    root:AddChild(stage)
    local notice=UI.Label {id="playMessage",fontSize=14,fontColor={65,46,28,255},whiteSpace="normal",flexShrink=0,pointerEvents="none"}
    local noticeArea=UI.ScrollView {id="playMessageArea",position="absolute",left=14,bottom=12,width="70%",maxWidth=680,
        minHeight=44,maxHeight=96,visible=false,scrollY=true,padding=12,pointerEvents="box-none",
        backgroundColor={244,232,208,255},borderColor={174,142,91,255},borderWidth=1,borderRadius=2,children={notice}} --[[@as Widget]]
    root:AddChild(noticeArea)
    local ctx={root=root,model=model,session=session,content=content,
        scene="home" --[[@as string]],panel=false --[[@as string|false]],stack={},
        storyId=false --[[@as string|false]],readerCache=false --[[@as table|false]],choosingLetter=false --[[@as boolean]],
        panelNotice=false --[[@as Label|false]],panelNoticeArea=false --[[@as ScrollView|false]],
        panelHeader=false --[[@as Widget|false]],
        zoom=Zoom.New(),salvage=Salvage.New(),destroyed=false --[[@as boolean]],portrait=false --[[@as boolean]],
        yawProbe=false --[[@as table|false]],
        messages=Messages.New(session.state.GetStatus().migrationNotice),importantMessage=false --[[@as string|false]]}
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
    end,developer); stage:AddChild(home.root); ctx.home=home
    home.SetInspect(require("ui.landscape.DevChecks").hotspots)
    local scene=UI.Panel {id="functionalScene",position="absolute",left=0,top=0,width="100%",height="100%",paddingTop=64,visible=false,backgroundColor={238,228,203,255}}
    stage:AddChild(scene)
    local seaside=Seaside.New(ctx);stage:AddChild(seaside.root);ctx.seaside=seaside
    root:AddChild(hud)
    -- Explicit order: equal-z siblings are not stably sorted by the UI library.
    local overlay=UI.Panel {id="overlayHost",position="absolute",left=0,top=0,width="100%",height="100%",zIndex=100,pointerEvents="box-none"}
    root:AddChild(overlay)
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
        local bounds=root:GetAbsoluteLayout()
        local vw,vh=bounds.w,bounds.h
        if UI.GetViewportSize then vw,vh=UI.GetViewportSize() end
        local hostSdk=rawget(_G,"sdk")
        local menu=hostSdk and hostSdk.GetNativeExitMenuRect and hostSdk:GetNativeExitMenuRect() or nil
        local required=236+12+108+72+24+(ctx.scene~="home" and 114 or 0)+(pending and pending.props.visible and 122 or 0)
        local offsets=HudLayout.Compute({x=bounds.x,y=bounds.y+8,w=bounds.w,h=48},{w=vw,h=vh},menu,required)
        local p=hud.props
        if p.top~=8+offsets.top or p.paddingRight~=offsets.right then
            if hud.SetStyle then hud:SetStyle({top=8+offsets.top,paddingRight=offsets.right})
            else p.top=8+offsets.top;p.paddingRight=offsets.right end
        end
        local contentTop=64+offsets.top
        if scene.props.paddingTop~=contentTop then
            if scene.SetStyle then scene:SetStyle({paddingTop=contentTop}) else scene.props.paddingTop=contentTop end
        end
        if ctx.panelHeader and ctx.panelHeader.GetAbsoluteLayout then
            local header=ctx.panelHeader
            local r=header:GetAbsoluteLayout()
            -- Compute from the unshifted position so a fallback margin cannot
            -- alternate between clearing the capsule and undoing itself.
            local safe=HudLayout.Compute({x=r.x,y=r.y-(header.props.marginTop or 0),w=r.w,h=r.h},{w=vw,h=vh},menu,250)
            if header.props.paddingRight~=safe.right or header.props.marginTop~=safe.top then
                if header.SetStyle then Widget.SetStyle(header,{paddingRight=safe.right,marginTop=safe.top})
                else header.props.paddingRight=safe.right;header.props.marginTop=safe.top end
            end
        end
        local portrait=vw<vh
        if ctx.portrait~=portrait then
            ctx.portrait=portrait;rotateGuard:SetVisible(portrait)
            if portrait then ctx.CancelHomeZoom("portrait");ctx.CancelSalvage("portrait") end
        end
        local now=clock()
        ctx.messages:Observe(model.message,now,ctx.importantMessage==model.message)
        local current=ctx.messages:Current(now)
        notice:SetText(current.text);noticeArea:SetVisible(current.visible and not ctx.panel and not ctx.salvage.active)
        local bottom=ctx.scene=="seaside" and 86 or 12
        if noticeArea.SetStyle and noticeArea.props.bottom~=bottom then Widget.SetStyle(noticeArea,{bottom=bottom}) end
        if ctx.panelNotice then ctx.panelNotice:SetText(current.text) end
        if ctx.panelNoticeArea then ctx.panelNoticeArea:SetVisible(current.visible) end
    end
    function ctx.CancelSalvage(reason)
        local active=ctx.salvage.active
        ctx.salvage.Cancel(reason);salvageBlocker:SetVisible(false)
        if active then
            model.dirty=true
            if ctx.salvage.letterInstanceId then model.message="信已收好，可继续阅读，也可从药铺抽屉查看。" end
        end
    end
    function ctx.OpenCapturedLetter()
        if ctx.destroyed or ctx.salvage.active or ctx.panel or ctx.scene~="seaside" then return false end
        local id=ctx.salvage.letterInstanceId;if not id then return false end
        local result=ctx.Read(id)
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
        ctx.destroyed=true
        if ctx.yawProbe then ctx.yawProbe.Close() end
        ctx.CancelHomeZoom("destroyed");ctx.CancelSalvage("destroyed");destroyRoot(self)
    end
    function ctx.OpenYawProbe()
        if not yawEnabled or ctx.destroyed or ctx.portrait or ctx.yawProbe or ctx.zoom.active or ctx.salvage.active or ctx.panel or ctx.scene~="home" then return false end
        ctx.yawProbe=require("ui.landscape.HomeYawProbe").New(root,function() ctx.yawProbe=false end)
        return true
    end
    function ctx.Navigate(target)
        if ctx.destroyed or ctx.salvage.active then return end
        if ctx.yawProbe then ctx.yawProbe.Close("navigate") end
        ctx.CancelHomeZoom("navigate")
        ctx.scene=target; ctx.panel=false; ctx.stack={}; ctx.readerCache=false; ctx.choosingLetter=false
        if target=="home" then model.ReturnHome() else model.Navigate(target) end
        model.dirty=true
    end
    function ctx.Push(kind)
        if ctx.destroyed or ctx.portrait or ctx.zoom.active or ctx.salvage.active or ctx.yawProbe then return end
        ctx.stack[#ctx.stack+1]=ctx.panel or false; ctx.panel=kind; ctx.readerCache=false; model.dirty=true
    end
    function ctx.Close()
        if ctx.destroyed or ctx.zoom.active or ctx.salvage.active or ctx.yawProbe then return end
        ctx.panel=table.remove(ctx.stack) or false; ctx.readerCache=false
        model.Navigate(ctx.panel=="reader" and "letter" or ctx.scene)
    end
    function ctx.Read(id)
        if ctx.destroyed or ctx.zoom.active or ctx.salvage.active or ctx.yawProbe then return end
        local result=model.Read(id)
        if result.ok then
            ctx.salvage.Acknowledge(id)
            ctx.Push("reader");ctx.choosingLetter=false
        end
        return result
    end
    function ctx.OpenPaper()
        local result=session.queries.GetLetters()
        if not result.ok then model.Notify(result); return end
        local known={}; for _,row in ipairs(result.value) do known[row.letterInstanceId]=true end
        local id=known[model.selectedLetter] and model.selectedLetter or false
        local data=model.Refresh(); local order=data and data.currentOrder
        if not id and order and known[order.letterInstanceId] then id=order.letterInstanceId end
        if id then ctx.Read(id)
        else ctx.panel="letters"; ctx.stack={}; ctx.choosingLetter=true; model.dirty=true end
    end
    function ctx.Open(kind)
        if ctx.destroyed or ctx.portrait or ctx.zoom.active or ctx.salvage.active or ctx.yawProbe then return end
        if kind=="paper" then ctx.OpenPaper(); return end
        if kind=="home" or kind=="brew" or kind=="seaside" then ctx.Navigate(kind); return end
        ctx.panel=kind; ctx.stack={}; ctx.readerCache=false; ctx.choosingLetter=false; model.dirty=true
    end
    local back=Harbor.Button {id="returnHome",text="返回主页",width=106,minHeight=44,visible=false,onClick=function() ctx.Navigate("home") end}
    hud:AddChild(back)
    pending=Harbor.Button {id="resumePending",text="待处理结果",width=114,minHeight=44,visible=false,onClick=function() ctx.Open("result") end}
    hud:AddChild(pending)
    hud:AddChild(Harbor.Button {id="toggleHomeHints",text="提示",width=72,minHeight=44,onClick=function()
        if ctx.scene=="home" and not ctx.zoom.active and not ctx.salvage.active then home.ShowHints(not home.HintsVisible()) end
    end})
    hud:AddChild(Harbor.Button {id="nextDay",text="结束当天",width=108,minHeight=44,fontSize=15,onClick=function() ctx.Open("day") end})
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
        clear(overlay); ctx.readerCache=false; ctx.panelNotice=false;ctx.panelNoticeArea=false;ctx.panelHeader=false
        if not ctx.panel then return end
        local kind=ctx.panel; local location=side[kind]
        if not location then
            -- Keep the blocker through pointer-up; only rebuild on Update.
            overlay:AddChild(UI.Panel {id="modalBlocker",position="absolute",left=0,top=0,width="100%",height="100%",
                backgroundColor={18,24,20,190},onClick=function() end})
        end
        local panelProps={id="activePanel",position="absolute",top=location and 0 or "3%",bottom=location and 0 or "3%",
            width=location and "38%" or "92%",minWidth=location and 260 or nil,maxWidth=location and "85%" or nil,
            backgroundColor={245,236,216,255},borderRadius=8,overflow="hidden",onClick=function() end}
        if location=="right" then panelProps.right=0 else panelProps.left=location and 0 or "4%" end
        local panel=UI.Panel(panelProps)
        overlay:AddChild(panel)
        local bar=UI.Panel {id="panelHeader",width="100%",height=50,flexShrink=0,flexDirection="row",alignItems="center",paddingLeft=16,paddingRight=12,gap=8,pointerEvents="box-none"}
        ctx.panelHeader=bar
        bar:AddChild(UI.Label {text=titles[kind] or "",fontSize=17,flexGrow=1,minWidth=0,fontColor={55,48,36,255}})
        bar:AddChild(Harbor.Button {id="closePanel",text=#ctx.stack>0 and "返回" or "关闭",width=76,minHeight=44,onClick=ctx.Close})
        panel:AddChild(bar)
        local current=ctx.messages:Current(clock())
        local panelNotice=UI.Label {id="panelMessage",text=current.text,fontSize=14,fontColor={108,53,30,255},whiteSpace="normal",flexShrink=0,pointerEvents="none"}
        local panelNoticeArea=UI.ScrollView {width="100%",height=44,visible=current.visible,flexShrink=0,scrollY=true,paddingLeft=16,paddingRight=16,children={panelNotice}}
        panel:AddChild(panelNoticeArea);ctx.panelNoticeArea=panelNoticeArea
        ctx.panelNotice=panelNotice
        local body,scroll=bodyIn(panel,"playScroll"); ctx.scroll=scroll
        assert(Panels.Renderers[kind])(ctx,body)
    end
    function ctx.Update()
        if ctx.destroyed then return end
        if ctx.yawProbe then ctx.yawProbe.Update() end
        if yawAuto then yawAuto(ctx) end
        if stoveAuto then stoveAuto(ctx) end
        if panZoomAuto then panZoomAuto(ctx) end
        local now,dt=clock();home.Update(dt)
        ctx.UpdateChrome()
        if ctx.scene=="seaside" then seaside.Update(GetTime():GetTimeStep()) end
        if ctx.salvage.active then
            local clock=GetTime()
            local result=ctx.salvage.Update(clock:GetTimeStep(),seaside.Fit(),input:HasFocus() and not input:IsMinimized(),clock:GetElapsedTime())
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
        model.dirty=false
        local data=model.Refresh()
        ctx.messages:Observe(model.message,now,ctx.importantMessage==model.message)
        if not data then return end
        ledger:SetText(string.format("金币 %d   ·   第 %d 天",data.live.economy.currency,data.live.gameFlow.day))
        pending:SetVisible(not not (data.currentOrder and data.currentOrder.pending))
        back:SetVisible(ctx.scene~="home")
        if developer and home.inspect then notice:SetText("热区检查 · "..(home.lastHit~="" and home.lastHit or "点击主体查看命中")) end
        if model.letterEdited and ctx.panel=="reader" and Panels.RefreshReader(ctx) then model.letterEdited=false; return end
        model.letterEdited=false
        home.root:SetVisible(ctx.scene=="home");seaside.root:SetVisible(ctx.scene=="seaside")
        scene:SetVisible(ctx.scene~="home" and ctx.scene~="seaside")
        seaside.Refresh()
        clear(scene)
        if ctx.scene~="home" and ctx.scene~="seaside" then local body=bodyIn(scene,"sceneScroll"); assert(Panels.Renderers[ctx.scene])(ctx,body) end
        renderPanel()
        ctx.UpdateChrome()
    end
    function ctx.Refresh() model.dirty=true end
    -- Saved pending results stay accessible in HUD; entering does not consume them.
    model.ReturnHome(); ctx.Update()
    return ctx
end
return A
