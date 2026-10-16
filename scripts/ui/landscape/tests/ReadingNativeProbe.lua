-- Opt-in native hover/wheel/Yoga evidence on a memory-only session.
local UI=require "urhox-libs/UI"
local Event=require "urhox-libs/UI/Core/PointerEvent"
local U=require "core.StateUtil"
local F=require "debug.fixtures.B5Fixtures"
local N={}
function N.New()
    local phase,deadline,done=0,0,false
    local view=false --[[@as table|false]]
    local fixture=false --[[@as table|false]]
    local before=false --[[@as table|false]]
    local letter=false --[[@as string|false]]
    local branch=false --[[@as string|false]]
    local transaction=false --[[@as string|false]]
    local footerY=0
    local currencyBefore=0
    local function node(id)
        local overlay=view.root:FindById("overlayHost")
        return assert((view.panel and overlay:FindById(id)) or view.root:FindById(id),id)
    end
    local function capture(name)
        local im=Image();assert(graphics:TakeScreenShot(im));assert(im:SavePNG("reading_native_"..name..".png"))
        print("[ReadingNative] CAPTURE "..name)
    end
    local function point(kind,x,y)
        local scale=UI.GetScale()
        local event=Event.new(kind,{x=x*scale,y=y*scale,pointerId=0,pointerType="mouse",button=MOUSEB_LEFT})
        if kind=="PointerDown" then UI.HandlePointerDown(event)
        elseif kind=="PointerUp" then UI.HandlePointerUp(event)
        else UI.HandlePointerMove(event) end
    end
    local function tap(id)
        local target=node(id);local r=target:GetAbsoluteLayout()
        assert(UI.FindWidgetAt(r.x+r.w/2,r.y+r.h/2)==target,"blocked "..id)
        point("PointerDown",r.x+r.w/2,r.y+r.h/2);point("PointerUp",r.x+r.w/2,r.y+r.h/2)
    end
    local function wheel(id,dy)
        local scroll=node(id);local r=scroll:GetAbsoluteLayout()
        point("PointerMove",r.x+r.w*.7,r.y+r.h*.6)
        local hit=UI.FindWidgetAt(r.x+r.w*.7,r.y+r.h*.6)
        local ancestor=hit
        while ancestor and ancestor~=scroll do ancestor=ancestor.parent end
        assert(ancestor==scroll,"wheel hit does not reach "..id)
        UI.HandleWheel(0,dy)
    end
    local function cleanup(ctx)
        if view then view.root:Destroy();view=false end
        ctx.root:SetVisible(true);ctx.Refresh();done=true
    end
    return function(ctx)
        if done or not ctx.root.parent then return end
        if view then view.Update() end
        local now=GetTime():GetElapsedTime();if now<deadline then return end
        -- PNG capture stalls wall time between rendered frames. Wait for the
        -- controller's animation clock before judging arrival/count-up evidence.
        if view then
            local record,reward=view.feedback.motion.record,view.feedback.motion.reward
            if phase==6 and record and record.time<record.duration+.05 then return end
            if phase==7 and reward and reward.time<.35 then return end
            if phase==8 and reward and reward.time<reward.duration+.05 then return end
            if phase==9 and reward and reward.time<reward.duration+.55 then return end
        end
        local ok,err=pcall(function()
            if phase==0 then
                print("[ReadingNative] START engine-native event routing; window focus="..tostring(input:HasFocus()))
                before=ctx.session.state.GetSnapshot()
                local data=U.Copy(require "data.content");data.release=nil
                fixture=F.New(data,{targetSchema=3})
                letter=F.Must(fixture.state.ReceiveLetter({letterId="letter_pa_01"})).letterInstanceId
                local checks=require "ui.landscape.DevChecks";checks.readingProbe=false
                view=require("ui.landscape.AppView").New(fixture.session,data);checks.readingProbe=true
                ctx.root:SetVisible(false);ctx.root.parent:AddChild(view.root)
                F.Must(view.Read(letter));view.Update();deadline=now+1.5
            elseif phase==1 then
                local action=node("acceptOrder"):GetAbsoluteLayout();local scroll=node("playScroll"):GetAbsoluteLayout()
                local panel=node("activePanel"):GetAbsoluteLayout()
                assert(action.y>=scroll.y+scroll.h-1,"accept is outside prose scroll")
                assert(math.abs(action.x+action.w/2-panel.x-panel.w/2)<2,"accept is centered")
                footerY=action.y;capture("reader_top");wheel("playScroll",-100);deadline=now+.6
            elseif phase==2 then
                local _,y=node("playScroll"):GetScroll();assert(y>0,"reader wheel scrolls")
                assert(math.abs(node("acceptOrder"):GetAbsoluteLayout().y-footerY)<1,"accept stays fixed")
                local reward=node("readerReward"):GetAbsoluteLayoutForHitTest()
                local summary=node("readerOrderSummary"):GetAbsoluteLayoutForHitTest()
                assert(reward.w>=160 and reward.h>=24 and reward.x+reward.w<=summary.x+summary.w,"reward has visible space inside commission slip")
                capture("reader_summary")
                local tokens={}
                for _,span in ipairs(F.Must(fixture.modules.letters.GetView(letter)).spans) do
                    tokens[span.wordId]=F.Must(view.model.Cut(span.spanId)).tokenId
                end
                tap("acceptOrder");view.Update()
                local recipe=require("debug.fixtures.NumericV02Cases")[1].recipe
                F.Must(view.model.Drop("word",tokens[recipe.mainWordId]))
                for _,word in ipairs(recipe.auxWordIds) do F.Must(view.model.Drop("word",tokens[word])) end
                for _,line in ipairs(recipe.ingredients) do for _=1,line.quantity do F.Must(view.model.Drop("ingredient",line.ingredientId)) end end
                view.brew.selected="recipe";view.model.dirty=true;view.Update();deadline=now+2.5
            elseif phase==3 then
                assert(node("brewNotesTitle") and not view.root:FindById("brewEffectNumbers"),"notes hide weights by default")
                local body=node("brewDetailBody"):GetAbsoluteLayout();local footer=node("brewNotesActions"):GetAbsoluteLayout()
                assert(body.h>20 and footer.y>=body.y+body.h-1,"notes have a scrolling body and fixed petals")
                capture("notes");tap("brewToggleNumbers");view.Update();deadline=now+1
            elseif phase==4 then
                assert(node("brewEffectNumbers"),"weights expand on request")
                capture("notes_numbers");tap("dismissIngredient");view.Update()
                view.brew.journal.Close();view.Update()
                F.Must(view.model.Preview());view.Open("result");view.Update();deadline=now+.7
            elseif phase==5 then
                assert(view.brew.journalOpen and view.feedback.motion.record,"saved story opens the closed record book")
                capture("record_trail");capture("result_top");wheel("resultScroll",-100);deadline=now+.8
            elseif phase==6 then
                local _,y=node("resultScroll"):GetScroll();assert(y>0,"result wheel scrolls through actual hover routing")
                local body=node("pendingBody"):GetAbsoluteLayoutForHitTest();local scroll=node("resultScroll"):GetAbsoluteLayout()
                assert(body.y+body.h<=scroll.y+scroll.h+2,"last result line is reachable")
                capture("record_arrived");capture("result_bottom")
                currencyBefore=fixture.state.GetSnapshot().live.economy.currency
                tap("confirmOrder");view.Update();deadline=now+.45
            elseif phase==7 then
                assert(view.feedback.motion.reward and view.feedback.motion.reward.amount>0,"saved shipping starts gold trail")
                assert(view.root:FindById("playLedger"):GetText():find("金币 "..currencyBefore,1,true),"ledger waits for trail arrival")
                capture("reward_trail");deadline=now+.1
            elseif phase==8 then
                capture("reward_arrival");deadline=now+.1
            elseif phase==9 then
                local current=fixture.state.GetSnapshot().live.economy.currency
                assert(view.root:FindById("playLedger"):GetText():find("金币 "..current,1,true),"visible amount catches up to real reward")
                capture("reward_settled")
                local reader=view --[[@as table]]
                assert(reader.panel==false and reader.brew.journalOpen,"shipping reuses pot-side catalog")
                local page=F.Must(fixture.session.queries.GetJournalPage("letter_pa_01"))
                for _,entry in ipairs(require("ui.landscape.JournalBook").Entries(page)) do
                    if entry.collected then branch=entry.fragmentId;transaction=entry.transactionId;break end
                end
                assert(branch and transaction,"stored journal branch has attempt identity")
                capture("journal_catalog");tap("bookEntry_"..branch);reader.Update();deadline=now+.7
            elseif phase==10 then
                assert(view.panel=="attempt" and view.model.selectedAttempt==transaction,"book opens exact saved attempt")
                local record=F.Must(fixture.session.queries.GetAttempt(transaction))
                assert(node("historyBody"):GetText()==record.followup.renderedText,"history is the saved full text")
                assert(not view.root:FindById("confirmOrder"),"history cannot settle twice")
                capture("history_top");wheel("resultScroll",-100);deadline=now+.6
            elseif phase==11 then
                local _,y=node("resultScroll"):GetScroll();assert(y>0,"history wheel scrolls")
                capture("history_bottom");tap("closePanel");view.Update();deadline=now+.7
            elseif phase==12 then
                local reader=view --[[@as table]]
                assert(reader.panel==false and node("bookEntry_"..branch),"closing history returns to pot-side catalog")
                local function countBooks(w)
                    ---@type number
                    local n=w.props.id=="bookArtFrame" and 1 or 0
                    for _,child in ipairs(w.children) do n=n+countBooks(child) end
                    return n
                end
                assert(countBooks(reader.root)==1,"only one record book exists")
                tap("brewJournalClose");reader.Update();deadline=now+.6
            elseif phase==13 then
                assert(not view.brew.journalOpen and not view.root:FindById("bookArtFrame"),"one close removes record book")
                capture("single_book_closed")
                assert(U.Equal(before,ctx.session.state.GetSnapshot()),"player state changed")
                cleanup(ctx)
                print("[ReadingNative] PASS fixed centered accept / separate summary / hover-wheel to final line / saved history paper / record trail opens single book / gold trail and actual count-up / catalog return / player state unchanged; NOT phone evidence")
            end
            phase=phase+1
        end)
        if not ok then print("[ReadingNative] FAIL phase="..phase.." "..tostring(err));cleanup(ctx) end
    end
end
return N
