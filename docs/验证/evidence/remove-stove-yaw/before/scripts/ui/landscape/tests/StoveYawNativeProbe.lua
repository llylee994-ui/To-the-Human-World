-- Explicit development flag only. Real engine UI dispatch, no OS mouse control.
local UI=require "urhox-libs/UI/Core/UI"
local Event=require "urhox-libs/UI/Core/PointerEvent"
local G=require "ui.landscape.LayoutGeometry"
local U=require "core.StateUtil"
local N={}
function N.New()
    local start,stage,stopped,snapshot=nil,0,false,nil
    local repeats,cycleAt=0,0
    local function tap(x,y)
        UI.HandlePointerDown(Event.new("PointerDown",{x=x,y=y,button=MOUSEB_LEFT,pointerType="mouse"}))
        UI.HandlePointerUp(Event.new("PointerUp",{x=x,y=y,button=MOUSEB_LEFT,pointerType="mouse"}))
    end
    local function button(ctx,id)
        local widget=assert(ctx.root:FindById(id),id);local r=widget:GetAbsoluteLayout()
        assert(UI.FindWidgetAt(r.x+r.w/2,r.y+r.h/2)==widget,"blocked "..id)
        tap(r.x+r.w/2,r.y+r.h/2)
    end
    local function object(ctx,id)
        for _,o in ipairs(ctx.home.manifest.objects) do if o.id==id then
            local r=o.regions[1];local x,y=G.ToScreen(ctx.home.manifest.layers[o.layer],ctx.home.Fit(),r.cx,r.cy)
            tap(x,y);return
        end end
        error(id)
    end
    return function(ctx)
        if stopped then return end
        local now=GetTime():GetElapsedTime();start=start or now;local t=now-start
        local ok,err=pcall(function()
            if stage==0 and t>=10 then
                snapshot=ctx.session.state.GetSnapshot();assert(not ctx.root:FindById("openHomeYawProbe"),"dev entry should stay hidden")
                object(ctx,"home.stove");assert(ctx.yawProbe and ctx.scene=="home","stove routing");stage=1
                print("[StoveYawNative] clicked stove t="..t)
            elseif stage==1 and t>=10.3 then
                assert(ctx.yawProbe.motion.active,"automatic play")
                local probe=ctx.yawProbe;local elapsed=probe.motion.elapsed
                object(ctx,"home.stove");object(ctx,"home.merchantShip")
                local r=ctx.root:FindById("nextDay"):GetAbsoluteLayout();tap(r.x+5,r.y+5)
                assert(ctx.yawProbe==probe and probe.motion.elapsed==elapsed and not ctx.panel,"repeated input blocked")
                stage=2
            elseif stage==2 and t>=12.5 then
                assert(ctx.scene=="brew" and not ctx.yawProbe and not ctx.home.blocked,"brew completion")
                print("[StoveYawNative] reached brew t="..t);stage=3
            elseif stage==3 and t>=14 then button(ctx,"returnHome");stage=4
            elseif stage==4 and t>=16 then
                assert(ctx.scene=="home" and ctx.home.zoom==1,"home restored");object(ctx,"home.stove");stage=5
            elseif stage==5 and t>=16.3 then button(ctx,"homeYawClose");stage=6
            elseif stage==6 and t>=18 then
                assert(ctx.scene=="home" and not ctx.yawProbe and not ctx.home.blocked,"cancel unlocks home")
                object(ctx,"home.stove");stage=7
            elseif stage==7 and t>=20.5 then
                assert(ctx.scene=="brew" and not ctx.yawProbe,"replay completion");button(ctx,"returnHome");stage=8
            elseif stage==8 and t>=22 then
                assert(ctx.scene=="home" and not ctx.panel and not ctx.yawProbe,"returned")
                assert(U.Equal(snapshot,ctx.session.state.GetSnapshot()),"business state changed")
                collectgarbage("collect");object(ctx,"home.stove");cycleAt=t;stage=9
            elseif stage==9 and t-cycleAt>=2 then
                assert(ctx.scene=="brew" and not ctx.yawProbe,"stress completion")
                button(ctx,"returnHome");cycleAt=t;stage=10
            elseif stage==10 and t-cycleAt>=.3 then
                assert(ctx.scene=="home" and not ctx.yawProbe and not ctx.home.blocked,"stress return")
                collectgarbage("collect");repeats=repeats+1
                if repeats<6 then object(ctx,"home.stove");cycleAt=t;stage=9
                else
                    assert(U.Equal(snapshot,ctx.session.state.GetSnapshot()),"stress state changed")
                    stopped=true;print("[StoveYawNative] PASS stove/autoplay/repeat/HUD/brew/return/cancel/replay/state/6-GC-reopen-cycles; internal UI input only")
                end
            end
        end)
        if not ok then stopped=true;print("[StoveYawNative] FAIL "..tostring(err)) end
    end
end
return N
