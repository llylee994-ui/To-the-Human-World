local UI=require "urhox-libs/UI"
local Panels=require "ui.landscape.Panels"
local H={}
local titles={shop="海上商店",letters="已收来信",reader="阅读与剪词",words="词卡",salvage="码头捕捞",brew="炼药工作区"}
local function clear(parent)
    for i=parent:GetNumChildren(),1,-1 do parent:GetChildAt(i):Destroy() end
end
local function btn(id,text,action)
    return UI.Button {id=id,text=text,minHeight=44,fontSize=15,paddingLeft=16,paddingRight=16,onClick=action,
        backgroundColor={70,86,68,255},textColor={255,246,220,255},borderRadius=7}
end
function H.New(ctx,rig,adapter,sceneView)
    local root=UI.Panel {id="labRoot",width="100%",height="100%",pointerEvents="box-none"}
    -- UI hit-testing is the only pointer entry. World input is a bottom sibling,
    -- so modal, scrolling and HUD events are processed by UI before any 3D ray.
    local sceneInput=UI.Panel {id="sceneInput",position="absolute",left=0,top=0,width="100%",height="100%",
        pointerEvents="box-only",onClick=function(_,event)
            if not event or (event.pointerType=="mouse" and event.button~=MOUSEB_LEFT) then return end
            local w,h=UI.GetViewportSize()
            local origin,direction=sceneView.Ray(event.x/w,event.y/h)
            adapter.Pointer(origin,direction,false)
        end}
    root:AddChild(sceneInput)
    local safe=UI.SafeAreaView {id="safeHud",width="100%",height="100%",pointerEvents="box-none"}
    root:AddChild(safe)
    local header=UI.Panel {position="absolute",top=10,left=12,right=12,height=50,flexDirection="row",alignItems="center",gap=10,
        paddingLeft=14,paddingRight=5,backgroundColor={44,49,39,238},borderRadius=8,pointerEvents="box-only",onClick=function() end}
    safe:AddChild(header)
    local ledger=UI.Label {id="ledger",text="寄往人间",fontSize=17,fontColor={255,239,205,255},flexGrow=1,minWidth=0,pointerEvents="none"}
    header:AddChild(ledger)
    local back=btn("returnHome","返回药铺",function() adapter.Navigate("Home") end); header:AddChild(back)
    local tray=btn("wordTray","词卡",function() adapter.Open("words") end); header:AddChild(tray)
    local footer=UI.Panel {position="absolute",bottom=10,left=12,right=12,minHeight=42,padding=10,
        backgroundColor={44,49,39,235},borderRadius=8,pointerEvents="box-only",onClick=function() end}
    local notice=UI.Label {id="notice",text="",fontSize=14,fontColor={250,236,206,255},whiteSpace="normal",pointerEvents="none"}
    footer:AddChild(notice); safe:AddChild(footer)
    local shore=btn("salvagePanel","捕捞来信",function() adapter.Open("salvage") end)
    local actions=UI.Panel {position="absolute",right=16,bottom=76,pointerEvents="box-none",children={shore}}
    safe:AddChild(actions)
    local overlay=UI.Panel {id="overlay",position="absolute",left=0,top=0,width="100%",height="100%",pointerEvents="box-none"}
    safe:AddChild(overlay)
    local motion=UI.Panel {id="motionBlocker",position="absolute",left=0,top=0,width="100%",height="100%",zIndex=1000,
        visible=false,pointerEvents="box-only",onClick=function() end}
    root:AddChild(motion)
    local panelCtx={model=ctx.model,session=ctx.session,content=ctx.content,labMinimal=true,readerCache=false,
        Read=adapter.Read,Open=adapter.Open,Close=adapter.Close}
    local ui={root=root,panelCtx=panelCtx}
    local lastRevision,lastMode=-1,""
    local function buildPanel()
        clear(overlay); panelCtx.readerCache=false
        local name=adapter.panel; if not name then return end
        local shade=UI.Panel {id="modalBlocker",position="absolute",left=0,top=0,width="100%",height="100%",
            backgroundColor={18,24,20,180},pointerEvents="box-only",onClick=function() end}
        overlay:AddChild(shade)
        local panel=UI.Panel {id="activePanel",position="absolute",top="7%",bottom="7%",left="12%",width="76%",
            backgroundColor={246,236,214,255},borderRadius=12,overflow="hidden",onClick=function() end}
        overlay:AddChild(panel)
        local bar=UI.Panel {width="100%",height=52,flexShrink=0,flexDirection="row",alignItems="center",paddingLeft=20,paddingRight=8,gap=8}
        bar:AddChild(UI.Label {text=titles[name] or "",fontSize=19,fontColor={61,53,36,255},flexGrow=1,minWidth=0})
        bar:AddChild(btn("closePanel","关闭",adapter.Close)); panel:AddChild(bar)
        local feedback=UI.Label {id="panelMessage",text=ctx.model.message,fontSize=14,fontColor={102,58,30,255},whiteSpace="normal",pointerEvents="none"}
        panel:AddChild(UI.ScrollView {height=38,flexShrink=0,scrollY=true,paddingLeft=20,paddingRight=20,children={feedback}})
        local scroll=UI.ScrollView {id="bodyScroll",width="100%",flexGrow=1,flexShrink=1,flexBasis=0,scrollY=true,showScrollbar=true}
        local body=UI.Panel {width="100%",padding=20,paddingRight=26,gap=12,flexShrink=0,pointerEvents="box-none"}
        scroll:AddChild(body); panel:AddChild(scroll)
        if name=="shop" then Panels.Shop(panelCtx,body)
        elseif name=="letters" then Panels.Letters(panelCtx,body)
        elseif name=="reader" then Panels.Reader(panelCtx,body)
        elseif name=="words" then
            local r=ctx.session.queries.GetWordTray()
            if not r.ok then Panels.Text(body,r.error.message)
            elseif #r.value.cards==0 then Panels.Text(body,"阅读来信并剪下标记词后，词卡会收在这里。")
            else for _,card in ipairs(r.value.cards) do Panels.Text(body,card.text.." · "..card.categoryId,19); Panels.Text(body,"来自："..card.sourceTitle,14) end end
        elseif name=="salvage" then
            local r=ctx.session.queries.GetSalvageView()
            if not r.ok then Panels.Text(body,r.error.message); return end
            Panels.Text(body,"今日剩余 "..r.value.remaining.." / "..r.value.dailyLimit.." 次",20)
            Panels.Button(body,"receiveLetter","开始捕捞",function() adapter.Salvage() end,r.value.enabled,r.value.message)
            Panels.Text(body,"收下的来信会放回药铺桌上。",15)
        end
    end
    function ui.Update()
        motion:SetVisible(rig.busy)
        if lastRevision==adapter.revision and lastMode==rig.mode and not ctx.model.dirty then return end
        local samePanel=lastRevision==adapter.revision
        lastRevision,lastMode=adapter.revision,rig.mode; ctx.model.dirty=false
        local data=ctx.model.Refresh(); if not data then return end
        ledger:SetText(string.format("寄往人间  ·  金币 %d  ·  第 %d 天",data.live.economy.currency,data.live.gameFlow.day))
        back:SetVisible(rig.mode~="Home"); shore:SetVisible(rig.mode=="Seaside")
        local hints={Home="点门边捞网前往码头；点船打开商店；点信纸阅读；点药炉靠近。",Seaside="点海上的帆船打开商店，或捕捞来信。",Brew="同一张工作桌上的药炉。"}
        notice:SetText(ctx.model.message~="" and ctx.model.message or (hints[rig.mode] or ""))
        -- Keep the Home artwork unobscured; business feedback still appears when needed.
        footer:SetVisible(ctx.model.message~="" or rig.mode~="Home")
        if ctx.model.letterEdited and adapter.panel=="reader" and samePanel and Panels.RefreshReader(panelCtx) then
            local message=root:FindById("panelMessage") --[[@as Label?]]
            if message then message:SetText(ctx.model.message) end
            ctx.model.letterEdited=false; return
        end
        ctx.model.letterEdited=false; buildPanel()
    end
    ui.Update(); UI.SetRoot(root)
    return ui
end
return H
