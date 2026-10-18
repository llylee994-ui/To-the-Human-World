-- Opt-in background check: independent Yoga trees + registered native font metrics.
-- Never mounts a test view, injects input, captures the desktop or touches player saves.
local UI=require "urhox-libs/UI"
local Theme=require "urhox-libs/UI/Core/Theme"
local Data=require "data.content"
local N={}
function N.New()
    local frames,done=0,false
    return function()
        if done then return end
        frames=frames+1;if frames<120 then return end
        done=true
        local roots={}
        local ok,err=pcall(function()
            local F=require "debug.fixtures.B5Fixtures"
            local Session=require "core.GameSession"
            local guideModule=require "ui.landscape.Onboarding"
            for _,vp in ipairs({{w=1280,h=720},{w=936,h=432},{w=740,h=360}}) do
                local fixture=F.New(Data,{targetSchema=4});fixture.files={}
                local session=Session.New(Data,{saveSystem=fixture.save,eventBus=fixture.bus,targetSchema=4,onboarding=true})
                assert(session.state.Load("native_onboarding_isolated"))
                assert(session.state.SetOnboarding({version=1,step="intro.note",completed=false,skipped=false,noteRead=false}).ok)
                local root=UI.Panel {width=vp.w,height=vp.h};roots[#roots+1]=root
                local ctx={root=root,session=session,viewport=vp,scene="home",panel=false,model={Notify=function() end}}
                local guide=guideModule.New(ctx)
                guide.Update()
                YGNodeCalculateLayout(root.node,vp.w,vp.h,YGDirectionLTR)
                guide.Update();YGNodeCalculateLayout(root.node,vp.w,vp.h,YGDirectionLTR)
                local paper=root:FindById("onboardingNote"):GetAbsoluteLayout()
                local scroll=root:FindById("onboardingNoteScroll"):GetAbsoluteLayout()
                local button=root:FindById("onboardingNoteDone"):GetAbsoluteLayout()
                assert(paper.x>=0 and paper.y>=0 and paper.x+paper.w<=vp.w+1 and paper.y+paper.h<=vp.h+1,"note exceeds viewport")
                assert(scroll.h>0 and scroll.y+scroll.h<=button.y+1,"note viewport overlaps its button")
                for i=1,4 do
                    local label=root:FindById("onboardingNoteParagraph"..i)
                    local r=label:GetAbsoluteLayout()
                    local measured=UI.MeasureTextFit(label:GetText(),{fontSize=Theme.FontSize(16),fontFace=Theme.FontFace("story","normal"),lineHeight=1.7,width=r.w,multiline=true})
                    assert(measured.height>0 and r.h+1>=measured.height,"native note text clipped: paragraph "..i)
                end
                assert(root:FindById("onboardingNoteDone").props.backgroundImage==require("ui.landscape.HarborStyle").woodImage,"note button lost wood art")
                root:FindById("onboardingNoteDone").props.onClick()
                assert(session.state.SetOnboarding({version=1,step="intro.paper",completed=false,skipped=false,noteRead=false}).ok)
                ctx.arrival=require("ui.landscape.ArrivalTransition").New(ctx)
                local entered=0
                ctx.arrival.Begin(function() entered=entered+1 end)
                for _=1,45 do
                    ctx.arrival.Update(.05,true,true);guide.Update()
                    YGNodeCalculateLayout(root.node,vp.w,vp.h,YGDirectionLTR)
                end
                assert(entered==1 and not ctx.arrival.IsActive(),"native arrival did not release input")
                local narration=root:FindById("onboardingNarration");local nr=narration:GetAbsoluteLayout()
                local nb=UI.MeasureTextFit(narration:GetText(),{fontSize=Theme.FontSize(16),fontFace=Theme.FontFace("story","normal"),lineHeight=1.5,width=nr.w,multiline=true})
                assert(narration.props.visible and nr.h>=nb.height and nr.y+nr.h<=vp.h,"scene narration clipped")
                -- All workbench explanations must fit the actual font in compact boxes.
                ctx.scene="brew"
                for _,step in ipairs({"brew.word","brew.book","brew.ingredient","brew.conditions","brew.ready"}) do
                    assert(session.state.SetOnboarding({version=1,step=step,completed=false,skipped=false,noteRead=true}).ok)
                    guide.Update();YGNodeCalculateLayout(root.node,vp.w,vp.h,YGDirectionLTR)
                    local tip=root:FindById("onboardingTooltip"):GetAbsoluteLayout()
                    local label=root:FindById("onboardingText");local r=label:GetAbsoluteLayout()
                    local know=root:FindById("onboardingKnow"):GetAbsoluteLayout()
                    local measured=UI.MeasureTextFit(label:GetText(),{fontSize=Theme.FontSize(15),fontFace=Theme.FontFace("story","normal"),lineHeight=1.45,width=r.w,multiline=true})
                    assert(measured.height>0 and r.h+1>=measured.height,string.format(
                        "native hint text clipped: %s actual=%.2fx%.2f requested=%.2f measured=%.2f text=%s",
                        step,r.w,r.h,label.props.height,measured.height,label:GetText()))
                    assert(know.y>=r.y+r.h-1 and know.y+know.h<=tip.y+tip.h+1,"hint acknowledgement overflows")
                    assert(tip.w<=320 and tip.h<220,"hint retains oversized empty space")
                    assert(tip.x>=0 and tip.y>=0 and tip.x+tip.w<=vp.w+1 and tip.y+tip.h<=vp.h+1,"hint exceeds viewport")
                end
                -- Reader action is outside flex flow, below the old footer position.
                local panel=UI.Panel {width=vp.w,height=vp.h,padding=32}
                roots[#roots+1]=panel
                local readerScroll=UI.Panel {width="100%",flexGrow=1};panel:AddChild(readerScroll)
                local body=UI.Panel {width="100%"};readerScroll:AddChild(body)
                require("ui.landscape.ReaderOrder").Action(body,"acceptOrder","接下这份委托",function() end,true)
                YGNodeCalculateLayout(panel.node,vp.w,vp.h,YGDirectionLTR)
                local action=panel:FindById("readerActions"):GetAbsoluteLayout()
                assert(readerScroll:GetAbsoluteLayout().h>=vp.h-65,"button still consumes reader flow space")
                assert(action.y+action.h>=vp.h-14,"reader button was not lowered to paper edge")
                print(string.format("[OnboardingNative] PASS %dx%d titleless note, arrival, narration bounds, compact five hints, floating action",vp.w,vp.h))
                guide.Destroy()
            end
        end)
        for _,root in ipairs(roots) do root:Destroy() end
        if not ok then print("[OnboardingNative] FAIL "..tostring(err)) end
    end
end
return N
