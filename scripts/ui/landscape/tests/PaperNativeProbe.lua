-- Opt-in native Yoga/render/pointer evidence using memory-only save fixtures.
-- Never receives/cuts letters in the player's persistent session.
local UI=require "urhox-libs/UI"
local Event=require "urhox-libs/UI/Core/PointerEvent"
local Data=require "data.content"
local F=require "debug.fixtures.B5Fixtures"
local N={}
function N.New()
    local frames,phase,done=0,0,false
    local view,fixture,letter,source,before
    local function capture(name)
        local im=Image();assert(graphics:TakeScreenShot(im))
        assert(im:SavePNG("paper_r2_"..name..".png"))
        print("[PaperNativeProbe] screenshot "..name)
    end
    return function(ctx)
        if done then return end
        frames=frames+1
        if view then view.Update() end
        if frames<120 or frames%90~=0 then return end
        local ok,err=pcall(function()
            if phase==0 then
                fixture=F.New(Data,{targetSchema=3})
                local checks=require "ui.landscape.DevChecks"
                checks.nativeProbe=false
                view=require("ui.landscape.AppView").New(fixture.session,Data)
                checks.nativeProbe=true
                ctx.root:SetVisible(false);ctx.root.parent:AddChild(view.root)
                letter=assert(view.model.Receive(fixture.session.queries.GetSalvageView().value.availableLetterIds[1]).value).letterInstanceId
                view.Open("letters");view.Update()
            elseif phase==1 then
                capture("native-drawer");assert(view.Read(letter).ok);view.Update()
            elseif phase==2 then
                local p=view.readerCache.presentation;p.Cancel();p.paper.EnsureLayout()
                capture("native-reader-before")
                source=assert(p.paper.Bounds(p.view.spans[1].spanId))
                local scroll=view.scroll:GetAbsoluteLayout()
                assert(source.y>=scroll.y and source.y+source.h<=scroll.y+scroll.h,"source outside visible paper")
                before=assert(view.root:FindById("readerTitle")):GetAbsoluteLayout()
                local x,y=source.x+source.w/2,source.y+source.h/2
                assert(UI.FindWidgetAt(x,y)==p.paper.root,"paper word pointer blocked")
                UI.HandlePointerDown(Event.new("PointerDown",{x=x,y=y,button=MOUSEB_LEFT,pointerType="touch",pointerId=1}))
                UI.HandlePointerUp(Event.new("PointerUp",{x=x,y=y,button=MOUSEB_LEFT,pointerType="touch",pointerId=1}))
                assert(p.view.spans[1].cut,"paper pointer did not cut")
            elseif phase==3 then
                local after=assert(view.root:FindById("readerTitle")):GetAbsoluteLayout()
                assert(after.x==before.x and after.y==before.y,"cut moved letter title")
                assert(not view.panelNoticeArea.props.visible,"cut inserted message row")
                capture("native-reader-after");view.Open("case");view.Update()
            elseif phase==4 then capture("native-case");view.Navigate("brew");view.Update()
            elseif phase==5 then capture("native-brew");view.Navigate("seaside");view.Update()
            elseif phase==6 then capture("native-seaside");view.Open("shop");view.Update()
            elseif phase==7 then capture("native-shop");view.Open("words");view.Update()
            elseif phase==8 then
                capture("native-words")
                view.root:Destroy();ctx.root:SetVisible(true);done=true
                print("[PaperNativeProbe] PASS native paper touch dispatch, stable cut geometry and seven rendered views; isolated save; NOT phone evidence")
            end
            phase=phase+1
        end)
        if not ok then
            done=true;print("[PaperNativeProbe] FAIL "..tostring(err))
            if view then view.root:Destroy() end
            ctx.root:SetVisible(true)
        end
    end
end
return N
