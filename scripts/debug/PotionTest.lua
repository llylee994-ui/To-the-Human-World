local U=require "core.StateUtil"
local F=require "debug.fixtures.B3Fixtures"
local Potion=require "systems.Potion"
local Tests={}

local function samples(check)
    local x=F.Setup()
    local before=U.Copy(x.baseline)
    local configBefore=U.Copy({x.content.words,x.content.ingredients,x.content.synthesis,x.content.stage1})
    for _, sample in ipairs(x.content.stage1.sampleCases) do
        local potion,resolved=x.Calculate(sample.id)
        local expected=sample.expect
        for _, key in ipairs({"effects","durationHours","onsetDelayHours","stability","unstable","sideEffects"}) do check(sample.id .. " " .. key,potion[key],expected[key]) end
        check(sample.id .. " tiers",potion.intensityByEffect,expected.tiers)
        check(sample.id .. " trace count",#potion.trace,8)
        for i,row in ipairs(potion.trace) do check(sample.id .. " trace step " .. i,row.step,i) end
        check(sample.id .. " result schema",Potion.ValidateResult(potion,x.content).ok,true)
        check(sample.id .. " JSON roundtrip",cjson.decode(cjson.encode(potion)),potion)
        if expected.residualSample then
            local point=expected.residualSample
            check(sample.id .. " residual",F.Must(Potion.SampleResidual(potion,point.effectId,point.atAfterDoseHours,x.content)),point.weight)
        end
        local evaluation=F.Must(x.order.Evaluate(x.content.letters[1].requirement,potion))
        check(sample.id .. " canShip",evaluation.canShip,expected.canShip)
        check(sample.id .. " failure count",#evaluation.failures,#expected.failures)
        for i, failure in ipairs(expected.failures) do
            local actual=evaluation.failures[i] or {}
            for _, key in ipairs({"id","kind","expected","actual","unit"}) do check(sample.id .. " failure " .. i .. " " .. key,actual[key],failure[key]) end
            check(sample.id .. " failure message " .. i,type(actual.message)=="string" and #actual.message>0,true)
        end
        check(sample.id .. " deterministic",F.Must(Potion.Calculate(resolved,x.content)),potion)
        -- 只核对 C2 药效与字面结果。facts/rating/fragments 属 B4，不读取它们来制造成功。
    end
    check("all samples baseline pure",x.baseline,before)
    check("all samples content pure",{x.content.words,x.content.ingredients,x.content.synthesis,x.content.stage1},configBefore)
    check("live inventory pure",x.economy.GetSnapshot(),before.live.economy)
    check("live tokens pure",x.words.GetSnapshot(),before.live.wordTokens)
    local a=x.Calculate("A")
    a.effects.sleep=900; a.trace[1].inputs.main.definition.effects.sleep=900
    check("output/data isolation",x.Calculate("A").effects.sleep,1)
end

local function edges(check)
    local x=F.Setup()
    ---@return table
    local function calculation(change,sample)
        local content=F.Content()
        change(content)
        local y=F.Setup(content)
        local request=y.Request(y.Sample(sample or "A").recipe)
        local resolved=y.order.ResolveRecipe(request,y.baseline)
        if not resolved.ok then return resolved end
        return Potion.Calculate(resolved.value,content)
    end
    for _, value in ipairs({0.6,1.2,2.2,99}) do
        local r=calculation(function(c) c.GetWord("word_sleep").effects={sleep=value} end)
        local label=({[0.6]="微弱",[1.2]="明显",[2.2]="强烈",[99]="过强"})[value]
        check("closed upper tier " .. value,F.Must(r).intensityByEffect.sleep,label)
    end
    check("tier overflow",calculation(function(c) c.GetWord("word_sleep").effects.sleep=99.01 end).error.code,"CONFIG_INVALID")
    local merged=F.Must(calculation(function(c)
        c.GetWord("word_dream").effects={calm=1}; c.GetWord("word_forget").effects={calm=1}
    end,"D"))
    check("step2 bonus includes preceding aux",merged.effects.calm,1.6)
    local tags=F.Must(calculation(function(c)
        c.ingredients[1].addTags={sleep=1}; c.ingredients[1].mods={intensity=2}
    end))
    check("step3 tags no sameTagBonus then scale",tags.effects.sleep,2.4)
    check("step3 trace before intensity",tags.trace[3].outputs.sleep,1.6)
    local side=F.Must(calculation(function(c) c.GetWord("word_sleep").effects.dream=0.8 end,"G2"))
    check("step7 additive not rescaled",side.effects.dream,1.6)
    check("step7 regrade",side.intensityByEffect.dream,"强烈")
    local once=F.Must(calculation(function(c) c.stage1.sampleCases[1].recipe.ingredients={{ingredientId="ing_ashen_herb",quantity=2}} end))
    check("side threshold multiple triggers once",#once.sideEffects,1)
    check("side value not multiplied twice",once.effects.dream,0.4)
    local zero=F.Must(calculation(function(c) c.ingredients[1].mods={intensity=-4} end))
    check("zero scale removes tags",zero.effects,{})
    check("negative scale denied",calculation(function(c)
        c.ingredients[1].mods={intensity=-4}; c.stage1.sampleCases[1].recipe.ingredients[1].quantity=2
    end).error.code,"CONFIG_INVALID")
    local negative=F.Must(calculation(function(c) c.ingredients[1].addTags={sleep=-2} end))
    check("nonpositive tag removed",negative.effects,{})
    check("missing mods rejected",calculation(function(c) c.ingredients[1].mods=nil end).error.code,"CONFIG_MISSING")
    check("out of range mod rejected",calculation(function(c) c.ingredients[1].mods={duration=4.1} end).error.code,"CONFIG_INVALID")
    check("unknown mod rejected",calculation(function(c) c.ingredients[1].mods={mystery=1} end).error.code,"CONFIG_INVALID")
    check("unknown tag rejected",calculation(function(c) c.ingredients[1].addTags={mystery=1} end).error.code,"UNKNOWN_ID")
    check("missing time profile",calculation(function(c) c.GetWord("word_sleep").attributeProfileId=nil end).error.code,"CONFIG_MISSING")
    check("unknown time profile",calculation(function(c) c.GetWord("word_sleep").attributeProfileId="absent" end).error.code,"UNKNOWN_ID")
    check("speed mapping missing",calculation(function(c) c.ingredients[1].mods={speed=1} end).error.code,"CONFIG_MISSING")
    check("speed mapping duplicate",calculation(function(c)
        c.attributeProfiles[1].speedToDelayHours[#c.attributeProfiles[1].speedToDelayHours+1]={speed=0,delayHours=1}
    end).error.code,"CONFIG_INVALID")
    check("time cannot be negative",calculation(function(c) c.ingredients[1].mods={duration=-4}; c.attributeProfiles[1].baseDurationHours=1 end).error.code,"CONFIG_INVALID")
    check("residual gap config",calculation(function(c) c.attributeProfiles[1].residualRules[1].points[2].hoursAfterEnd=2 end).error.code,"CONFIG_INVALID")
    check("residual increasing config",calculation(function(c) c.attributeProfiles[1].residualRules[1].points[2].ratio=0.9 end).error.code,"CONFIG_INVALID")
    check("synthesis missing",calculation(function(c) c.synthesis=nil end).error.code,"CONFIG_MISSING")
    check("tier missing",calculation(function(c) c.synthesis.intensityTiers=nil end).error.code,"CONFIG_MISSING")
    check("tier unsorted",calculation(function(c) c.synthesis.intensityTiers[2].max=0.5 end).error.code,"CONFIG_INVALID")
    check("duplicate side rule",calculation(function(c) c.synthesis.sideEffectRules[2]=U.Copy(c.synthesis.sideEffectRules[1]) end).error.code,"CONFIG_INVALID")
    check("invalid residual ratio",calculation(function(c) c.attributeProfiles[1].residualRules[1].points[1].ratio=1.1 end).error.code,"CONFIG_INVALID")
    local a,resolved=x.Calculate("A")
    for _, case in ipairs({{9,1},{10,0.6},{11,0.3},{12,0.1},{13,0.05},{14,0},{15,0}}) do
        check("residual exact " .. case[1],F.Must(Potion.SampleResidual(a,"sleep",case[1],x.content)),case[2])
    end
    check("residual no interpolation",Potion.SampleResidual(a,"sleep",10.5,x.content).error.code,"CONFIG_MISSING")
    check("residual missing even absent effect",Potion.SampleResidual(a,"calm",12,x.content).error.code,"CONFIG_MISSING")
    check("residual negative time",Potion.SampleResidual(a,"sleep",-1,x.content).error.code,"INVALID_REQUEST")
    local bad=U.Copy(resolved); bad.ingredients[1].quantity=3
    check("independent Potion slot gate",Potion.Calculate(bad,x.content).error.code,"SLOT_LIMIT")
    bad=U.Copy(resolved); bad.main.definition.effects.sleep=999
    check("independent definition tamper",Potion.Calculate(bad,x.content).error.code,"INVALID_REQUEST")
    bad=U.Copy(resolved); bad.aux={bad.main}
    check("independent duplicate token",Potion.Calculate(bad,x.content).error.code,"DUPLICATE_TOKEN")
    bad=U.Copy(resolved); bad.extra=true
    check("independent unknown field",Potion.Calculate(bad,x.content).error.code,"INVALID_REQUEST")
    local config=F.Content(); config.synthesis.auxWeight=0/0
    check("nonfinite config",Potion.Calculate(resolved,config).error.code,"CONFIG_INVALID")
    bad=U.Copy(resolved); bad.ingredients[1].quantity=math.huge
    check("nonfinite request",Potion.Calculate(bad,x.content).error.code,"INVALID_REQUEST")
    bad=U.Copy(resolved); bad.loop=bad
    check("cyclic request",Potion.Calculate(bad,x.content).error.code,"INVALID_REQUEST")
    check("missing calculation config",Potion.Calculate(resolved,nil).error.code,"CONFIG_MISSING")
    local plus=F.Must(calculation(function(c) c.ingredients[1].mods={stability=-0.001} end))
    check("stability strictly below threshold",plus.unstable,true)
    check("stability at threshold",x.Calculate("E").unstable,false)
end

local function envelopeCompatibility(check)
    -- 保留 B1/B2 的技术后果/评分占位，仅替换真实 B3 输出，证明字段能进入既有完整 Envelope。
    -- 这不是人物后果、评分、确认或真实读档验收。
    local x=F.Setup()
    local technical=require("debug.fixtures.B1Fixtures").V2("pending")
    local live=U.Copy(x.baseline.live)
    live.gameFlow=U.Copy(technical.live.gameFlow)
    live.world=U.Copy(technical.live.world)
    live.narrative=U.Copy(technical.live.narrative)
    local base={contentVersion=x.content.contentVersion,revision=0,nextOrderSerial=2,live=live,currentOrder=false}
    local data=require("debug.fixtures.B2Fixtures").Pending(base,"letter:" .. x.content.letters[1].id,x.byWord.word_sleep[1])
    local order=data.currentOrder
    local request=x.Request(x.Sample("A").recipe)
    request.orderId,request.baselineId=order.orderId,order.baseline.id
    order.recipe=U.Copy(request)
    local resolved=F.Must(x.order.ResolveRecipe(request,order.baseline))
    local potion=F.Must(Potion.Calculate(resolved,x.content))
    local pending=order.pending
    pending.potion=potion
    pending.requirementResult=F.Must(x.order.Evaluate(x.content.letters[1].requirement,potion))
    pending.consumption.ingredients=U.Copy(request.ingredients)
    pending.candidateLive.economy=F.Must(x.economy.PlanSettlement(base.live.economy,request.ingredients,{},pending.reward)).state
    local record=pending.candidateLive.orders.confirmedById[order.orderId]
    record.recipe=U.Copy(request); record.potion=U.Copy(potion); record.requirementResult=U.Copy(pending.requirementResult)
    record.consumption=U.Copy(pending.consumption)
    local result=require("core.SaveSchema").ValidateV2(data,{contentVersion=x.content.contentVersion,synthesisVersion=x.content.synthesis.version,economy=x.economy,letters=x.letters,wordTokens=x.words})
    check("real B3 outputs fit complete technical Envelope",result.ok,true)
    if not result.ok then print("[B3] schema " .. result.error.path .. " " .. result.error.message) end
end

local function defaultFiles()
    local storage=require("core.SaveSystem").EngineStorage()
    local result={}
    for _, suffix in ipairs({".json","_a.json","_b.json","_a.commit","_b.commit"}) do
        local path="save_slot1" .. suffix
        result[path]=storage.exists(path) and storage.read(path) or false
    end
    return result
end

function Tests.Run()
    local check,finish=F.Checks()
    local bus=require "core.EventBus"
    local save=require "core.SaveSystem"
    local oldEmit,oldSave=bus.Emit,save.Save
    local beforeFiles=defaultFiles()
    local events,writes=0,0
    bus.Emit=function() events=events+1; return 0 end
    save.Save=function() writes=writes+1; return false,U.Error("TEST_WRITE_FORBIDDEN","B3","B3 纯计算不得写盘") end
    local ok,err=pcall(function() samples(check); edges(check); require("debug.OrderTest").Run(check); envelopeCompatibility(check) end)
    bus.Emit,save.Save=oldEmit,oldSave
    if not ok then print("[B3] ERROR " .. tostring(err)); check("runtime",false,true) end
    check("no events",events,0); check("no save calls",writes,0)
    check("default files unchanged",defaultFiles(),beforeFiles)
    return finish()
end
return Tests
