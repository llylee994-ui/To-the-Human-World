-- Real game commands with isolated file/UI/clock adapters. No native acceptance claim.
local U=require "core.StateUtil"
local R=require "debug.fixtures.ReleaseFixtures"
local E=require "debug.fixtures.ReleaseEndingFixtures"
local View=require "ui.PlayView"
local Art=require "ui.landscape.CalendarArt"
local T={}
function T.Run()
    local check,finish=R.Checks("Calendar")
    local function open(x)
        local host=require("ui.landscape.tests.ZoomTestHost").New()
        local v=View.New(x.session,x.content);v.Open("day");v.Update()
        local function w(id) return assert(v.root:FindById(id),"missing "..id) end
        local function click(id) local node=w(id);assert(not node.props.disabled);node.props.onClick();v.Update() end
        return v,w,click,host
    end
    check("unreceived, accepted and pending days cannot tear or advance",function()
        local x=R.New();local v,w=open(x)
        for phase=1,3 do
            local before,writes=x.state.GetSnapshot(),x.writes
            assert(w("confirmNextDay").props.disabled and not v.root:FindById("calendarStamp"))
            w("confirmNextDay").props.onClick()
            assert(U.Equal(before,x.state.GetSnapshot()) and writes==x.writes and not v.calendar.motion.active)
            if phase==1 then x.request=R.Accept(x,1) elseif phase==2 then R.Preview(x,x.request) end
            v.Refresh();v.Update()
        end
    end)
    check("save precedes tear; date freezes; repeat and navigation callbacks cannot skip",function()
        local x=R.New();R.Ship(x,1);local v,w,click,host=open(x)
        local callback=w("confirmNextDay").props.onClick
        local revision=x.state.GetSnapshot().revision;local events=x.Events("DayStarted")
        assert(w("calendarStampText"):GetText()=="已寄出")
        click("confirmNextDay")
        local writes=x.writes
        assert(x.state.GetSnapshot().revision==revision+1 and x.Events("DayStarted")==events+1 and x.state.GetSnapshot().live.gameFlow.day==2)
        assert(v.panel=="day" and w("calendarCurrentDay"):GetText()=="1" and w("calendarNextDay"):GetText()=="2")
        assert(w("calendarTomorrow").props.visible and v.calendar.motion.active)
        callback();v.Close();v.Navigate("brew");v.Open("shop");v.OpenPaper();v.Push("letters")
        w("titleHome").props.onClick();assert(v.panel=="day" and x.writes==writes)
        host.Step(v,.55);assert(v.calendar.motion.active and v.calendar.motion.Pose().fly>0)
        host.Step(v,1.1);assert(v.panel==false and not v.calendar and x.writes==writes)
        callback();assert(x.writes==writes)
        v.Open("day");v.Update();assert(w("calendarCurrentDay"):GetText()=="2" and not v.root:FindById("calendarStamp"))
    end)
    check("write failure keeps date and supports a deliberate retry",function()
        local x=R.New();R.Ship(x,1);local v,w,click,host=open(x)
        x.fault="write";click("confirmNextDay");x.fault=false
        assert(x.state.GetSnapshot().live.gameFlow.day==1 and not v.calendar.motion.active)
        assert(w("calendarNotice"):GetText():find("保存失败",1,true))
        click("confirmNextDay");host.Step(v,2)
        assert(x.state.GetSnapshot().live.gameFlow.day==2 and v.panel==false)
    end)
    check("uncertain commit reloads the saved day without replaying it",function()
        local x=R.New();R.Ship(x,1);local v,w,click=open(x)
        x.commitWritten=false;x.fault="uncertain";click("confirmNextDay");x.fault=false
        assert(not x.state.CanMutate() and not v.calendar.motion.active and w("reloadCalendarSave").props.visible)
        assert(w("confirmNextDay").props.disabled)
        local writes=x.writes;click("reloadCalendarSave")
        assert(x.state.CanMutate() and x.state.GetSnapshot().live.gameFlow.day==2 and x.writes==writes)
        assert(w("calendarCurrentDay"):GetText()=="2" and not v.calendar.motion.active)
    end)
    check("last order collects the calendar then opens closing without a new day",function()
        local x=E.SmallComplete();local v,w,click,host=open(x);local day=x.state.GetSnapshot().live.gameFlow.day
        assert(w("confirmNextDay"):GetText()=="收好日历")
        click("confirmNextDay")
        assert(v.calendar.motion.kind=="closing" and not w("calendarTomorrow").props.visible)
        assert(x.state.GetSnapshot().chapter.phase=="closing" and x.state.GetSnapshot().live.gameFlow.day==day)
        assert(not v.root:FindById("continueEpilogue"));host.Step(v,1.2)
        assert(v.panel=="closing" and w("continueEpilogue") and x.state.GetSnapshot().live.gameFlow.day==day)
    end)
    check("cancelled, destroyed and stale-revision buttons cannot commit",function()
        local x=R.New();R.Ship(x,1);local v,w,click=open(x)
        local old=w("confirmNextDay").props.onClick;local before,writes=x.state.GetSnapshot(),x.writes
        click("cancelNextDay");old();assert(v.panel==false and U.Equal(before,x.state.GetSnapshot()) and x.writes==writes)
        v.Open("day");v.Update();old=w("confirmNextDay").props.onClick
        R.Must(x.state.NextDay());writes=x.writes;old();v.Update()
        assert(x.writes==writes and w("calendarCurrentDay"):GetText()=="2")
        old=w("confirmNextDay").props.onClick;v.root:Destroy();old();assert(x.writes==writes)
    end)
    check("focus loss and destruction complete only presentation after commit",function()
        for _,mode in ipairs({"focus","destroy"}) do
            local x=R.New();R.Ship(x,1);local v,w,click,host=open(x)
            click("confirmNextDay");local writes=x.writes
            if mode=="focus" then host.focused=false;host.Step(v,.01);assert(v.panel==false)
            else v.root:Destroy();host.Step(v,2) end
            assert(x.writes==writes and x.state.GetSnapshot().live.gameFlow.day==2)
            assert(x.state.ReloadCurrent());assert(x.state.GetSnapshot().live.gameFlow.day==2)
        end
    end)
    check("calendar and notice stay inside landscape safe insets",function()
        for _,size in ipairs({{1280,720},{900,420},{640,360},{1920,1080}}) do
            local safe={left=44,right=18,top=16,bottom=24};local f=Art.Layout({w=size[1],h=size[2]},safe)
            assert(f.x>=safe.left and f.x+f.w<=size[1]-safe.right)
            assert(f.y>=safe.top and f.y+f.h<=size[2]-safe.bottom)
            assert(f.noteY+f.noteH<=size[2]-safe.bottom and f.noteW>0)
        end
    end)
    check("renderer uses the transparent asset and transforms paper with its UI text",function()
        local x=R.New();R.Ship(x,1);local v,w,click,host=open(x)
        local canvas=w("calendarCanvas");canvas.GetAbsoluteLayout=function() return v.calendar.fit end
        local leaf=w("calendarLeaf")
        local old={}
        local names={"nvgSave","nvgRestore","nvgTranslate","nvgRotate","nvgTransform","nvgGlobalAlpha","nvgIntersectScissor"}
        ---@type number,number,number
        local transforms,depth,calls=0,0,0
        for _,name in ipairs(names) do old[name]=rawget(_G,name);_G[name]=function() end end
        nvgSave=function() depth=depth+1 end;nvgRestore=function() depth=depth-1;assert(depth>=0) end
        nvgTransform=function(_,a,b,c,d,e,f) assert(a==1 and d>0);transforms=transforms+1 end
        local function draw(node) if node==leaf then calls=calls+1 end end
        canvas:CustomRenderChildren({},draw);assert(calls==1 and transforms==0)
        click("confirmNextDay");host.Step(v,.55);calls=0
        canvas:CustomRenderChildren({},draw)
        assert(calls==18 and transforms==18 and depth==0)
        assert(w("calendarBase").props.backgroundImage=="image/calendar-r1/blank.png")
        assert(canvas.props.pointerEvents=="box-none" and w("confirmNextDay").props.pointerEvents=="auto")
        for _,name in ipairs(names) do _G[name]=old[name] end
    end)
    check("real input traversal hits controls but intercepts the exposed room",function()
        local x=R.New();R.Ship(x,1);local v,w,click,host=open(x)
        host.Bind(v.root)
        local function place(node,parent)
            local p=node.props
            node.testLayout={x=parent.x+(type(p.left)=="number" and p.left or 0),
                y=parent.y+(type(p.top)=="number" and p.top or 0),
                w=type(p.width)=="number" and p.width or parent.w,h=type(p.height)=="number" and p.height or parent.h}
            for _,child in ipairs(node.children) do place(child,node.testLayout) end
        end
        place(w("calendarOverlay"),{x=0,y=0,w=1280,h=720})
        -- Same explicit mouse-enum adapter as ReleaseUITest; no native input is injected.
        MOUSEB_LEFT,MOUSEB_MIDDLE,MOUSEB_RIGHT=0,1,2
        local EngineUI=require "urhox-libs/UI/Core/UI"
        EngineUI.SetRoot(v.root)
        local hit=EngineUI.FindWidgetAt(1,719)
        assert(hit and hit.props.id=="modalBlocker","room corner must be intercepted")
        local r=w("confirmNextDay").testLayout
        hit=EngineUI.FindWidgetAt(r.x+r.w/2,r.y+r.h/2)
        assert(hit and hit.props.id=="confirmNextDay","calendar parents must allow button input")
        click("confirmNextDay")
        hit=EngineUI.FindWidgetAt(1,719)
        assert(hit and hit.props.id=="modalBlocker","transition must retain the blocker")
    end)
    return finish()
end
return T
