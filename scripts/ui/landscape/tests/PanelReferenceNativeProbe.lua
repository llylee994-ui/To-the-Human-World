-- Opt-in native acceptance: real production queries with an isolated memory save.
-- No fixture is ever installed into the player's GameSession.
local UI=require "urhox-libs/UI"
local Event=require "urhox-libs/UI/Core/PointerEvent"
local U=require "core.StateUtil"
local Data=require "data.content"
local F=require "debug.fixtures.B5Fixtures"
local N={}
---@alias PanelReferenceFixture {session:table,state:table,order:table,modules:table,tokens:table,letterId:string}
function N.New()
    local frames,phase,done=0,0,false
    ---@type table|nil
    local view,before,playerBefore
    ---@type PanelReferenceFixture|nil
    local fixture
    ---@type string|nil
    local selected,branch,storedText
    local function capture(name)
        local im=Image();assert(graphics:TakeScreenShot(im));assert(im:SavePNG("panel_reference_"..name..".png"))
        print("[PanelReferenceNative] screenshot "..name)
    end
    local function node(id) return assert(view.root:FindById(id),id) end
    local function tap(id)
        local widget=node(id);local r=widget:GetAbsoluteLayout()
        local x,y=r.x+r.w/2,r.y+r.h/2
        assert(r.w>0 and r.h>0 and UI.FindWidgetAt(x,y)==widget,"blocked/empty: "..id)
        UI.HandlePointerDown(Event.new("PointerDown",{x=x,y=y,button=MOUSEB_LEFT,pointerType="touch",pointerId=1}))
        UI.HandlePointerUp(Event.new("PointerUp",{x=x,y=y,button=MOUSEB_LEFT,pointerType="touch",pointerId=1}))
    end
    return function(ctx)
        if done then return end
        frames=frames+1
        if view then view.Update() end
        if frames<180 or frames%90~=0 then return end
        local ok,err=pcall(function()
            if phase==0 then
                playerBefore=ctx.session.state.GetSnapshot()
                fixture=F.New(Data,{targetSchema=3}) --[[@as PanelReferenceFixture]]
                local id=F.Must(fixture.state.ReceiveLetter({letterId="letter_pa_01"})).letterInstanceId
                F.Must(fixture.state.ReadLetter({letterInstanceId=id}))
                fixture.tokens={};fixture.letterId=id
                for _,span in ipairs(F.Must(fixture.modules.letters.ParseDefinition("letter_pa_01")).spans) do
                    fixture.tokens[span.wordId]=F.Must(fixture.state.CutWord({letterInstanceId=id,spanId=span.spanId})).tokenId
                end
                before=fixture.state.GetSnapshot()
                local checks=require "ui.landscape.DevChecks";checks.nativeProbe=false
                view=require("ui.landscape.AppView").New(fixture.session,Data);checks.nativeProbe=true
                ctx.root:SetVisible(false);ctx.root.parent:AddChild(view.root)
                view.root:AddChild(UI.Label {text="界面验收 · 内存样本",position="absolute",left="40%",bottom=8,
                    fontFamily="story",fontSize=13,fontColor={255,244,218,255},backgroundColor={42,32,25,200},padding=4,pointerEvents="none",zIndex=100})
                view.Open("words");view.Update()
            elseif phase==1 then
                local p=node("activePanel"):GetAbsoluteLayout()
                local t=node("wordTrayFrame"):GetAbsoluteLayout()
                assert(t.x<p.x and t.x+t.w<p.x+p.w,"tray crop differs from reference")
                capture("tray")
                local categories=F.Must(fixture.session.queries.GetWordTray()).categories
                for _,category in ipairs(categories) do
                    if category.id~=view.wordTray.category then selected=category.id;break end
                end
                tap("wordTrayTab_"..assert(selected));view.Update()
            elseif phase==2 then
                assert(view.wordTray.category==selected,"category did not change")
                for _,card in ipairs(F.Must(fixture.session.queries.GetWordTray()).cards) do
                    if card.categoryId==selected then selected=card.tokenId;break end
                end
                tap("wordTrayCard_"..assert(selected));view.Update()
            elseif phase==3 then
                assert(view.wordTray.selected==selected,"paper did not select")
                assert(U.Equal(before,fixture.state.GetSnapshot()),"tray browsing changed snapshot")
                capture("tray_selected");tap("closePanel")
            elseif phase==4 then
                assert(view.panel==false,"tray close did not finish")
                -- Produce one real branch using schema-3 order actions, entirely in memory.
                local orderId=F.Must(fixture.order.Accept({letterInstanceId=fixture.letterId})).orderId
                local sample=require("debug.fixtures.NumericV02Cases")[1].recipe
                local draft={equipmentId=sample.equipmentId,mainTokenId=fixture.tokens[sample.mainWordId],
                    auxTokenIds={},ingredients=U.Copy(sample.ingredients),specialItemIds={}}
                F.Must(fixture.order.UpdateDraft({orderId=orderId,draft=draft}))
                local request=U.Copy(fixture.state.GetSnapshot().currentOrder.draft);request.orderId=orderId
                F.Must(fixture.order.Preview(request))
                local order=fixture.state.GetSnapshot().currentOrder
                F.Must(fixture.order.Reset({orderId=orderId,baselineId=order.baseline.id,transactionId=order.pending.transactionId}))
                local page=F.Must(fixture.session.queries.GetJournalPage("letter_pa_01"))
                branch=page.outcomes[1].branchFragmentId
                storedText=page.outcomes[1].attempts[1].text
                before=fixture.state.GetSnapshot()
                view.Open("journal");view.Update()
            elseif phase==5 then
                local p=node("activePanel"):GetAbsoluteLayout()
                local b=node("bookArtFrame"):GetAbsoluteLayout()
                local page=node("bookPage"):GetAbsoluteLayout()
                assert(b.x+b.w>p.x+p.w and math.abs(b.w/b.h-2/3)<.01,"book crop/proportion differs from reference")
                assert(page.x>b.x+b.w*.14 and page.x+page.w<=p.x+p.w,"text outside page/screen")
                assert(node("bookDriedFlowers").props.pointerEvents=="none","flower steals input")
                capture("journal_catalog");tap("bookEntry_"..assert(branch));view.Update()
            elseif phase==6 then
                assert(node("bookEntryText"):GetText()==storedText,"detail differs from saved follow-up")
                capture("journal_detail")
                local scroll=node("bookEntryBody") --[[@as ScrollView]]
                scroll:OnWheel(0,-3)
                selected=tostring(scroll.state.scrollY)
            elseif phase==7 then
                local scroll=node("bookEntryBody") --[[@as ScrollView]]
                assert(scroll.state.scrollY>0,"follow-up did not scroll")
                capture("journal_scrolled");tap("bookEntryBack");view.Update()
            elseif phase==8 then
                assert(node("bookEntryList"),"back did not restore catalog")
                tap("closePanel")
            elseif phase==9 then
                assert(view.panel==false,"book close did not finish")
                assert(U.Equal(before,fixture.state.GetSnapshot()),"reading changed fixture snapshot")
                assert(U.Equal(playerBefore,ctx.session.state.GetSnapshot()),"player snapshot changed")
                view.root:Destroy();view=nil;ctx.root:SetVisible(true)
                ctx.Open("journal");done=true
                print("[PanelReferenceNative] PASS actual Yoga, cropped art, category/card touch, stored detail, scroll, back and animated closes; player save unchanged; memory sample; NOT phone evidence")
            end
            phase=phase+1
        end)
        if not ok then
            done=true;print("[PanelReferenceNative] FAIL phase="..phase.." "..tostring(err))
            if view then view.root:Destroy();view=nil end
            ctx.root:SetVisible(true)
        end
    end
end
return N
