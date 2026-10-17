local R=require "debug.fixtures.ReleaseFixtures"
local U=require "core.StateUtil"
local T={}
function T.Run()
    local check,done=R.Checks("Departure")
    local function advanceTime(sequence,seconds,focused)
        for _=1,math.ceil(seconds/.02) do sequence.Update(.02,focused~=false) end
    end
    check("current ending has five exact frozen narration pages",function()
        local S=require "ui.landscape.DepartureSequence"
        local x=R.New(700)
        R.Must(x.state.PurchaseTravelTicket(R.Quote(x,"travel_ticket",666)))
        local ending=R.Must(x.session.queries.GetEndingView()).ending
        local pages=S.Pages(ending.text)
        assert(#pages==5,"expected five pages")
        assert(pages[5]=="至于下船后先去哪里，你还没有想好，商人给你指了路，又往你手里塞了一块面包。你道了谢，坐下来慢慢吃，打算下船后先去他说的地方看看。")
        assert(table.concat(pages,"\n\n")==ending.text)
        local legacy="旧信第一段。\r\n\r\n旧信第二段，不能替换。"
        assert(S.Pages(legacy)[2]=="旧信第二段，不能替换。")
    end)
    check("reading never auto advances; transition and rapid taps cannot skip pages",function()
        local S=require "ui.landscape.DepartureSequence"
        local seq=S.New(5)
        assert(not seq.Advance())
        advanceTime(seq,1.2);assert(seq.CanAdvance() and seq.index==1)
        advanceTime(seq,4);assert(seq.index==1)
        for i=1,4 do
            assert(seq.Advance());assert(not seq.Advance())
            advanceTime(seq,.8);assert(seq.CanAdvance() and seq.index==i+1)
        end
        assert(seq.Advance());assert(not seq.done)
        advanceTime(seq,1);assert(not seq.done)
        advanceTime(seq,2);assert(seq.done and seq.darkAlpha>=.85 and seq.titleAlpha==1)
        assert(not seq.Advance())
    end)
    check("focus loss pauses motion; destroyed sequences reject callbacks",function()
        local seq=require("ui.landscape.DepartureSequence").New(2)
        local before=seq.darkAlpha
        advanceTime(seq,2,false);assert(seq.darkAlpha==before)
        advanceTime(seq,1.2);assert(seq.CanAdvance())
        seq.Destroy();assert(not seq.Advance())
        local index=seq.index;advanceTime(seq,4);assert(seq.index==index)
    end)
    check("real ending view reads frozen text; navigation and replay never write",function()
        local x=R.New(700)
        R.Must(x.state.PurchaseTravelTicket(R.Quote(x,"travel_ticket",666)))
        local snapshot=x.state.GetSnapshot();local writes=x.writes
        local host=require("ui.landscape.tests.ZoomTestHost").New()
        local view=require("ui.PlayView").New(x.session,x.content)
        local function w(id) return assert(view.root:FindById(id),id) end
        local function step(seconds) for _=1,math.ceil(seconds/.02) do host.Step(view,.02) end end
        local event={IsPrimaryAction=function() return true end,StopPropagation=function() end}
        local tap=w("departureAdvance")
        local finish=w("endGame")
        assert(not finish.props.visible)
        finish.props.onClick();assert(not view.atTitle)
        step(1.2)
        for i=1,5 do
            assert(w("releaseEndingText"):GetText()==view.journeyView.pages[i])
            tap.props.onPointerDown(event);tap.props.onClick(tap,event)
            tap.props.onClick(tap,event)
            step(i==5 and 3 or .8)
        end
        assert(finish.props.visible and x.writes==writes)
        finish.props.onClick();view.Update();assert(view.atTitle)
        assert(U.Equal(snapshot,x.state.GetSnapshot()))
        view.root:FindById("openMemories").props.onClick();view.Update()
        view.root:FindById("memory_1").props.onClick();view.Update()
        assert(w("releaseEndingText"):GetText()==view.journeyView.pages[1])
        local stale=w("departureAdvance");view.journeyView.Destroy()
        stale.props.onPointerDown(event);stale.props.onClick(stale,event)
        assert(x.writes==writes)
    end)
    check("secondary pointer and a press begun during fade never advance",function()
        local x=R.New(700);R.Must(x.state.PurchaseTravelTicket(R.Quote(x,"travel_ticket",666)))
        local host=require("ui.landscape.tests.ZoomTestHost").New()
        local view=require("ui.PlayView").New(x.session,x.content)
        local tap=assert(view.root:FindById("departureAdvance"))
        local primary={IsPrimaryAction=function() return true end,StopPropagation=function() end}
        tap.props.onPointerDown(primary)
        for _=1,70 do host.Step(view,.02) end
        tap.props.onClick(tap,primary);assert(view.journeyView.sequence.index==1)
        -- Headless host has no native mouse constants; use engine button indices.
        local left,middle,right=MOUSEB_LEFT,MOUSEB_MIDDLE,MOUSEB_RIGHT
        MOUSEB_LEFT,MOUSEB_MIDDLE,MOUSEB_RIGHT=0,1,2
        local Event=require "urhox-libs/UI/Core/PointerEvent"
        MOUSEB_LEFT,MOUSEB_MIDDLE,MOUSEB_RIGHT=left,middle,right
        local secondary=Event.new("PointerDown",{pointerType="touch",pointerId=12,isPrimary=false})
        assert(secondary:IsPrimaryAction(),"engine permits secondary touches as actions")
        tap.props.onPointerDown(secondary);tap.props.onClick(tap,secondary)
        assert(view.journeyView.sequence.index==1)
        tap.props.onPointerDown(primary);tap.props.onPointerCancel(primary);tap.props.onClick(tap,primary)
        assert(view.journeyView.sequence.index==1)
        local first=Event.new("PointerDown",{pointerType="touch",pointerId=11,isPrimary=true})
        tap.props.onPointerDown(first)
        tap.props.onPointerDown(secondary);tap.props.onPointerCancel(secondary);tap.props.onClick(tap,secondary)
        local up=Event.new("PointerUp",{pointerType="touch",pointerId=11,isPrimary=false})
        tap.props.onPointerUp(up);tap.props.onClick(tap,up)
        assert(view.journeyView.sequence.phase=="out","accepted touch keeps ownership through release")
        for _=1,45 do host.Step(view,.02) end
        tap.props.onPointerDown(first);tap.props.onPointerUp(up) -- release outside: no click
        tap.props.onPointerDown(first);tap.props.onPointerCancel(first)
        tap.props.onClick(tap,up)
        assert(view.journeyView.sequence.index==2 and view.journeyView.sequence.phase=="read")
        local scroll=assert(view.root:FindById("departureNarrationScroll"))
        tap.props.onPointerDown(first)
        require("urhox-libs/UI/Core/Widget").OnPointerCancel(scroll,first) -- touch pan cancels pressed ScrollView
        local nextTouch=Event.new("PointerDown",{pointerType="touch",pointerId=13,isPrimary=true})
        tap.props.onPointerDown(nextTouch);tap.props.onClick(tap,nextTouch)
        assert(view.journeyView.sequence.phase=="out","narration scrolling must release pointer ownership")
    end)
    return done()
end
return T
