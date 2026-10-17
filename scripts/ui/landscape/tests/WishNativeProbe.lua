-- Explicitly enabled native evidence. Memory-only real eleven-letter route; no OS input.
local UI=require "urhox-libs/UI"
local U=require "core.StateUtil"
local E=require "debug.fixtures.ReleaseEndingFixtures"
local Event=require "urhox-libs/UI/Core/PointerEvent"
local Hud=require "ui.landscape.HudLayout"
local Gesture=require "urhox-libs/UI/Core/GestureEvent"
local P={}
function P.New()
    local stage,deadline,done=0,0,false
    local cooldown=0
    local view=false --[[@as table|false]]
    local fixture=false --[[@as table|false]]
    local before=false --[[@as table|false]]
    local readHost=Hud.ReadHost
    local host="left"
    local surface=false --[[@as table|false]]
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
        view.Update()
    end
    local function drag(id,dx,dy)
        UI.Layout()
        local r=node(id):GetAbsoluteLayout();local x,y=r.x+r.w/2,r.y+r.h/2
        local hit=UI.FindWidgetAt(x,y)
        print("[WishNative] DRAG "..id.." rect="..cjson.encode(r).." hit="..tostring(hit and hit.props.id))
        assert(hit==node(id),"gesture handle was not the pointer target")
        local revision=fixture.state.GetSnapshot().revision;local s=UI.GetScale()
        local function pan(kind,xx,yy)
            UI.HandleGestureEvent(Gesture.new(kind,{target=hit,x=xx*s,y=yy*s,pointerId=0,pointerType="mouse",
                deltaX=dx*s,deltaY=dy*s,totalDeltaX=dx*s,totalDeltaY=dy*s}))
        end
        send("PointerDown",x,y);pan("PanStart",x,y)
        send("PointerMove",x+dx,y+dy);pan("PanMove",x+dx,y+dy)
        assert(fixture.state.GetSnapshot().revision==revision,"native preview cannot write")
        send("PointerUp",x+dx,y+dy);pan("PanEnd",x+dx,y+dy);view.Update()
        assert(fixture.state.GetSnapshot().revision==revision+1,"native gesture commits once")
    end
    local function capture(name)
        local img=Image();assert(graphics:TakeScreenShot(img))
        if host~="desktop" then local s=UI.GetScale();img=img:GetSubimage(IntRect(0,0,math.floor(1206*s),math.floor(540*s))) end
        assert(img:SavePNG("second_batch_"..name..".png"))
        print("[WishNative] CAPTURE "..name)
    end
    local function transform(mode,factor,degrees)
        UI.Layout()
        local p=view.journeyView.paper;local id=view.wishSelected;local row=p.cards[id].display
        local cx,cy=p.rect.x+row.x*p.rect.w,p.rect.y+row.y*p.rect.h
        local b=node("wishHandle_"..mode):GetAbsoluteLayout();local x,y=b.x+b.w/2,b.y+b.h/2
        local dx,dy=x-cx,y-cy;local a=math.rad(degrees or 0)
        drag("wishHandle_"..mode,(dx*math.cos(a)-dy*math.sin(a))*factor-dx,(dx*math.sin(a)+dy*math.cos(a))*factor-dy)
    end
    local function centered(kind)
        if surface then surface.Destroy();surface.root:Destroy() end
        local ctx=setmetatable({SetDepartureMusic=function() end,SetApprenticeMusic=function() end},{__index=view})
        local ending=kind=="wish" and E.Must(fixture.session.queries.GetEndingView()).ending or fixture.content.releaseEndings[kind]
        local render=kind=="apprentice" and require("ui.landscape.ApprenticeView").Narration
            or kind=="wish" and require("ui.landscape.WishEnding").New or require("ui.landscape.DepartureView").New
        surface=render(ctx,ending,false);surface.root.props.zIndex=5000;view.root:AddChild(surface.root)
        for _=1,2000 do
            surface.Update(.1,true)
            if surface.sequence.CanAdvance() then surface.sequence.Advance() end
            if surface.sequence.done then break end
        end
        assert(surface.sequence.done);UI.Layout()
        local evidence={kind=kind,host=host,viewport=view.viewport,safe=view.safeInsets,
            parent=U.Copy(view.root:GetAbsoluteLayout()),root=U.Copy(surface.root:GetAbsoluteLayout()),controls={}}
        for _,id in ipairs({"releaseEndingTitle","departureSubtitle","endGame"}) do
            local r=surface.root:FindById(id):GetAbsoluteLayout();evidence.controls[id]=U.Copy(r)
            assert(math.abs(r.x+r.w/2-view.viewport.w/2)<1,"center chain "..kind.." "..host.." "..id)
        end
        print("[WishNative] CENTER_ALL "..cjson.encode(evidence))
    end
    local function take(id)
        UI.Layout();local target=node(id);local b=target:GetAbsoluteLayout();local p=view.journeyView.paper.rect
        local x,y=b.x+b.w/2,b.y+b.h/2
        assert(UI.FindWidgetAt(x,y)==target,"tray source must receive pointer")
        local revision=fixture.state.GetSnapshot().revision
        send("PointerDown",x,y);send("PointerUp",x,y)
        assert(fixture.state.GetSnapshot().revision==revision,"tap must not take a tray piece")
        send("PointerDown",x,y);send("PointerMove",p.x+p.w*.65,p.y+p.h*.55)
        assert(fixture.state.GetSnapshot().revision==revision,"tray drag must not write before release")
        send("PointerUp",p.x+p.w*.65,p.y+p.h*.55);view.Update()
        assert(fixture.state.GetSnapshot().revision==revision+1,"tray drag must commit once")
    end
    local function arrange()
        local wish=E.Must(fixture.session.queries.GetWishView());local byText={}
        for _,sample in ipairs(wish.samples) do byText[sample.text]=sample.sourceTokenId end
        local rows={};local selected
        local specs={{"笑着",.43,.37,-4,1.35},{"唱歌",.61,.37,4,1.35},
            {"安安稳稳",.44,.58,-2,1.25},{"合上眼",.65,.58,4,1.25}}
        for _,s in ipairs(specs) do
            local id=assert(byText[s[1]],s[1]);selected=id
            rows[#rows+1]={sourceTokenId=id,x=s[2],y=s[3],angle=s[4],scale=s[5],z=10+#rows,canvasAspect=2}
        end
        local decor={{"paper-long",.52,.37,-2,1.9,1},{"paper-medium",.54,.58,2,2.4,2},
            {"daisy",.23,0,-18,1.05,5},{"forget-me-not",.98,.40,18,.95,6},
            {"fern",.02,.72,-28,1.2,7},{"wheat",.80,1.01,30,1.05,8},{"pink-wildflower",.54,.79,67,.85,9}}
        for i,s in ipairs(decor) do rows[#rows+1]={decorationId=s[1],instanceId="decor:"..i,x=s[2],y=s[3],angle=s[4],scale=s[5],z=s[6],canvasAspect=2,freePlacement=true} end
        E.Must(fixture.state.UpdateWishLayout(E.Request(fixture,{placements=rows})))
        view.wishSelected=selected;view.Refresh();view.Update()
    end
    local function fits(paper,area)
        local rect=paper.root:GetAbsoluteLayout()
        assert(rect.x>=area.x-2 and rect.y>=area.y-2 and rect.x+rect.w<=area.x+area.w+2 and rect.y+rect.h<=area.y+area.h+2,"whole letter fits")
        for _,card in pairs(paper.cards) do
            local r=card.root:GetAbsoluteLayout();local a=math.rad(card.display.angle)
            local w=math.abs(math.cos(a))*r.w+math.abs(math.sin(a))*r.h
            local h=math.abs(math.sin(a))*r.w+math.abs(math.cos(a))*r.h
            local x,y=r.x+r.w/2-w/2,r.y+r.h/2-h/2
            assert(x>=area.x-2 and y>=area.y-2 and x+w<=area.x+area.w+2 and y+h<=area.y+area.h+2,"all rotated overflow artwork fits")
        end
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
        if cooldown>0 then cooldown=cooldown-1;return end
        local now=GetTime():GetElapsedTime();if now<deadline then return end
        local ok,err=pcall(function()
            if stage==0 then
                Hud.ReadHost=function()
                    if host=="desktop" then local w,h=UI.GetViewportSize();return {w=w,h=h},{left=0,right=0,top=0,bottom=0},nil end
                    return {w=1206,h=540},{left=host=="left" and 48 or 0,right=host=="right" and 48 or 0,top=0,bottom=12},
                        {left=.86,right=.99,top=.02,bottom=.16}
                end
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
                if require("urhox-libs/UI/Core/ImageCache").Get("image/wish-collage-r1/table-background.png")<=0 then return end
                assert(view.panel=="wish");assert(node("activePanel"):GetAbsoluteLayout().x==0)
                assert(not view.root:FindById("wishFooter"),"no fixed bottom toolbar")
                local paper=node("wishPaper"):GetAbsoluteLayout();assert(paper.w>800 and paper.h>390,"large fitted paper")
                capture("03-empty-editor");arrange();deadline=now+1
            elseif stage==9 then
                UI.Layout()
                local edge=node("wish_piece_decor:6");local b=edge:GetAbsoluteLayout()
                assert(b.y+b.h/2>view.journeyView.paper.rect.y+view.journeyView.paper.rect.h,"flower center is outside paper")
                assert(UI.FindWidgetAt(b.x+b.w/2,b.y+b.h/2)==edge,"outside flower remains selectable")
                tap("wish_piece_decor:6")
                capture("04-word-tray")
                if not view.root:FindById("wordTrayTab_wish_decor") then tap("wordTrayCategoryNext");deadline=now+.3;return end
                deadline=now+.6
            elseif stage==10 then tap("wordTrayTab_wish_decor");deadline=now+.8
            elseif stage==11 then capture("05-decor-tray");take("wish_decor_daisy");deadline=now+.6
            elseif stage==12 then
                assert(#E.Must(fixture.session.queries.GetWishView()).placements==12)
                transform("scale",1.8);deadline=now+.6
            elseif stage==13 then
                local rows=E.Must(fixture.session.queries.GetWishView()).placements
                assert(rows[#rows].scale>1,"native scale handle did not persist")
                transform("rotate",1,90)
                rows=E.Must(fixture.session.queries.GetWishView()).placements
                assert(math.abs(rows[#rows].angle-90)<.1,"native rotate handle did not persist")
                tap("wishLock");deadline=now+.6
            elseif stage==14 then
                local rows=E.Must(fixture.session.queries.GetWishView()).placements
                assert(rows[#rows].locked,"native lock did not persist")
                capture("11-native-rotated-locked")
                tap("wishUndo");deadline=now+.6
            elseif stage==15 then
                tap("wishUndo");deadline=now+.6
            elseif stage==16 then
                tap("wishUndo");tap("wishUndo");deadline=now+.6
            elseif stage==17 then
                assert(#E.Must(fixture.session.queries.GetWishView()).placements==11)
                local nextPage=node("wordTrayNext")
                if not nextPage.props.disabled then tap("wordTrayNext");deadline=now+.2;return end
                deadline=now+.7
            elseif stage==18 then capture("06-blank-paper-tray");tap("previewWish");deadline=now+.8
            elseif stage==19 then
                local Layout=require "ui.landscape.WishLayout"
                fits(view.journeyView.paper,Layout.Compute(view.viewport,view.safeInsets,true,2,view.menuRect).area)
                capture("07-preview");tap("confirmWish");deadline=now+1.4
            elseif stage==20 then
                if not view.journeyView.sequence.CanAdvance() then return end
                assert(view.panel=="ending");capture("08-sending-narration");tap("departureAdvance");deadline=now+.9
            elseif stage==21 or stage==22 then
                if not view.journeyView.sequence.CanAdvance() then return end
                tap("departureAdvance");deadline=now+(stage==22 and 3.2 or .9)
            elseif stage==23 then
                if not view.journeyView.sequence.done then return end
                local evidence={viewport=view.viewport,safe=view.safeInsets,parent=view.root:GetAbsoluteLayout(),root=view.journeyView.root:GetAbsoluteLayout(),controls={}}
                for _,id in ipairs({"releaseEndingTitle","departureSubtitle","endGame","viewEndingCollage"}) do
                    local r=node(id):GetAbsoluteLayout();evidence.controls[id]=r
                    assert(math.abs(r.x+r.w/2-603)<1,"mobile ending screen axis "..id)
                end
                print("[WishNative] CENTER "..cjson.encode(evidence))
                assert(node("endGame").props.visible);capture("09-ending");tap("viewEndingCollage");deadline=now+.7
            elseif stage==24 then
                local overlay=node("wishFrozenPaper")
                local ending=E.Must(fixture.session.queries.GetEndingView()).ending
                assert(ending.collage.placements[10].freePlacement and ending.collage.placements[10].y==1.01,"frozen flower keeps its outside coordinate")
                local cards={}
                for _,row in ipairs(ending.collage.placements) do cards[require("systems.WishCollage").Id(row)]={root=node("wish_piece_"..require("systems.WishCollage").Id(row)),display=row} end
                fits({root=overlay,cards=cards},{x=0,y=0,w=view.viewport.w,h=view.viewport.h-72})
                capture("10-frozen-collage");tap("closeFrozenWish");deadline=now+.5
            elseif stage==25 then tap("endGame");deadline=now+.7
            elseif stage==26 then
                assert(view.atTitle,"return-to-title failed")
                assert(U.Equal(before,ctx.session.state.GetSnapshot()),"real player state changed")
            elseif stage>=27 and stage<=35 then
                local index=stage-27
                if index>0 then capture("center-"..({"left","right","desktop"})[math.floor((index-1)/3)+1].."-"..({"departure","apprentice","wish"})[(index-1)%3+1]) end
                host=({"left","right","desktop"})[math.floor(index/3)+1];view.Update()
                centered(({"departure","apprentice","wish"})[index%3+1]);deadline=now+.5
            elseif stage==36 then
                capture("center-desktop-wish")
                assert(U.Equal(before,ctx.session.state.GetSnapshot()),"real player state changed")
                if surface then surface.Destroy();surface.root:Destroy();surface=false end
                Hud.ReadHost=readHost
                view.root:Destroy();view=false;ctx.root:SetVisible(true);ctx.SetDepartureMusic(nil)
                done=true;print("[WishNative] PASS real eleven-letter route; native drag/scale/rotate/pan/lock/undo/send; nine ending center chains; player state unchanged; NOT physical phone")
            end
            print("[WishNative] STEP "..stage.." panel="..tostring(view and view.panel))
            stage=stage+1
            cooldown=3 -- Screenshot reads the rendered backbuffer, not the freshly mutated tree.
        end)
        if not ok then
            print("[WishNative] FAIL stage="..stage.." "..tostring(err))
            Hud.ReadHost=readHost
            if surface then surface.Destroy();surface.root:Destroy();surface=false end
            if view then view.root:Destroy();view=false end
            ctx.root:SetVisible(true);ctx.SetDepartureMusic(nil);done=true
        end
    end
end
return P
