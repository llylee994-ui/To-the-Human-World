-- 实际合成/订单/世界判定。这里的词引用只用于纯计算，不发卡或写玩家存档。
local Data=require "data.content"
local Potion=require "systems.Potion"
local Order=require "systems.Order"
local U=require "core.StateUtil"
local T={}
---@type table|nil
local world
---@type table|nil
local initial
local function must(r) assert(r.ok,cjson.encode(r.error));return r.value end
function T.Calculate(mainId,auxIds,ingredients,letterId)
    local function ref(id)
        return {tokenId="balance:"..id,definition=Data.GetWord(id),source={wordId=id,
            sourceLetterInstanceId="balance:source",sourceSpanId=id,sourceNpcId="balance:source"}}
    end
    local aux,uses={},{}
    for _,id in ipairs(auxIds) do aux[#aux+1]=ref(id) end
    for id,count in pairs(ingredients) do uses[#uses+1]={ingredientId=id,quantity=count,definition=Data.GetIngredient(id)} end
    local potion=must(Potion.Calculate({orderId="balance",baselineId="balance",contentVersion=Data.contentVersion,
        equipment=Data.GetEquipment("kit_old_cauldron"),main=ref(mainId),aux=aux,ingredients=uses,specialItems={}},Data))
    local letter=Data.GetLetter(letterId)
    local gate=must(Order.Evaluate(letter.requirement,potion))
    local primarySatisfied=true
    for id,minimum in pairs(letter.requirement.tags) do
        if (potion.effects[id] or 0)<minimum then primarySatisfied=false end
    end
    assert(gate.canShip==primarySatisfied,letterId.." 主药效门槛不得被副作用或时间条件改变")
    local result={canShip=gate.canShip,effects=potion.effects,failures=gate.failures}
    if gate.canShip then
        if not world then world=require("systems.WorldState").New(Data);initial=must(world.InitialSnapshot()) end
        local simulated=must(world.Simulate(initial,potion,{letterId=letterId,orderId="balance",day=letter.appearCondition.dayMin}))
        assert(#simulated.facts==1)
        result.fact=simulated.facts[1].id
        result.stars=must(Order.Rate(simulated.facts,letter.ratingSetId)).stars
    end
    return result
end
function T.VerifyEconomicRecipes(evidence)
    assert(evidence.status=="passed" and #evidence.routes==4,"economic evidence must contain four completed routes")
    local R=require "debug.fixtures.ReleaseFixtures"
    local x=R.New();local sourceByToken={}
    -- Public receive/read/cut operations recreate source identities, without issuing or duplicating cards.
    for day,id in ipairs(Data.release.requiredOrderIds) do
        while x.state.GetSnapshot().live.gameFlow.day<day do R.Must(x.state.NextDay()) end
        local instance=R.Must(x.state.ReceiveLetter({letterId=id})).letterInstanceId
        R.Must(x.state.ReadLetter({letterInstanceId=instance}))
        for _,span in ipairs(R.Must(x.modules.letters.ParseDefinition(id)).spans) do
            local token=R.Must(x.state.CutWord({letterInstanceId=instance,spanId=span.spanId})).tokenId
            sourceByToken[token]={wordId=span.wordId,day=day}
        end
    end
    local checked=0
    for _,route in ipairs(evidence.routes) do
        assert(#route.days==11)
        local consumed={}
        for _,row in ipairs(route.days) do
            local function use(id)
                local source=assert(sourceByToken[id],"unobtained economic source")
                assert(source.day<=row.day and not consumed[id],"future or reused economic source")
                consumed[id]=true;return source.wordId
            end
            local q=row.recipe;local main=use(q.mainTokenId);local aux,ingredients={},{}
            for _,id in ipairs(q.auxTokenIds) do aux[#aux+1]=use(id) end
            for _,i in ipairs(q.ingredients) do ingredients[i.ingredientId]=i.quantity end
            local actual=T.Calculate(main,aux,ingredients,row.sourceLetterId)
            assert(actual.canShip and actual.stars==row.stars and actual.fact==row.fact,"final rules differ from economic route "..route.kind.." "..row.day)
            checked=checked+1
        end
    end
    return checked
end
function T.VerifyPrimaryOnlyGate()
    local R=require "debug.fixtures.ReleaseFixtures"
    local Model=require "ui.PlayModel"
    local cases={
        {name="主药效达标且带恐惧",main="word_candidate_elias_sleep",aux={"word_candidate_elias_fear"},ingredients={"ing_night_dew"},ready=true},
        {name="主药效达标且带混乱",main="word_candidate_elias_sleep",aux={"word_candidate_e01_c1"},ingredients={"ing_night_dew"},ready=true},
        {name="困加梦见加夜露",main="word_candidate_elias_sleep_alt",aux={"word_candidate_elias_dream"},ingredients={"ing_night_dew"},ready=true,fact="e01_result_mother_dream"},
        {name="困加合上眼加灰烬草",main="word_candidate_elias_sleep_alt",aux={"word_candidate_elias_sleep"},ingredients={"ing_ashen_herb"},ready=true,fact="e01_result_fragmented_dream"},
        {name="主药效达标但主词时间档不同",main="word_candidate_e01_c1",aux={"word_candidate_elias_sleep"},ingredients={"ing_ashen_herb"},ready=true},
        {name="合上眼加干花瓣仍缺睡眠药力",main="word_candidate_elias_sleep",aux={},ingredients={"ing_dried_petal"},ready=false},
        {name="仅有睡眠主词仍缺药力",main="word_candidate_elias_sleep",aux={},ingredients={},ready=false},
    }
    for _,case in ipairs(cases) do
        local x=R.New();R.Accept(x,1)
        local model=Model.New(x.session,x.content)
        must(model.Edit("clear"));must(model.Drop("word",x.tokens[case.main]))
        for _,id in ipairs(case.aux) do must(model.Drop("word",x.tokens[id])) end
        for _,id in ipairs(case.ingredients) do must(model.Drop("ingredient",id)) end
        local summary=must(x.session.queries.GetOrderSummary())
        assert(summary.requirementHint.canShip==case.ready,case.name.."：主药效达标就应允许熬制，不能被副作用或时长拦截")
        local note=require("ui.landscape.PotionNotes").Project(summary,Data.effects,model.GetDraft())
        assert(note.ready==case.ready and (#note.gaps==0)==case.ready,case.name.." 手札与门槛不一致")
        local before=x.state.GetSnapshot().live
        local p=must(model.Preview())
        local current=x.state.GetSnapshot().currentOrder
        assert((p.phase=="pending")==case.ready and U.Equal(before,x.state.GetSnapshot().live),case.name.." 试做状态或资源错误")
        if case.ready then
            local pending=assert(current.pending)
            assert(#pending.facts==1 and #pending.followup.fragmentIds==1,case.name.." 必须生成唯一后续")
            if case.fact then assert(pending.facts[1].id==case.fact,case.name.." 后续错误") end
            local loaded,status=x.Reload();assert(loaded,cjson.encode(status))
            assert(U.Equal(x.state.GetSnapshot().currentOrder.pending,pending),"副作用试做重读不能变化")
            model=Model.New(x.session,x.content)
            must(model.Resolve(true))
            assert(x.state.GetSnapshot().live.economy.currency==before.economy.currency+100,"应能确认发货并结算")
            assert(x.Reload(),"副作用发货后应能重读")
        else assert(not current.pending,"主药效不足不能产生后续") end
        print("[PrimaryGate] PASS "..case.name)
    end
    return #cases
end
function T.VerifyExistingV3Records()
    local R=require "debug.fixtures.ReleaseFixtures"
    for _,confirmed in ipairs({false,true}) do
        local x=R.New();x.content.release.primaryEffectsOnly=false
        local q=R.Accept(x,1);local p=R.Preview(x,q)
        assert(#x.state.GetSnapshot().currentOrder.pending.requirementResult.checks>1,"兼容回归必须确实带有旧版额外检查")
        if confirmed then must(x.order.Confirm({orderId=q.orderId,transactionId=p.transactionId})) end
        local before=x.state.GetSnapshot();local writes=x.writes
        x.content.release.primaryEffectsOnly=true
        local loaded,status=x.Reload();assert(loaded,cjson.encode(status))
        assert(U.Equal(before,x.state.GetSnapshot()) and x.writes==writes,"旧v3试做/发货记录应原样重读，不重置进度或写档")
        if not confirmed then must(x.order.Confirm({orderId=q.orderId,transactionId=p.transactionId})) end
        assert(x.Reload(),"旧检查记录在新规则确认后应可再次重读")
    end
    print("[PrimaryGate] PASS existing v3 pending and shipped records remain readable without rewriting")
end
function T.Run()
    local primaryCases=T.VerifyPrimaryOnlyGate()
    T.VerifyExistingV3Records()
    local available,seen={},{}
    local report={status="running",orders={},fixedCombos={},scope="all words obtainable by each order, assumed unconsumed; optimistic upper bound for fixed no-aux material strategies"}
    local combos={{}}
    for _,i in ipairs(Data.ingredients) do combos[#combos+1]={[i.id]=1} end
    for a=1,#Data.ingredients do for b=a,#Data.ingredients do
        local c={};local x,y=Data.ingredients[a].id,Data.ingredients[b].id
        c[x]=(c[x] or 0)+1;c[y]=(c[y] or 0)+1;combos[#combos+1]=c
    end end
    local bare=0
    for _,id in ipairs(Data.release.requiredOrderIds) do
        local letter=Data.GetLetter(id)
        for _,wid in ipairs(letter.cutWordIds) do if not seen[wid] then available[#available+1]=wid;seen[wid]=true end end
        local row={letterId=id,bareThreeStars={},availableWordCount=#available,comboThreeStars={}}
        for n,combo in ipairs(combos) do
            local found=false
            for _,wid in ipairs(available) do
                local result=T.Calculate(wid,{},combo,id)
                if result.canShip and result.stars==3 then
                    found=true
                    if n==1 then row.bareThreeStars[#row.bareThreeStars+1]=wid;bare=bare+1 end
                end
            end
            if found then report.fixedCombos[n]=(report.fixedCombos[n] or 0)+1 end
            row.comboThreeStars[n]=found
        end
        report.orders[#report.orders+1]=row
    end
    local publish=rawget(_G,"BALANCE_REPORT");if publish then publish(cjson.encode(report)) end
    assert(bare==0,"裸主词仍能三星："..bare.." 个可达订单/词组合")
    for n,count in pairs(report.fixedCombos) do assert(count<11,"同一原料套路覆盖全部11单："..n) end
    local checked=0
    for _,case in ipairs(Data.recipes) do
        local ingredients={};for _,i in ipairs(case.recipe.ingredients) do ingredients[i.ingredientId]=i.quantity end
        local r=T.Calculate(case.recipe.mainWordId,case.recipe.auxWordIds,ingredients,case.letterId)
        assert(r.canShip and r.fact==case.expect.facts[1] and r.stars==case.expect.stars,case.id.." 登记分支不可达")
        checked=checked+1
    end
    assert(checked==58)
    assert(T.Calculate("word_candidate_n06_m1",{"word_candidate_n06_w1","word_candidate_e01_c1"},{},"letter_n06").canShip,"主药效合格的混乱配方应可熬制")
    assert(T.Calculate("word_candidate_n09_q1",{"word_candidate_n04_r1","word_candidate_elias_forget"},{},"letter_n09").canShip,"主药效合格的遗忘配方应可熬制")
    assert(T.Calculate("word_candidate_n10_recall",{"word_candidate_elias_reason","word_candidate_elias_forget"},{},"letter_n10").canShip,"承诺单也不能把遗忘设为熬制禁令")
    -- Different word/material strategies, hand-selected independently of generated registrations.
    local alternatives={
        {"letter_pa_01","word_candidate_elias_sleep",{"word_candidate_elias_dream"},{}},
        {"letter_n01","word_candidate_n01_brave",{"word_candidate_n01_curiosity"},{ing_night_dew=1}},
        {"letter_n02","word_candidate_n02_happy",{"word_candidate_n02_h2"},{ing_sea_salt=2}},
        {"letter_n03","word_candidate_n03_k1",{"word_candidate_n01_trust"},{}},
        {"letter_n04","word_candidate_n04_h1",{"word_candidate_n04_h2"},{ing_sea_salt=2}},
        {"letter_n05","word_candidate_n05_a1",{"word_candidate_elias_happy"},{}},
        {"letter_n06","word_candidate_n06_m1",{"word_candidate_n06_w1"},{}},
        {"letter_n07","word_candidate_n07_a1",{"word_candidate_elias_reason"},{}},
        {"letter_n08","word_candidate_n08_r1",{"word_candidate_n03_k1"},{}},
        {"letter_n09","word_candidate_n01_recall",{"word_candidate_n09_q1"},{}},
        {"letter_n10","word_candidate_n01_curiosity",{"word_candidate_n10_recall"},{ing_night_dew=1}},
    }
    for _,a in ipairs(alternatives) do
        local r=T.Calculate(a[2],a[3],a[4],a[1]);assert(r.canShip and r.stars==3,"alternative "..a[1])
    end
    local R=require "debug.fixtures.ReleaseFixtures"
    local x=R.New();local q=R.Accept(x,1);q.ingredients={}
    R.Must(x.order.UpdateDraft({orderId=q.orderId,draft=require("systems.RecipeDraft").Project(q)}))
    local before=x.state.GetSnapshot()
    local summary=R.Must(x.session.queries.GetOrderSummary())
    assert(summary.requirementHint.evaluated and not summary.requirementHint.canShip and #summary.requirementHint.failures>0)
    local preview=R.Must(x.order.Preview(q))
    assert(preview.phase=="accepted" and not preview.requirementResult.canShip)
    assert(not x.state.GetSnapshot().currentOrder.pending and U.Equal(before.live,x.state.GetSnapshot().live),"insufficient brew cannot spend, award or invent a followup")
    local note=require("ui.landscape.PotionNotes").Project(summary,Data.effects,{mainTokenId=q.mainTokenId})
    assert(note.gaps and #note.gaps>0 and note.gaps[1]:find("睡眠",1,true),"player must see which necessary effect is missing")
    require("ui.landscape.tests.ZoomTestHost").New()
    local view=require("ui.PlayView").New(x.session,x.content)
    view.Navigate("brew");view.Update()
    local beforeNotes,writes=x.state.GetSnapshot(),x.writes
    view.root:FindById("brewRecipeDetails").props.onClick();view.Update()
    assert(view.root:FindById("brewRequirementGap_1"):GetText()==note.gaps[1],"real notes render missing effect")
    view.root:FindById("brewToggleNumbers").props.onClick();view.Update()
    assert(view.root:FindById("brewRequirementGap_1"):GetText():find("1.15",1,true),"numeric view exposes actual threshold")
    assert(U.Equal(beforeNotes,x.state.GetSnapshot()) and writes==x.writes,"browsing requirements cannot write")
    view.root:Destroy()
    report.status="passed";report.registrationsChecked=checked;report.alternativesChecked=#alternatives
    report.blockedPreviewPreservesResources=true;report.requirementNotesRendered=true;report.primaryGateCases=primaryCases
    local economic=rawget(_G,"BALANCE_ECONOMY_JSON")
    if economic then report.economicRecipesRechecked=T.VerifyEconomicRecipes(cjson.decode(economic));assert(report.economicRecipesRechecked==44) end
    if publish then publish(cjson.encode(report)) end
    print("[Balance] PASS no bare-main 3-star route, no fixed ingredient route across 11 orders, all 58 original outcomes reachable")
    print("[Balance] PASS 11 independent alternative recipes + actual frontend requirement query + rejected brew leaves resources unchanged")
    return true
end
return T
