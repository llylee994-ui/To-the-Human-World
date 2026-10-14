-- Opt-in real Runtime evidence. Internal UI pointers only; never OS input or business commands.
local UI=require "urhox-libs/UI/Core/UI"
local Event=require "urhox-libs/UI/Core/PointerEvent"
local G=require "ui.landscape.LayoutGeometry"
local U=require "core.StateUtil"
local N={}
function N.New()
    local start,stage,stopped,snapshot=nil,0,false,nil
    local visits,blocked=0,false
    local startedAt=0 --[[@as number]]
    local function tap(x,y)
        UI.HandlePointerDown(Event.new("PointerDown",{x=x,y=y,button=MOUSEB_LEFT,pointerType="mouse"}))
        UI.HandlePointerUp(Event.new("PointerUp",{x=x,y=y,button=MOUSEB_LEFT,pointerType="mouse"}))
    end
    local function point(ctx,id)
        for _,o in ipairs(ctx.home.manifest.objects) do if o.id==id then
            local r=o.regions[1];return G.ToScreen(ctx.home.manifest.layers[o.layer],ctx.home.Fit(),r.cx,r.cy)
        end end
        error(id)
    end
    local function object(ctx,id)
        local x,y=point(ctx,id)
        assert(assert(UI.FindWidgetAt(x,y)).props.id==id,"incorrect hit "..id);tap(x,y)
    end
    local function button(ctx,id)
        local widget=assert(ctx.root:FindById(id));local r=widget:GetAbsoluteLayout()
        assert(UI.FindWidgetAt(r.x+r.w/2,r.y+r.h/2)==widget,"blocked "..id);tap(r.x+r.w/2,r.y+r.h/2)
    end
    return function(ctx)
        if stopped then return end
        local clock=GetTime();local now=clock:GetElapsedTime();start=start or now;local t=now-start
        local ok,err=pcall(function()
            if stage==0 and t>=20 then
                assert(input:HasFocus() and not input:IsMinimized(),"native window unfocused; no OS activation permitted")
                snapshot=ctx.session.state.GetSnapshot()
                assert(ctx.scene=="home" and not ctx.home.inspect and not ctx.yawProbe,"normal home")
                object(ctx,"home.stove");assert(ctx.zoom.active and ctx.scene=="home","delayed stove entry")
                startedAt=now;stage=1
                local p=ctx.zoom.profile
                print(string.format("[StovePanZoomNative] START t=%.6f now=%.6f target=%.3f duration=%.3f pan=(%.6f,%.6f) subject=(%.6f,%.6f)",t,now,p.target,p.duration,p.panX,p.panY,p.subjectX,p.subjectY))
            elseif stage==1 or stage==6 then
                print(string.format("[StovePanZoomNative] FRAME t=%.6f now=%.6f dt=%.6f elapsed=%.6f scale=%.6f pan=(%.6f,%.6f) scene=%s",t,now,clock:GetTimeStep(),ctx.zoom.elapsed,ctx.zoom.scale,ctx.zoom.panX,ctx.zoom.panY,ctx.scene))
                if ctx.zoom.active and ctx.zoom.elapsed>.15 and not blocked then
                    tap(point(ctx,"home.stove"));tap(point(ctx,"home.net"));tap(point(ctx,"home.merchantShip"))
                    local day=ctx.root:FindById("nextDay"):GetAbsoluteLayout();tap(day.x+5,day.y+5)
                    assert(ctx.zoom.active and not ctx.panel and ctx.scene=="home","repeated input/HUD");blocked=true
                end
                if ctx.scene=="brew" then
                    visits=visits+1
                    assert(not ctx.home.blocked and not ctx.zoom.active and ctx.home.zoom==1,"navigation reset")
                    assert(ctx.root:FindById("brewStage") and not ctx.root:FindById("homeYawCanvas"),"existing functional brew only")
                    print(string.format("[StovePanZoomNative] BREW t=%.6f wall=%.6f visit=%d",t,now-startedAt,visits))
                    stage=stage==1 and 2 or 7
                else assert(ctx.zoom.active,"animation cancelled: "..ctx.zoom.reason) end
            elseif stage==2 and t>=23 then
                button(ctx,"returnHome");assert(ctx.scene=="home" and ctx.home.zoom==1,"return reset")
                print("[StovePanZoomNative] RETURN t="..t);stage=3
            elseif stage==3 and t>=25 then
                object(ctx,"home.merchantShip");assert(ctx.panel=="shop","ship still opens shop");stage=4
            elseif stage==4 and t>=27 then
                local x,y=point(ctx,"home.stove")
                assert(UI.FindWidgetAt(x,y)~=ctx.root:FindById("home.stove"),"modal blocks stove")
                button(ctx,"closePanel");assert(not ctx.panel and not ctx.zoom.active,"no click-through on close");stage=5
            elseif stage==5 and t>=29 then
                object(ctx,"home.stove");assert(ctx.zoom.active,"replay");blocked=false;startedAt=now;stage=6
                print("[StovePanZoomNative] REPLAY t="..t)
            elseif stage==7 and t>=32 then
                button(ctx,"returnHome");stage=8
            elseif stage==8 and t>=33 then
                assert(ctx.scene=="home" and not ctx.home.blocked and not ctx.panel and visits==2,"final home")
                assert(U.Equal(snapshot,ctx.session.state.GetSnapshot()),"business state changed")
                stopped=true
                print("[StovePanZoomNative] PASS real homepage / two visits / repeats / HUD / modal / return / state; native internal pointer, not OS/manual/mobile")
            end
        end)
        if not ok then stopped=true;print("[StovePanZoomNative] FAIL "..tostring(err)) end
    end
end
return N
