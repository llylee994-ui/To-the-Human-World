-- The same room/workbench, with two independent read-only drawers and real draft commands.
local UI=require "urhox-libs/UI"
local Widget=require "urhox-libs/UI/Core/Widget"
local H=require "ui.landscape.HarborStyle"
local Home=require "ui.landscape.HomeView"
local Camera=require "ui.landscape.StovePanZoom"
local Tray=require "ui.landscape.WordTrayDrawer"
local Book=require "ui.landscape.JournalBook"
local Art=require "ui.landscape.IngredientArt"
local L=require "ui.landscape.BrewLayout"
local Interaction=require "ui.landscape.BrewInteraction"
local Banner=require "ui.landscape.BrewBanner"
local BrewArt=require "ui.landscape.BrewArt"
local Recipe=require "ui.landscape.BrewRecipe"
local Smoke=require "ui.landscape.BrewSmoke"
local StoryStyle=require "ui.landscape.StoryStyle"
local B={}
local ink={65,47,32,255}
local function clear(parent)
    for i=parent:GetNumChildren(),1,-1 do parent:GetChildAt(i):Destroy() end
end
local function box(r,id)
    return {id=id,position="absolute",left=r.x,top=r.y,width=r.w,height=r.h,pointerEvents="box-none"}
end
local function text(parent,value,size,id)
    local label=UI.Label {id=id,text=value,fontFamily=H.fontFamily,fontSize=size or 14,fontColor=ink,
        whiteSpace="normal",lineHeight=1.35,flexShrink=0,pointerEvents="none"}
    parent:AddChild(label);return label
end
local function button(parent,id,title,callback,allowed,style)
    local props={id=id,text=title,height=44,minHeight=44,fontSize=13,disabled=allowed==false,onClick=callback}
    for key,value in pairs(style or {}) do props[key]=value end
    local b=H.Button(props)
    parent:AddChild(b);return b
