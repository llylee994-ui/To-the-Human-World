-- Opt-in native layout/Graphics evidence. Never consumes or reads a letter.
local UI=require "urhox-libs/UI/Core/UI"
local Widget=require "urhox-libs/UI/Core/Widget"
local G=require "ui.landscape.LayoutGeometry"
local U=require "core.StateUtil"
local N={}
function N.New()
    local frame,phase,done=0,0,false
    local before=false --[[@as table|false]]
    local samples={}
    local function screenshot(name)
        local im=Image();assert(graphics:TakeScreenShot(im),"capture failed")
        assert(im:SavePNG(name),"save failed "..name)
        print("[FullscreenMotionProbe] screenshot "..name)
    end
    local function fillCheck(view)
        local a=view.root:GetAbsoluteLayout();local b=view.background:GetAbsoluteLayout()
        assert(math.abs(a.x-b.x)<.1 and math.abs(a.y-b.y)<.1 and math.abs(a.w-b.w)<.1 and math.abs(a.h-b.h)<.1,"background not fullscreen")
        assert(view.background.props.pointerEvents=="none","background intercepts input")
        return a
    end
    return function(ctx)
        if done then return end
        frame=frame+1;if frame<160 or frame%40~=0 then return end
        local ok,err=pcall(function()
            if phase==0 then
                before=ctx.session.state.GetSnapshot()
                fillCheck(ctx.home);ctx.home.ShowHints(false)
                screenshot("fullscreen_r2_home_normal.png")
                ctx.Navigate("seaside");phase=1;return
            elseif phase<=9 then
                fillCheck(ctx.seaside)
                local fit=ctx.seaside.Fit();local ship=ctx.seaside.ShipLayer()
                local x,y=G.ToScreen(ship,fit,.47,.34)
                assert(assert(UI.FindWidgetAt(x,y)).props.id=="seaside.merchantShip","moving ship input mismatch")
                samples[#samples+1]={time=ctx.seaside.time,shipY=ship.y,rotation=ship.rotation}
                screenshot(string.format("seaside_motion_r2_%02d.png",phase))
                phase=phase+1;return
            elseif phase==10 then
                local bounds=ctx.root:GetAbsoluteLayout()
                Widget.SetStyle(ctx.root,{height=bounds.w*9/20})
                phase=11;return
            elseif phase==11 then
                local bounds=fillCheck(ctx.seaside)
                local root=ctx.root:GetAbsoluteLayout()
                assert(math.abs(root.w/root.h-20/9)<.01,"20:9 layout not applied")
                screenshot("fullscreen_r2_seaside_20x9.png")
                print("[FullscreenMotionProbe] wide root "..cjson.encode({root=root,scene=bounds,fit=ctx.seaside.Fit()}))
                ctx.Navigate("home");phase=12;return
            elseif phase==12 then
                fillCheck(ctx.home)
                local fit=ctx.home.Fit()
                for _,object in ipairs(ctx.home.manifest.objects) do
                    local r=object.regions[1]
                    local x,y=G.ToScreen(ctx.home.manifest.layers[object.layer],fit,r.cx,r.cy)
                    assert(assert(UI.FindWidgetAt(x,y)).props.id==object.id,"wide home target obstructed "..object.id)
                end
                screenshot("fullscreen_r2_home_20x9.png")
                Widget.SetStyle(ctx.root,{height="100%"});ctx.Navigate("seaside");phase=13;return
            end
            assert(U.Equal(before,ctx.session.state.GetSnapshot()),"inspection changed player progress")
            print("[FullscreenMotionProbe] PASS full backgrounds, 20:9 UI area, moving ship hit; samples="..cjson.encode(samples).."; OS/mobile viewport not tested")
            done=true
        end)
        if not ok then
            done=true;Widget.SetStyle(ctx.root,{height="100%"})
            print("[FullscreenMotionProbe] FAIL "..tostring(err))
        end
    end
end
return N
