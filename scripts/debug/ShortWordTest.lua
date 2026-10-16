-- 真实剪词、卡片展示与旧字面存档；文件介质由content_test_runtime隔离。
local U=require "core.StateUtil"
local Data=require "data.content"
local F=require "debug.fixtures.B5Fixtures"
local R=require "debug.fixtures.ReleaseFixtures"
local T={}
local names={
    word_candidate_n03_e1={old="比我还要快",new="不服气",letter="letter_n03",span="body:3"},
    word_candidate_n04_e1={old="偷偷比了比",new="比了比",letter="letter_n04",span="body:5"},
    word_candidate_n04_s1={old="没见她回来",new="失落",letter="letter_n04",span="body:4"},
    word_candidate_n06_m1={old="手底下先实了",new="稳",letter="letter_n06",span="body:3"},
}
local function must(r) assert(r.ok,cjson.encode(r.error));return r.value end
local function oldContent()
    local c=U.Copy(Data)
    for _,w in ipairs(c.words) do if names[w.id] then w.displayText=names[w.id].old end end
    for _,l in ipairs(c.letters) do
        if l.id=="letter_n03" then
            l.body=l.body:gsub("我心里有点{{不服气}}。",""):gsub("她数数比我还要快","她数数{{比我还要快}}",1)
        elseif l.id=="letter_n04" then
            l.body=l.body:gsub("想到这儿，我心里就有点{{失落}}。","")
                :gsub("也没见她回来","也{{没见她回来}}",1):gsub("偷偷{{比了比}}","{{偷偷比了比}}",1)
        elseif l.id=="letter_n06" then
            l.body=l.body:gsub("我这只手先{{稳}}了下来","我自己{{手底下先实了}}",1)
        end
    end
    local function find(list,id) for _,row in ipairs(list) do if row.id==id then return row end end end
    c.GetWord=function(id) return find(c.words,id) end
    c.GetLetter=function(id) return find(c.letters,id) end
    return c
