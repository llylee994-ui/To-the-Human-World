local R=require "debug.fixtures.ReleaseFixtures"
local E=require "debug.fixtures.ReleaseEndingFixtures"
local U=require "core.StateUtil"
local T={}
function T.Run()
    local record,done=R.Checks("Apprentice")
    local function check(name,fn)
        if rawget(_G,"APPRENTICE_SKIP_FULL") and name:find("real eleven",1,true) then return end
        record(name,fn)
    end
    local function seed(full)
        local x=full and E.Route(11) or E.SmallComplete(10000)
        x.content.releaseEndings=U.Copy(require "data.release_endings")
        E.Homes(x);return x
    end
    local function open(x)
        local host=require("ui.landscape.tests.ZoomTestHost").New()
        local v=require("ui.PlayView").New(x.session,x.content)
        local function w(id) return assert(v.root:FindById(id),"missing "..id) end
        local function step(seconds) for _=1,math.ceil(seconds/.02) do host.Step(v,.02) end end
        local function tap(id,event)
            local node=w(id)
            if node.props.onPointerDown then node.props.onPointerDown(event) end
            node.props.onClick(node,event);v.Update()
        end
        return v,w,step,tap,host
    end
    check("text separates delivery, actual letter, bonus and two closing pages",function()
        local Text=require "ui.landscape.ApprenticeText"
        local d=require("data.release_endings").apprentice
        local normal=Text.Read(d.text)
        assert(normal.intro=="商人给你送来一封信，说是上一任店主托他带来的。")
        assert(normal.letter:find("店里那支笔",1,true) and not normal.letter:find("商人",1,true))
        assert(#normal.pages==2 and normal.pages[2]:find("起身把灯熄了",1,true))
        local bonus=Text.Read(d.text.."\n\n"..d.allThreeStarText)
        assert(bonus.letter:find("得意门生",1,true) and #bonus.pages==2)
        assert(not bonus.letter:find("信的末尾还有一行字",1,true))
        assert(not table.concat(bonus.pages):find("得意门生",1,true))
        local old=Text.Read("旧信的原文，没有引号。")
        assert(old.letter=="旧信的原文，没有引号。")
    end)
    check("real eleven letters end at sea, transition indoors and collect once before epilogue",function()
        local x=seed(true);local v,w,step,tap=open(x)
        v.Navigate("seaside");v.Update();v.Open("day");v.Update()
        assert(w("confirmNextDay").props.text=="结束今天")
        local day=x.state.GetSnapshot().live.gameFlow.day
        tap("confirmNextDay");assert(v.calendar.motion.active)
        step(1.4)
        assert(v.scene=="home" and v.panel=="closing" and w("apprenticeIntro"))
        assert(x.state.GetSnapshot().live.gameFlow.day==day,"presentation must not change business day rules")
        assert(not w("homeHud").props.visible)
        tap("continueEpilogue");assert(not w("apprenticeLetter").props.visible,"fade cannot be skipped")
        step(1.1);tap("continueEpilogue");step(.9)
        assert(not v.root:FindById("merchantLetterTitle"))
        assert(w("merchantLetterText"):GetText():find("得意门生",1,true))
        assert(w("apprenticeSmile") and w("finishMerchantLetter").props.backgroundImage:find("story-result",1,true))
        local stale=w("finishMerchantLetter");tap("finishMerchantLetter")
        assert(x.state.GetSnapshot().chapter.ending.kind=="apprentice")
        local writes=x.writes;stale.props.onClick();assert(x.writes==writes)
        step(.6);assert(v.panel=="ending")
        assert(not w("releaseEndingText"):GetText():find("商人给你",1,true))
        assert(v.journeyView.sequence.darkAlpha==0,"collecting letter should not flash black before narration")
        local snapshot=x.state.GetSnapshot()
        step(1.2);tap("departureAdvance");step(.8);tap("departureAdvance");step(3)
        assert(w("releaseEndingTitle"):GetText()=="学徒" and w("endGame").props.visible)
        tap("endGame");assert(v.atTitle and x.writes==writes and U.Equal(snapshot,x.state.GetSnapshot()))
    end)
    check("failed collection retains letter and never starts closing narration",function()
        local x=seed();R.Must(x.state.NextDay());R.Must(x.state.AdvanceEpilogue(E.Request(x,{expectedStep="dawn"})))
        local v,w,step,tap=open(x);step(1)
        local before=x.state.GetSnapshot();x.fault="write";tap("finishMerchantLetter");x.fault=false
        assert(U.Equal(before,x.state.GetSnapshot()) and v.panel=="closing")
        assert(w("merchantLetterText") and not v.root:FindById("releaseEndingText"))
        assert(v.model.message:find("保存失败",1,true))
    end)
    check("frozen memory replays delivery and letter without saving",function()
        local x=seed();R.Must(x.state.NextDay());R.Must(x.state.AdvanceEpilogue(E.Request(x,{expectedStep="dawn"})))
        R.Must(x.state.ConfirmEnding(E.Request(x,{kind="apprentice"})))
        local frozen=U.Copy(x.state.GetSnapshot().chapter.ending)
        x.content.releaseEndings.apprentice.text="新的正文不能替换旧留念。"
        local v,w,step,tap=open(x)
        step(1.2);v.ShowTitle();v.Update();tap("openMemories");tap("memory_1")
        local before=x.state.GetSnapshot();local writes=x.writes
        step(1.2);tap("continueEpilogue");step(.9)
        assert(w("merchantLetterText"):GetText():find("店里那支笔",1,true))
        assert(not w("merchantLetterText"):GetText():find("新的正文",1,true))
        tap("finishMerchantLetter");step(.6);step(1.2)
        tap("departureAdvance");step(.8);tap("departureAdvance");step(3)
        tap("backToMemories");assert(v.panel=="memories")
        assert(U.Equal(before,x.state.GetSnapshot()) and x.writes==writes)
        assert(frozen.text==x.state.GetSnapshot().chapter.ending.text)
    end)
    check("secondary, focus loss and stale callbacks cannot collect",function()
        local x=seed();R.Must(x.state.NextDay())
        local v,w,step,tap,host=open(x);step(1.2)
        local secondary={pointerId=2,isPrimary=false,IsPrimaryAction=function() return true end}
        tap("continueEpilogue",secondary);assert(not w("apprenticeLetter").props.visible)
        local intro=w("continueEpilogue");intro.props.onPointerDown();host.focused=false;step(.2);host.focused=true
        intro.props.onClick(intro);assert(not w("apprenticeLetter").props.visible)
        step(.4);tap("continueEpilogue");step(.9)
        local stale=w("finishMerchantLetter");local snapshot=x.state.GetSnapshot();v.root:Destroy()
        stale.props.onClick();assert(U.Equal(snapshot,x.state.GetSnapshot()))
    end)
    check("a collection press begun during opening cannot commit after opening",function()
        local x=seed();R.Must(x.state.NextDay());R.Must(x.state.AdvanceEpilogue(E.Request(x,{expectedStep="dawn"})))
        local v,w,step,tap=open(x)
        local event={pointerId=7,isPrimary=true,IsPrimaryAction=function() return true end}
        local collect=w("finishMerchantLetter")
        if collect.props.onPointerDown then collect.props.onPointerDown(event) end
        step(1)
        local before=x.state.GetSnapshot()
        collect.props.onClick(collect,event);v.Update()
        assert(U.Equal(before,x.state.GetSnapshot()),"release after fade must not collect")
        tap("finishMerchantLetter",{pointerId=8,isPrimary=false,IsPrimaryAction=function() return true end})
        assert(U.Equal(before,x.state.GetSnapshot()),"secondary touch cannot collect")
        if collect.props.onPointerDown then collect.props.onPointerDown(event) end
        local release={pointerId=7,isPrimary=false,IsPrimaryAction=function() return true end}
        collect.props.onClick(collect,release);v.Update()
        assert(x.state.GetSnapshot().chapter.ending.kind=="apprentice","accepted down owns touch release")
    end)
    return done()
end
return T
