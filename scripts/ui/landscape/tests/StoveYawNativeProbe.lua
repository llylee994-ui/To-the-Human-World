-- Compatibility filename/flag: the opt-in probe now checks direct stove entry.
-- Real engine UI dispatch; no OS pointer control or gameplay commands.
local UI=require "urhox-libs/UI/Core/UI"
local Event=require "urhox-libs/UI/Core/PointerEvent"
local G=require "ui.landscape.LayoutGeometry"
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
        assert(UI.FindWidgetAt(r.x+r.w/2,r.y+r.h/2)==widget,"blocked "..id)
        tap(r.x+r.w/2,r.y+r.h/2)
    end
    local function point(ctx,id)
        for _,o in ipairs(ctx.home.manifest.objects) do if o.id==id then
            local r=o.regions[1];return G.ToScreen(ctx.home.manifest.layers[o.layer],ctx.home.Fit(),r.cx,r.cy)
        end end
        error(id)
    end
    local function object(ctx,id)
        local x,y=point(ctx,id)
        assert(assert(UI.FindWidgetAt(x,y)).props.id==id,"incorrect subject hit "..id)
        tap(x,y)
    end
    return function(ctx)
        if stopped then return end
        local now=GetTime():GetElapsedTime();start=start or now;local t=now-start
        local ok,err=pcall(function()
            if stage==0 and t>=8 then
                snapshot=ctx.session.state.GetSnapshot()
                assert(ctx.scene=="home" and not ctx.root:FindById("openHomeYawProbe"),"normal player home")
                object(ctx,"home.stove")
                assert(ctx.scene=="brew" and not ctx.yawProbe and not ctx.zoom.active and not ctx.home.blocked,"immediate stove route")
                print("[StoveDirectNative] immediate brew, no yaw t="..t);stage=1
            elseif stage==1 and t>=10 then
                assert(ctx.root:FindById("brewStage") and (ctx.root:FindById("brewWords") or ctx.root:FindById("openPending")),"existing brew page")
                assert(not ctx.root:FindById("homeYawCanvas") and not ctx.yawProbe,"no test scene")
                print("[StoveDirectNative] brew controls visible t="..t);stage=2
            elseif stage==2 and t>=12 then
                button(ctx,"returnHome");assert(ctx.scene=="home" and ctx.home.zoom==1 and not ctx.home.blocked,"return")
                print("[StoveDirectNative] home restored t="..t);stage=3
            elseif stage==3 and t>=14 then
                object(ctx,"home.merchantShip");assert(ctx.panel=="shop","ship shop");stage=4
            elseif stage==4 and t>=16 then
                local x,y=point(ctx,"home.stove")
                assert(UI.FindWidgetAt(x,y)~=ctx.root:FindById("home.stove"),"modal blocks stove")
                -- Do not click arbitrary modal content: it could be a purchase button.
                button(ctx,"closePanel");assert(ctx.scene=="home" and not ctx.panel,"close without penetration");stage=5
            elseif stage==5 and t>=18 then
                object(ctx,"home.stove");assert(ctx.scene=="brew" and not ctx.yawProbe,"re-enter directly");stage=6
            elseif stage==6 and t>=20 then
                assert(ctx.root:FindById("brewStage") and not ctx.root:FindById("homeYawCanvas"),"repeat page")
                button(ctx,"returnHome");stage=7
            elseif stage==7 and t>=22 then
                assert(ctx.scene=="home" and not ctx.panel and not ctx.yawProbe and not ctx.home.blocked,"final home")
                assert(U.Equal(snapshot,ctx.session.state.GetSnapshot()),"navigation changed business state")
                stopped=true
                print("[StoveDirectNative] PASS direct entry/re-entry/return/shop/modal/state; internal UI input, not OS or mobile")
            end
        end)
        if not ok then stopped=true;print("[StoveDirectNative] FAIL "..tostring(err)) end
    end
end
return N
