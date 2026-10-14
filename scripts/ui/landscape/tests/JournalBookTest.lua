-- 记录书：布料底衬、索引贴、两级页内与翻页。查询用夹具桩，验证不写玩家状态。
local Data=require "data.content"
local F=require "debug.fixtures.B5Fixtures"
local View=require "ui.PlayView"
local U=require "core.StateUtil"
local T={}
function T.Run()
    local n=0
    local function check(value,message) n=n+1;assert(value,message) end
    local host=require("ui.landscape.tests.ZoomTestHost").New()
    local x=F.New(Data,{targetSchema=3})
    local v=View.New(x.session,Data);host.Bind(v.root);v.Update()
    local function widget(id) return v.root:FindById(id) end
    local function click(id)
        local node=assert(widget(id),id);check(not node.props.disabled,id.." disabled")
        node.props.onClick();v.Update()
    end
    -- 桩：两个已收到（第一个两支已收集 + 一支空位，第二个全空）＋ 一个未收到。
    local received,other,locked="letter_pa_01","letter_n01","letter_n02"
    local branchA,branchB,branchC="frag_e01_result_rested","frag_e01_result_mother_dream","frag_e01_result_song_faded"
    rawset(x.session.queries,"GetJournalStories",function() return U.Ok({
        {sourceLetterId=received,title="铁锚巷的一夜",received=true,attemptCount=2,discoveredOutcomeCount=2,totalBranchCount=3},
        {sourceLetterId=other,title="面包坊与抄写铺",received=true,attemptCount=0,discoveredOutcomeCount=0,totalBranchCount=2},
        {sourceLetterId=locked,title="两个人的晚饭",received=false,attemptCount=0,discoveredOutcomeCount=0,totalBranchCount=5}}) end)
    rawset(x.session.queries,"GetJournalPage",function(id)
        if id==other then
            return U.Ok({sourceLetterId=id,title="面包坊与抄写铺",
                branches={{fragmentId="frag_n01_result_departure_agreed",shortName="一个月后的新学徒"},
                    {fragmentId="frag_n01_result_stayed_for_promise",shortName="加薪与账本"}},
                outcomes={}})
        end
        if id~=received then return U.Fail("UNKNOWN_ID","sourceLetterId","尚未收到该信件") end
        return U.Ok({sourceLetterId=id,title="铁锚巷的一夜",
            branches={{fragmentId=branchA,shortName="踏实的一夜"},{fragmentId=branchB,shortName="梦里的母亲"},
                {fragmentId=branchC,shortName="淡去的旧事"}},
            outcomes={
                {outcomeKey="k1",branchFragmentId=branchA,shortName="踏实的一夜",displayTitle="埃利亚斯·沃德的回信",
                    attempts={{transactionId="t1",status="shipped",stars=3,day=3,text="第一支的后续正文。",recipeSummary={main={text="安稳"}}}}},
                {outcomeKey="k2",branchFragmentId=branchB,shortName="梦里的母亲",displayTitle="埃利亚斯·沃德的回信",
                    attempts={{transactionId="t2",status="reset",stars=2,day=5,text="第二支的后续正文（重置过）。"}}}}})
    end)

    local before,writes=x.state.GetSnapshot(),x.writes
    v.Open("journal");v.Update()
    local panel=assert(widget("activePanel"),"book panel")
    check(panel.props.backgroundImage~=nil and panel.props.backgroundImage:find("桌布",1,true)~=nil,"book sits on the cloth mat")
    check(widget("journalBookTitle"):GetText()=="记录书","book title")
    local closed=panel.props.right
    for _=1,40 do host.Step(v,.05) end
    check(panel.props.right>closed,"cloth slides in from the right edge")
    check(v.journalBook.open==1,"slide finishes")

    -- 索引贴：全部故事都在，未收到的锁住且不剧透。
    check(widget("bookTab_"..received),"received story keeps its tab")
    local lockedTab=assert(widget("bookTab_"..locked),"unreceived story keeps a locked tab")
    check(lockedTab.props.disabled,"unreceived story tab is locked")
    check(lockedTab:GetText()=="？？？","locked tab does not reveal the story title")

    -- 目录：分支目录含空位，目录页不混入详情。
    check(assert(widget("bookEntry_"..branchA)),"collected branch row")
    check(assert(widget("bookEntry_"..branchC)),"uncollected branch keeps an empty slot")
    check(widget("bookEntryName_"..branchC):GetText():find("？",1,true)~=nil,"uncollected branch hides its name")
    check(widget("bookEntryMeta_"..branchC):GetText()=="未收集","uncollected branch is marked")
    check(widget("bookProgress"):GetText():find("2 / 3",1,true)~=nil,"catalog counts collected branches")
    check(not widget("bookEntryBody"),"catalog does not mix in the branch detail")

    -- 详情：存档原文回看，重置过的记录同样可读。
    click("bookEntry_"..branchA)
    check(assert(widget("bookEntryBody")),"branch detail opens inside the page")
    check(widget("bookEntryText"):GetText()=="第一支的后续正文。","stored follow-up text is readable")
    check(widget("bookEntryMeta"):GetText():find("第 3 天",1,true)~=nil,"detail keeps the attempt day")
    check(widget("bookEntryMeta"):GetText():find("3 星",1,true)~=nil,"detail keeps the star rating")
    click("bookEntryBack")
    check(assert(widget("bookEntry_"..branchA)),"return-to-catalog restores the list")
    click("bookEntry_"..branchB)
    check(widget("bookEntryText"):GetText()=="第二支的后续正文（重置过）。","reset history stays readable")
    click("bookEntryBack")

    -- 锁住的标签点了也不动：不变故事、不翻页。
    lockedTab.props.onClick();v.Update()
    check(v.journalBook.story==received and v.journalBook.flip==0,"locked tab cannot switch stories")

    -- 切故事：翻页；全空的故事给出空目录而不是报错。
    click("bookTab_"..other)
    check(v.journalBook.flip>0,"switching story starts a page turn")
    check(widget("bookStoryTitle"):GetText()=="面包坊与抄写铺","page follows the selected story")
    check(widget("bookProgress"):GetText():find("0 / 2",1,true)~=nil,"all-empty story keeps its empty slots")
    check(assert(widget("bookEntry_frag_n01_result_departure_agreed")),"empty story still lists its branches")
    for _=1,40 do host.Step(v,.05) end
    check(v.journalBook.flip==0,"page turn finishes")

    -- 自绘冒烟：书脊与翻页在 nvg 适配器上真的走一遍（显式适配器，不是原生画面证据）。
    local calls={}
    local names={"nvgSave","nvgRestore","nvgIntersectScissor","nvgBeginPath","nvgRect","nvgFill","nvgFillPaint",
        "nvgFillColor","nvgLinearGradient","nvgFontFace","nvgFontSize","nvgTextAlign","nvgText"}
    local saved={}
    for _,name in ipairs(names) do
        saved[name]=rawget(_G,name)
        _G[name]=function(_,...) calls[#calls+1]={name=name,args={...}} end
    end
    local rgba=rawget(_G,"nvgRGBA")
    rawset(_G,"nvgRGBA",function(...) return {...} end)
    -- 无头环境没有引擎注入的 NVG_ALIGN_*，显式给值（同 LetterRenderTest）。
    local aligns={NVG_ALIGN_LEFT,NVG_ALIGN_TOP,NVG_ALIGN_CENTER,NVG_ALIGN_MIDDLE,NVG_ALIGN_RIGHT}
    NVG_ALIGN_LEFT=1;NVG_ALIGN_TOP=8;NVG_ALIGN_CENTER=2;NVG_ALIGN_MIDDLE=16;NVG_ALIGN_RIGHT=4
    local page=v.journalBook.page
    page.GetAbsoluteLayout=function() return {x=700,y=60,w=520,h=600} end
    calls={};v.journalBook.flip=0;page:RenderOverlays(1)
    local spine=0
    for _,call in ipairs(calls) do if call.name=="nvgFill" then spine=spine+1 end end
    check(spine>=6,"spine shading is drawn on the page edge")
    calls={};v.journalBook.flip=0.17;v.journalBook.flipTitle="铁锚巷的一夜";page:RenderOverlays(1)
    local gradients,texts=0,0
    for _,call in ipairs(calls) do
        if call.name=="nvgLinearGradient" then gradients=gradients+1 end
        if call.name=="nvgText" then
            texts=texts+1
            check(call.args[3]=="铁锚巷的一夜","turning sheet carries the outgoing story title")
        end
    end
    check(gradients>=3,"sheet, fold shadow and cast shadow all use gradients")
    check(texts==1,"exactly one title is painted on the turning sheet")
    v.journalBook.flip=0
    for _,name in ipairs(names) do rawset(_G,name,saved[name]) end
    rawset(_G,"nvgRGBA",rgba)
    NVG_ALIGN_LEFT,NVG_ALIGN_TOP,NVG_ALIGN_CENTER,NVG_ALIGN_MIDDLE,NVG_ALIGN_RIGHT=table.unpack(aligns)

    -- 关闭：先滑出，再真正关面板。
    click("closePanel")
    check(v.journalBook.closing,"close button starts the slide out before closing")
    for _=1,40 do host.Step(v,.05) end
    check(v.panel==false,"book closes through its own animation")

    -- 未收到的故事被直接指定（防御路径）时给空页提示，而不是抛错。
    v.storyId=locked;v.Open("journal");v.Update()
    for _=1,40 do host.Step(v,.05) end
    check(assert(widget("bookLocked")),"unreceived story shows an empty page")
    check(not widget("bookEntry_frag_e01_result_rested"),"locked story cannot show another story's branches")
    click("closePanel")
    for _=1,40 do host.Step(v,.05) end
    check(v.panel==false,"locked page still closes")
    check(U.Equal(before,x.state.GetSnapshot()) and x.writes==writes,"book never writes player state")
    print("[JournalBookTest] PASS assertions="..n.."; cloth mat, locked index tabs, two-level stored text, page turn; NOT native evidence")
end
return T