end
---@param ctx table
---@return table
function B.New(ctx)
    local root=UI.Panel {id="brewWorkbench",position="absolute",left=0,top=0,width="100%",height="100%",visible=false,pointerEvents="box-none"}
    local room=Home.New(function() end,false,ctx.content.release~=nil)
    room.SetBlocked(true);room.SetPanelOpen(true);room.hiddenLayers.stove=true;root:AddChild(room.root)
    local center=UI.Panel {id="brewCenter",position="absolute",left=0,top=0,width="100%",height="100%",zIndex=2,pointerEvents="box-none"}
    local wordsHost=UI.Panel {id="brewWordsHost",position="absolute",left=0,top=0,width="100%",height="100%",zIndex=4,pointerEvents="box-none"}
    local journalHost=UI.Panel {id="brewJournalHost",position="absolute",left=0,top=0,width="100%",height="100%",zIndex=5,pointerEvents="box-none"}
    local fx=UI.Panel {id="brewEffects",position="absolute",left=0,top=0,width="100%",height="100%",zIndex=8,pointerEvents="none"}
    local smoke=UI.Panel {id="brewSmokeBlocker",position="absolute",left=0,top=0,width="100%",height="100%",zIndex=1500,visible=false,onClick=function() end}
    root:AddChild(center);root:AddChild(wordsHost);root:AddChild(journalHost);root:AddChild(fx)
    ctx.root:AddChild(smoke)
    local b={root=root,wordsOpen=true --[[@as boolean]],journalOpen=true --[[@as boolean]],
        selected=false --[[@as string|table|false]],entered=false --[[@as boolean]],layout=L.Compute(1280,720),
        entryTime=0,revealTail=0,signature="",orderId=false --[[@as string|false]],room=room}
    b.interaction=Interaction.New(ctx.model,function()
        if ctx.scene=="brew" and not ctx.destroyed then
            if b.interaction.elapsed>=b.interaction.duration then b.revealTail=Smoke.revealDuration end
            ctx.Open("result")
        end
    end)
    local function dropTarget(item,x,y) return L.Target(b.layout,item,x,y) end
    local function canEdit() return ctx.model.Action("UpdateDraft").enabled and not ctx.panel and not b.interaction.active and not (b.interaction.flight and b.interaction.flight.accepted) end
    local function bindSource(widget,item)
        local oldClick=widget.props.onClick
        widget.props.onPointerDown=function(event)
            if not b.interaction.drag then b.interaction.suppressClick=false end
            if canEdit() then b.interaction.Begin(item,event) end
        end
        widget.props.onPointerMove=function(event) b.interaction.Move(event,dropTarget) end
        widget.props.onPointerUp=function(event) b.interaction.Release(event,dropTarget) end
        widget.props.onPointerCancel=function(event)
            local d=b.interaction.drag
            if d and d.pointerId==event.pointerId then
                b.interaction.CancelDrag()
                if widget.state then widget.state.dragging=false end
            end
        end
        widget.props.onClick=function(self,event)
            if not b.interaction.ClickAllowed() then return end
            if oldClick then oldClick(self,event) end
        end
        -- A drag beginning on a card owns the gesture in every direction.
        -- Pans beginning on the unoccupied tray/shelf still reach ScrollView.
        local originalPanStart=widget.OnPanStart
        function widget:OnPanStart(event)
            local d=b.interaction.drag
            if d and d.pointerId==event.pointerId then
                b.interaction.Move(event,dropTarget,true)
                if d.active then self.state=self.state or {};self.state.dragging=true;return true end
            end
            return originalPanStart and originalPanStart(self,event) or false
        end
        function widget:OnPanMove(event) b.interaction.Move(event,dropTarget) end
        function widget:OnPanEnd(event)
            if self.state then self.state.dragging=false end
            b.interaction.Release(event,dropTarget)
        end
    end
    ---@return table
    local function child()
        return {model=ctx.model,session=ctx.session,content=ctx.content,viewport=ctx.viewport,safeInsets=ctx.safeInsets,workbench=true,
            storyId=false,wordTray=false,journalBook=false,Open=function(kind) b.interaction.CancelDrag();ctx.Open(kind) end,
            Push=function(kind) b.interaction.CancelDrag();ctx.Push(kind) end}
    end
    b.words=child();b.journal=child()
    function b.Throw(kind,id)
        if not canEdit() then return false end
        local source=root:FindById(kind=="ingredient" and "brewIngredient_"..id or "wordTrayCard_"..id)
        local bounds=source and source.GetAbsoluteLayout and source:GetAbsoluteLayout() or b.layout.shelf
        local label=id
        if kind=="ingredient" then for _,item in ipairs(ctx.content.ingredients) do if item.id==id then label=item.name;break end end
        else
            local tray=ctx.session.queries.GetWordTray()
            if tray.ok then for _,card in ipairs(tray.value.cards) do if card.tokenId==id then label=card.text;break end end end
        end
        local result=b.interaction.Commit({kind=kind,id=id,text=label},bounds.x+bounds.w/2,bounds.y+bounds.h/2,b.layout.drop)
        if result and result.ok then b.selected=false end
        return result
    end
    -- Only the click-to-add command is adapted; all state and dirty writes still forward to the shared model.
    b.words.model=setmetatable({Drop=b.Throw},{__index=ctx.model,__newindex=function(_,key,value) ctx.model[key]=value end})
    b.words.Close=function() b.wordsOpen=false;ctx.model.dirty=true end
    b.journal.Close=function() b.journalOpen=false;ctx.model.dirty=true end
    function b.OpenJournal(storyId)
        b.interaction.CancelDrag();b.journalOpen=true
        if b.journal.journalBook and b.journal.journalBook.closing then Book.Reset(b.journal) end
        if storyId then b.journal.storyId=storyId;Book.Select(b.journal,storyId) end
        Book.Open(b.journal);ctx.model.dirty=true
    end
    b.words.brewDrag=function(widget,card)
        if card.available and not card.selectedRole then bindSource(widget,{kind="word",id=card.tokenId,text=card.text}) end
    end
    function b.Enter()
        if b.entered then return end
        b.entered=true;b.wordsOpen=true;b.journalOpen=true;b.orderId=false;b.selected=false;b.entryTime=0
        Tray.Reset(b.words);Book.Reset(b.journal);ctx.model.dirty=true
    end
    function b.Cancel() b.interaction.Cancel();b.revealTail=0;smoke:SetVisible(false) end
    function b.Leave()
        b.Cancel();b.entered=false;Tray.Reset(b.words);Book.Reset(b.journal)
        clear(center);clear(wordsHost);clear(journalHost)
    end
    function b.Start()
        if b.revealTail>0 then return false end
        if not b.interaction.active then b.interaction.elapsed=0 end
        return b.interaction.Start()
    end
    function b.Skip() b.interaction.Skip() end
    local skip=H.Button {id="skipBrew",text="跳过演出",position="absolute",right=28,bottom=18,width=120,minHeight=44,onClick=b.Skip}
    smoke:AddChild(skip)
    function b.Refresh()
        local result=ctx.session.queries.GetOrderSummary()
        if not result.ok then ctx.model.Notify(result);return end
        local summary=result.value
        if b.orderId~=summary.orderId then
            b.interaction.flight=false;b.interaction.pulse=false
            b.orderId=summary.orderId
            b.journal.storyId=summary.sourceLetterId or false
            if b.journal.journalBook then b.journal.journalBook.story=b.journal.storyId;b.journal.journalBook.entry=false end
        end
        for _,sub in ipairs({b.words,b.journal}) do sub.viewport=ctx.viewport;sub.safeInsets=ctx.safeInsets end
        clear(center);clear(wordsHost);clear(journalHost)
        if b.wordsOpen then
            Tray.Open(b.words);Tray.Render(b.words,wordsHost)
            local p=wordsHost:FindById("activePanel");if p then p.id="brewWordPanel";p.props.id="brewWordPanel" end
            local close=wordsHost:FindById("closePanel");if close then close.id="brewWordsClose";close.props.id="brewWordsClose" end
        end
        if b.journalOpen then
            Book.Open(b.journal);Book.Render(b.journal,journalHost)
            local p=journalHost:FindById("activePanel");if p then p.id="brewBookPanel";p.props.id="brewBookPanel" end
            local close=journalHost:FindById("closePanel");if close then close.id="brewJournalClose";close.props.id="brewJournalClose" end
        end
        local l=b.layout
        local safe=ctx.safeInsets or {left=0,right=0,top=0,bottom=0}
        local reopen=UI.Panel {position="absolute",left=l.center.x,top=safe.top+12,width=l.center.w,height=44,
            flexDirection="row",gap=8,justifyContent="flex-start",pointerEvents="box-none"}
        center:AddChild(reopen)
        button(reopen,"brewWords",b.wordsOpen and "收起词条" or "展开词条",function()
            b.interaction.CancelDrag();b.wordsOpen=not b.wordsOpen
            if b.wordsOpen then Tray.Reset(b.words) end
            ctx.model.dirty=true
        end)
        button(reopen,"brewJournal",b.journalOpen and "收起记录" or "展开记录",function()
            b.interaction.CancelDrag();b.journalOpen=not b.journalOpen
            if b.journalOpen then Book.Reset(b.journal);b.journal.storyId=summary.sourceLetterId end
            ctx.model.dirty=true
        end)
        local data=ctx.model.Refresh()
        local draft=summary.draft or ctx.model.GetDraft()
        local kit=false --[[@as table|false]]
        for _,item in ipairs(ctx.content.equipment) do if item.id==draft.equipmentId then kit=item end end
        local viewport=ctx.viewport or {w=1280,h=720}
        b.layout=L.Compute(viewport.w,viewport.h,ctx.safeInsets,kit and kit.slots.auxWord,kit and kit.slots.ingredient)
        l=b.layout
        Banner.Render(ctx,center,summary,l)
        local pot=UI.Panel(box(l.pot,"brewPotArt"));pot.props.pointerEvents="none";center:AddChild(pot)
        function pot:Render(vg)
            local r=self:GetAbsoluteLayout();local t=math.min(1,b.entryTime/.42);local ease=t*t*(3-2*t)
            local scale=.96+.04*ease
            BrewArt.Draw(vg,BrewArt.pot,{x=r.x+r.w*(1-scale)/2,y=r.y+r.h*(1-scale)/2+8*(1-ease),w=r.w*scale,h=r.h*scale},ease)
        end
        local shelfProps=box(l.shelf,"brewShelf");shelfProps.scrollX=true;shelfProps.scrollY=false;shelfProps.showScrollbar=false
        local shelf=UI.ScrollView(shelfProps);center:AddChild(shelf)
        local rowWidth=math.max(l.shelf.w,4*112)
        local shelfRow=UI.Panel {width=rowWidth,height=l.shelf.h,pointerEvents="box-none"};shelf:AddChild(shelfRow)
        local wood=BrewArt.Panel(BrewArt.tray,{id="brewMaterialTray",position="absolute",left=0,top=0,width=rowWidth,height=l.shelf.h,pointerEvents="none"})
        shelfRow:AddChild(wood)
        local editable=canEdit()
        for index,item in ipairs(ctx.content.ingredients) do
            local chosen=0;for _,row in ipairs(draft.ingredients) do if row.ingredientId==item.id then chosen=row.quantity end end
            local remaining=math.max(0,(data.live.economy.ingredients[item.id] or 0)-chosen)
            local card=UI.Panel {id="brewIngredient_"..item.id,position="absolute",left=8+(index-1)*(rowWidth-16)/4,top=5,
                width=(rowWidth-16)/4,height=l.shelf.h-10,onClick=function()
                    if b.selected==item.id then b.selected=false else b.selected=item.id end
                    ctx.model.dirty=true
                end}
            shelfRow:AddChild(card)
            card:AddChild(Art.Panel(item.id,{width="100%",height=l.shelf.h-36,padding=4,imageTint=remaining==0 and {145,145,145,255} or nil}))
            -- The painted plaques scale with the whole shelf. Position names on
            -- that shared canvas, rather than a fixed bottom inset in each card.
            local cell=(rowWidth-16)/4
            shelfRow:AddChild(UI.Label {id="brewIngredientName_"..item.id,text=item.name.." · "..remaining,position="absolute",
                left=8+(index-1)*cell+cell*.15,top=l.shelf.h*.885-10,width=cell*.70,height=20,
                padding=0,lineHeight=1,textAlign="center",verticalAlign="middle",whiteSpace="nowrap",zIndex=2,pointerEvents="none",
                fontFamily=H.fontFamily,fontColor=ink,fontSize=l.compact and 10 or 12})
            if remaining>0 and editable then bindSource(card,{kind="ingredient",id=item.id,text=item.name,path=Art.Get(item.id)}) end
        end
        local drop=UI.Panel(box(l.drop,"brewPotDrop"));center:AddChild(drop)
        if summary.pending then
            button(drop,"openPending","查看待处理结果",function() ctx.Open("result") end,true,
                {position="absolute",left=0,top=0,width="100%"})
        else
            local hint=text(center,"拖入词条与原料",12,"brewPotHint")
            Widget.SetStyle(hint,{position="absolute",left=l.pot.x+l.pot.w+8,top=l.pot.y+l.pot.h*.45,
                width=math.max(52,l.center.x+l.center.w-l.pot.x-l.pot.w-12),fontColor={255,241,210,245}})
            hint:SetVisible(not draft.mainTokenId and not b.interaction.active)
        end
        Recipe.Render(ctx,b,center,summary,data,editable)
        local controlsProps=box(l.controls,"brewControls");controlsProps.flexDirection="row";controlsProps.gap=8;controlsProps.justifyContent="center"
        local controls=UI.Panel(controlsProps)
        center:AddChild(controls)
        controls:AddChild(StoryStyle.Button {id="previewOrder",text=summary.pending and "查看这锅后续" or "开始熬制",onClick=b.Start,
            disabled=not (summary.pending or (summary.actions.Preview.enabled and draft.mainTokenId and summary.requirementHint.canShip)),
            width=math.min(300,l.center.w-70),minWidth=0,height=48,minHeight=48,fontSize=20})
        button(controls,"clearDraft","清空",function() if canEdit() then ctx.model.Edit("clear") end end,editable)
        smoke:SetVisible(b.interaction.active or b.revealTail>0)
    end
    function b.Update(dt,focused)
        if ctx.scene~="brew" then return end
        local viewport=ctx.viewport or {w=1280,h=720}
        local safe=ctx.safeInsets or {left=0,right=0,top=0,bottom=0}
        local signature=table.concat({viewport.w,viewport.h,safe.left,safe.right,safe.top,safe.bottom},":")
        if signature~=b.signature then
            b.signature=signature;b.Cancel();b.layout=L.Compute(viewport.w,viewport.h,safe);ctx.model.dirty=true
        end
        b.entryTime=math.min(.42,b.entryTime+math.max(0,dt))
        if not focused or ctx.portrait or dt<0 or dt>.5 then b.revealTail=0
        else b.revealTail=math.max(0,b.revealTail-dt) end
        b.interaction.Update(dt,focused and not ctx.portrait)
        if ctx.panel then
            b.interaction.CancelDrag()
            if b.interaction.flight or b.interaction.pulse then b.interaction.flight=false;b.interaction.pulse=false;ctx.model.dirty=true end
        end
        smoke:SetVisible(b.interaction.active or b.revealTail>0);skip:SetVisible(b.interaction.active)
        Tray.Update(b.words,dt);Book.Update(b.journal,dt)
        if room.root.GetAbsoluteLayout then
            local fit=room.Fit()
            if fit.scale>0 then
                local profile=Camera.Plan(room.manifest,fit,room.root:GetAbsoluteLayout())
                room.SetPanZoom(profile.target,profile.panX,profile.panY)
            end
        end
        room.Update(0)
    end
    -- No drop-zone drawing and no pointer-following item-name labels.
    local cardFace=UI.Label {id="brewDragCardFace",position="absolute",visible=false,width=110,height=30,
        textAlign="center",fontFamily=H.fontFamily,fontSize=16,fontColor=ink,pointerEvents="none"}
    fx:AddChild(cardFace)
    function fx:Render(vg)
        local d=b.interaction.drag
        local sample=d and d.active and {kind=d.kind,id=d.id,text=d.text,x=d.x,y=d.y-Interaction.Lift,scale=1,alpha=.9} or b.interaction.SampleFlight()
        if sample then
            if sample.kind=="ingredient" then
                BrewArt.DrawIngredient(vg,sample.id,sample.x,sample.y,78*sample.scale,sample.alpha)
            else
                local w,h=116*sample.scale,38*sample.scale
                nvgBeginPath(vg);nvgRoundedRect(vg,sample.x-w/2,sample.y-h/2,w,h,3)
                nvgFillColor(vg,nvgRGBA(246,230,195,math.floor(235*sample.alpha)));nvgFill(vg)
            end
        end
        local pulse=b.interaction.pulse
        if pulse then
            local t=pulse.elapsed/.4
            for i=1,2 do
                nvgBeginPath(vg);nvgEllipse(vg,pulse.x,pulse.y,(12+35*t)*i,(5+14*t)*i)
                nvgStrokeColor(vg,nvgRGBA(249,220,147,math.floor(150*(1-t))));nvgStrokeWidth(vg,1.5);nvgStroke(vg)
            end
        end
    end
    local update=b.Update
    function b.Update(dt,focused)
        update(dt,focused)
        local d=b.interaction.drag
        local sample=d and d.active and {kind=d.kind,text=d.text,x=d.x,y=d.y-Interaction.Lift,scale=1,alpha=1} or b.interaction.SampleFlight()
        cardFace:SetVisible(sample and sample.kind=="word" or false)
        if sample and sample.kind=="word" then
            cardFace:SetText(sample.text or "")
            Widget.SetStyle(cardFace,{left=sample.x-55*sample.scale,top=sample.y-15*sample.scale,
                width=110*sample.scale,height=30*sample.scale,fontSize=16*sample.scale,opacity=sample.alpha})
        end
    end
    function smoke:Render(vg)
        local r=b.layout.drop
        local alpha=b.interaction.active and 1 or b.revealTail/Smoke.revealDuration
        Smoke.Render(vg,ctx.viewport or {w=1280,h=720},{x=r.x+r.w/2,y=r.landingY or r.y+r.h/2},b.interaction.elapsed,alpha)
    end
    return b
end
return B
