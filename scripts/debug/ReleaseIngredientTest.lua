-- 真实信源、配方求值与后果见证；只隔离 File/UI，不伪造药效或发放词卡。
local U=require "core.StateUtil"
local Data=require "data.content"
local F=require "debug.fixtures.B5Fixtures"
local Potion=require "systems.Potion"
local T={}
local SALT,DEW,HERB,PETAL="ing_sea_salt","ing_night_dew","ing_ashen_herb","ing_dried_petal"
local function must(r) assert(r.ok,cjson.encode(r.error));return r.value end
local function near(actual,want) assert(math.abs(actual-want)<1e-10,"weight "..actual.." expected "..want) end
local function prepare(index)
    local x=F.New(Data,{targetSchema=3});x.tokens={}
    for day=1,index do
        while x.state.GetSnapshot().live.gameFlow.day<day do must(x.state.NextDay()) end
        local id=Data.release.requiredOrderIds[day]
        local instance=must(x.state.ReceiveLetter({letterId=id})).letterInstanceId
        must(x.state.ReadLetter({letterInstanceId=instance}))
        for _,s in ipairs(must(x.modules.letters.ParseDefinition(id)).spans) do
            x.tokens[s.wordId]=must(x.state.CutWord({letterInstanceId=instance,spanId=s.spanId})).tokenId
        end
        if day==index then
            x.letterId=id
            x.orderId=must(x.order.Accept({letterInstanceId=instance})).orderId
        end
    end
    return x
