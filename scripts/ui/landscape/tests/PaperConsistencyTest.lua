-- Real constructors/state with an isolated clock/widget host; native QA is separate.
local H=require "ui.landscape.HarborStyle"
local Data=require "data.content"
local F=require "debug.fixtures.B5Fixtures"
local View=require "ui.PlayView"
local T={}
function T.Run()
    local n=0;local function check(ok,msg) n=n+1;assert(ok,msg) end
    for _,props in ipairs({{}, {padding=0},{padding=12},{padding={6,14}}}) do
        local p=H.PaperProps(props)
        check(p.paddingLeft>=32 and p.paddingRight>=32,"all paper content clears torn side edges")
        check(p.paddingTop>=32 and p.paddingBottom>=32,"full paper frames clear top/bottom edges")
    end
    local compact=H.PaperProps({compact=true,padding={6,32},height=76})
    check(compact.paddingLeft>=32 and compact.paddingTop>=6,"compact sea/HUD paper keeps side clearance without inflating height")
    local ledger=H.PaperProps({height=32})
    check(ledger.paddingTop+ledger.paddingBottom<=12,"compact paper must not inherit full-frame 64px vertical padding")
    local host=require("ui.landscape.tests.ZoomTestHost").New()
    local x=F.New(Data,{targetSchema=3});local view=View.New(x.session,Data)
    local hud=assert(view.root:FindById("playLedger")).parent
    check(hud.props.height<=36 and hud.props.paddingLeft<=18,"ledger remains a small status tag")
    local id=assert(view.model.Receive(x.session.queries.GetSalvageView().value.availableLetterIds[1]).value).letterInstanceId
    assert(view.Read(id).ok);view.Update();host.Bind(view.root)
    local sender=view.root:FindById("readerSender")
    local Panels=require "ui.landscape.Panels"
    check(sender~=nil,"reader keeps one sender metadata row")
    check(Panels.IntroText("来信人：埃利亚斯·沃德","埃利亚斯·沃德")=="","name-only introduction must not repeat the sender")
    check(Panels.IntroText("来信人：埃利亚斯·沃德\n我叫埃利亚斯。","埃利亚斯·沃德")=="我叫埃利亚斯。","dedup preserves actual biography")
    for _=1,25 do host.Step(view,1/60) end
    local scroll=view.root:FindById("playScroll")
    local presentation=view.readerCache.presentation --[[@as table]]
    local spans=x.modules.letters.GetView(id).value.spans
    assert(presentation.Cut(spans[1].spanId).ok);view.Update()
    check(view.panelNoticeArea.props.visible==false,"cut feedback must not insert a row above the reading viewport")
    check(view.root:FindById("playScroll")==scroll,"cut retains the same scroll node")
    view.Open("journal");view.Update()
    check(not view.root:FindById("bookEntryBody"),"story directory must not mix with the selected branch detail")
    local rows=x.session.queries.GetJournalStories().value
    local first=false
    for _,row in ipairs(rows) do if not first and row.received then first=row end end
    assert(first,"fixture has a received story")
    local tab=assert(view.root:FindById("bookTab_"..first.sourceLetterId),"story keeps an index tab")
    check(tab.props.disabled~=true,"received story tab is selectable")
    local page=x.session.queries.GetJournalPage(first.sourceLetterId).value
    local collected=false
    for _,outcome in ipairs(page.outcomes) do if not collected then collected=outcome.branchFragmentId end end
    if collected then
        assert(view.root:FindById("bookEntry_"..collected),"collected branch keeps a catalog row")
        view.root:FindById("bookEntry_"..collected).props.onClick();view.Update()
        check(view.root:FindById("bookEntryBody") and view.root:FindById("bookEntryBack"),"branch detail has its own body and return-to-catalog action")
        check(view.root:FindById("bookEntryText"):GetText()~="","stored follow-up text renders inside the page")
    end
    check(#page.branches>=#page.outcomes,"catalog keeps every branch, including uncollected ones")
    -- 词条栏与记录书改走布料面板（WordTrayDrawer / JournalBook），不再共用纸面框架，故不在此列。
    for _,kind in ipairs({"letters","case","day","result"}) do
        view.Open(kind);view.Update()
        local p=view.root:FindById("activePanel").props
        check(p.paddingLeft>=32 and p.paddingTop>=32,kind.." uses the same safe paper frame")
    end
    view.Navigate("brew");view.Update()
    local p=view.root:FindById("functionalScene").props
    check(p.paddingLeft>=32 and p.paddingRight>=32,"brew scene retains paper clearance after safe-area updates")
    print("[PaperConsistencyTest] PASS assertions="..n.."; global frames, sender dedup, stable cut viewport; NOT native evidence")
    return n
end
return T