end
local function legacyTrial(c,case,status)
    local x=F.New(c,{targetSchema=4})
    local day=c.GetLetter(case.letter).appearCondition.dayMin
    if day>1 then R.LegacyDay(x,day) end -- 复现旧版可跨日、未发货的合法历史档。
    local instance=must(x.state.ReceiveLetter({letterId=case.letter})).letterInstanceId
    must(x.state.ReadLetter({letterInstanceId=instance}))
    local tokens={}
    for _,span in ipairs(must(x.modules.letters.ParseDefinition(case.letter)).spans) do
        tokens[span.wordId]=must(x.state.CutWord({letterInstanceId=instance,spanId=span.spanId})).tokenId
    end
    local oid=must(x.order.Accept({letterInstanceId=instance})).orderId
    local aux={};for _,id in ipairs(case.aux) do aux[#aux+1]=assert(tokens[id]) end
    local q={orderId=oid,equipmentId="kit_old_cauldron",mainTokenId=assert(tokens[case.main]),auxTokenIds=aux,
        ingredients={{ingredientId=case.ingredient,quantity=1}},specialItemIds={}}
    must(x.order.UpdateDraft({orderId=oid,draft=require("systems.RecipeDraft").Project(q)}))
    local p=must(x.order.Preview(q));assert(p.phase=="pending")
    if status=="shipped" then must(x.order.Confirm({orderId=oid,transactionId=p.transactionId}))
    elseif status=="reset" then must(x.order.Reset({orderId=oid,transactionId=p.transactionId,baselineId=x.state.GetSnapshot().currentOrder.baseline.id})) end
    return x
end
function T.Run()
    assert(Data.Load())
    assert(Data.GetEffect("steady").name=="稳定","稳定属性显示名尚未接入")
    local parser=require("systems.Letter").New(Data)
    local count=0
    for _,l in ipairs(Data.letters) do if l.cuttable then
        for _,span in ipairs(must(parser.ParseDefinition(l.id)).spans) do
            assert(utf8.len(span.text)<=4,"可剪词仍超过4字："..span.text)
            count=count+1
            local rename=names[span.wordId]
            if rename then assert(span.text==rename.new and span.spanId==rename.span,"短词字面或旧来源位置不匹配") end
        end
    end end
    assert(count==61)
    local cases={
        {letter="letter_n03",main="word_candidate_n03_k1",aux={"word_candidate_n03_e1"},ingredient="ing_night_dew"},
        {letter="letter_n04",main="word_candidate_n04_h1",aux={"word_candidate_n04_e1"},ingredient="ing_ashen_herb"},
        {letter="letter_n04",main="word_candidate_n04_h1",aux={"word_candidate_n04_r1","word_candidate_n04_s1"},ingredient="ing_ashen_herb"},
        {letter="letter_n06",main="word_candidate_n06_m1",aux={},ingredient="ing_night_dew"},
    }
    local checked=0
    for _,case in ipairs(cases) do for _,status in ipairs({"pending","shipped","reset"}) do
        local x=legacyTrial(oldContent(),case,status)
        local before=x.state.GetSnapshot();local files=U.Copy(x.files)
        local session=require("core.GameSession").New(Data,{saveSystem=x.save,eventBus=x.bus,targetSchema=4})
        local loaded,info=session.state.Load("b5_flow")
        assert(loaded,"旧字面"..status.."记录无法读取："..cjson.encode(info))
        local after=session.state.GetSnapshot()
        assert(U.Equal(files,x.files),"读取旧词名不得覆写原档")
        for _,key in ipairs({"wordTokens","economy","gameFlow","world"}) do
            assert(U.Equal(before.live[key],after.live[key]),"词名修订不得改变资源或世界结果："..key)
        end
        for _,a in pairs(after.journal.byAttemptId) do
            local old=before.journal.byAttemptId[a.transactionId]
            assert(U.Equal(a.followup,old.followup) and U.Equal(a.rating,old.rating),"旧回信与评分必须保持")
            local cards={a.recipeDisplay.main,table.unpack(a.recipeDisplay.aux)}
            for _,card in ipairs(cards) do if names[card.wordId] then assert(card.text==names[card.wordId].new,"历史用料仍显示旧长词") end end
        end
        for _,card in ipairs(must(session.queries.GetWordTray()).cards) do
            if names[card.wordId] then assert(card.text==names[card.wordId].new,"词卡托盘仍显示旧长词") end
        end
        if status=="pending" then
            local order=after.currentOrder
            must(session.order.Confirm({orderId=order.orderId,transactionId=order.pending.transactionId}))
            assert(session.state.ReloadCurrent(),"旧试做确认后不能重读")
            local bad=U.Copy(before);bad.currentOrder.pending.potion.trace[1].inputs.main.definition.displayText="伪造词"
            assert(x.save.Save("short_bad",bad,4))
            local forged=require("core.GameSession").New(Data,{saveSystem=x.save,eventBus=x.bus,targetSchema=4})
            assert(not forged.state.Load("short_bad"),"兼容处理不得放过未知词名")
            bad=U.Copy(before)
            local effects=bad.currentOrder.pending.potion.trace[1].inputs.main.definition.effects
            local effect=next(effects);effects[effect]=effects[effect]+.125
            assert(x.save.Save("short_bad_weight",bad,4))
            forged=require("core.GameSession").New(Data,{saveSystem=x.save,eventBus=x.bus,targetSchema=4})
            assert(not forged.state.Load("short_bad_weight"),"旧字面兼容不得放过药效篡改")
        end
        checked=checked+1
    end end
    print("[ShortWords] PASS 61 real cut spans <=4 chars; four renamed sources unchanged; stable label; "..checked.." legacy pending/shipped/reset loads + new labels + strict forged-label rejection")
    return true
end
return T
