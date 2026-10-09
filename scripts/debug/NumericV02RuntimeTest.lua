-- 真配置接入回归；File/UI 介质由 run_b1 隔离，业务模块保持真实。
local U=require "core.StateUtil"
local Data=require "data.content"
local T={}
local function must(result)
    assert(result.ok,cjson.encode(result.error))
    return result.value
end
function T.Run()
    assert(Data.Load())
    local letter=require("systems.Letter").New(Data)
    local parsed=must(letter.ParseDefinition("letter_pa_01"))
    local seen={}
    for _,span in ipairs(parsed.spans) do seen[span.wordId]=true end
    assert(seen.word_candidate_elias_sleep,"首信尚未投放 v02 合上眼来源")
    assert(not seen.word_sleep,"首信不能仍沿用旧剪词")
    local orders=0
    for _,l in ipairs(Data.letters) do if l.kind=="order" then orders=orders+1 end end
    assert(orders==11,"11单应全部可收取")
    local a=must(letter.ParseDefinition("letter_n01"))
    local b=must(letter.ParseDefinition("letter_n02"))
    local function afraid(p)
        for _,s in ipairs(p.spans) do if s.text=="怕" then return s.wordId end end
    end
    assert(afraid(a)=="word_candidate_n01_fear")
    assert(afraid(b)=="word_candidate_n02_fear","同字词必须按来源辨别")
    local world=require("systems.WorldState").New(Data)
    local initial=must(world.InitialSnapshot())
    local narrative=require("systems.Narrative").New(Data)
    local rating=require("systems.Order").New(Data)
    -- 数值区间专项使用完整PotionResult夹具；真正合成和事务另跑登记锅。
    local function numericPotion(e)
        local p={contentVersion=Data.contentVersion,synthesisVersion=Data.synthesis.version,effects=e,intensityByEffect={},
            durationHours=2,onsetDelayHours=1,recoveryAfterEndHours=0,residuals={},sideEffects={},stability=0,unstable=false,
            mods={intensity=0,duration=0,speed=0,stability=0,sideEffect=0},trace={}}
        for k,v in pairs(e) do
            for _,tier in ipairs(Data.synthesis.intensityTiers) do
                p.intensityByEffect[k]=tier.label
                if v<=tier.max then break end
            end
        end
        for i=1,8 do p.trace[i]={step=i,inputs={},outputs={},sourceIds={}} end
        return p
    end
    local function outcome(e,expected,stars)
        local potion=numericPotion(e)
        local ctx={letterId="letter_n02",orderId="numeric-boundary",day=4}
        local simulated=must(world.Simulate(initial,potion,ctx))
        assert(#simulated.facts==1,"同一锅只产生一条结果事实")
        assert(simulated.facts[1].id==expected)
        assert(must(rating.Rate(simulated.facts,"rating_n02")).stars==stars)
        ctx.world=simulated.world;ctx.potion=potion
        assert(#must(narrative.ResolveDirect(simulated.facts,ctx)).fragmentIds==1)
    end
    outcome({happy=1,fear=0.6,sadness=0.6},"n02_candidate_escaped",1)
    outcome({happy=1,fear=0.6,sadness=0.6-1e-9},"n02_candidate_swallowed",2)
    outcome({happy=1.8,fear=0.6-1e-9},"n02_candidate_care",2)
    outcome({happy=5,fear=5,sadness=5,suspicion=0.6},"n02_candidate_doubted",1)
    local p=numericPotion({happy=0.8,sleep=50});p.durationHours=99;p.onsetDelayHours=2
    local gate=must(rating.Evaluate(Data.GetLetter("letter_n02").requirement,p))
    assert(gate.canShip,"主轴达标，睡眠和时长不额外拒绝发货")
    assert(Data.ValidateStage1())
    local old=require("debug.fixtures.B5Fixtures").New(Data)
    local incompatible=old.state.GetSnapshot();incompatible.contentVersion="story-v0.4-r1"
    assert(old.save.Save("b5_flow",incompatible,2))
    local files=U.Copy(old.files)
    local loaded,status=old.Reload()
    assert(not loaded and status.status=="migration_required" and status.error.code=="CONTENT_VERSION_MISMATCH")
    assert(U.Equal(old.files,files),"旧档失败不清除或覆写")
    print("[NumericV02] PASS actual source mapping + exclusive boundary outcomes + shipping")
    return true
end
return T
