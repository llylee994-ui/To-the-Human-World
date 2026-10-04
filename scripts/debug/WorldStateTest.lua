local U=require "core.StateUtil"
local F=require "debug.fixtures.B4Fixtures"
local T={}
function T.Run(check)
    local x=F.Setup()
    local world=x.world
    local initial=U.Copy(x.initialWorld)
    check("world JSON restore",F.Must(world.Restore(cjson.decode(cjson.encode(initial)))),initial)
    local exposed=world.GetSnapshot(); exposed.npcs.npc_passerby_a.sleepState="troubled"
    check("world returned copy",world.GetSnapshot(),initial)
    local function invalid(name,edit,code)
        local value=U.Copy(initial); edit(value)
        local result=world.Restore(value)
        check(name,result.ok,false)
        if code then check(name .. " code",result.error and result.error.code,code) end
        check(name .. " preserves world",world.GetSnapshot(),initial)
    end
    invalid("missing npc",function(v) v.npcs.npc_passerby_a=nil end)
    invalid("unknown npc",function(v) v.npcs.ghost={} end)
    invalid("unknown field",function(v) v.npcs.npc_passerby_a.ghost=true end)
    invalid("unknown enum",function(v) v.npcs.npc_passerby_a.sleepState="perfect" end)
    invalid("missing memory",function(v) v.npcs.npc_passerby_a.memories={} end)
    invalid("unknown memory",function(v) v.npcs.npc_passerby_a.memories.ghost={} end)
    invalid("undeclared flag",function(v) v.flags.caseSolved=true end,"CONFIG_MISSING")
    invalid("cyclic input",function(v) v.flags.self=v end,"STATE_INVALID")
    invalid("nonfinite input",function(v) v.npcs.npc_passerby_a.sleepState=0/0 end,"STATE_INVALID")
    local potion=x.Calculate("A")
    local function altered(name,edit,code)
        local content=F.Content(); edit(content)
        local w=require("systems.WorldState").New(content)
        local result=w.Simulate(initial,potion,x.context)
        check(name,result.ok,false)
        if code then check(name .. " code",result.error and result.error.code,code) end
    end
    local function change(content,path,op,value)
        F.ById(content.directRules,"rule_pa_rest_ok").changes={{path=path,op=op,value=value}}
    end
    altered("unknown condition op",function(c) F.ById(c.directRules,"rule_pa_rest_ok").when[1].op="eval" end,"CONFIG_INVALID")
    altered("unknown condition source",function(c) F.ById(c.directRules,"rule_pa_rest_ok").when[1].source="os" end,"CONFIG_INVALID")
    altered("unknown condition effect",function(c) F.ById(c.directRules,"rule_pa_rest_ok").when[1].path="ghost" end,"UNKNOWN_ID")
    altered("missing context is not false",function(c) F.ById(c.directRules,"rule_pa_rest_ok").when={{source="context",path="missing",op="ne",value=false}} end,"FILL_SOURCE_MISSING")
    altered("mismatched comparison types",function(c) F.ById(c.directRules,"rule_pa_rest_ok").when[1].value="0.8" end,"CONFIG_INVALID")
    altered("sparse conditions",function(c) F.ById(c.directRules,"rule_pa_rest_ok").when={[1]={source="potion.effects",path="sleep",op="gte",value=0.8},[3]={source="potion.effects",path="sleep",op="gte",value=0.8}} end,"CONFIG_INVALID")
    altered("unknown change target",function(c) change(c,"world.npcs.npc_passerby_a.ghost","set",true) end,"CONFIG_INVALID")
    altered("cannot change currency",function(c) change(c,"economy.currency","set",999) end,"CONFIG_INVALID")
    altered("unknown change operation",function(c) change(c,"world.npcs.npc_passerby_a.sleepState","delete","improved") end,"CONFIG_INVALID")
    altered("invalid candidate enum",function(c) change(c,"world.npcs.npc_passerby_a.sleepState","set","perfect") end,"STATE_INVALID")
    altered("add refuses text",function(c) change(c,"world.npcs.npc_passerby_a.sleepState","add",1) end,"CONFIG_INVALID")
    altered("undeclared private memory",function(c) F.ById(c.directRules,"rule_pa_rest_ok").facts[1].objectId="ghost" end,"CONFIG_INVALID")
    altered("no matching fact",function(c) F.ById(c.directRules,"rule_pa_rest_ok").when[1].value=2 end,"CONTENT_UNCOVERED")
    altered("conflicting set",function(c)
        c.directRules[#c.directRules+1]={id="technical_conflict",ruleSetId="rules_pa_01",priority=0,when={},facts={},
            changes={{path="world.npcs.npc_passerby_a.sleepState",op="set",value="troubled"}}}
    end,"NARRATIVE_CONFLICT")
    altered("exclusive facts",function(c) F.ById(c.directRules,"rule_pa_dream_mother").when={}; F.ById(c.directRules,"rule_pa_dream_mother").unless={}; F.ById(c.directRules,"rule_pa_dream_unclear").when={} end,"NARRATIVE_CONFLICT")
    -- 同输入匹配：第二条规则不能看到第一条刚写入的 improved。
    local content=F.Content()
    content.directRules[#content.directRules+1]={id="technical_same_input",ruleSetId="rules_pa_01",priority=-1,
        when={{source="world.npcs",path="npc_passerby_a.sleepState",op="eq",value="improved"}},
        facts={{id="technical_fact",subjectId="npc_passerby_a",value=true,important=false}},changes={}}
    local simulated=F.Must(require("systems.WorldState").New(content).Simulate(initial,potion,x.context))
    check("rules match original snapshot",F.Ids(simulated.facts),{"fx_morning_work_ok","fx_sleep_improved"})
    -- 技术 schema 验证 false、数字 add、输入事实来源；只改测试副本。
    F.ById(content.npcs,"npc_passerby_a").initialState.ready=false; F.ById(content.npcs,"npc_passerby_a").initialStateSchema.ready={type="boolean"}
    F.ById(content.npcs,"npc_passerby_a").initialState.counter=2; F.ById(content.npcs,"npc_passerby_a").initialStateSchema.counter={type="integer"}
    F.ById(content.directRules,"rule_pa_rest_ok").changes[#F.ById(content.directRules,"rule_pa_rest_ok").changes+1]={path="world.npcs.npc_passerby_a.counter",op="add",value=3}
    content.directRules[#content.directRules].when={{source="world.npcs",path="npc_passerby_a.ready",op="eq",value=false}}
    content.directRules[#content.directRules].changes={{path="world.npcs.npc_passerby_a.counter",op="add",value=4}}
    local techWorld=require("systems.WorldState").New(content)
    local technical=F.Must(techWorld.InitialSnapshot())
    local combined=F.Must(techWorld.Simulate(technical,potion,x.context))
    check("sum numeric adds from original",combined.world.npcs.npc_passerby_a.counter,9)
    check("false remains false",combined.world.npcs.npc_passerby_a.ready,false)
    check("technical input unmodified",technical.npcs.npc_passerby_a.counter,2)
    content.directRules[#content.directRules].changes={{path="world.npcs.npc_passerby_a.counter",op="set",value=9}}
    check("set add conflict",techWorld.Simulate(technical,potion,x.context).error.code,"NARRATIVE_CONFLICT")
    content.directRules[#content.directRules].changes={}
    content.directRules[#content.directRules].when={{source="facts",path="fx_sleep_improved",op="eq",value=true}}
    local prior=U.Copy(x.context); prior.facts=F.Must(x.Simulate("A")).facts
    check("prior facts accepted",techWorld.Simulate(technical,potion,prior).ok,true)
    check("same batch facts not visible",techWorld.Simulate(technical,potion,x.context).error.code,"FILL_SOURCE_MISSING")
    check("world default not installed by simulation",world.GetSnapshot(),initial)
end
return T
