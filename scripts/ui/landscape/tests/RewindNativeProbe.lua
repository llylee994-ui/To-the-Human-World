-- Opt-in native UI evidence with memory-only saves and synthetic touch input.
-- Phone host adapters verify layout; they are not physical-device acceptance.
local UI=require "urhox-libs/UI"
local U=require "core.StateUtil"
local R=require "debug.fixtures.ReleaseFixtures"
local Hud=require "ui.landscape.HudLayout"
local Pointer=require "urhox-libs/UI/Core/PointerEvent"
local Gesture=require "urhox-libs/UI/Core/GestureEvent"
local P={}
function P.New()
    local stage,deadline,done=0,0,false
    local cooldown=0
    local view=false --[[@as table|false]]
    local fixture=false --[[@as table|false]]
    local before=false --[[@as table|false]]
    local host="left"
    local readHost=Hud.ReadHost
    local function node(id) return assert(view.root:FindById(id),id) end
    local function tap(id)
        UI.Layout()
        local target=node(id);local r=target:GetAbsoluteLayoutForHitTest()
        local x,y=r.x+r.w/2,r.y+r.h/2
        assert(UI.FindWidgetAt(x,y)==target,"touch blocked: "..id.." "..cjson.encode(r))
        local s=UI.GetScale()
        UI.HandlePointerDown(Pointer.new("PointerDown",{x=x*s,y=y*s,pointerId=81,pointerType="touch",button=MOUSEB_LEFT}))
        UI.HandlePointerUp(Pointer.new("PointerUp",{x=x*s,y=y*s,pointerId=81,pointerType="touch",button=MOUSEB_LEFT}))
        view.Update()
    end
    local function capture(name)
        local im=Image();assert(graphics:TakeScreenShot(im))
        if host~="desktop" then local s=UI.GetScale();im=im:GetSubimage(IntRect(0,0,math.floor(1206*s),math.floor(540*s))) end
        assert(im:SavePNG("third_rewind_"..name..".png"))
        print("[RewindNative] CAPTURE "..name)
    end
    local function layout()
        UI.Layout()
        local evidence={host=host,viewport=view.viewport,safe=view.safeInsets,controls={}}
        local vp,safe=view.viewport,view.safeInsets
        for _,id in ipairs({"rewindPaper","rewindClose","rewindActions","rewindCancel","rewindRestore","rewindScroll"}) do
            local r=node(id):GetAbsoluteLayout();evidence.controls[id]=U.Copy(r)
            assert(r.w>0 and r.h>0 and r.x>=safe.left-1 and r.x+r.w<=vp.w-safe.right+1
                and r.y>=safe.top-1 and r.y+r.h<=vp.h-safe.bottom+1,"safe fit "..host.." "..id)
        end
        print("[RewindNative] LAYOUT "..cjson.encode(evidence))
    end
    local function scrollBackup()
        UI.Layout()
        local r=node("rewindScroll"):GetAbsoluteLayout();local x,y=r.x+r.w*.9,r.y+r.h*.7
        local target=assert(UI.FindWidgetAt(x,y));local s=UI.GetScale()
        local function pan(kind,yy)
            UI.HandleGestureEvent(Gesture.new(kind,{target=target,x=x*s,y=yy*s,pointerId=82,pointerType="touch",
                deltaX=0,deltaY=-180*s,totalDeltaX=0,totalDeltaY=-180*s}))
        end
        UI.HandlePointerDown(Pointer.new("PointerDown",{x=x*s,y=y*s,pointerId=82,pointerType="touch",button=MOUSEB_LEFT}))
        pan("PanStart",y-8);pan("PanMove",y-180);pan("PanEnd",y-180)
        UI.HandlePointerUp(Pointer.new("PointerUp",{x=x*s,y=(y-180)*s,pointerId=82,pointerType="touch",button=MOUSEB_LEFT}))
    end
    local function cleanup(ctx)
        Hud.ReadHost=readHost
        if view then
            if view.journeyView then view.journeyView.Destroy() end
            view.root:Destroy();view=false
        end
        ctx.root:SetVisible(true);ctx.Refresh();done=true
    end
    return function(ctx)
        if done or not ctx.root.parent then return end
        if view then view.Update() end
        if cooldown>0 then cooldown=cooldown-1;return end
        local now=GetTime():GetElapsedTime();if now<deadline then return end
        local ok,err=pcall(function()
            if stage==0 then
                before=ctx.session.state.GetSnapshot();fixture=R.New()
                R.Must(fixture.state.StartJourney({expectedRevision=0}))
                for day=1,7 do R.Ship(fixture,day);R.Must(fixture.state.NextDay()) end
                Hud.ReadHost=function()
                    if host=="desktop" then local w,h=UI.GetViewportSize();return {w=w,h=h},{left=0,right=0,top=0,bottom=0},nil end
                    return {w=1206,h=540},{left=host=="left" and 48 or 0,right=host=="right" and 48 or 0,top=0,bottom=12},
                        {left=.86,right=.99,top=.02,bottom=.16}
                end
                local checks=require "ui.landscape.DevChecks";checks.rewindProbe=false
                view=require("ui.landscape.AppView").New(fixture.session,fixture.content);checks.rewindProbe=true
                ctx.root:SetVisible(false);ctx.root.parent:AddChild(view.root)
                assert(view.ShowTitle());view.Update()
            elseif stage==1 then
                if require("urhox-libs/UI/Core/ImageCache").Get("image/title-screen-r1/shop-doorway-soft.png")<=0 then return end
                capture("01-title-left");tap("openRewind")
            elseif stage==2 then
                layout();capture("02-days-left");tap("rewindNext")
            elseif stage==3 then
                assert(node("rewindDay_8"));capture("03-page-two-left");tap("rewindPrev")
            elseif stage==4 then
                tap("rewindDay_2")
            elseif stage==5 then
                capture("04-selection-left")
                local revision=fixture.state.GetSnapshot().revision
                tap("rewindRestore")
                assert(view.panel==false and fixture.state.GetSnapshot().live.gameFlow.day==2)
                assert(fixture.state.GetSnapshot().revision==revision+1)
                local reloaded=require("debug.fixtures.ReleaseEndingFixtures").Clone(fixture)
                assert(reloaded.state.GetSnapshot().live.gameFlow.day==2)
                assert(view.ShowTitle());view.Update();tap("openRewind")
            elseif stage==6 then
                layout();scrollBackup()
            elseif stage==7 then
                local _,y=node("rewindScroll"):GetScroll();assert(y>0,"touch scroll reaches backup")
                capture("05-backup-left");tap("rewindBackupRestore")
                assert(fixture.state.GetSnapshot().live.gameFlow.day==8)
                host="right";assert(view.ShowTitle());view.Update();tap("openRewind")
            elseif stage==8 then
                layout();capture("06-days-right")
                local writes=fixture.writes;tap("rewindCancel")
                assert(view.panel=="title" and fixture.writes==writes,"cancel wrote progress")
                host="desktop";view.Update();tap("openRewind")
            elseif stage==9 then
                layout();capture("07-days-desktop");tap("rewindDay_2")
                local old=view.session.state.GetSnapshot();fixture.fault="write"
                tap("rewindRestore");fixture.fault=false
                assert(view.panel=="rewind" and U.Equal(old,view.session.state.GetSnapshot()),"failed save installed state")
                assert(view.model.message:find("保存失败",1,true))
            elseif stage==10 then
                capture("08-write-failure-desktop")
                assert(U.Equal(before,ctx.session.state.GetSnapshot()),"player save changed")
                cleanup(ctx)
                print("[RewindNative] PASS native title/paging/select/restore/reload/backup/cancel/save-failure; left/right safe areas and desktop; player state unchanged; NOT physical phone")
            end
            print("[RewindNative] STEP "..stage)
            stage=stage+1;deadline=now+.8
            cooldown=3 -- Screen capture reads a rendered frame, not a freshly changed tree.
        end)
        if not ok then print("[RewindNative] FAIL stage="..stage.." "..tostring(err));cleanup(ctx) end
    end
end
return P
