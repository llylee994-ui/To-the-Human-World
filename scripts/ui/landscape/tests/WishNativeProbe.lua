-- Explicitly enabled native evidence. Memory-only real eleven-letter route; no OS input.
local UI=require "urhox-libs/UI"
local U=require "core.StateUtil"
local E=require "debug.fixtures.ReleaseEndingFixtures"
local Event=require "urhox-libs/UI/Core/PointerEvent"
local P={}
function P.New()
    local stage,deadline,done=0,0,false
    local view=false --[[@as table|false]]
    local fixture=false --[[@as table|false]]
    local before=false --[[@as table|false]]
    local function node(id) return assert(view.root:FindById(id),id) end
    local function send(kind,x,y)
        local e=Event.new(kind,{x=x*UI.GetScale(),y=y*UI.GetScale(),pointerId=0,pointerType="mouse",button=MOUSEB_LEFT})
        if kind=="PointerDown" then UI.HandlePointerDown(e)
        elseif kind=="PointerMove" then UI.HandlePointerMove(e) else UI.HandlePointerUp(e) end
    end
    local function tap(id)
        UI.Layout()
        local r=node(id):GetAbsoluteLayoutForHitTest();local x,y=r.x+r.w/2,r.y+r.h/2
        send("PointerDown",x,y);send("PointerUp",x,y)
    end
    local function drag(id,dx,dy)
        UI.Layout()
        local r=node(id):GetAbsoluteLayout();local x,y=r.x+r.w/2,r.y+r.h/2
        local hit=UI.FindWidgetAt(x,y)
        print("[WishNative] DRAG "..id.." rect="..cjson.encode(r).." hit="..tostring(hit and hit.props.id))
        assert(hit==node(id),"gesture handle was not the pointer target")
        send("PointerDown",x,y);send("PointerMove",x+dx,y+dy);send("PointerUp",x+dx,y+dy)
    end
    local function capture(name)
        local img=Image();assert(graphics:TakeScreenShot(img))
        assert(img:SavePNG("wish_native_"..name..".png"))
        print("[WishNative] CAPTURE "..name)
    end
    local function arrange()
        local wish=E.Must(fixture.session.queries.GetWishView());local byText={}
        for _,sample in ipairs(wish.samples) do byText[sample.text]=sample.sourceTokenId end
        local rows={};local selected
        local specs={{"笑着",.43,.37,-4,1.35},{"唱歌",.61,.37,4,1.35},
            {"安安稳稳",.44,.58,-2,1.25},{"合上眼",.65,.58,4,1.25}}
        for _,s in ipairs(specs) do
            local id=assert(byText[s[1]],s[1]);selected=id
            rows[#rows+1]={sourceTokenId=id,x=s[2],y=s[3],angle=s[4],scale=s[5],z=10+#rows}
        end
        local decor={{"paper-long",.52,.37,-2,1.9,1},{"paper-medium",.54,.58,2,2.4,2},
            {"daisy",.23,.36,-18,1.05,5},{"forget-me-not",.76,.40,18,.95,6},
            {"fern",.22,.72,-28,1.2,7},{"wheat",.80,.72,30,1.05,8},{"pink-wildflower",.54,.79,67,.85,9}}
        for i,s in ipairs(decor) do rows[#rows+1]={decorationId=s[1],instanceId="decor:"..i,x=s[2],y=s[3],angle=s[4],scale=s[5],z=s[6]} end
        E.Must(fixture.state.UpdateWishLayout(E.Request(fixture,{placements=rows})))
        view.wishSelected=selected;view.Refresh();view.Update()
    end
    return function(ctx)
        if done or not ctx.root.parent then return end
        if view then
            local journey=view.journeyView
            if journey and journey.Update and not journey.backgroundEvidence then
                local update=journey.Update
                journey.Update=function(dt) update(dt,true) end
                journey.backgroundEvidence=true
            end
            view.Update()
        end
        local now=GetTime():GetElapsedTime();if now<deadline then return end
        local ok,err=pcall(function()
            if stage==0 then
                before=ctx.session.state.GetSnapshot();fixture=E.Route(7)
                fixture.content.releaseEndings=U.Copy(require "data.release_endings")
                local p=E.Must(fixture.session.queries.GetReleaseProgress())
                assert(p.completedCount==11 and not p.canApprentice)
                local checks=require "ui.landscape.DevChecks";checks.wishProbe=false
                view=require("ui.landscape.AppView").New(fixture.session,fixture.content);checks.wishProbe=true
                ctx.root:SetVisible(false);ctx.SetDepartureMusic(0)
                ctx.root.parent:AddChild(view.root)
                view.Navigate("seaside");view.Update();view.Open("day");view.Update();deadline=now+2
            elseif stage==1 then
                tap("confirmNextDay");deadline=now+2.5
            elseif stage==2 then
                assert(view.panel=="closing");capture("01-bottle-intro");tap("continueEpilogue");deadline=now+1.2
            elseif stage==3 then tap("catchEpilogueBottle");deadline=now+3
            elseif stage==4 then
                if node("wishPreludeHint").props.opacity~=1 then return end
                capture("02-letter-narration");tap("openEpilogueBottle");deadline=now+.9
            elseif stage>=5 and stage<=7 then
                if node("wishPreludeHint").props.opacity~=1 then return end
                tap("openEpilogueBottle");deadline=now+.9
            elseif stage==8 then
                assert(view.panel=="wish");capture("03-empty-editor");arrange();deadline=now+1
            elseif stage==9 then
                capture("04-word-tray")
                node("wordTrayTabs"):ScrollToBottom();deadline=now+.6
            elseif stage==10 then tap("wordTrayTab_wish_decor");deadline=now+.8
            elseif stage==11 then capture("05-decor-tray");tap("wish_decor_daisy");deadline=now+.6
            elseif stage==12 then
                assert(#E.Must(fixture.session.queries.GetWishView()).placements==12)
                drag("wishHandle_scale",35,30);deadline=now+.6
            elseif stage==13 then
                local rows=E.Must(fixture.session.queries.GetWishView()).placements
                assert(rows[#rows].scale>1,"native scale handle did not persist")
                tap("wishLock");deadline=now+.6
            elseif stage==14 then
                local rows=E.Must(fixture.session.queries.GetWishView()).placements
                assert(rows[#rows].locked,"native lock did not persist")
                tap("wishUndo");deadline=now+.6
            elseif stage==15 then
                tap("wishUndo");deadline=now+.6
            elseif stage==16 then
                tap("wishUndo");deadline=now+.6
            elseif stage==17 then
                assert(#E.Must(fixture.session.queries.GetWishView()).placements==11)
                local scroll=node("wordTrayStrips") --[[@as ScrollView]]
                scroll:ScrollToBottom();deadline=now+.7
            elseif stage==18 then capture("06-blank-paper-tray");tap("previewWish");deadline=now+.8
            elseif stage==19 then capture("07-preview");tap("confirmWish");deadline=now+1.4
            elseif stage==20 then
                if not view.journeyView.sequence.CanAdvance() then return end
                assert(view.panel=="ending");capture("08-sending-narration");tap("departureAdvance");deadline=now+.9
            elseif stage==21 or stage==22 then
                if not view.journeyView.sequence.CanAdvance() then return end
                tap("departureAdvance");deadline=now+(stage==22 and 3.2 or .9)
            elseif stage==23 then
                if not view.journeyView.sequence.done then return end
                assert(node("endGame").props.visible);capture("09-ending");tap("viewEndingCollage");deadline=now+.7
            elseif stage==24 then
                capture("10-frozen-collage");tap("closeFrozenWish");deadline=now+.5
            elseif stage==25 then tap("endGame");deadline=now+.7
            elseif stage==26 then
                assert(view.atTitle,"return-to-title failed")
                assert(U.Equal(before,ctx.session.state.GetSnapshot()),"real player state changed")
                view.root:Destroy();view=false;ctx.root:SetVisible(true);ctx.SetDepartureMusic(nil)
                done=true;print("[WishNative] PASS real eleven-letter route; native drag/scale/lock/undo/send; player state unchanged")
            end
            print("[WishNative] STEP "..stage.." panel="..tostring(view and view.panel))
            stage=stage+1
        end)
        if not ok then
            print("[WishNative] FAIL stage="..stage.." "..tostring(err))
            if view then view.root:Destroy();view=false end
            ctx.root:SetVisible(true);ctx.SetDepartureMusic(nil);done=true
        end
    end
end
return P
