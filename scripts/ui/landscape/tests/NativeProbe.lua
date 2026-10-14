-- Opt-in native Yoga/input-tree check. No OS mouse injection, no business commands.
-- Keep DevChecks.nativeProbe=false for the player entry.
local UI=require "urhox-libs/UI/Core/UI"
local Event=require "urhox-libs/UI/Core/PointerEvent"
local Geometry=require "ui.landscape.LayoutGeometry"
local U=require "core.StateUtil"
local N={}
function N.New()
    if require("ui.landscape.DevChecks").wordTrayProbe then
        return require("ui.landscape.tests.WordTrayNativeProbe").New()
    end
    if require("ui.landscape.DevChecks").chromeProbe then
        return require("ui.landscape.tests.ChromeNativeProbe").New()
    end
    if require("ui.landscape.DevChecks").paperProbe then
        return require("ui.landscape.tests.PaperNativeProbe").New()
    end
    if require("ui.landscape.DevChecks").sceneFillProbe then
        return require("ui.landscape.tests.FullscreenMotionProbe").New()
    end
    if require("ui.landscape.DevChecks").homeHudProbe then
        return require("ui.landscape.tests.HomeHudNativeProbe").New()
    end
    if require("ui.landscape.DevChecks").seasideProbe then
        return require("ui.landscape.tests.SeasideNativeProbe").New()
    end
    if require("ui.landscape.DevChecks").hitFeedback then
        return require("ui.landscape.tests.HitFeedbackProbe").New()
    end
    local frame,index,phase=0,1,"open"
    local snapshot,stopped=nil,false
    local function tap(x,y)
        UI.HandlePointerDown(Event.new("PointerDown",{x=x,y=y,button=MOUSEB_LEFT,pointerType="mouse"}))
        UI.HandlePointerUp(Event.new("PointerUp",{x=x,y=y,button=MOUSEB_LEFT,pointerType="mouse"}))
    end
    local function button(ctx,id)
        local widget=assert(ctx.root:FindById(id),id)
        local r=widget:GetAbsoluteLayout();assert(r.w>0 and r.h>0,"zero-size "..id)
        local x,y=r.x+r.w/2,r.y+r.h/2
        assert(UI.FindWidgetAt(x,y)==widget,"input blocked: "..id);tap(x,y)
    end
    return function(ctx)
        if stopped then return end
        frame=frame+1;if frame<90 or frame%20~=0 then return end
        local ok,err=pcall(function()
            snapshot=snapshot or ctx.session.state.GetSnapshot()
            local manifest=ctx.home.manifest
            local object=manifest.objects[index]
            if not object then
                assert(U.Equal(snapshot,ctx.session.state.GetSnapshot()),"navigation changed saved state")
                print("[HomeNativeProbe] PASS eight native Yoga/input targets, panel/close bounds, unchanged state; OS input/device NOT verified")
                stopped=true;return
            end
            if phase=="open" then
                -- Read may mark a received letter read. Never do that in this read-only probe.
                if object.target=="paper" and #ctx.session.queries.GetLetters().value>0 then
                    print("[HomeNativeProbe] SKIP paper read mutation with existing letters");index=index+1;return
                end
                local fit=ctx.home.Fit();local r=assert(object.regions[1])
                local x,y=Geometry.ToScreen(assert(manifest.layers[object.layer]),fit,r.cx,r.cy)
                local hit=assert(UI.FindWidgetAt(x,y),"no subject hit "..object.id)
                assert(hit.props.id==object.id,"wrong subject "..object.id.." -> "..tostring(hit.props.id))
                tap(x,y);phase="close"
            else
                local expected=object.target=="paper" and "letters" or object.target
                assert((ctx.panel or ctx.scene)==expected,"wrong navigation "..object.id)
                if ctx.panel then
                    local body=assert(ctx.root:FindById("playScroll")):GetAbsoluteLayout()
                    assert(body.w>100 and body.h>40,"panel cannot display content")
                    button(ctx,"closePanel")
                else button(ctx,"returnHome") end
                print("[HomeNativeProbe] PASS "..object.id.." -> "..expected.." -> home")
                phase="open";index=index+1
            end
        end)
        if not ok then stopped=true;print("[HomeNativeProbe] FAIL "..tostring(err)) end
    end
end
return N
