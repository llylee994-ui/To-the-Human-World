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
-- 2026-10-18追加词位后，旧词位必须原位保留，旧存档的body:N才能继续对得上。
---@type table<string, string[]|nil>
local oldSpans={
    letter_pa_01={"困","合上眼","帮忙","没好意思","神志不清","算","乐了","梦见","忘记"},
    letter_n01={"多问几句","客套话","怕","骂骂咧咧","记在心里","壮起胆子","漂亮话","火气","掏心掏肺"},
    letter_n02={"哭","高兴","怕","盘问","笑着"},
    letter_n03={"头一回","怕得要命","不服气","没关系"},
    letter_n04={"唱歌","老厨娘","甜极了","失落","比了比"},
    letter_n05={"姑母","落魄","肥烤鹅","算盘"},
    letter_n06={"粗糙","酸疼","稳","搓热乎"},
    letter_n07={"堵我的嘴","骨节发白","干笑","更没指望"},
    letter_n08={"轮休","笑","数落","定定心心","安安稳稳"},
    letter_n09={"寝食难安","对不上","底册","死规矩","旁证","暗火","核一遍"},
    letter_n10={"想起","痛骂","准话","汤","不敢"},
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
        elseif l.id=="letter_n02" then
            l.body=l.body:gsub("{{满满当当}}","满满当当",1)
        elseif l.id=="letter_n05" then
            l.body=l.body:gsub("{{账目}}","账目",1):gsub("{{一针一线}}","一针一线",1):gsub("{{新蜡烛}}","新蜡烛",1)
        elseif l.id=="letter_n06" then
            l.body=l.body:gsub("我这只手先{{稳}}了下来","我自己{{手底下先实了}}",1)
                :gsub("{{叠好}}","叠好",1):gsub("{{收进抽屉}}","收进抽屉",1)
        elseif l.id=="letter_n07" then
            l.body=l.body:gsub("{{盘了一遍}}","盘了一遍",1):gsub("{{轻悄悄}}","轻悄悄",1):gsub("{{整整齐齐}}","整整齐齐",1)
        elseif l.id=="letter_n09" then
            l.body=l.body:gsub("{{笑了笑}}","笑了笑",1):gsub("{{道理}}","道理",1):gsub("{{亮堂}}","亮堂",1)
        elseif l.id=="letter_n10" then
            l.body=l.body:gsub("{{浑浑噩噩}}","浑浑噩噩",1):gsub("{{天亮}}","天亮",1)
                :gsub("{{收拾好}}","收拾好",1):gsub("{{办完}}","办完",1)
        end
    end
    local added={
        word_candidate_n02_abundance=true,word_candidate_n05_reason=true,word_candidate_n05_steady=true,word_candidate_n05_warmth=true,
        word_candidate_n06_steady_alt=true,word_candidate_n06_safety=true,word_candidate_n07_recall=true,word_candidate_n07_relax=true,
        word_candidate_n07_steady=true,word_candidate_n09_happy=true,word_candidate_n09_reason=true,word_candidate_n09_warmth=true,
        word_candidate_n10_confusion=true,word_candidate_n10_safety=true,word_candidate_n10_brave=true,word_candidate_n10_steady=true,
    }
    for _,l in ipairs(c.letters) do
        if l.cutWordIds then
            local kept={}
            for _,id in ipairs(l.cutWordIds) do if not added[id] then kept[#kept+1]=id end end
            l.cutWordIds=kept
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
    ---@type table[]
    local letters=Data.letters
    for _,l in ipairs(letters) do if l.cuttable then
        local spans=must(parser.ParseDefinition(l.id)).spans
        for _,span in ipairs(spans) do
            assert(utf8.len(span.text)<=4,"可剪词仍超过4字："..span.text)
            count=count+1
            local rename=names[span.wordId]
            if rename then assert(span.text==rename.new and span.spanId==rename.span,"短词字面或旧来源位置不匹配") end
        end
        local expected=oldSpans[l.id]
        if expected then
            assert(#spans>=#expected,l.id.." 旧词位被删除")
            for i,text in ipairs(expected) do
                assert(spans[i].spanId=="body:"..i and spans[i].text==text,l.id.." 旧词位被移动："..tostring(i))
            end
        end
    end end
    assert(count==77)
    local cases={
        {letter="letter_n03",main="word_candidate_n03_k1",aux={"word_candidate_n03_e1"},ingredient="ing_night_dew"},
        {letter="letter_n04",main="word_candidate_n04_h1",aux={"word_candidate_n04_e1"},ingredient="ing_ashen_herb"},
        {letter="letter_n04",main="word_candidate_n04_h1",aux={"word_candidate_n04_r1","word_candidate_n04_s1"},ingredient="ing_ashen_herb"},
        {letter="letter_n06",main="word_candidate_n06_m1",aux={},ingredient="ing_night_dew"},
        {letter="letter_n02",main="word_candidate_n02_happy",aux={},ingredient="ing_ashen_herb"},
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
    print("[ShortWords] PASS 77 real cut spans <=4 chars; old span positions stable; four renamed sources unchanged; stable label; "..checked.." legacy pending/shipped/reset loads + new labels + strict forged-label rejection")
    return true
end
return T
