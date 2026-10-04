-- 正式内容回归：真实 GameSession/业务模块；只替换文件介质，不赠词或补库存。
local U=require "core.StateUtil"
local F=require "debug.fixtures.B5Fixtures"
local C=require "debug.fixtures.B4Fixtures"
local Data=require "data.content"
local T={}
local W=require "debug.fixtures.SingleUseFixtures"

function T.Run(options)
    options=options or {singleUseCopy=rawget(_G,"STORY_SINGLE_USE_COPY")==true}
    local function makeContent() return options.singleUseCopy and W.Content() or C.Content() end
    local function new() return F.New(makeContent()) end
    print("[Story] mode=" .. (options.singleUseCopy and "TECHNICAL ALL SINGLE USE COPY" or "FORMAL CONTENT"))
    local total,failed=0,0
    local caseId,step="startup","content"
    local function display(value) return cjson.encode(value) end
    local function check(name,actual,expected)
        total=total+1
        if not U.Equal(actual,expected) then
            failed=failed+1
            print("[Story] FAIL " .. caseId .. " step=" .. step .. " " .. name
                .. " actual=" .. display(actual) .. " expected=" .. display(expected))
        end
    end
    local function must(result,label)
        step=label
        if not result.ok then error(result.error,0) end
        return result.value
    end
    local function run(id,fn)
        caseId,step=id,"setup"
        local before=failed
        local ok,err=pcall(fn)
        if not ok then
            failed=failed+1
            print("[Story] FAIL " .. id .. " step=" .. step .. " " .. display(err))
        end
        local passed=failed==before
        print("[Story] " .. (passed and "PASS " or "FAILED ") .. id)
        return passed
    end
    local function advance(x,day)
        while x.state.GetSnapshot().live.gameFlow.day<day do must(x.state.NextDay(),"NextDay") end
    end
    local function receive(x,id)
        local instance=must(x.state.ReceiveLetter({letterId=id}),"ReceiveLetter " .. id).letterInstanceId
        must(x.state.ReadLetter({letterInstanceId=instance}),"ReadLetter " .. id)
        x.tokensByWord=x.tokensByWord or {}; x.instances=x.instances or {}; x.instances[id]=instance
        for _,span in ipairs(must(x.modules.letters.ParseDefinition(id),"ParseDefinition").spans) do
            local list=x.tokensByWord[span.wordId] or {}; x.tokensByWord[span.wordId]=list
            list[#list+1]=must(x.state.CutWord({letterInstanceId=instance,spanId=span.spanId}),"CutWord " .. span.spanId).tokenId
        end
    end
    local function prepareSources(x)
        -- 先按真实出现日收取当前全部订单，均在建立本单基准前剪取。
        local definitions={}
        for _,letter in ipairs(x.content.letters) do
            if letter.kind=="order" then definitions[#definitions+1]=letter end
        end
        table.sort(definitions,function(a,b)
            local ad,bd=a.appearCondition.dayMin or 1,b.appearCondition.dayMin or 1
            if ad~=bd then return ad<bd end
            return a.id<b.id
        end)
        for _,letter in ipairs(definitions) do advance(x,letter.appearCondition.dayMin or 1); receive(x,letter.id) end
    end
    local function coverage(content,pending,expected)
        local facts,covered,seen={},{},{}
        for _,fact in ipairs(pending.facts) do
            check("unique fact " .. fact.id,seen[fact.id]==nil,true)
            seen[fact.id]=true; facts[fact.id]=true
            check("fact source " .. fact.id,U.String(fact.sourceRuleId),true)
        end
        for _,id in ipairs(expected.facts) do check("required fact " .. id,facts[id]==true,true) end
        for _,id in ipairs(pending.followup.fragmentIds) do
            for _,factId in ipairs(C.ById(content.fragments,id).coversFacts) do covered[factId]=true end
        end
        for _,fact in ipairs(pending.facts) do
            if fact.important then check("important fact covered " .. fact.id,covered[fact.id]==true,true) end
        end
        check("nonempty followup",U.String(pending.followup.renderedText),true)
        check("no placeholders",pending.followup.renderedText:find("{{",1,true)==nil,true)
        check("feedback",U.String(pending.rating.feedback),true)
        check("stars",pending.rating.stars,expected.stars)
        check("durationHours",pending.potion.durationHours,expected.durationHours)
        check("onsetDelayHours",pending.potion.onsetDelayHours,expected.onsetDelayHours)
        check("canShip",pending.requirementResult.canShip,expected.canDeliver)
        print("[Story] RESULT " .. caseId .. " stars=" .. pending.rating.stars .. " facts=" .. display(C.Ids(pending.facts)))
    end
    local function attempt(x,letterId,recipe,expected)
        local orderId=must(x.order.Accept({letterInstanceId=x.instances[letterId]}),"Accept").orderId
        local baselineId=must(x.order.BeginBrew({orderId=orderId}),"BeginBrew").baselineId
        local aux={}
        for _,id in ipairs(recipe.auxWordIds) do aux[#aux+1]=W.Select(x,id) end
        local request={orderId=orderId,baselineId=baselineId,equipmentId=recipe.equipmentId,
            mainTokenId=W.Select(x,recipe.mainWordId),auxTokenIds=aux,
            ingredients=U.Copy(recipe.ingredients),specialItemIds=U.Copy(recipe.specialItemIds)}
        local baseline=x.state.GetSnapshot()
        local first=must(x.order.Preview(request),"Preview")
        check("pending phase",first.phase,"pending")
        local saved=x.state.GetSnapshot()
        check("preview keeps formal state",saved.live,baseline.live)
        W.CheckConsumption(check,x.content,baseline.live.wordTokens,saved.currentOrder.pending.candidateLive.wordTokens,
            request,saved.currentOrder.pending.consumption.consumedTokenIds)
        coverage(x.content,saved.currentOrder.pending,expected)
        step="pending reload"
        local loaded,status=x.Reload(); check("pending load",loaded~=nil,true)
        if not loaded then error(status,0) end
        check("pending unchanged",x.state.GetSnapshot(),saved)
        must(x.order.Reset({orderId=orderId,baselineId=baselineId,transactionId=first.transactionId}),"Reset")
        check("reset formal baseline",x.state.GetSnapshot().live,baseline.live)
        local second=must(x.order.Preview(request),"Preview after reset")
        check("new transaction",second.transactionId~=first.transactionId,true)
        local pending=x.state.GetSnapshot().currentOrder.pending
        for _,key in ipairs({"potion","facts","worldChanges","followup","rating","consumption","reward"}) do
            check("same baseline deterministic " .. key,pending[key],saved.currentOrder.pending[key])
        end
        local beforeStale=x.state.GetSnapshot()
        check("stale confirm rejected",x.order.Confirm({orderId=orderId,transactionId=first.transactionId}).ok,false)
        check("stale confirm unchanged",x.state.GetSnapshot(),beforeStale)
        local confirmed=must(x.order.Confirm({orderId=orderId,transactionId=second.transactionId}),"Confirm")
        local committed=x.state.GetSnapshot()
        check("complete candidate installed",committed.live,pending.candidateLive)
        W.CheckConsumption(check,x.content,baseline.live.wordTokens,committed.live.wordTokens,request,pending.consumption.consumedTokenIds)
        check("currency once",committed.live.economy.currency,baseline.live.economy.currency+pending.reward.currency)
        check("delivery count once",committed.live.gameFlow.deliveredOrders,baseline.live.gameFlow.deliveredOrders+1)
        for _,entry in ipairs(recipe.ingredients) do
            check("ingredient once " .. entry.ingredientId,committed.live.economy.ingredients[entry.ingredientId],
                baseline.live.economy.ingredients[entry.ingredientId]-entry.quantity)
        end
        check("confirmed rating",confirmed.record.rating,pending.rating)
        local writes,events=x.writes,#x.events
        check("repeat confirm",must(x.order.Confirm({orderId=orderId,transactionId=second.transactionId}),"repeat Confirm").alreadyConfirmed,true)
        check("repeat no writes/events",{x.writes,#x.events},{writes,events})
        step="confirmed reload"
        loaded,status=x.Reload(); check("confirmed load",loaded~=nil,true)
        if not loaded then error(status,0) end
        check("confirmed unchanged",x.state.GetSnapshot(),committed)
        writes,events=x.writes,#x.events
        check("repeat after reload",must(x.order.Confirm({orderId=orderId,transactionId=second.transactionId}),"Confirm after reload").alreadyConfirmed,true)
        check("reload repeat no writes/events",{x.writes,#x.events},{writes,events})
        check("reload repeat keeps all state",x.state.GetSnapshot(),committed)
    end
    local function futureCalculation(ref)
        -- 仅纯计算技术引用，不进入 GameSession、不写词库/账本，不声称这些来源已存在。
        local content=makeContent()
        local function word(id)
            return {tokenId="technical:" .. id,definition=U.Copy(C.ById(content.words,id)),
                source={wordId=id,sourceLetterInstanceId="technical:future",sourceSpanId="technical:" .. id,sourceNpcId="technical:future"}}
        end
        local r=ref.recipe
        local resolved={orderId="technical:future",baselineId="technical:future",contentVersion=content.contentVersion,
            equipment=U.Copy(C.ById(content.equipment,r.equipmentId)),main=word(r.mainWordId),aux={},ingredients={},specialItems={}}
        for _,id in ipairs(r.auxWordIds) do resolved.aux[#resolved.aux+1]=word(id) end
        for _,entry in ipairs(r.ingredients) do
            resolved.ingredients[#resolved.ingredients+1]={ingredientId=entry.ingredientId,quantity=entry.quantity,definition=U.Copy(C.ById(content.ingredients,entry.ingredientId))}
        end
        check("no unsupported special items",r.specialItemIds,{})
        local potion=must(require("systems.Potion").Calculate(resolved,content),"future Potion.Calculate")
        local letter=C.ById(content.letters,ref.letterId)
        local order=require("systems.Order").New(content)
        local evaluation=must(order.Evaluate(letter.requirement,potion),"future Evaluate")
        local world=require("systems.WorldState").New(content)
        local context={letterId=letter.id,orderId=resolved.orderId,day=letter.appearCondition.dayMin or 1}
        local simulated=must(world.Simulate(must(world.InitialSnapshot(),"initial world"),potion,context),"future Simulate")
        context.world=simulated.world; context.potion=potion
        coverage(content,{potion=potion,requirementResult=evaluation,facts=simulated.facts,
            followup=must(require("systems.Narrative").New(content).ResolveDirect(simulated.facts,context),"future ResolveDirect"),
            rating=must(order.Rate(simulated.facts,letter.ratingSetId),"future Rate")},ref.expect)
    end

    local sourceWords={}
    local sourceLetters=require("systems.Letter").New(Data)
    for _,letter in ipairs(Data.letters) do
        if letter.kind=="order" and letter.cuttable then
            for _,span in ipairs(must(sourceLetters.ParseDefinition(letter.id),"source coverage").spans) do sourceWords[span.wordId]=true end
        end
    end
    local function checkSourceStatus(ref)
        local missing=not sourceWords[ref.recipe.mainWordId]
        for _,id in ipairs(ref.recipe.auxWordIds) do if not sourceWords[id] then missing=true end end
        check("future-source declaration matches actual letters",ref.requiresFutureSources,missing)
    end
    local reachablePassed,reachableTotal,futurePassed,futureTotal=0,0,0,0
    for _,ref in ipairs(Data.recipes) do
        if ref.requiresFutureSources then
            futureTotal=futureTotal+1
            if run(ref.id .. " [FUTURE PURE ONLY]",function() checkSourceStatus(ref); futureCalculation(ref) end) then futurePassed=futurePassed+1 end
        else
            reachableTotal=reachableTotal+1
            if run(ref.id,function()
                checkSourceStatus(ref)
                local x=new(); prepareSources(x); attempt(x,ref.letterId,ref.recipe,ref.expect)
            end) then reachablePassed=reachablePassed+1 end
        end
    end
    run("reference coverage counts",function()
        check("current sources",reachableTotal,16); check("future pure calculations",futureTotal,9)
    end)
    local matrixPassed,matrixTotal=0,0
    for _,recall in ipairs({0,0.59,0.6}) do
        for _,forget in ipairs({0,0.59,0.6}) do
            matrixTotal=matrixTotal+1
            if run("N01 calm=2.2 recall=" .. recall .. " forget=" .. forget .. " [FACT MATRIX ONLY]",function()
                local ref=C.ById(Data.recipes,"recipe_n01_a")
                -- 技术词定义副本只用于构造自洽的 PotionResult；不注入玩家词库，不声称旧锅可达。
                local content=makeContent()
                local effects={steady=0.8,calm=2.2}
                if recall>0 then effects.recall=recall end
                if forget>0 then effects.forget=forget end
                C.ById(content.words,ref.recipe.mainWordId).effects=effects
                local fixture=C.Setup(content)
                local resolved=must(fixture.order.ResolveRecipe(fixture.Request(ref.recipe),fixture.baseline),"matrix technical recipe")
                local potion=must(require("systems.Potion").Calculate(resolved,content),"matrix Potion.Calculate")
                check("matrix requested effects",potion.effects,effects)
                local result=must(fixture.world.Simulate(fixture.initialWorld,potion,
                    {letterId=ref.letterId,orderId="technical:matrix",day=4}),"matrix WorldState.Simulate")
                local counts={}
                for _,fact in ipairs(result.facts) do counts[fact.id]=(counts[fact.id] or 0)+1 end
                local conflict=recall>=0.6 and forget>=0.6
                check("action_dulled exactly once unless conflict",counts.n01_action_dulled or 0,conflict and 0 or 1)
                check("memory_contested only both",counts.n01_memory_contested or 0,conflict and 1 or 0)
            end) then matrixPassed=matrixPassed+1 end
        end
    end
    run("continuous three orders initial stock",function()
        local x=new(); receive(x,"letter_pa_01")
        local first=C.ById(x.content.stage1.sampleCases,"A")
        attempt(x,"letter_pa_01",first.recipe,{stars=first.expect.rating.stars,facts=first.expect.facts,
            canDeliver=first.expect.canShip,durationHours=first.expect.durationHours,onsetDelayHours=first.expect.onsetDelayHours})
        for _,target in ipairs({{day=2,id="recipe_n01_a"},{day=4,id="recipe_n02_a"}}) do
            advance(x,target.day)
            local ref=C.ById(Data.recipes,target.id)
            receive(x,ref.letterId); attempt(x,ref.letterId,ref.recipe,ref.expect)
        end
        local live=x.state.GetSnapshot().live
        check("three deliveries",live.gameFlow.deliveredOrders,3)
        check("currency 270 from current fixed rewards",live.economy.currency,270)
        if options.singleUseCopy or Data.contentVersion=="story-v0.3-r3" then
            check("three single-use main cards consumed",must(x.modules.wordTokens.GetInventoryView(),"inventory view").availableDefinitionCount,11)
        end
        print("[Story] SEQUENTIAL delivered=" .. live.gameFlow.deliveredOrders .. " currency=" .. live.economy.currency
            .. " ingredients=" .. display(live.economy.ingredients))
    end)
    run("B5 existing recovery and failure coverage",function()
        step="OrderRecoveryTest.Run"
        require("debug.OrderRecoveryTest").Run(check,makeContent)
    end)
    print("[Story] reachable=" .. reachablePassed .. "/" .. reachableTotal .. " future-pure=" .. futurePassed .. "/" .. futureTotal
        .. " matrix=" .. matrixPassed .. "/" .. matrixTotal .. " checks=" .. total .. " failures=" .. failed)
    return failed==0
end
return T
