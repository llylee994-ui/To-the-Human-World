-- Opt-in actual Yoga/engine-pointer/Graphics evidence. No gameplay mutations.
local UI=require "urhox-libs/UI/Core/UI"
local Event=require "urhox-libs/UI/Core/PointerEvent"
local G=require "ui.landscape.LayoutGeometry"
local U=require "core.StateUtil"
local Theme=require "urhox-libs/UI/Core/Theme"
local N={}
function N.New()
    local frame,phase,done=0,0,false
    local before=false --[[@as table|false]]
    local function tap(widget)
        local r=widget:GetAbsoluteLayout()
        assert(r.w>=44 and r.h>=44,"small button "..widget.props.id)
        local x,y=r.x+r.w/2,r.y+r.h/2
        assert(UI.FindWidgetAt(x,y)==widget,"blocked button "..widget.props.id)
        UI.HandlePointerDown(Event.new("PointerDown",{x=x,y=y,button=MOUSEB_LEFT,pointerType="touch",pointerId=1}))
        UI.HandlePointerUp(Event.new("PointerUp",{x=x,y=y,button=MOUSEB_LEFT,pointerType="touch",pointerId=1}))
    end
    local function capture(name)
        local im=Image();assert(graphics:TakeScreenShot(im),"capture failed")
        assert(im:SavePNG(name),"save failed "..name)
        print("[HomeHudNativeProbe] screenshot "..name)
    end
    return function(ctx)
        if done then return end
        frame=frame+1;if frame<180 or frame%40~=0 then return end
        local ok,err=pcall(function()
            if phase==0 then
                before=ctx.session.state.GetSnapshot();ctx.home.ShowHints(true);phase=1;return
            elseif phase==1 then
                assert(ctx.home.HintsVisible(),"hints not visible")
                local fit=ctx.home.Fit();assert(fit.scale>0,"home not fitted")
                local ledger=assert(ctx.root:FindById("playLedger")):GetAbsoluteLayout()
                assert(ledger.w>=180 and ledger.h>=20,"ledger clipped")
                for _,object in ipairs(ctx.home.manifest.objects) do
                    local tag=assert(ctx.root:FindById("hint_"..object.id))
                    local tagBounds=tag:GetAbsoluteLayout()
                    assert(tag.props.pointerEvents=="none" and tagBounds.h>=28,"hint not readable/transparent")
                    local textWidth=UI.MeasureTextWidth(tag.props.text,Theme.FontSize(tag.props.fontSize),"sans")
                    assert(tagBounds.w-24>=textWidth,"clipped CJK hint "..object.id)
                    local layer=ctx.home.manifest.layers[object.layer];local region=object.regions[1]
                    local x,y=G.ToScreen(layer,fit,region.cx,region.cy)
                    assert(assert(UI.FindWidgetAt(x,y)).props.id==object.id,"hint blocks object "..object.id)
                end
                capture("home_hud_native_hints_r1.png")
                tap(assert(ctx.root:FindById("toggleHomeHints")));phase=2;return
            elseif phase==2 then
                assert(not ctx.home.HintsVisible(),"hint toggle not effective")
                capture("home_hud_native_clean_r1.png")
                phase=3;return -- SavePNG can cause a long frame: start net later.
            elseif phase==3 then
                local object
                for _,item in ipairs(ctx.home.manifest.objects) do if item.id=="home.net" then object=item end end
                assert(object);local region=object.regions[1]
                local x,y=G.ToScreen(ctx.home.manifest.layers[object.layer],ctx.home.Fit(),region.cx,region.cy)
                assert(assert(UI.FindWidgetAt(x,y)).props.id=="home.net","net input obstructed")
                UI.HandlePointerDown(Event.new("PointerDown",{x=x,y=y,button=MOUSEB_LEFT,pointerType="touch",pointerId=1}))
                UI.HandlePointerUp(Event.new("PointerUp",{x=x,y=y,button=MOUSEB_LEFT,pointerType="touch",pointerId=1}))
                phase=4;return
            elseif phase==4 then
                if ctx.scene~="seaside" and not ctx.zoom.active and ctx.zoom.reason=="focus-lost" then
                    print("[HomeHudNativeProbe] SKIP door animation: window focus lost; use direct readonly scene navigation for chrome evidence")
                    ctx.Navigate("seaside");return
                end
                assert(ctx.scene=="seaside" and not ctx.zoom.active,"net did not reach seaside: "..tostring(ctx.zoom.reason))
                capture("home_hud_native_seaside_r1.png")
                phase=5;return
            elseif phase==5 then
                tap(assert(ctx.root:FindById("seasideShop")));phase=6;return
            elseif phase==6 then
                assert(ctx.panel=="shop","shop button failed")
                tap(assert(ctx.root:FindById("closePanel")));phase=7;return
            end
            assert(not ctx.panel and ctx.scene=="seaside","shop close failed")
            assert(U.Equal(before,ctx.session.state.GetSnapshot()),"UI inspection changed progress")
            print("[HomeHudNativeProbe] PASS native hints/input/ledger/net/sea/shop/close; progress unchanged; OS phone/platform overlay not tested")
            done=true
        end)
        if not ok then done=true;print("[HomeHudNativeProbe] FAIL "..tostring(err)) end
    end
end
return N
