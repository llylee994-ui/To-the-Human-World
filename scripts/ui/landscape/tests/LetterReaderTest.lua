-- Integration: real reader and real persistence; explicit UI/font/clock adapters.
local UI=require("urhox-libs/UI") --[[@as table]]
local Data=require "data.content"
local F=require "debug.fixtures.B5Fixtures"
local View=require "ui.PlayView"
local U=require "core.StateUtil"
local T={}
function T.Run()
    package.loaded["debug.DeveloperMode"]=false
    local host=require("ui.landscape.tests.ZoomTestHost").New()
    local x=F.New(Data,{targetSchema=3});local view=View.New(x.session,Data)
    local n=0;local function check(ok,msg) n=n+1;assert(ok,msg) end
    local function must(r) assert(r.ok,cjson.encode(r.error));return r.value end
    local id=must(view.model.Receive(must(x.session.queries.GetSalvageView()).availableLetterIds[1])).letterInstanceId
    must(view.Read(id));view.Update();host.Bind(view.root)
    ---@type table
    local cache=view.readerCache
    check(cache.presentation~=nil,"real reader must own its unfold/cut presentation")
    local scroll=assert(view.root:FindById("playScroll"));scroll.testScrollY=420
    for _=1,25 do host.Step(view,1/60) end
    cache=view.readerCache
    local presentation=cache.presentation --[[@as table]]
    scroll=assert(view.root:FindById("playScroll"));scroll.testScrollY=420
    local spans=must(x.modules.letters.GetView(id)).spans
    local before=x.state.GetSnapshot();x.fault="write"
    check(not presentation.Cut(spans[1].spanId).ok,"failed persistence refuses the paper cut")
    x.fault=false;view.Update()
    check(U.Equal(before,x.state.GetSnapshot()) and not presentation.motion.flight,"failure leaves text/card inventory and flight unchanged")
    must(presentation.Cut(spans[1].spanId));view.Update()
    check(presentation.motion.flight~=false,"successful saved cut starts a paper strip")
    before=x.state.GetSnapshot();local writes=x.writes
    check(not presentation.Cut(spans[1].spanId).ok,"same source cannot start two cuts")
    for _=1,65 do host.Step(view,1/60) end
    check(U.Equal(before,x.state.GetSnapshot()) and writes==x.writes,"animation updates never write or settle business")
    check(not presentation.motion.flight and not presentation.motion.opening,"animation advances even when model is clean")
    check(view.root:FindById("playScroll")==scroll and scroll.testScrollY==420,"paper animations/cutting retain scroll node and position")
    local paper=view.root:FindById("letterPaper")
    check(not paper:GetText():find("【",1,true) and not paper:GetText():find("〔",1,true),"reader text must not contain fake bracket cut-outs")
    must(presentation.Cut(spans[2].spanId));view.Update();view.Close();view.Update()
    check(not presentation.motion.flight,"close cancels the transient flight")
    before=x.state.GetSnapshot();must(view.Read(id));view.Update()
    check(U.Equal(before,x.state.GetSnapshot()),"reopening does not undo saved cuts")
    check(not view.readerCache.presentation.motion.flight,"reopening does not replay previously collected cards")
    check(view.readerCache.presentation.view.spans[1].cut,"saved cut is still disabled")
    check(not view.root:FindById("cut_"..spans[1].spanId),"paper is the only cutting interaction; no separate cut buttons")
    local capture=rawget(_G,"LETTER_READER_EVIDENCE")
    if capture then capture(view,x,host) end
    print("[LetterReaderTest] PASS assertions="..n.."; save failures, one source card, dirty-free timeline, close/reopen and scroll preservation")
    return n
end
return T
