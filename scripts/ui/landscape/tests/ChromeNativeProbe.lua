-- Native rendering at a wide-window ratio; capsule/phone insets are simulated.
-- All progression stays in an isolated memory fixture, never a player save.
local UI=require "urhox-libs/UI"
local U=require "core.StateUtil"
local Data=require "data.content"
local F=require "debug.fixtures.B5Fixtures"
local Hud=require "ui.landscape.HudLayout"
local Event=require "urhox-libs/UI/Core/PointerEvent"
local N={}
function N.New()
    local frame,phase,done=0,0,false
    local v,fixture,capsule,oldHost
    local function capture(name)
        local im=Image();assert(graphics:TakeScreenShot(im));assert(im:SavePNG("chrome_r3_"..name..".png"))
        print("[ChromeNativeProbe] screenshot "..name)
    end
    return function(ctx)
        if done then return end
        frame=frame+1;if v then v.Update() end
        if frame<600 or frame%90~=0 then return end
        local ok,err=pcall(function()
            if phase==0 then
                fixture=F.New(Data,{targetSchema=3})
                local definition=Data.GetLetter("letter_pa_01")
                fixture.session.queries.GetJournalStories=function() return U.Ok({{sourceLetterId=definition.id,title=definition.title,attemptCount=1}}) end
                fixture.session.queries.GetJournalPage=function() return U.Ok({title=definition.title,outcomes={{displayTitle="回信记录",attempts={{transactionId="native_fixture",status="shipped",stars=3}}}}}) end
                oldHost=Hud.ReadHost
                Hud.ReadHost=function(ui,bounds)
                    local w,h=ui.GetViewportSize()
                    return {w=w,h=h},{left=52,top=0,right=12,bottom=14},{left=.884,top=.126,right=.986,bottom=.212}
                end
                local checks=require "ui.landscape.DevChecks";checks.nativeProbe=false
                v=require("ui.landscape.AppView").New(fixture.session,Data);checks.nativeProbe=true
                ctx.root:SetVisible(false);ctx.root.parent:AddChild(v.root);v.home.ShowHints(true)
                local w,h=UI.GetViewportSize()
                capsule=UI.Panel {position="absolute",left=w*.884,top=h*.126,width=w*.102,height=h*.086,
                    backgroundColor={73,69,59,170},borderRadius=25,pointerEvents="none",alignItems="center",justifyContent="center",
                    children={UI.Label {text="···  ○",fontFamily="sans",fontSize=18,fontColor={255,255,255,255},pointerEvents="none"}}}
                v.root:AddChild(capsule)
            elseif phase==1 then
                capture("home-hints");v.home.ShowHints(false)
            elseif phase==2 then
                capture("home-clean");v.Open("journal");v.Update()
            elseif phase==3 then
                capture("journal-list")
                assert(v.root:FindById("story_letter_pa_01")).props.onClick();v.Update()
            elseif phase==4 then
                capture("journal-detail")
                local close=assert(v.root:FindById("closePanel")):GetAbsoluteLayout()
                local w,h=UI.GetViewportSize()
                assert(close.y>=h*.212,"close control overlaps the simulated capsule")
                local back=assert(v.root:FindById("journalBack"));local r=back:GetAbsoluteLayout()
                local x,y=r.x+r.w/2,r.y+r.h/2
                assert(UI.FindWidgetAt(x,y)==back,"journal return pointer blocked")
                UI.HandlePointerDown(Event.new("PointerDown",{x=x,y=y,button=MOUSEB_LEFT,pointerType="touch",pointerId=1}))
                UI.HandlePointerUp(Event.new("PointerUp",{x=x,y=y,button=MOUSEB_LEFT,pointerType="touch",pointerId=1}))
                v.Update();assert(not v.storyId,"journal return did not show directory")
                v.Close();v.Navigate("brew");v.Update()
            elseif phase==5 then capture("brew");v.Navigate("seaside");v.Open("shop");v.Update()
            elseif phase==6 then
                capture("shop");v.Close();v.Navigate("home");v.Update()
            elseif phase==7 then
                local fit=v.home.Fit();local b=v.root:GetAbsoluteLayout()
                assert(fit.y>=b.y and fit.y+fit.h<=b.y+b.h+.1,"complete room cropped")
                for _,o in ipairs(v.home.manifest.objects) do
                    local g=require "ui.landscape.LayoutGeometry";local r=o.regions[1]
                    local x,y=g.ToScreen(v.home.manifest.layers[o.layer],fit,r.cx,r.cy)
                    assert(UI.FindWidgetAt(x,y).props.id==o.id,"scene input moved away from "..o.id)
                end
                print("[ChromeNativeProbe] PASS native wide-room bounds, actual object/journal input; mock capsule/insets; isolated journal fixture; NOT phone evidence")
                Hud.ReadHost=oldHost;v.root:Destroy();ctx.root:SetVisible(true);done=true
            end
            phase=phase+1
        end)
        if not ok then
            done=true;print("[ChromeNativeProbe] FAIL "..tostring(err))
            if oldHost then Hud.ReadHost=oldHost end
            if v then v.root:Destroy() end
            ctx.root:SetVisible(true)
        end
    end
end
return N
