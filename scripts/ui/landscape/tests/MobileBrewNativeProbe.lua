-- Desktop engine evidence with a 1200x540 host/safe-area adapter and real touch
-- routing. Memory-only fixture; this is not a claim of physical-phone testing.
local UI=require "urhox-libs/UI"
local Pointer=require "urhox-libs/UI/Core/PointerEvent"
local Gesture=require "urhox-libs/UI/Core/GestureEvent"
local Hud=require "ui.landscape.HudLayout"
local U=require "core.StateUtil"
local F=require "debug.fixtures.B5Fixtures"
local N={}
function N.New()
    local phase,deadline,done=0,0,false
    local view=false --[[@as table|false]]
    local fixture=false --[[@as table|false]]
    local before=false --[[@as table|false]]
    local main=false --[[@as string|false]]
    local recipe=false --[[@as table|false]]
    local tokens={}
    local landingCaptured=false
    local readHost=Hud.ReadHost
    local function cleanup(ctx)
        Hud.ReadHost=readHost
        if view then view.root:Destroy();view=false end
        ctx.root:SetVisible(true);ctx.Refresh();done=true
    end
    local function node(id) return assert(view.root:FindById(id),id) end
    local function capture(name)
        local im=Image();assert(graphics:TakeScreenShot(im))
        local s=UI.GetScale()
        local phone=im:GetSubimage(IntRect(0,0,math.floor(1200*s),math.floor(540*s)))
        assert(phone:SavePNG("mobile_brew_"..name..".png"));print("[MobileBrewNative] CAPTURE "..name)
    end
    local function point(kind,x,y,id)
        local s=UI.GetScale()
        local event=Pointer.new(kind,{x=x*s,y=y*s,pointerId=id,pointerType="touch",button=MOUSEB_LEFT})
        if kind=="PointerDown" then UI.HandlePointerDown(event)
        elseif kind=="PointerUp" then UI.HandlePointerUp(event)
        else UI.HandlePointerMove(event) end
    end
    local function pan(kind,target,x,y,id,dx,dy)
        local s=UI.GetScale()
        UI.HandleGestureEvent(Gesture.new(kind,{target=target,x=x*s,y=y*s,pointerId=id,pointerType="touch",
            deltaX=dx*s,deltaY=dy*s,totalDeltaX=dx*s,totalDeltaY=dy*s}))
    end
    local function drag(id,target,vertical,pointerId)
        local source=node(id);local r=source:GetAbsoluteLayout();local x,y=r.x+r.w/2,r.y+r.h/2
        assert(UI.FindWidgetAt(x,y)==source,"source hit "..id)
        point("PointerDown",x,y,pointerId)
        local dx,dy=vertical and 0 or 3,vertical and 3 or 0
        point("PointerMove",x+dx,y+dy,pointerId)
        pan("PanStart",source,x+dx,y+dy,pointerId,dx,dy)
        assert(view.brew.interaction.drag and view.brew.interaction.drag.active,"first small touch pan captured "..id)
        pan("PanMove",source,target.x,target.y,pointerId,target.x-x,target.y-y)
        local dropStarted=(os.clock()*1000)
        pan("PanEnd",source,target.x,target.y,pointerId,target.x-x,target.y-y)
        local dropMS=(os.clock()*1000)-dropStarted
        local saved,writes=fixture.state.GetSnapshot(),fixture.writes
        point("PointerUp",target.x,target.y,pointerId)
        assert(U.Equal(saved,fixture.state.GetSnapshot()) and writes==fixture.writes,"pan-end/up never double-drops")
        local refresh=view.brew.Refresh;local refreshMS=0
        view.brew.Refresh=function()
            local start=(os.clock()*1000);refresh();refreshMS=(os.clock()*1000)-start
        end
        local updateStarted=(os.clock()*1000);view.Update()
        print("[DropProfile] "..id.." drop_ms="..dropMS.." update_ms="..((os.clock()*1000)-updateStarted).." brew_refresh_ms="..refreshMS)
        view.brew.Refresh=refresh
    end
    local function tap(id,pointerId)
        local target=node(id);local r=target:GetAbsoluteLayout();local x,y=r.x+r.w/2,r.y+r.h/2
        assert(UI.FindWidgetAt(x,y)==target,"blocked "..id)
        point("PointerDown",x,y,pointerId);point("PointerUp",x,y,pointerId)
    end
    return function(ctx)
        if done or not ctx.root.parent then return end
        if view then view.Update() end
        local flight=view and view.brew.interaction.flight
        if phase==2 and flight and flight.accepted and flight.elapsed>.08 and not landingCaptured then
            local captured,reason=pcall(capture,"landing");landingCaptured=true
            if not captured then print("[MobileBrewNative] FAIL landing capture "..tostring(reason));cleanup(ctx);return end
        end
        local now=GetTime():GetElapsedTime();if now<deadline then return end
        local ok,err=pcall(function()
            if phase==0 then
                before=ctx.session.state.GetSnapshot()
                Hud.ReadHost=function() return {w=1200,h=540},{left=48,right=0,top=0,bottom=0},{left=.88,right=.99,top=.02,bottom=.14} end
                local data=U.Copy(require "data.content");data.release=nil
                fixture=F.New(data,{targetSchema=3})
                local checks=require "ui.landscape.DevChecks";checks.mobileBrewProbe=false
                view=require("ui.landscape.AppView").New(fixture.session,data);checks.mobileBrewProbe=true
                local brewUpdate=view.brew.Update
                view.brew.Update=function(dt) brewUpdate(dt,true) end -- focused touch-host adapter, not OS focus evidence
                ctx.root:SetVisible(false);ctx.root.parent:AddChild(view.root)
                local letter=F.Must(view.model.Receive("letter_pa_01"));F.Must(view.model.Read(letter.letterInstanceId))
                for _,span in ipairs(F.Must(fixture.modules.letters.GetView(letter.letterInstanceId)).spans) do
                    tokens[span.wordId]=F.Must(view.model.Cut(span.spanId)).tokenId
                end
                F.Must(view.model.Accept());recipe=require("debug.fixtures.NumericV02Cases")[1].recipe;main=tokens[recipe.mainWordId]
                view.Navigate("brew");view.Update()
                for _,card in ipairs(F.Must(fixture.session.queries.GetWordTray()).cards) do
                    if card.tokenId==main then view.brew.words.wordTray.category=card.categoryId end
                end
                view.Refresh();view.Update()
                view.root:AddChild(UI.Panel {id="mobileCapsuleReference",position="absolute",left=1056,top=11,width=132,height=65,
                    zIndex=2200,borderRadius=30,backgroundColor={70,67,62,220},pointerEvents="none",
                    children={UI.Label {text="系统胶囊占位",fontSize=11,fontColor={255,255,255,255},padding=12,pointerEvents="none"}}})
                print("[MobileBrewNative] START 1200x540 safe-left48 host and focused-touch adapters; OS focus="..tostring(input:HasFocus()))
                deadline=now+2
            elseif phase==1 then
                assert(node("brewWordPanel"):GetAbsoluteLayout().x==0,"tray flush left")
                assert(node("brewPotArt"):GetAbsoluteLayout().h>=180,"cauldron enlarged on short screen")
                local close=node("brewJournalClose"):GetAbsoluteLayout()
                assert(close.y>460 and UI.FindWidgetAt(close.x+close.w/2,close.y+close.h/2)==node("brewJournalClose"),"bottom book arrow clears HUD and capsule")
                local leftClose=node("brewWordsClose"):GetAbsoluteLayout()
                assert(leftClose.y>460 and UI.FindWidgetAt(leftClose.x+leftClose.w/2,leftClose.y+leftClose.h/2)==node("brewWordsClose"),"bottom tray arrow has a clear touch target")
                local label=node("brewIngredientName_ing_sea_salt")
                print("[MobileBrewNative] ingredient-label "..cjson.encode({label=label:GetAbsoluteLayout(),shelf=node("brewShelf"):GetAbsoluteLayout(),
                    text=label:GetText(),paddingTop=label.props.paddingTop,paddingBottom=label.props.paddingBottom,fontSize=label.props.fontSize,
                    card=node("brewIngredient_ing_sea_salt"):GetAbsoluteLayout()}))
                capture("workbench")
                local drop=view.brew.layout.drop
                drag("wordTrayCard_"..main,{x=drop.landingX,y=drop.landingY},true,71)
                assert(view.model.GetDraft().mainTokenId==main,"one touch curve saves the word")
                view.Update();deadline=now+.6
            elseif phase==2 then
                local drop=view.brew.layout.drop
                drag("brewIngredient_ing_sea_salt",{x=drop.landingX,y=drop.landingY},false,72)
                assert(view.model.GetDraft().ingredients[1].ingredientId=="ing_sea_salt","one horizontal-first touch saves ingredient")
                view.brew.Cancel()
                -- Continue with the real fixture recipe after checking both source types.
                F.Must(view.model.TakeOut("ingredient","ing_sea_salt"))
                for _,word in ipairs(recipe.auxWordIds) do F.Must(view.model.Drop("word",tokens[word])) end
                for _,line in ipairs(recipe.ingredients) do for _=1,line.quantity do F.Must(view.model.Drop("ingredient",line.ingredientId)) end end
                F.Must(view.model.Preview());view.Open("result");view.Update();deadline=now+1
            elseif phase==3 then
                local paper=node("activePanel"):GetAbsoluteLayout();local scroll=node("resultScroll"):GetAbsoluteLayout()
                local actions=node("resultActions"):GetAbsoluteLayout()
                assert(paper.y<30 and paper.h>=480,"paper uses full height beside capsule")
                assert(scroll.h>=260 and actions.y+actions.h<=paper.y+paper.h,"body space and fixed actions fit")
                capture("result_top")
                local x,y=scroll.x+scroll.w*.6,scroll.y+scroll.h*.7
                local target=UI.FindWidgetAt(x,y)
                point("PointerDown",x,y,73);pan("PanStart",target,x,y-8,73,0,-8)
                pan("PanMove",target,x,y-1400,73,0,-1400);pan("PanEnd",target,x,y-1400,73,0,-1400)
                point("PointerUp",x,y-1400,73);deadline=now+.6
            elseif phase==4 then
                local _,y=node("resultScroll"):GetScroll();assert(y>0,"touch pan scrolls the story")
                local body=node("pendingBody"):GetAbsoluteLayoutForHitTest();local scroll=node("resultScroll"):GetAbsoluteLayout()
                assert(body.y+body.h<=scroll.y+scroll.h+2,"last story line is reachable")
                capture("result_bottom");tap("closePanel",74);view.Update()
                F.Must(view.model.Resolve(true));view.Update()
                F.Must(view.model.NextDay())
                F.Must(fixture.state.ReceiveLetter({letterId="letter_n01"}))
                view.brew.OpenJournal("letter_n01");view.Update();view.feedback.Cancel();deadline=now+.6
            elseif phase==5 then
                local title=node("bookStoryTitle"):GetAbsoluteLayout()
                capture("long_title")
                print("[MobileBrewNative] heading "..node("bookStoryTitle"):GetText().." "..cjson.encode(title))
                assert(node("bookStoryTitle"):GetText()=="面包坊与抄写铺" and title.h<=34 and node("bookStoryTitle").props.whiteSpace=="nowrap","full second title uses a compact line")
                assert(not view.brew.journal.journalBook.flip and not view.brew.journal.journalBook.page.RenderOverlays,"no page turn exists")
                tap("brewWordsClose",76);tap("brewJournalClose",75);view.Update();deadline=now+.5
            elseif phase==6 then
                assert(not view.brew.journalOpen and not view.root:FindById("bookArtFrame"),"one touch closes the only book")
                assert(not view.brew.wordsOpen and not view.root:FindById("wordTrayFrame"),"one touch closes the tray with its bottom arrow")
                assert(U.Equal(before,ctx.session.state.GetSnapshot()),"original player progress unchanged")
                cleanup(ctx)
                print("[MobileBrewNative] PASS first small touch pan / word and ingredient one drop / tray edge / larger pot / close hit / tall story and touch scroll / compact full title / no flip / original player unchanged; NOT physical-phone evidence")
            end
            phase=phase+1
        end)
        if not ok then print("[MobileBrewNative] FAIL phase="..phase.." "..tostring(err));cleanup(ctx) end
    end
end
return N
