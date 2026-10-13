-- Opt-in native UI-pointer sequence. No OS input, no gameplay commands.
local UI=require "urhox-libs/UI/Core/UI"
local Event=require "urhox-libs/UI/Core/PointerEvent"
local U=require "core.StateUtil"
local N={}
function N.New()
    local start,stage,stopped,snapshot=nil,0,false,nil
    local function tap(x,y)
        UI.HandlePointerDown(Event.new("PointerDown",{x=x,y=y,button=MOUSEB_LEFT,pointerType="mouse"}))
        UI.HandlePointerUp(Event.new("PointerUp",{x=x,y=y,button=MOUSEB_LEFT,pointerType="mouse"}))
    end
    local function button(ctx,id)
        local widget=assert(ctx.root:FindById(id),id);local r=widget:GetAbsoluteLayout()
        assert(r.w>0 and r.h>0,"zero bounds "..id)
        local x,y=r.x+r.w/2,r.y+r.h/2
        assert(UI.FindWidgetAt(x,y)==widget,"blocked "..id);tap(x,y)
    end
    return function(ctx)
        if stopped then return end
        local now=GetTime():GetElapsedTime();start=start or now;local t=now-start
        local ok,err=pcall(function()
            if stage==0 and t>=3 then
                snapshot=ctx.session.state.GetSnapshot();button(ctx,"openHomeYawProbe");stage=1
            elseif stage==1 and t>=15 then
                assert(ctx.yawProbe and not ctx.yawProbe.error,"probe creation failed")
                button(ctx,"homeYawPlay");stage=2
            elseif stage==2 and t>=15.3 then
                local elapsed=ctx.yawProbe.motion.elapsed;button(ctx,"homeYawPlay")
                assert(ctx.yawProbe.motion.elapsed==elapsed,"repeat restarted animation")
                local r=ctx.root:FindById("nextDay"):GetAbsoluteLayout()
                tap(r.x+r.w/2,r.y+r.h/2)
                assert(not ctx.panel and ctx.scene=="home" and not ctx.zoom.active,"underlay navigated")
                stage=3
            elseif stage==3 and t>=18 then
                assert(ctx.yawProbe.motion.reason=="complete","animation did not complete")
                assert(ctx.yawProbe.renderer.Sample(1.2,"native-complete"),"objects moved")
                button(ctx,"homeYawReset");assert(ctx.yawProbe.motion.yaw==0,"reset");stage=4
            elseif stage==4 and t>=20 then button(ctx,"homeYawPlay");stage=5
            elseif stage==5 and t>=20.5 then button(ctx,"homeYawReset");stage=6
            elseif stage==6 and t>=22 then
                assert(ctx.yawProbe.motion.yaw==0 and not ctx.yawProbe.motion.active,"mid-play reset")
                button(ctx,"homeYawPlay");stage=7
            elseif stage==7 and t>=22.4 then button(ctx,"homeYawClose");stage=8
            elseif stage==8 and t>=24 then
                assert(not ctx.yawProbe and not ctx.root:FindById("homeYawProbe"),"close release")
                button(ctx,"openHomeYawProbe");stage=9
            elseif stage==9 and t>=26 then
                assert(ctx.yawProbe and not ctx.yawProbe.error and ctx.yawProbe.motion.yaw==0,"reopen")
                button(ctx,"homeYawPlay");stage=10
            elseif stage==10 and t>=29 then
                assert(ctx.yawProbe.motion.reason=="complete","replay");button(ctx,"homeYawClose");stage=11
            elseif stage==11 and t>=31 then
                assert(not ctx.yawProbe and ctx.scene=="home" and not ctx.panel,"return home")
                button(ctx,"openHomeYawProbe");stage=12
            elseif stage==12 and t>=33 then button(ctx,"homeYawPlay");stage=13
            elseif stage==13 and t>=33.4 then
                ctx.root:FindById("homeYawCanvas"):SetWidth(ctx.root:GetAbsoluteLayout().w*.6);stage=14
            elseif stage==14 and t>=35 then
                assert(ctx.yawProbe.motion.reason=="resized" and ctx.yawProbe.motion.yaw==0,"resize resets animation")
                local r=ctx.yawProbe.renderer
                assert(r.width<1000 and r.width/r.height==16/9 and math.abs(r.camera.aspectRatio-16/9)<.00001,"resized RT aspect")
                ctx.root:FindById("homeYawCanvas"):SetWidth(ctx.root:GetAbsoluteLayout().w);stage=15
            elseif stage==15 and t>=37 then
                assert(not ctx.yawProbe.error,"resize recovery");button(ctx,"homeYawPlay");stage=16
            elseif stage==16 and t>=40 then
                assert(ctx.yawProbe.motion.reason=="complete","replay after resize");button(ctx,"homeYawClose");stage=17
            elseif stage==17 and t>=42 then
                assert(not ctx.yawProbe and ctx.scene=="home" and not ctx.panel,"return after resize")
                assert(U.Equal(snapshot,ctx.session.state.GetSnapshot()),"business state changed")
                stopped=true
                print("[HomeYawNative] PASS play/repeat/reset/mid-reset/close-during-play/reopen/replay/modal/resize/state; native UI dispatch, no OS input")
            end
        end)
        if not ok then stopped=true;print("[HomeYawNative] FAIL "..tostring(err)) end
    end
end
return N
