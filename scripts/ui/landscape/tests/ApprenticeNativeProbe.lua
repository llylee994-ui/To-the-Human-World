-- Explicit opt-in screenshots using a memory-only session and the native renderer.
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
    local function tap(id)
        local w=node(id);local r=w:GetAbsoluteLayout()
        local x,y=(r.x+r.w/2)*UI.GetScale(),(r.y+r.h/2)*UI.GetScale()
        for _,kind in ipairs({"PointerDown","PointerUp"}) do
            local event=Event.new(kind,{x=x,y=y,pointerId=0,pointerType="mouse",button=MOUSEB_LEFT})
            if kind=="PointerDown" then UI.HandlePointerDown(event) else UI.HandlePointerUp(event) end
        end
    end
    local function capture(name)
        local img=Image();assert(graphics:TakeScreenShot(img))
        -- Maker writes relative image paths into its resource cache.
        assert(img:SavePNG("apprentice_native_"..name..".png"))
        print("[ApprenticeNative] CAPTURE "..name)
    end
    return function(ctx)
        if done or not ctx.root.parent then return end
        if view then
            -- Only the memory-only evidence presentation ignores desktop focus.
            -- No OS input, window activation or production focus policy changes.
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
                before=ctx.session.state.GetSnapshot()
                fixture=E.SmallComplete(10000)
                fixture.content.releaseEndings=U.Copy(require "data.release_endings")
                E.Homes(fixture);E.Must(fixture.state.NextDay())
                local checks=require "ui.landscape.DevChecks";checks.apprenticeProbe=false
                view=require("ui.landscape.AppView").New(fixture.session,fixture.content)
                checks.apprenticeProbe=true
                ctx.root:SetVisible(false);ctx.SetApprenticeMusic(0)
                ctx.root.parent:AddChild(view.root);deadline=now+2
            elseif stage==1 then
                if view.journeyView.busy then return end
                capture("01-delivery");tap("continueEpilogue");deadline=now+1.5
            elseif stage==2 then
                if view.journeyView.busy then return end
                assert(node("apprenticeLetter").props.visible)
                capture("02-letter");tap("finishMerchantLetter");deadline=now+2
            elseif stage==3 then
                if view.journeyView.busy then return end
                assert(view.panel=="ending");capture("03-narration")
                tap("departureAdvance");deadline=now+1
            elseif stage==4 then
                if view.journeyView.busy then return end
                tap("departureAdvance");deadline=now+3.5
            elseif stage==5 then
                if view.journeyView.busy then return end
                assert(node("endGame").props.visible);capture("04-ending")
                assert(U.Equal(before,ctx.session.state.GetSnapshot()),"player state changed")
                view.root:Destroy();view=false;ctx.root:SetVisible(true);ctx.SetApprenticeMusic(nil)
                done=true;print("[ApprenticeNative] PASS native screenshots; memory-only fixture; real player state unchanged")
            end
            stage=stage+1
        end)
        if not ok then
            print("[ApprenticeNative] FAIL stage="..stage.." "..tostring(err))
            if view then view.root:Destroy();view=false end
            ctx.root:SetVisible(true);ctx.SetApprenticeMusic(nil);done=true
        end
    end
end
return P