end
local function calculate(x,mainId,auxIds,ingredientIds)
    local data=x.state.GetSnapshot()
    local aux={};for _,id in ipairs(auxIds) do aux[#aux+1]=assert(x.tokens[id],"unobtained "..id) end
    local counts,uses={},{}
    for _,id in ipairs(ingredientIds) do counts[id]=(counts[id] or 0)+1 end
    for id,n in pairs(counts) do uses[#uses+1]={ingredientId=id,quantity=n} end
    table.sort(uses,function(a,b)return a.ingredientId<b.ingredientId end)
    local baseId=x.orderId..":query"
    local request={orderId=x.orderId,baselineId=baseId,equipmentId=Data.stage1.initialEquipmentId,
        mainTokenId=assert(x.tokens[mainId]),auxTokenIds=aux,ingredients=uses,specialItemIds={}}
    local resolved=must(x.order.ResolveRecipe(request,{id=baseId,revision=data.revision,contentVersion=data.contentVersion,live=data.live}))
    local potion=must(Potion.Calculate(resolved,Data))
    local definition=Data.GetLetter(x.letterId)
    local gate=must(x.order.Evaluate(definition.requirement,potion))
    local facts,stars={ },false
    if gate.canShip then
        facts=must(x.modules.world.Simulate(data.live.world,potion,{letterId=x.letterId,orderId=x.orderId,day=data.live.gameFlow.day})).facts
        stars=must(x.order.Rate(facts,definition.ratingSetId)).stars
        assert(#facts==1,"one exclusive outcome")
    end
    local cost=0
    for _,row in ipairs(uses) do
        local item=assert(Data.GetIngredient(row.ingredientId)) --[[@as table]]
        cost=cost+item.price*row.quantity
    end
    return {potion=potion,canShip=gate.canShip,facts=facts,stars=stars,cost=cost,recipe=U.Copy(request)}
end
local function outcome(result) return result.facts[1] and result.facts[1].id or false end
function T.Run()
    local passed,failed=0,0
    local report={witnesses={},registrations={},combinationChecks=0}
    local prepared={}
    local function session(index) prepared[index]=prepared[index] or prepare(index);return prepared[index] end
    local function scenario(name,callback)
        local ok,err=pcall(callback)
        if ok then passed=passed+1 else failed=failed+1 end
        print("[ReleaseIngredients] "..(ok and "PASS " or "FAIL ")..name..(ok and "" or " "..tostring(err)))
    end
    scenario("actual main weights, additive modifiers and deterministic extra effect",function()
        local x=session(1);local main="word_candidate_elias_sleep_alt"
        near(calculate(x,main,{},{}).potion.effects.sleep,1)
        near(calculate(x,main,{},{SALT}).potion.effects.sleep,0.9)
        near(calculate(x,main,{},{SALT,SALT}).potion.effects.sleep,0.8)
        near(calculate(x,main,{},{DEW}).potion.effects.sleep,1.25)
        near(calculate(x,main,{},{DEW,DEW}).potion.effects.sleep,1.5)
        local herb=calculate(x,main,{},{HERB});near(herb.potion.effects.sleep,1.5);near(herb.potion.effects.dream,0.4)
        local petals=calculate(x,main,{},{PETAL});near(petals.potion.effects.calm,0.4)
        local mixed=calculate(x,main,{},{SALT,DEW});near(mixed.potion.effects.sleep,1.15)
        local herbPetal=calculate(x,main,{},{HERB,PETAL});near(herbPetal.potion.effects.calm,0.6);near(herbPetal.potion.effects.dream,0.4)
        assert(not herbPetal.potion.unstable and herbPetal.potion.onsetDelayHours==2)
        assert(not calculate(x,main,{},{SALT,SALT}).canShip,"v3不能把削弱后的不足药效发货")
    end)
    scenario("four ingredients each alter a real outcome using already obtained sources",function()
        local seeds={
            {name="海盐",index=7,main="word_candidate_n06_m1",aux={"word_candidate_n06_p1","word_candidate_n06_w1"},beforeIngredients={},ingredients={SALT},before="n06_candidate_pain",after="n06_candidate_good"},
            {name="夜露",index=9,main="word_candidate_n08_r1",aux={"word_candidate_n01_trust"},beforeIngredients={},ingredients={DEW},before=false,after="n08_candidate_good"},
            {name="灰烬草",index=1,main="word_candidate_elias_sleep",aux={},beforeIngredients={DEW},ingredients={DEW,HERB},before="e01_result_rested",after="e01_result_fragmented_dream"},
            {name="干花瓣",index=9,main="word_candidate_n08_r1",aux={"word_candidate_n03_k1"},beforeIngredients={},ingredients={PETAL,PETAL},before="n08_candidate_good",after="n08_candidate_slow"},
        }
        for _,seed in ipairs(seeds) do
            local x=session(seed.index);local before=calculate(x,seed.main,seed.aux,seed.beforeIngredients)
            local after=calculate(x,seed.main,seed.aux,seed.ingredients)
            assert(before.canShip==(seed.before~=false) and after.canShip)
            assert(outcome(before)==seed.before and outcome(after)==seed.after,seed.name.." outcome witness")
            report.witnesses[#report.witnesses+1]={name=seed.name,day=seed.index,sourceLetterId=x.letterId,
                before={effects=before.potion.effects,fact=outcome(before),stars=before.stars},
                after={effects=after.potion.effects,fact=outcome(after),stars=after.stars,cost=after.cost,recipe=after.recipe}}
        end
    end)
    scenario("58 registered outcomes and all 15 zero/one/two-slot combinations",function()
        local combinations={{}}
        local ids={SALT,DEW,HERB,PETAL}
        for _,id in ipairs(ids) do combinations[#combinations+1]={id} end
        for i=1,#ids do for j=i,#ids do combinations[#combinations+1]={ids[i],ids[j]} end end
        assert(#combinations==15)
        local index={};for i,id in ipairs(Data.release.requiredOrderIds) do index[id]=i end
        for _,case in ipairs(Data.recipes) do
            local x=session(index[case.letterId]);local recipe=case.recipe;local ingredients={}
            for _,row in ipairs(recipe.ingredients) do for _=1,row.quantity do ingredients[#ingredients+1]=row.ingredientId end end
            local registered=calculate(x,recipe.mainWordId,recipe.auxWordIds,ingredients)
            assert(registered.canShip and registered.stars==case.expect.stars and outcome(registered)==case.expect.facts[1],case.id)
            report.registrations[#report.registrations+1]={id=case.id,sourceLetterId=case.letterId,
                cost=registered.cost,stars=registered.stars,fact=outcome(registered),recipe=registered.recipe,effects=registered.potion.effects}
            for _,combo in ipairs(combinations) do
                local result=calculate(x,recipe.mainWordId,recipe.auxWordIds,combo)
                if result.canShip then assert(#result.facts==1 and result.stars>=1 and result.stars<=3) else assert(#result.facts==0 and result.stars==false) end
                report.combinationChecks=report.combinationChecks+1
            end
        end
        assert(#report.registrations==58 and report.combinationChecks==870)
    end)
    scenario("frontend describes modifiers and shows the actual selected potion without spending",function()
        require("ui.landscape.tests.ZoomTestHost").New()
        local x=session(1);local view=require("ui.PlayView").New(x.session,Data)
        local summary=must(x.session.queries.GetOrderSummary())
        assert(summary.orderId==x.orderId)
        local token=assert(x.tokens.word_candidate_elias_sleep_alt)
        must(view.model.Drop("word",token));must(view.model.Drop("ingredient",SALT))
        local snapshot=x.state.GetSnapshot();local writes=x.writes
        summary=must(x.session.queries.GetOrderSummary())
        near(summary.potionPreview.effects.sleep,0.9)
        view.Navigate("brew");view.Update()
        view.brew.selected=SALT;view.Refresh();view.Update()
        assert(view.root:FindById("brewIngredientDescription"):GetText():find("10%",1,true),"ingredient purpose must be visible on demand")
        view.brew.selected="recipe";view.Refresh();view.Update()
        view.root:FindById("brewToggleNumbers").props.onClick();view.Update()
        local effect=assert(view.root:FindById("brewEffectNumber_sleep"),"actual effect preview must be visible") --[[@as Label]]
        near(tonumber(effect:GetText()),0.9)
        view.Open("shop");view.Update()
        local desc=assert(view.root:FindById("shopItemDescription")):GetText()
        assert(desc:find("10%",1,true),"shop must explain actual attenuation")
        assert(U.Equal(snapshot,x.state.GetSnapshot()) and writes==x.writes,"query/render cannot consume or pay")
        must(view.model.Edit("clear"));view.root:Destroy()
    end)
    report.status=failed==0 and "passed" or "failed";report.passed=passed;report.failed=failed
    local publish=rawget(_G,"RELEASE_INGREDIENT_REPORT")
    if publish then publish(cjson.encode(report)) end
    print("[ReleaseIngredients] "..passed.." passed; "..failed.." failed; combos="..report.combinationChecks)
    return failed==0
end
return T
