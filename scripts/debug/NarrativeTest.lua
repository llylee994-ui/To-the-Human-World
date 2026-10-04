local U=require "core.StateUtil"
local F=require "debug.fixtures.B4Fixtures"
local T={}

local function samples(check)
    local x=F.Setup()
    local before=U.Copy({world=x.world.GetSnapshot(),narrative=x.narrative.GetSnapshot(),baseline=x.baseline})
    local contentBefore=U.Copy(x.content)
    for _,sample in ipairs(x.content.stage1.sampleCases) do
        local result,potion=x.Simulate(sample.id)
        if sample.expect.canShip then
            local simulated=F.Must(result)
            local followup=F.Must(x.Resolve(simulated,potion))
            local rating=F.Must(x.order.Rate(simulated.facts,x.definition.ratingSetId))
            check(sample.id .. " facts",F.Ids(simulated.facts),F.Sorted(sample.expect.facts))
            check(sample.id .. " fragments",F.Sorted(followup.fragmentIds),F.Sorted(sample.expect.followupFragments))
            check(sample.id .. " stars",rating.stars,sample.expect.rating.stars)
            check(sample.id .. " rating rule",rating.ruleId,sample.expect.rating.ruleId)
            check(sample.id .. " text has no placeholders",not followup.renderedText:find("{{",1,true),true)
            check(sample.id .. " nonempty feedback",U.String(rating.feedback),true)
            check(sample.id .. " deterministic world",F.Must(x.Simulate(sample.id)),simulated)
            check(sample.id .. " deterministic letter",F.Must(x.Resolve(simulated,potion)),followup)
            check(sample.id .. " deterministic rating",F.Must(x.order.Rate(simulated.facts,x.definition.ratingSetId)),rating)
            check(sample.id .. " world JSON roundtrip",F.Must(x.world.ValidateSnapshot(cjson.decode(cjson.encode(simulated.world)))),simulated.world)
            check(sample.id .. " result JSON roundtrip",cjson.decode(cjson.encode({simulated,followup,rating})),{simulated,followup,rating})
            check(sample.id .. " sleep candidate",simulated.world.npcs.npc_passerby_a.sleepState,"improved")
            check(sample.id .. " work candidate",simulated.world.npcs.npc_passerby_a.workState,"recovered")
            for _,fact in ipairs(simulated.facts) do
                check(sample.id .. " provenance " .. fact.id,U.String(fact.sourceRuleId) and #fact.inputs.when>0,true)
                check(sample.id .. " potion basis " .. fact.id,fact.inputs.potionEffects,potion.effects)
            end
            if sample.id=="C" then
                check("C uses real song title",followup.renderedText:find("摇橹调",1,true)~=nil,true)
                check("C stores binding value",followup.bindings.frag_pa_forget_song.songTitle,"摇橹调")
                check("C persistent memory",simulated.world.npcs.npc_passerby_a.memories.mem_mother.state,"faded")
            elseif sample.id=="D" then
                check("D no full mother recognition",followup.renderedText:find("夜里还梦见了我娘",1,true)==nil,true)
                check("D explicit distress",followup.renderedText:find("心里都像压着块石头",1,true)~=nil,true)
                check("D persistent memory",simulated.world.npcs.npc_passerby_a.memories.mem_mother.state,"faded")
            end
            check(sample.id .. " reward unchanged",x.definition.reward.currency,80)
        else
            check(sample.id .. " refuses consequences",result.error.code,"INVALID_ORDER_STATE")
            local context=U.Copy(x.context); context.world=x.initialWorld; context.potion=potion
            check(sample.id .. " refuses direct letter",x.narrative.ResolveDirect({},context).error.code,"INVALID_ORDER_STATE")
            check(sample.id .. " no invented rating",x.order.Rate({},x.definition.ratingSetId).error.code,"RATING_UNCOVERED")
        end
    end
    check("all samples preserve formal state and stock",{world=x.world.GetSnapshot(),narrative=x.narrative.GetSnapshot(),baseline=x.baseline},before)
    check("all samples preserve content",x.content,contentBefore)
end

local function narrativeEdges(check)
    local x=F.Setup()
    local function altered(name,edit,id,code)
        local content=F.Content(); edit(content)
        local fresh=F.Setup(content)
        local result,potion=fresh.Simulate(id or "A")
        local resolved=fresh.Resolve(F.Must(result),potion)
        check(name,resolved.ok,false)
        check(name .. " code",resolved.error and resolved.error.code,code)
    end
    altered("important fact uncovered",function(c) F.ById(c.fragments,"frag_pa_work_recovered").coversFacts={} end,"A","CONTENT_UNCOVERED")
    altered("unbound placeholder",function(c) F.ById(c.fragments,"frag_pa_forget_song").bindings=nil end,"C","FILL_SOURCE_MISSING")
    altered("binding missing source",function(c) F.ById(c.fragments,"frag_pa_forget_song").bindings.songTitle.path="npc_passerby_a.memories.mem_mother.missing" end,"C","FILL_SOURCE_MISSING")
    altered("base incompatible",function(c) F.ById(c.fragments,"frag_pa_work_recovered").requiresFacts={"fx_self_distressed"} end,"A","CONTENT_UNCOVERED")
    altered("fragment invents fact",function(c) F.ById(c.fragments,"frag_pa_sleep_only").coversFacts={"fx_dreamt_mother"} end,"A","NARRATIVE_CONFLICT")
    altered("override cycle",function(c) F.ById(c.fragments,"frag_pa_sleep_only").overrides={"frag_pa_generic"}; F.ById(c.fragments,"frag_pa_generic").overrides={"frag_pa_sleep_only"} end,"A","NARRATIVE_CONFLICT")
    altered("unknown template field",function(c) F.ById(c.followupTemplates,"tpl_pa_01").surprise=true end,"A","CONFIG_INVALID")
    altered("unknown fragment kind",function(c) F.ById(c.fragments,"frag_pa_sleep_only").kind="random" end,"A","CONFIG_INVALID")
    altered("unknown required fact",function(c) F.ById(c.fragments,"frag_pa_sleep_only").requiresFacts={"invented"} end,"A","CONFIG_INVALID")
    -- 技术兜底文本仍来源于现有配置；修改的仅为调试副本。
    local c=F.Content()
    F.ById(c.fragments,"frag_pa_forget_song").bindings.songTitle.path="npc_passerby_a.memories.mem_mother.missing"
    F.ById(c.fragments,"frag_pa_generic").requiresFacts={"fx_mother_memory_faded"}
    F.ById(c.fragments,"frag_pa_generic").coversFacts={"fx_mother_memory_faded"}
    F.ById(c.fragments,"frag_pa_generic").text="技术兜底：已发生记忆变淡。"
    local fallback=F.Setup(c).Joint("C")
    check("compatible fallback covers important fact",fallback.followup.fragmentIds,{"frag_pa_work_recovered","frag_pa_generic"})
    check("fallback has no invented song",fallback.followup.renderedText:find("摇橹调",1,true)==nil,true)
    local d=F.Must(x.Simulate("D")); local p=x.Calculate("D")
    local tampered=U.Copy(d); tampered.facts[1].sourceRuleId="ghost"
    check("fact provenance required",x.Resolve(tampered,p).error.code,"FILL_SOURCE_MISSING")
    tampered=U.Copy(d); tampered.facts[1].inputs={}
    check("fact input evidence required",x.Resolve(tampered,p).error.code,"FILL_SOURCE_MISSING")
    -- 互斥组依 priority/ID，渲染档次不更改同组的取舍规则。
    c=F.Content(); F.ById(c.fragments,"frag_pa_sleep_only").exclusiveGroup="technical"; F.ById(c.fragments,"frag_pa_generic").exclusiveGroup="technical"
    F.ById(c.fragments,"frag_pa_generic").priority=99; F.ById(c.followupTemplates,"tpl_pa_01").fragmentIds[#F.ById(c.followupTemplates,"tpl_pa_01").fragmentIds+1]="frag_pa_generic"; F.ById(c.followupTemplates,"tpl_pa_01").fallbackFragmentIds={}
    local grouped=F.Setup(c).Joint("A")
    check("exclusive group highest priority",grouped.followup.fragmentIds,{"frag_pa_work_recovered","frag_pa_generic"})
    c=F.Content(); F.ById(c.fragments,"frag_pa_sleep_only").requiresFacts={"fx_sleep_improved"}; F.ById(c.fragments,"frag_pa_sleep_only").excludesFacts={}
    F.ById(c.fragments,"frag_pa_sleep_only").overrides={"frag_pa_dream_mother"}
    local overridden=F.Setup(c)
    local result,potion=overridden.Simulate("B")
    check("overrides cannot hide important fact",overridden.Resolve(F.Must(result),potion).error.code,"CONTENT_UNCOVERED")
    local sources={context={actual=false}}
    local text,filled=require("systems.StoryRules").Render("技术布尔={{flag}}",{flag={source="context",path="actual"}},sources,x.content,"technical")
    check("false binding retained",filled.flag,false); check("false binding renders",text,"技术布尔=false")
    local n=x.narrative
    local initial=F.Must(n.InitialSnapshot())
    check("narrative JSON restore",F.Must(n.Restore(cjson.decode(cjson.encode(initial)))),initial)
    local unlocked=U.Copy(initial); unlocked.unlockedLetterIds.letter_pa_01=true
    check("valid unlocked order",n.Restore(unlocked).ok,true)
    local got=n.GetSnapshot(); got.unlockedLetterIds.letter_pa_01=nil
    check("narrative snapshot copy",n.GetSnapshot(),unlocked)
    for _,bad in ipairs({{unlockedLetterIds={letter_pa_01_followup=true},delayedQueue={},resolvedEventIds={}},
        {unlockedLetterIds={},delayedQueue={},resolvedEventIds={invented=true}},
        {unlockedLetterIds={},delayedQueue={{eventId="unknown"}},resolvedEventIds={}},
        {unlockedLetterIds={letter_pa_01=false},delayedQueue={},resolvedEventIds={}}}) do
        check("invalid narrative refused",n.Restore(bad).ok,false)
        check("invalid restore preserves narrative",n.GetSnapshot(),unlocked)
    end
end

local function ratingEdges(check)
    local x=F.Setup()
    local facts=F.Must(x.Simulate("A")).facts
    local function rule(id,stars,p) return {id=id,ratingSetId="technical",stars=stars,priority=p,requiresFacts={"fx_sleep_improved"},excludesFacts={},feedback="技术反馈：有已生成的睡眠事实。"} end
    local function rate(rules)
        local c=F.Content(); c.orderRatings=rules
        return require("systems.Order").New(c).Rate(facts,"technical")
    end
    check("3 stars beats high priority 1",F.Must(rate({rule("z_three",3,1),rule("a_one",1,999)})).ruleId,"z_three")
    check("2 stars beats high priority 1",F.Must(rate({rule("two",2,1),rule("one",1,999)})).stars,2)
    check("legal 1 star fallback",F.Must(rate({rule("one",1,1)})).stars,1)
    check("same star priority",F.Must(rate({rule("a",2,1),rule("z",2,2)})).ruleId,"z")
    check("same star stable id",F.Must(rate({rule("z",2,2),rule("a",2,2)})).ruleId,"a")
    check("empty rating config",rate({}).error.code,"RATING_UNCOVERED")
    local r=rule("one",1,1); r.feedback=""
    check("empty feedback",rate({r}).error.code,"RATING_UNCOVERED")
    r.feedback="{{missing}}"
    check("no feedback source no downgrade",rate({r}).error.code,"FILL_SOURCE_MISSING")
    r.feedback="技术文字"; r.requiresFacts={}
    check("feedback must cite fact",rate({r}).error.code,"FILL_SOURCE_MISSING")
    r=rule("invalid",4,1)
    check("invalid stars",rate({r}).error.code,"CONFIG_INVALID")
    local original=F.Must(x.order.Rate(facts,"rating_pa_01"))
    original.factIds[1]="changed"
    check("rating returns copy",F.Must(x.order.Rate(facts,"rating_pa_01")).factIds[1],"fx_sleep_improved")
end

local function scheduling(check)
    local content=F.Content()
    -- Only this technical scheduling scenario delays other orders; production content is untouched.
    for _,letter in ipairs(content.letters) do
        if letter.kind=="order" and letter.id~="letter_pa_01" then letter.appearCondition={dayMin=99} end
    end
    local n=require("systems.Narrative").New(content)
    local live={gameFlow={day=1,phase="day",canSalvage=true,mainStoryStage="intro",deliveredOrders=0},
        letters=F.Must(require("systems.Letter").New(content).InitialSnapshot()),
        world=F.Must(require("systems.WorldState").New(content).InitialSnapshot()),narrative=F.Must(n.InitialSnapshot())}
    local before=U.Copy(live)
    check("real day1 scheduler",F.Must(n.FindAvailable(live)),{"letter_pa_01"})
    check("scheduler pure and no cross day",live,before)
    F.ById(content.letters,"letter_pa_01").appearCondition={dayMin=2,dayMax=3}
    check("day too early",F.Must(n.FindAvailable(live)),{})
    live.gameFlow.day=2; check("day min inclusive",F.Must(n.FindAvailable(live)),{"letter_pa_01"})
    live.gameFlow.day=3; check("day max inclusive",F.Must(n.FindAvailable(live)),{"letter_pa_01"})
    live.gameFlow.day=4; check("day too late",F.Must(n.FindAvailable(live)),{})
    live.gameFlow.day=2
    live.letters=F.Must(require("systems.Letter").New(content).PlanReceive(live.letters,"letter_pa_01")).state
    check("already received never requeued",F.Must(n.FindAvailable(live)),{})
    F.ById(content.letters,"letter_pa_01").appearCondition.afterLetter="letter_pa_01"
    check("unsupported condition refused even if received",n.FindAvailable(live).error.code,"CONFIG_INVALID")
end

local function envelopeCompatibility(check)
    local x=F.Setup()
    for _,id in ipairs({"A","B","C","D","G2","G3"}) do
        local data=F.Envelope(x,id)
        local result=require("core.SaveSchema").ValidateV2(data,{contentVersion=x.content.contentVersion,synthesisVersion=x.content.synthesis.version,economy=x.economy,letters=x.letters,wordTokens=x.words})
        check(id .. " real B3 B4 Envelope",result.ok,true)
        if not result.ok then print("[B4] Envelope " .. result.error.code .. " " .. result.error.path) end
        local restored=cjson.decode(cjson.encode(data))
        check(id .. " full JSON roundtrip",restored,data)
        check(id .. " candidate world restorable",x.world.Restore(restored.currentOrder.pending.candidateLive.world).ok,true)
        check(id .. " baseline world restorable",x.world.Restore(restored.currentOrder.baseline.live.world).ok,true)
        check(id .. " reset snapshot retains memories",x.world.GetSnapshot(),x.initialWorld)
        check(id .. " candidate narrative restorable",x.narrative.Restore(restored.currentOrder.pending.candidateLive.narrative).ok,true)
        check(id .. " fixed reward",restored.currentOrder.pending.reward,x.definition.reward)
    end
end

local function defaultFiles()
    local storage=require("core.SaveSystem").EngineStorage()
    local files={}
    for _,suffix in ipairs({".json","_a.json","_b.json","_a.commit","_b.commit"}) do
        local path="save_slot1" .. suffix
        files[path]=storage.exists(path) and storage.read(path) or false
    end
    return files
end

local function reorderedContent(check)
    local c=F.Content()
    for _,key in ipairs({"letters","npcs","directRules","fragments","followupTemplates","orderRatings"}) do
        local reversed={}
        for i=#c[key],1,-1 do reversed[#reversed+1]=c[key][i] end
        c[key]=reversed
    end
    local original,reordered=F.Setup(),F.Setup(c)
    for _,id in ipairs({"A","B","C","D"}) do
        check("configuration order independent " .. id,reordered.Joint(id),original.Joint(id))
    end
    local ok,message=pcall(F.ById,c.directRules,"technical_missing_id")
    check("missing fixture id fails explicitly",not ok and tostring(message):find("technical_missing_id",1,true)~=nil,true)
end

function T.Run()
    local check,finish=F.Checks()
    local bus,save=require "core.EventBus",require "core.SaveSystem"
    local oldEmit,oldSave=bus.Emit,save.Save
    local beforeFiles=defaultFiles()
    local events,writes=0,0
    bus.Emit=function() events=events+1; return 0 end
    save.Save=function() writes=writes+1; return false,U.Error("TEST_WRITE_FORBIDDEN","B4","纯计算不可保存") end
    local ok,err=pcall(function() samples(check); require("debug.WorldStateTest").Run(check); narrativeEdges(check); ratingEdges(check); scheduling(check); envelopeCompatibility(check); reorderedContent(check) end)
    bus.Emit,save.Save=oldEmit,oldSave
    if not ok then print("[B4] ERROR " .. (type(err)=="table" and cjson.encode(err) or tostring(err))); check("runtime",false,true) end
    check("no events",events,0); check("no save calls",writes,0)
    check("default files unchanged",defaultFiles(),beforeFiles)
    return finish()
end
return T
