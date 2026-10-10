local U=require "core.StateUtil"
local F=require "debug.fixtures.B5Fixtures"
local Data=require "data.content"
local T={}
local function must(r) assert(r.ok,cjson.encode(r.error)); return r.value end
function T.RunQueries()
    local x=F.New(Data)
    local before,writes,events=x.state.GetSnapshot(),x.writes,#x.events
    for _,name in ipairs({"GetLetters","GetWordTray","GetSalvageView","GetOrderSummary","GetShopView","GetCaseBoard"}) do
        local result=must(x.session.queries[name]()); result.__edited=true
    end
    assert(not x.session.queries.GetAttempt("missing").ok)
    assert(not x.session.queries.GetJournalPage("missing").ok)
    assert(U.Equal(before,x.state.GetSnapshot()) and writes==x.writes and events==#x.events)
    print("[Landscape] query contracts: PASS; zero writes/events")
end
local checks=0
local function check(condition,message) checks=checks+1; assert(condition,message) end
local function prepare()
    local x=F.New(Data,{targetSchema=3})
    local id=must(x.state.ReceiveLetter({letterId="letter_pa_01"})).letterInstanceId
    must(x.state.ReadLetter({letterInstanceId=id}))
    local tokens={}
    for _,span in ipairs(must(x.modules.letters.ParseDefinition("letter_pa_01")).spans) do tokens[span.wordId]=must(x.state.CutWord({letterInstanceId=id,spanId=span.spanId})).tokenId end
    local orderId=must(x.order.Accept({letterInstanceId=id})).orderId
    local sample=assert(require("debug.fixtures.NumericV02Cases")[1]).recipe
    local draft={equipmentId=sample.equipmentId,mainTokenId=tokens[sample.mainWordId],auxTokenIds={},ingredients=U.Copy(sample.ingredients),specialItemIds={}}
    x.orderId=orderId; x.letterId=id; x.tokens=tokens; x.draft=draft
    function x.Select(d) return x.order.UpdateDraft({orderId=x.orderId,draft=d or x.draft}) end
    function x.Trial()
        local request=U.Copy(x.state.GetSnapshot().currentOrder.draft); request.orderId=x.orderId
        return x.order.Preview(request)
    end
    function x.Credentials()
        local order=x.state.GetSnapshot().currentOrder
        return {orderId=x.orderId,baselineId=order.baseline.id,transactionId=order.pending.transactionId}
    end
    return x
end
function T.RunFlow()
    local x=prepare(); local live=x.state.GetSnapshot().live
    must(x.Select())
    check(x.state.GetSnapshot().currentOrder.baseline==false,"draft must not freeze")
    check(x.state.GetSnapshot().currentOrder.phase=="accepted","draft stays accepted")
    check(U.Equal(x.state.GetSnapshot().live,live),"draft must not consume")
    local writes=x.writes; must(x.Select()); check(writes==x.writes,"same draft no save")
    assert(x.Reload()); check(U.Equal(x.state.GetSnapshot().currentOrder.draft,x.draft),"draft recovery")
    check(x.state.NextDay().error.code=="DRAFT_NOT_EMPTY","draft day gate")
    must(x.state.Shop({ingredientId="ing_sea_salt",quantity=1}))
    live=x.state.GetSnapshot().live
    local preview=must(x.Trial()); check(preview.phase=="pending","preview success")
    check(U.Equal(x.state.GetSnapshot().live,live),"preview no settlement")
    local credentials=x.Credentials(); writes=x.writes
    must(x.Trial()); check(writes==x.writes,"repeat preview no save")
    check(#x.state.GetSnapshot().journal.attemptIds==1,"single journal entry")
    for _,result in ipairs({x.Select(),x.state.Shop({ingredientId="ing_sea_salt",quantity=1}),x.state.NextDay(),x.state.CutWord({letterInstanceId=x.letterId,spanId="body:1"}),x.state.ReceiveLetter({letterId="letter_pa_01"})}) do check(not result.ok,"pending mutation locked") end
    local model=require("ui.PlayModel").New(x.session,Data)
    local before=x.state.GetSnapshot(); writes=x.writes
    model.ReturnHome(); must(model.OpenAttempt(credentials.transactionId)); model.Navigate("brew")
    check(writes==x.writes and U.Equal(before,x.state.GetSnapshot()),"navigation/history no commit")
    assert(x.Reload()); check(U.Equal(before,x.state.GetSnapshot()),"pending exact recovery")
    must(x.order.Reset(credentials)); check(U.Equal(live,x.state.GetSnapshot().live),"reset preserves formal resources")
    check(x.state.GetSnapshot().journal.byAttemptId[credentials.transactionId].status=="reset","reset history preserved")
    writes=x.writes; must(x.order.Reset(credentials)); check(writes==x.writes,"repeat reset noop")
    assert(x.Reload()); check(#x.state.GetSnapshot().journal.attemptIds==1,"reset recovery")
    must(x.state.Shop({ingredientId="ing_sea_salt",quantity=1})); live=x.state.GetSnapshot().live
    must(x.Select()); must(x.Trial())
    local second=x.Credentials()
    check(second.baselineId~=credentials.baselineId and second.transactionId~=credentials.transactionId,"new attempt ids")
    check(U.Equal(x.state.GetSnapshot().currentOrder.baseline.live,live),"new baseline includes purchases")
    check(not x.order.Reset(credentials).ok,"stale reset rejected")
    check(not x.order.Confirm({orderId=x.orderId,transactionId=credentials.transactionId}).ok,"stale shipment rejected")
    local confirm={orderId=x.orderId,transactionId=second.transactionId}
    must(x.order.Confirm(confirm)); local shipped=x.state.GetSnapshot(); writes=x.writes
    must(x.order.Confirm(confirm)); check(writes==x.writes,"duplicate shipment no write")
    check(shipped.live.gameFlow.deliveredOrders==1,"one shipment")
    check(x.Events("PotionDelivered")==1,"one delivery notification")
    check(shipped.live.economy.currency==live.economy.currency+80,"real reward once")
    check(shipped.live.economy.ingredients.ing_sea_salt==live.economy.ingredients.ing_sea_salt-1,"one ingredient consumed")
    check(not shipped.live.wordTokens.byId[x.draft.mainTokenId].available,"one token consumed")
    assert(x.Reload()); must(x.order.Confirm(confirm)); check(U.Equal(shipped,x.state.GetSnapshot()),"confirmed reload/idempotence")
    check(must(x.session.queries.GetCaseBoard()).availability=="unopened","no invented/reset case unlock")
    local page=must(x.session.queries.GetJournalPage("letter_pa_01"))
    check(#page.outcomes==1 and #page.outcomes[1].attempts==2,"same outcome grouped without losing attempts")
    local attempt=must(x.session.queries.GetAttempt(credentials.transactionId)); attempt.rating.stars=99
    check(must(x.session.queries.GetAttempt(credentials.transactionId)).rating.stars==3,"history returned by copy")
    print("[Landscape] transaction, draft, journal, recovery: PASS")
end
function T.RunFaults()
    for _,operation in ipairs({"draft","preview","reset","confirm"}) do
        for _,fault in ipairs({"write","encode","readback","before_commit","after_commit","uncertain"}) do
            local x=prepare()
            if operation~="draft" then must(x.Select()) end
            if operation=="reset" or operation=="confirm" then must(x.Trial()) end
            local credentials=(operation=="reset" or operation=="confirm") and x.Credentials() or nil
            local before=x.state.GetSnapshot(); local eventCount=#x.events
            x.fault=fault; x.commitWritten=false
            local result
            if operation=="draft" then result=x.Select()
            elseif operation=="preview" then result=x.Trial()
            elseif operation=="reset" then result=x.order.Reset(credentials)
            else result=x.order.Confirm({orderId=x.orderId,transactionId=credentials.transactionId}) end
            if fault=="after_commit" then check(result.ok,"committed result must be success")
            elseif fault=="uncertain" then
                check(not result.ok and not x.state.CanMutate(),"uncertain commit locks session")
                check(U.Equal(before,x.state.GetSnapshot()) and #x.events==eventCount,"uncertain no live install or notifications")
            else
                check(not result.ok,"injected save failure rejected: "..operation.."/"..fault)
                check(U.Equal(before,x.state.GetSnapshot()) and #x.events==eventCount,"save failure preserves state/events")
            end
            x.fault=false; assert(x.Reload())
            local loaded=x.state.GetSnapshot()
            if fault=="after_commit" or fault=="uncertain" then
                check(not U.Equal(before,loaded),"committed candidate recovered")
                if operation=="confirm" then
                    must(x.order.Confirm({orderId=x.orderId,transactionId=credentials.transactionId}))
                    check(U.Equal(loaded,x.state.GetSnapshot()),"uncertain shipment never repeats")
                end
            else check(U.Equal(before,loaded),"previous generation restored") end
        end
    end
    local x=prepare(); must(x.Select()); must(x.Trial())
    local c=x.Credentials(); x.onEvent=function() error("injected notification failure") end
    local result=must(x.order.Confirm({orderId=x.orderId,transactionId=c.transactionId}))
    check(result.notificationErrors~=nil,"notification failure reported after committed shipment")
    check(x.state.GetSnapshot().live.gameFlow.deliveredOrders==1,"notification cannot undo settlement")
    print("[Landscape] fault matrix: PASS")
end
function T.RunInputs()
    local x=prepare(); local model=require("ui.PlayModel").New(x.session,Data)
    local tokenIds={}; for _,id in pairs(x.tokens) do tokenIds[#tokenIds+1]=id end; table.sort(tokenIds)
    must(model.Drop("word",tokenIds[1])); must(model.Drop("word",tokenIds[2]))
    must(model.TakeOut("word",tokenIds[1])); local d=model.GetDraft()
    check(d.mainTokenId==false and d.auxTokenIds[1]==tokenIds[2],"remove main preserves aux")
    must(model.Drop("word",tokenIds[3])); check(model.GetDraft().mainTokenId==tokenIds[3],"next card fills main")
    check(not model.Drop("word",tokenIds[2]).ok,"duplicate card rejected")
    local before=x.state.GetSnapshot(); local writes=x.writes
    local invalid=U.Copy(x.draft); invalid.ingredients[1].quantity=999
    check(not x.Select(invalid).ok and writes==x.writes and U.Equal(before,x.state.GetSnapshot()),"invalid quantity no write")
    invalid=U.Copy(x.draft); invalid.equipmentId="missing"
    check(not x.Select(invalid).ok,"unknown equipment rejected")
    must(model.Edit("clear")); before=x.state.GetSnapshot(); writes=x.writes
    check(not x.Trial().ok and writes==x.writes,"missing main no trial")
    -- 真实内容中的字面失败：信任主词达不到本单睡眠门槛。
    invalid=U.Copy(x.draft); invalid.mainTokenId=x.tokens.word_candidate_elias_trust; invalid.ingredients={}
    must(x.Select(invalid)); before=x.state.GetSnapshot(); writes=x.writes
    local result=must(x.Trial())
    check(result.phase=="accepted" and result.requirementResult.canShip==false,"literal failure returns preparation")
    check(writes==x.writes and U.Equal(before,x.state.GetSnapshot()),"literal failure no journal/baseline")
    local q=x.session.queries
    for _,name in ipairs({"GetLetters","GetWordTray","GetSalvageView","GetOrderSummary","GetShopView","GetCaseBoard","GetJournalStories"}) do must(q[name]()) end
    check(writes==x.writes and U.Equal(before,x.state.GetSnapshot()),"all real-state queries remain readonly")
    must(model.Edit("clear")); must(x.state.NextDay())
    check(x.state.GetSnapshot().currentOrder.orderId==x.orderId,"empty accepted order survives next day")
    print("[Landscape] inputs and literal rejection: PASS")
end
function T.RunSalvage()
    local x=F.New(Data,{targetSchema=3}); local before=x.state.GetSnapshot()
    check(not x.state.ReceiveLetter({letterId="missing"}).ok and U.Equal(before,x.state.GetSnapshot()),"unknown catch no quota cost")
    x.fault="write"; check(not x.state.ReceiveLetter({letterId="letter_pa_01"}).ok,"catch save failure"); x.fault=false
    check(x.state.GetSnapshot().live.gameFlow.salvageUsedToday==0,"failed catch no quota cost")
    must(x.state.ReceiveLetter({letterId="letter_pa_01"})); local writes=x.writes
    must(x.state.ReceiveLetter({letterId="letter_pa_01"}))
    check(writes==x.writes and x.state.GetSnapshot().live.gameFlow.salvageUsedToday==1,"duplicate catch before exhausted gate is noop")
    assert(x.Reload()); check(must(x.session.queries.GetSalvageView()).remaining==0,"daily quota survives restart")
    must(x.state.NextDay()); check(x.state.GetSnapshot().live.gameFlow.salvageUsedToday==0,"next day resets quota")
    local y=F.New(Data,{targetSchema=3}); must(y.state.NextDay())
    must(y.state.ReceiveLetter({letterId="letter_pa_01"}))
    check(not y.state.ReceiveLetter({letterId="letter_n01"}).ok,"second available letter blocked by daily limit")
    must(y.state.NextDay()); must(y.state.ReceiveLetter({letterId="letter_n01"}))
    check(y.state.GetSnapshot().live.gameFlow.salvageUsedToday==1,"next day admits one new catch")
    print("[Landscape] salvage counters: PASS")
end
function T.RunRepeatPolicy()
    -- 测试专用内容副本：同定义在两个真实 span 剪出两张卡，不改运行配置。
    local content=U.Copy(Data)
    function content.GetLetter(id) for _,d in ipairs(content.letters) do if d.id==id then return d end end end
    local letter=assert(content.GetLetter("letter_pa_01")); local wid="word_candidate_elias_sleep"
    letter.body=letter.body.."{{"..content.GetWord(wid).displayText.."}}"; letter.cutWordIds[#letter.cutWordIds+1]=wid
    content.stage1.recipePolicy.repeatWordDefinition=false
    local x=F.New(content,{targetSchema=3}); local lid=must(x.state.ReceiveLetter({letterId=letter.id})).letterInstanceId
    must(x.state.ReadLetter({letterInstanceId=lid})); local cards={}
    for _,span in ipairs(must(x.modules.letters.ParseDefinition(letter.id)).spans) do if span.wordId==wid then cards[#cards+1]=must(x.state.CutWord({letterInstanceId=lid,spanId=span.spanId})).tokenId end end
    local oid=must(x.order.Accept({letterInstanceId=lid})).orderId
    local draft={equipmentId=content.stage1.initialEquipmentId,mainTokenId=cards[1],auxTokenIds={cards[2]},ingredients={},specialItemIds={}}
    check(cards[1]~=cards[2],"same definition retains independent source cards")
    check(not x.order.UpdateDraft({orderId=oid,draft=draft}).ok,"repeat definition denied by config")
    content.stage1.recipePolicy.repeatWordDefinition=true
    must(x.order.UpdateDraft({orderId=oid,draft=draft}))
    check(x.state.GetSnapshot().live.wordTokens.byId[cards[1]].available and x.state.GetSnapshot().live.wordTokens.byId[cards[2]].available,"allowed duplicate definition selects without consuming")
    print("[Landscape] repeat definition source policy: PASS")
end
function T.RunSupplementAndAudit()
    local x=F.New(Data,{targetSchema=3})
    local id=must(x.state.ReceiveLetter({letterId="letter_pa_01"})).letterInstanceId
    must(x.state.ReadLetter({letterInstanceId=id}))
    local spans=must(x.modules.letters.ParseDefinition("letter_pa_01")).spans
    ---@type table|nil
    local mainSpan
    local others={}
    for _,span in ipairs(spans) do if span.wordId=="word_candidate_elias_sleep" then mainSpan=span else others[#others+1]=span end end
    assert(mainSpan,"registered main span required")
    local token=must(x.state.CutWord({letterInstanceId=id,spanId=mainSpan.spanId})).tokenId
    local writes=x.writes; must(x.state.CutWord({letterInstanceId=id,spanId=mainSpan.spanId}))
    check(writes==x.writes,"duplicate cut is persisted noop")
    local oid=must(x.order.Accept({letterInstanceId=id})).orderId
    local draft={equipmentId=Data.stage1.initialEquipmentId,mainTokenId=token,auxTokenIds={},ingredients={{ingredientId="ing_sea_salt",quantity=1}},specialItemIds={}}
    must(x.order.UpdateDraft({orderId=oid,draft=draft}))
    must(x.state.CutWord({letterInstanceId=id,spanId=others[1].spanId}))
    check(U.Equal(x.state.GetSnapshot().currentOrder.draft,draft),"supplement cut during selection preserves draft")
    local req=U.Copy(draft); req.orderId=oid
    must(x.order.Preview(req)); local order=x.state.GetSnapshot().currentOrder
    local before=x.state.GetSnapshot()
    local mutations={
        function(d) d.currentOrder.baseline.id="order:1:baseline:999" end,
        function(d) d.journal.attemptIds[2]=d.journal.attemptIds[1] end,
        function(d) d.journal.byAttemptId[d.journal.attemptIds[1]].rating.stars=99 end,
        function(d) d.journal.byAttemptId[d.journal.attemptIds[1]].originSchema=2 end,
        function(d) d.currentOrder.pending.candidateLive.gameFlow.salvageUsedToday=0 end,
        function(d) d.currentOrder.draft.unknown=true end,
        function(d) d.extra=true end,
    }
    for _,mutation in ipairs(mutations) do local bad=U.Copy(before); mutation(bad); check(not x.order.ValidateEnvelope(bad).ok,"forged v3 rejected") end
    must(x.order.Reset({orderId=oid,baselineId=order.baseline.id,transactionId=order.pending.transactionId}))
    local added=must(x.state.CutWord({letterInstanceId=id,spanId=others[2].spanId})).tokenId
    must(x.order.UpdateDraft({orderId=oid,draft=draft})); must(x.order.Preview(req))
    check(x.state.GetSnapshot().currentOrder.baseline.live.wordTokens.byId[added]~=nil,"next attempt uses newly cut inventory")
    local pending=x.state.GetSnapshot(); writes=x.writes
    local summary=must(x.session.queries.GetOrderSummary())
    check(summary.pending.candidateLive==nil and summary.pending.transactionId==pending.currentOrder.pending.transactionId,"query hides candidate ledger")
    must(x.session.queries.GetJournalPage("letter_pa_01")); must(x.session.queries.GetJournalStories())
    check(writes==x.writes and U.Equal(pending,x.state.GetSnapshot()),"pending history readonly")
    check(not x.session.queries.GetJournalPage("letter_n01").ok,"unreceived story hidden")
    print("[Landscape] supplementary cuts and hostile snapshots: PASS")
end
function T.Run()
    T.RunQueries(); T.RunFlow(); T.RunInputs(); T.RunSalvage(); T.RunRepeatPolicy(); T.RunSupplementAndAudit(); T.RunFaults()
    require("debug.SaveV3MigrationTest").Run()
    print("[Landscape] checks="..checks); return true
end
return T
