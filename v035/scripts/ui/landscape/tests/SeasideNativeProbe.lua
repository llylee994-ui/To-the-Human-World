-- Explicit opt-in, actual Yoga/pointer/Graphics check. Never receives or reads a letter.
local UI=require "urhox-libs/UI/Core/UI"
local Event=require "urhox-libs/UI/Core/PointerEvent"
local G=require "ui.landscape.LayoutGeometry"
local U=require "core.StateUtil"
local N={}
function N.New()
    local frame,phase,done=0,0,false
    local before=false --[[@as table|false]]
    local function tap(widget)
        local r=widget:GetAbsoluteLayout()
        assert(r.w>=40 and r.h>=40,"button too small")
        local x,y=r.x+r.w/2,r.y+r.h/2
        assert(UI.FindWidgetAt(x,y)==widget,"button blocked")
        UI.HandlePointerDown(Event.new("PointerDown",{x=x,y=y,button=MOUSEB_LEFT,pointerType="mouse"}))
        UI.HandlePointerUp(Event.new("PointerUp",{x=x,y=y,button=MOUSEB_LEFT,pointerType="mouse"}))
    end
    return function(ctx)
        if done then return end
        frame=frame+1;if frame<80 or frame%20~=0 then return end
        local ok,err=pcall(function()
            if phase==0 then
                before=ctx.session.state.GetSnapshot();ctx.Navigate("seaside");phase=1;return
            elseif phase==1 then
                local fit=ctx.seaside.Fit();local bounds=ctx.seaside.canvas:GetAbsoluteLayout()
                assert(fit.scale>0 and math.abs(fit.w-bounds.w)<.01,"invalid full-width scene projection")
                local capture=assert(ctx.root:FindById("startSalvage")):GetAbsoluteLayout()
                local shop=assert(ctx.root:FindById("seasideShop")):GetAbsoluteLayout()
                assert(capture.w>=150 and capture.h>=44 and shop.w>=100 and shop.h>=44,"controls clipped")
                assert(capture.x+capture.w<=shop.x+.01,"buttons overlap")
                local layer=ctx.seaside.ShipLayer();local x,y=G.ToScreen(layer,fit,.47,.34)
                assert(assert(UI.FindWidgetAt(x,y)).props.id=="seaside.merchantShip","ship art/input mismatch")
                UI.HandlePointerDown(Event.new("PointerDown",{x=x,y=y,button=MOUSEB_LEFT,pointerType="mouse"}))
                UI.HandlePointerUp(Event.new("PointerUp",{x=x,y=y,button=MOUSEB_LEFT,pointerType="mouse"}))
                print("[SeasideNativeProbe] layout "..cjson.encode({fit=fit,canvas=bounds,capture=capture,shop=shop,pixels={graphics:GetWidth(),graphics:GetHeight()}}))
                phase=2;return
            elseif phase==2 then
                assert(ctx.panel=="shop","native ship did not open shop")
                tap(assert(ctx.root:FindById("closePanel")));phase=3;return
            end
            assert(ctx.scene=="seaside" and not ctx.panel,"shop close did not return seaside")
            assert(U.Equal(before,ctx.session.state.GetSnapshot()),"read-only navigation changed progress")
            local image=Image()
            local captured=graphics:TakeScreenShot(image)
            local saved=captured and image:SavePNG("seaside_native_r1_final.png")
            print("[SeasideNativeProbe] PASS actual Yoga controls, ship pointer, shop close, unchanged progress; screenshot captured="..tostring(captured).." saved="..tostring(saved).." file=seaside_native_r1_final.png; no salvage/OS touch/device test")
            done=true
        end)
        if not ok then done=true;print("[SeasideNativeProbe] FAIL "..tostring(err)) end
    end
end
return N
