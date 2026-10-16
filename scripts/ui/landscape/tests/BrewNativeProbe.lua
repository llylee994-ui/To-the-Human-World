-- Opt-in native Yoga/pointer evidence, using memory-only saves. Player state is read-only.
local UI=require "urhox-libs/UI"
local Event=require "urhox-libs/UI/Core/PointerEvent"
local U=require "core.StateUtil"
local N={}
function N.New()
    local phase,deadline,done=0,0,false
    local view=false --[[@as table|false]]
    local fixture=false --[[@as table|false]]
    local before=false --[[@as table|false]]
    local token=false --[[@as string|false]]
    local source=false --[[@as Widget|false]]
    local sample=false --[[@as table|false]]
    local function capture(name)
        local im=Image();assert(graphics:TakeScreenShot(im));assert(im:SavePNG("brew_native_"..name..".png"))
        print("[BrewNative] CAPTURE "..name)
    end
    local function pointer(kind,x,y)
        local scale=UI.GetScale()
        local event=Event.new(kind,{x=x*scale,y=y*scale,pointerId=9,pointerType="touch",button=MOUSEB_LEFT})
        if kind=="PointerDown" then UI.HandlePointerDown(event)
        elseif kind=="PointerMove" then UI.HandlePointerMove(event)
        else UI.HandlePointerUp(event) end
    end
    local function node(id)
        local overlay=view.root:FindById("overlayHost")
        return assert((view.panel and overlay:FindById(id)) or view.root:FindById(id),id)
    end
    local function tap(id)
        local target=node(id);local r=target:GetAbsoluteLayout()
        assert(r.w>=1 and r.h>=1,"zero layout "..id)
        assert(UI.FindWidgetAt(r.x+r.w/2,r.y+r.h/2)==target,"blocked "..id)
        pointer("PointerDown",r.x+r.w/2,r.y+r.h/2);pointer("PointerUp",r.x+r.w/2,r.y+r.h/2)
    end
    return function(ctx)
        if done then return end
        if not ctx.root.parent then return end -- AppView.New performs one pre-mount Update.
        if phase==0 and (not input:HasFocus() or input:IsMinimized()) then return end
        local now=GetTime():GetElapsedTime()
        if view then view.Update() end
        -- PNG capture can spend wall time between frames. Await animation state,
        -- rather than inferring elapsed animation time from the wall deadline.
        if phase==6 and view.brew.interaction.active and view.brew.interaction.elapsed<require("ui.landscape.BrewSmoke").coverAt+.05 then return end
        if phase==7 and (view.brew.interaction.active or view.brew.revealTail>.28) then return end
        if now<deadline then return end
        local ok,err=pcall(function()
            if phase==0 then
                before=ctx.session.state.GetSnapshot()
                local data=U.Copy(require "data.content");data.release=nil
                local F=require "debug.fixtures.B5Fixtures"
                fixture=F.New(data,{targetSchema=3})
                local id=F.Must(fixture.state.ReceiveLetter({letterId="letter_pa_01"})).letterInstanceId
                F.Must(fixture.state.ReadLetter({letterInstanceId=id}))
                local tokens={}
                for _,span in ipairs(F.Must(fixture.modules.letters.GetView(id)).spans) do
                    tokens[span.wordId]=F.Must(fixture.state.CutWord({letterInstanceId=id,spanId=span.spanId})).tokenId
                end
                F.Must(fixture.order.Accept({letterInstanceId=id}))
                sample=require("debug.fixtures.NumericV02Cases")[1].recipe
                token=assert(tokens[sample.mainWordId])
                local checks=require "ui.landscape.DevChecks";checks.brewWorkbenchProbe=false
                view=require("ui.landscape.AppView").New(fixture.session,data)
                checks.brewWorkbenchProbe=true
                ctx.root:SetVisible(false);ctx.root.parent:AddChild(view.root)
                view.Navigate("brew");view.Update()
                for _,card in ipairs(F.Must(fixture.session.queries.GetWordTray()).cards) do
                    if card.tokenId==token then view.brew.words.wordTray.category=card.categoryId end
                end
                view.Refresh();view.Update();deadline=now+2
            elseif phase==1 then
                local title=node("wordTrayTitle"):GetAbsoluteLayout()
                local strips=node("wordTrayStrips"):GetAbsoluteLayout()
                assert(title.y>=60 and title.y+title.h<=strips.y,"title clears ledger and cards")
                local l=view.brew.layout
                assert(l.summary.y+l.summary.h<=l.shelf.y and l.shelf.y+l.shelf.h<=l.controls.y,"native center order")
                local status=node("brewCapacity"):GetAbsoluteLayout()
                local slot=node("slot_main"):GetAbsoluteLayout()
                assert(status.y>=slot.y+slot.h,"status below slots")
                local start=node("previewOrder"):GetAbsoluteLayout()
                assert(start.x>l.center.x+20 and start.w>=200,"main action centered and readable")
                assert(node("brewSlotsTitle"):GetAbsoluteLayout().w>=100,"recipe title readable")
                assert(node("brewMaterialTray"):GetAbsoluteLayout().w>=l.shelf.w-1,"wooden material tray spans row")
                local info=node("brewWishInfo"):GetAbsoluteLayout()
                local letter=node("brewLetters"):GetAbsoluteLayout()
                assert(info.x+info.w+8<=letter.x,"letter button cannot cover information")
                assert(not view.root:FindById("brewDragText"),"no drag name tooltip")
                capture("empty")
                source=node("wordTrayCard_"..token)
                local r=source:GetAbsoluteLayout();local drop=view.brew.layout.drop
                print("[BrewNative] GEOMETRY "..cjson.encode({source=r,drop=drop,viewport=view.viewport}))
                assert(UI.FindWidgetAt(r.x+r.w/2,r.y+r.h/2)==source,"source is occluded")
                pointer("PointerDown",r.x+r.w/2,r.y+r.h/2)
                pointer("PointerMove",drop.x+drop.w/2,drop.y+drop.h/2)
                assert(view.brew.interaction.drag and view.brew.interaction.drag.active,"native drag starts")
                deadline=now+.4
            elseif phase==2 then
                local r=view.brew.layout.drop
                print("[BrewNative] RELEASE "..cjson.encode({focused=input:HasFocus(),dt=GetTime():GetTimeStep(),drag=view.brew.interaction.drag}))
                capture("drag")
                pointer("PointerUp",r.x+r.w/2,r.y+r.h/2)
                assert(view.model.GetDraft().mainTokenId==token,"native drag saves source card")
                local F=require "debug.fixtures.B5Fixtures"
                for _,line in ipairs(sample.ingredients) do
                    for _=1,line.quantity do F.Must(view.model.Drop("ingredient",line.ingredientId)) end
                end
                view.Refresh();view.Update();deadline=now+.15
            elseif phase==3 then
                assert(view.brew.interaction.flight,"saved word is still in a visual transition")
                capture("landing");deadline=now+.5
            elseif phase==4 then
                local ingredient=node("brewIngredient_ing_sea_salt"):GetAbsoluteLayout()
                local pot=view.brew.layout.slots[4]
                assert(UI.FindWidgetAt(ingredient.x+ingredient.w/2,ingredient.y+ingredient.h/2)==node("brewIngredient_ing_sea_salt"),"ingredient source occluded")
                pointer("PointerDown",ingredient.x+ingredient.w/2,ingredient.y+ingredient.h/2)
                pointer("PointerMove",ingredient.x+ingredient.w/2,ingredient.y-16)
                pointer("PointerMove",pot.x+pot.w/2,pot.y+pot.h/2)
                pointer("PointerUp",pot.x+pot.w/2,pot.y+pot.h/2)
                local draft=view.model.GetDraft()
                assert(draft.ingredients[1] and draft.ingredients[1].ingredientId=="ing_sea_salt" and draft.ingredients[1].quantity==1,"native ingredient drag saves one portion")
                print("[BrewNative] INGREDIENT_SLOT_DROP sea salt / one portion / real saved draft")
                deadline=now+.6
            elseif phase==5 then
                capture("prepared")
                tap("previewOrder");view.Update()
                assert(view.brew.interaction.active and fixture.state.GetSnapshot().currentOrder.pending,"saved pending before smoke")
                deadline=now+.42
            elseif phase==6 then
                assert(require("ui.landscape.BrewSmoke").Cover(view.brew.interaction.elapsed)==1,"complete smoke coverage")
                assert(node("brewSmokeBlocker").parent==view.root,"smoke is above the whole screen")
                capture("smoke");deadline=now+.72
            elseif phase==7 then
                assert(view.panel=="result" and view.brew.revealTail>0,"saved story mounts beneath fading smoke")
                capture("reveal");deadline=now+1
            elseif phase==8 then
                assert(view.panel=="result" and node("resultStars"),"native stored result opens")
                local header=node("resultStars"):GetAbsoluteLayout()
                local actions=node("resultActions"):GetAbsoluteLayout()
                local scroll=node("resultScroll"):GetAbsoluteLayout()
                assert(header.y<scroll.y and actions.y>=scroll.y+scroll.h-1,"stars/actions outside body scroll")
                assert(header.w>=160 and header.h>=40,"stars have a readable fixed header box")
                local paper=node("activePanel"):GetAbsoluteLayout()
                assert(paper.w<=821 and paper.x>view.viewport.w*.1,"story page is centered and narrow")
                assert(not view.panelNoticeArea:IsVisible(),"no vanishing success notice in story")
                print("[BrewNative] RESULT "..cjson.encode({stars=header,actions=actions,scroll=scroll,text=node("resultStars"):GetText()}))
                capture("result");deadline=now+1
            elseif phase==9 then
                tap("closePanel");view.Update()
                assert(fixture.state.GetSnapshot().currentOrder.pending,"close retains pending")
                assert(U.Equal(before,ctx.session.state.GetSnapshot()),"player save changed")
                view.root:Destroy();view=false;ctx.root:SetVisible(true);ctx.Refresh();done=true
                print("[BrewNative] PASS native Yoga/source touch-pointer drag/saved trial/smoke/fixed stars/close; memory-only fixture; NOT phone evidence")
            end
            phase=phase+1
        end)
        if not ok then
            done=true;print("[BrewNative] FAIL phase="..phase.." "..tostring(err))
            if view then view.root:Destroy();view=false end
            ctx.root:SetVisible(true)
        end
    end
end
return N
