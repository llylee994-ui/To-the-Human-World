-- Native Yoga, image and pointer evidence. All collected cards use memory-only saves.
local UI=require "urhox-libs/UI"
local Event=require "urhox-libs/UI/Core/PointerEvent"
local U=require "core.StateUtil"
local Data=require "data.content"
local F=require "debug.fixtures.B5Fixtures"
local N={}
---@alias WordTrayProbeView {root:Widget, Update:fun(), Open:fun(string), wordTray:table, panel:string|false}
function N.New()
    local frame,phase,done=0,0,false
    ---@type WordTrayProbeView|nil
    local view
    ---@type {session:table,state:table,modules:table}|nil
    local fixture
    ---@type table|nil
    local before,playerBefore
    ---@type string|nil
    local chosen
    local function capture(name)
        local im=Image();assert(graphics:TakeScreenShot(im))
        local filename="word_tray_accept_"..name..".png"
        -- Image.SavePNG writes into Maker's resource cache; copy evidence before refresh.
        assert(im:SavePNG(filename))
        print("[WordTrayNative] screenshot "..name)
    end
    ---@return WordTrayProbeView
    local function mount(ctx,x)
        local checks=require "ui.landscape.DevChecks"
        checks.nativeProbe=false
        local v=require("ui.landscape.AppView").New(x.session,Data)
        checks.nativeProbe=true
        ctx.root.parent:AddChild(v.root)
        return v --[[@as WordTrayProbeView]]
    end
    local function tap(id)
        local node=assert(view.root:FindById(id),id)
        local r=node:GetAbsoluteLayout()
        assert(r.w>0 and r.h>0,"zero-size "..id)
        local x,y=r.x+r.w/2,r.y+r.h/2
        assert(UI.FindWidgetAt(x,y)==node,"blocked "..id)
        UI.HandlePointerDown(Event.new("PointerDown",{x=x,y=y,button=MOUSEB_LEFT,pointerType="touch",pointerId=1}))
        UI.HandlePointerUp(Event.new("PointerUp",{x=x,y=y,button=MOUSEB_LEFT,pointerType="touch",pointerId=1}))
    end
    local function bounds()
        local panel=assert(view.root:FindById("activePanel")):GetAbsoluteLayout()
        local tray=assert(view.root:FindById("wordTrayFrame")):GetAbsoluteLayout()
        local footer=assert(view.root:FindById("wordTrayFooter")):GetAbsoluteLayout()
        local close=assert(view.root:FindById("closePanel")):GetAbsoluteLayout()
        assert(math.abs(tray.w/tray.h-.75)<.01,"wood tray distorted")
        assert(tray.x>=panel.x and tray.x+tray.w<=panel.x+panel.w+.1,"tray escapes cloth")
        assert(footer.y+footer.h<=panel.y+panel.h+.1,"footer outside cloth")
        assert(close.x>=panel.x and close.x+close.w<=panel.x+panel.w+.1,"close outside cloth")
        local flowers=view.root:FindById("wordTrayDriedFlowers")
        if flowers then
            local f=flowers:GetAbsoluteLayout()
            local papers=assert(view.root:FindById("wordTrayStrips")):GetAbsoluteLayout()
            assert(flowers.props.pointerEvents=="none","flowers intercept pointers")
            assert(f.x+f.w<=papers.x+.1,"flowers overlap paper strips")
            assert(f.y+f.h<=footer.y+.1,"flowers overlap source footer")
        end
        print("[WordTrayNative] bounds "..cjson.encode({panel=panel,tray=tray,footer=footer,close=close}))
    end
    return function(ctx)
        if done then return end
        frame=frame+1
        if view then view.Update() end
        if frame<180 or frame%180~=0 then return end
        local ok,err=pcall(function()
            if phase==0 then
                playerBefore=ctx.session.state.GetSnapshot()
                fixture=F.New(Data,{targetSchema=3}) --[[@as {session:table,state:table,modules:table}]]
                local id=F.Must(fixture.state.ReceiveLetter({letterId="letter_pa_01"})).letterInstanceId
                F.Must(fixture.state.ReadLetter({letterInstanceId=id}))
                for _,span in ipairs(F.Must(fixture.modules.letters.ParseDefinition("letter_pa_01")).spans) do
                    F.Must(fixture.state.CutWord({letterInstanceId=id,spanId=span.spanId}))
                end
                before=fixture.state.GetSnapshot()
                ctx.root:SetVisible(false);view=mount(ctx,fixture)
                view.Open("words");view.Update()
            elseif phase==1 then
                bounds();capture("category")
                local cards=F.Must(fixture.session.queries.GetWordTray())
                local nextCategory
                for _,category in ipairs(cards.categories) do
                    if category.id~=view.wordTray.category then nextCategory=category.id;break end
                end
                assert(nextCategory,"need two real categories")
                tap("wordTrayTab_"..nextCategory);view.Update()
            elseif phase==2 then
                capture("second-category")
                for _,card in ipairs(F.Must(fixture.session.queries.GetWordTray()).cards) do
                    if card.categoryId==view.wordTray.category then chosen=card.tokenId;break end
                end
                tap("wordTrayCard_"..assert(chosen));view.Update()
            elseif phase==3 then
                assert(view.wordTray.selected==chosen,"paper did not select")
                bounds();capture("selected")
                assert(U.Equal(before,fixture.state.GetSnapshot()),"browsing changed fixture")
                tap("closePanel")
            elseif phase==4 then
                assert(view.panel==false,"close did not finish")
                capture("closed");view.root:Destroy()
                view=mount(ctx,F.New(Data,{targetSchema=3}))
                view.Open("words");view.Update()
            elseif phase==5 then
                assert(view.root:FindById("wordTrayEmpty"),"missing empty state")
                bounds();capture("empty")
                assert(U.Equal(playerBefore,ctx.session.state.GetSnapshot()),"player save changed")
                view.root:Destroy();view=nil;ctx.root:SetVisible(true);done=true
                print("[WordTrayNative] PASS native image/Yoga bounds, category and paper touch dispatch, animated close, empty state; memory fixture; NOT phone evidence")
            end
            phase=phase+1
        end)
        if not ok then
            done=true;print("[WordTrayNative] FAIL "..tostring(err))
            if view then view.root:Destroy();view=nil end
            ctx.root:SetVisible(true)
        end
    end
end
return N
