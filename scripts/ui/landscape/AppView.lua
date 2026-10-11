local UI=require "urhox-libs/UI"
local Model=require "ui.PlayModel"
local Home=require "ui.landscape.HomeView"
local Panels=require "ui.landscape.Panels"
local Zoom=require "ui.landscape.HomeZoom"
local A={}
local side={words="left",journal="right"}
local titles={letters="来信抽屉",reader="阅读信件",words="词条栏",journal="故事记录",attempt="试做记录",shop="商队商店",case="案件板",day="结束当天",result="试做结果"}
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
    local developer=(require("debug.DeveloperMode") or require("ui.landscape.DevChecks").hotspots) --[[@as boolean]]
    -- main owns SafeAreaView; fill its mainPanel without shrinking under old headings.
    local root=UI.Panel {id="playPanel",position="absolute",left=0,top=0,width="100%",height="100%",
        backgroundColor={48,42,34,255},pointerEvents="box-none",overflow="hidden"}
    local hud=UI.Panel {id="homeHud",width="100%",height=48,flexShrink=0,flexDirection="row",alignItems="center",gap=10,paddingLeft=12,paddingRight=8,pointerEvents="box-none",backgroundColor={40,42,33,245}}
    local ledger=UI.Label {id="playLedger",fontSize=16,fontColor={255,239,208,255},flexGrow=1,minWidth=0,pointerEvents="none"}
    hud:AddChild(ledger); root:AddChild(hud)
    local stage=UI.Panel {id="homeStage",width="100%",flexGrow=1,flexShrink=1,flexBasis=0,minHeight=0,pointerEvents="box-none"}
    root:AddChild(stage)
    local notice=UI.Label {id="playMessage",fontSize=14,fontColor={255,229,179,255},whiteSpace="normal",flexShrink=0,pointerEvents="none"}
    local noticeArea=UI.ScrollView {id="playMessageArea",width="100%",height=36,flexShrink=0,scrollY=true,paddingLeft=12,paddingRight=12,children={notice}}
    root:AddChild(noticeArea)
    local ctx={root=root,model=model,session=session,content=content,
        scene="home" --[[@as string]],panel=false --[[@as string|false]],stack={},
        storyId=false --[[@as string|false]],readerCache=false --[[@as table|false]],choosingLetter=false --[[@as boolean]],
        panelNotice=false --[[@as Label|false]],zoom=Zoom.New(),destroyed=false --[[@as boolean]]}
    local home=Home.New(function(target,id)
        if id=="home.net" then ctx.BeginHomeZoom() else ctx.Open(target) end
    end,developer); stage:AddChild(home.root); ctx.home=home
    home.SetInspect(require("ui.landscape.DevChecks").hotspots)
    local scene=UI.Panel {id="functionalScene",position="absolute",left=0,top=0,width="100%",height="100%",visible=false,backgroundColor={238,228,203,255}}
    stage:AddChild(scene)
    local overlay=UI.Panel {id="overlayHost",position="absolute",left=0,top=0,width="100%",height="100%",pointerEvents="box-none"}
    root:AddChild(overlay)
    -- Stable topmost blocker: blocks HUD and all room inputs without rebuilding the tree.
    local zoomBlocker=UI.Panel {id="homeZoomBlocker",position="absolute",left=0,top=0,width="100%",height="100%",
        zIndex=1000,visible=false,pointerEvents="box-only",onClick=function() end}
    root:AddChild(zoomBlocker)
    function ctx.CancelHomeZoom(reason)
        ctx.zoom.Reset(reason);home.SetZoom(1);home.SetBlocked(false);zoomBlocker:SetVisible(false)
    end
    function ctx.BeginHomeZoom()
        if ctx.destroyed or ctx.scene~="home" or (ctx.panel and not side[ctx.panel]) then return false end
        if not ctx.zoom.Start(home.Fit(),GetTime():GetElapsedTime()) then return false end
        home.SetBlocked(true);zoomBlocker:SetVisible(true)
        if ctx.panel then ctx.panel=false;ctx.stack={};model.dirty=true end
        return true
    end
    local destroyRoot=root.Destroy
    function root:Destroy()
        ctx.destroyed=true;ctx.CancelHomeZoom("destroyed");destroyRoot(self)
    end
    function ctx.Navigate(target)
        if ctx.destroyed then return end
        ctx.CancelHomeZoom("navigate")
        ctx.scene=target; ctx.panel=false; ctx.stack={}; ctx.readerCache=false; ctx.choosingLetter=false
        if target=="home" then model.ReturnHome() else model.Navigate(target) end
        model.dirty=true
    end
    function ctx.Push(kind)
        if ctx.destroyed or ctx.zoom.active then return end
        ctx.stack[#ctx.stack+1]=ctx.panel or false; ctx.panel=kind; ctx.readerCache=false; model.dirty=true
    end
    function ctx.Close()
        if ctx.destroyed or ctx.zoom.active then return end
        ctx.panel=table.remove(ctx.stack) or false; ctx.readerCache=false
        model.Navigate(ctx.panel=="reader" and "letter" or ctx.scene)
    end
    function ctx.Read(id)
        if ctx.destroyed or ctx.zoom.active then return end
        local result=model.Read(id)
        if result.ok then ctx.Push("reader"); ctx.choosingLetter=false end
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
        if ctx.destroyed or ctx.zoom.active then return end
        if kind=="paper" then ctx.OpenPaper(); return end
        if kind=="home" or kind=="brew" or kind=="seaside" then ctx.Navigate(kind); return end
        ctx.panel=kind; ctx.stack={}; ctx.readerCache=false; ctx.choosingLetter=false; model.dirty=true
    end
    local back=UI.Button {id="returnHome",text="返回主页",width=106,minHeight=44,visible=false,onClick=function() ctx.Navigate("home") end}
    hud:AddChild(back)
    local pending=UI.Button {id="resumePending",text="待处理结果",width=114,minHeight=44,visible=false,onClick=function() ctx.Open("result") end}
    hud:AddChild(pending)
    hud:AddChild(UI.Button {id="nextDay",text="结束当天",width=108,minHeight=44,fontSize=15,onClick=function() ctx.Open("day") end})
    if developer then
        hud:AddChild(UI.Button {id="toggleHomeHotspots",text="热区检查",width=98,minHeight=44,onClick=function()
            if ctx.zoom.active then return end
            home.SetInspect(not home.inspect); model.dirty=true
        end})
    end
    local function renderPanel()
        clear(overlay); ctx.readerCache=false; ctx.panelNotice=false
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
        local bar=UI.Panel {width="100%",height=50,flexShrink=0,flexDirection="row",alignItems="center",paddingLeft=16,paddingRight=6,gap=8,pointerEvents="box-none"}
        bar:AddChild(UI.Label {text=titles[kind] or "",fontSize=17,flexGrow=1,minWidth=0,fontColor={55,48,36,255}})
        bar:AddChild(UI.Button {id="closePanel",text=#ctx.stack>0 and "返回" or "关闭",width=76,minHeight=44,onClick=ctx.Close})
        panel:AddChild(bar)
        local panelNotice=UI.Label {id="panelMessage",text=model.message,fontSize=14,fontColor={108,53,30,255},whiteSpace="normal",flexShrink=0,pointerEvents="none"}
        panel:AddChild(UI.ScrollView {width="100%",height=36,flexShrink=0,scrollY=true,paddingLeft=16,paddingRight=16,children={panelNotice}})
        ctx.panelNotice=panelNotice
        local body,scroll=bodyIn(panel,"playScroll"); ctx.scroll=scroll
        assert(Panels.Renderers[kind])(ctx,body)
    end
    function ctx.Update()
        if ctx.destroyed then return end
        -- main already calls this every Update. Advance BEFORE the business dirty guard.
        if ctx.zoom.active then
            local clock=GetTime()
            local result=ctx.zoom.Update(clock:GetTimeStep(),home.Fit(),input:HasFocus() and not input:IsMinimized(),clock:GetElapsedTime())
            home.SetZoom(ctx.zoom.scale)
            if result=="complete" then ctx.Navigate("seaside")
            elseif result=="cancelled" then ctx.CancelHomeZoom(ctx.zoom.reason) end
        end
        if nativeProbe then nativeProbe(ctx) end
        if not model.dirty then return end
        model.dirty=false
        local data=model.Refresh()
        notice:SetText(model.message)
        if ctx.panelNotice then ctx.panelNotice:SetText(model.message) end
        if not data then return end
        ledger:SetText(string.format("金币 %d   ·   第 %d 天",data.live.economy.currency,data.live.gameFlow.day))
        pending:SetVisible(not not (data.currentOrder and data.currentOrder.pending))
        back:SetVisible(ctx.scene~="home")
        if developer and home.inspect then notice:SetText("热区检查 · "..(home.lastHit~="" and home.lastHit or "点击主体查看命中")) end
        if model.letterEdited and ctx.panel=="reader" and Panels.RefreshReader(ctx) then model.letterEdited=false; return end
        model.letterEdited=false
        home.root:SetVisible(ctx.scene=="home"); scene:SetVisible(ctx.scene~="home")
        clear(scene)
        if ctx.scene~="home" then local body=bodyIn(scene,"sceneScroll"); assert(Panels.Renderers[ctx.scene])(ctx,body) end
        renderPanel()
    end
    function ctx.Refresh() model.dirty=true end
    -- Saved pending results stay accessible in HUD; entering does not consume them.
    model.ReturnHome(); ctx.Update()
    return ctx
end
return A
