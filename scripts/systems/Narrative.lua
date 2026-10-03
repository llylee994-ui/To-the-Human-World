-- 事实驱动的文字与订单信筛选；不推进天数，不接管订单确认或归档。
local U=require "core.StateUtil"
local G=require "systems.CalculationGuard"
local R=require "systems.StoryRules"
local Narrative={}
local KIND={key=1,combination=2,single=3,generic=4}
local function priority(a,b)
    if a.priority~=b.priority then return a.priority>b.priority end
    return a.id<b.id
end
local function fragmentOrder(a,b)
    if KIND[a.kind]~=KIND[b.kind] then return KIND[a.kind]<KIND[b.kind] end
    return priority(a,b)
end

function Narrative.New(content)
    local api={}
    local worldApi=require("systems.WorldState").New(content)
    local letterApi=require("systems.Letter").New(content)
    ---@type table|nil
    local state
    function api.ValidateSnapshot(snapshot)
        return G.Run(function()
            G.Pure(snapshot,"narrative","STATE_INVALID")
            G.Keys(snapshot,{unlockedLetterIds=true,delayedQueue=true,resolvedEventIds=true},"narrative","STATE_INVALID")
            G.Need(type(snapshot.unlockedLetterIds)=="table" and type(snapshot.resolvedEventIds)=="table" and U.Array(snapshot.delayedQueue),"STATE_INVALID","narrative","剧情集合缺失或类型错误")
            for id,value in pairs(snapshot.unlockedLetterIds) do
                G.Need(value==true,"STATE_INVALID","narrative.unlockedLetterIds","集合值须为 true")
                local letter=G.Known(content,"letters",id,"narrative.unlockedLetterIds")
                G.Need(letter.kind=="order","STATE_INVALID","narrative.unlockedLetterIds","直接回信不进入解锁队列")
            end
            G.Need(next(snapshot.resolvedEventIds)==nil and #snapshot.delayedQueue==0,"CONFIG_MISSING","narrative","当前内容未声明延迟事件及其条件，不可恢复未知事件")
            return U.Copy(snapshot)
        end)
    end
    function api.InitialSnapshot() return api.ValidateSnapshot({unlockedLetterIds={},delayedQueue={},resolvedEventIds={}}) end
    function api.Restore(snapshot)
        local valid=api.ValidateSnapshot(snapshot)
        if valid.ok then state=U.Copy(valid.value) end
        return valid
    end
    function api.GetSnapshot() return state and U.Copy(state) or nil end

    -- context={letterId,orderId,day,world,potion}；world 使用 Simulate 的候选世界。
    -- template 可省略；显式传入时必须与该订单在统一配置中的模板相同。
    function api.ResolveDirect(facts,context,template)
        return G.Run(function()
            G.Pure(context,"context")
            G.Keys(context,{letterId=true,orderId=true,day=true,world=true,potion=true},"context")
            G.Need(U.String(context.orderId) and U.Integer(context.day,1),"INVALID_REQUEST","context","缺少订单与正式天数")
            local letter=G.Known(content,"letters",context.letterId,"context.letterId")
            G.Need(letter.kind=="order","INVALID_ORDER_STATE","context.letterId","须为来源订单")
            G.Value(worldApi.ValidateSnapshot(context.world))
            local evaluation=G.Value(require("systems.Order").New(content).Evaluate(letter.requirement,context.potion))
            G.Need(evaluation.canShip,"INVALID_ORDER_STATE","context.potion","字面失败不可生成回信")
            local index,values,definitions=R.Facts(facts,content)
            -- 防止将其他订单规则产生的事实拼进本单。
            for _,fact in ipairs(facts) do
                local rule=G.Known(content,"directRules",fact.sourceRuleId,"facts.sourceRuleId")
                G.Need(rule.ruleSetId==letter.directRuleSetId,"NARRATIVE_CONFLICT","facts","事实不属于本单规则集")
            end
            local configured=G.Known(content,"followupTemplates",letter.followupTemplateId,"letter.followupTemplateId")
            if template~=nil then G.Need(U.Equal(template,configured),"CONFIG_INVALID","template","模板与订单配置不一致") end
            template=configured
            G.Pure(template,"template","CONFIG_INVALID")
            G.Keys(template,{id=true,letterId=true,opening=true,closing=true,baseFragmentIds=true,fragmentIds=true,fallbackFragmentIds=true},"template","CONFIG_INVALID")
            local followup=G.Known(content,"letters",template.letterId,"template.letterId")
            G.Need(followup.kind=="direct_followup" and followup.cuttable==false and followup.senderId==letter.senderId and followup.followupTemplateId==template.id,"CONFIG_INVALID","template.letterId","直接回信关联错误")
            local sources={world=context.world,potion=context.potion,context=context,facts=values}
            local opening=R.Render(template.opening,nil,sources,content,"template.opening")
            local closing=R.Render(template.closing,nil,sources,content,"template.closing")
            local baseIds=R.Ids(template.baseFragmentIds,"template.baseFragmentIds")
            R.Ids(template.fragmentIds,"template.fragmentIds"); R.Ids(template.fallbackFragmentIds,"template.fallbackFragmentIds")
            local all,seen={},{ }
            for _,list in ipairs({template.baseFragmentIds,template.fragmentIds,template.fallbackFragmentIds}) do
                for _,id in ipairs(list) do
                    G.Need(not seen[id],"CONFIG_INVALID","template","片段在模板中重复引用")
                    seen[id]=true
                    local f=G.Known(content,"fragments",id,"template.fragmentIds")
                    G.Pure(f,"fragments." .. id,"CONFIG_INVALID")
                    G.Keys(f,{id=true,templateId=true,kind=true,priority=true,desc=true,requiresFacts=true,excludesFacts=true,coversFacts=true,overrides=true,exclusiveGroup=true,text=true,bindings=true},"fragments." .. id,"CONFIG_INVALID")
                    G.Need(f.templateId==template.id and KIND[f.kind]~=nil,"CONFIG_INVALID","fragments." .. id,"片段类型或模板引用不符")
                    G.Required(f.priority,G.Finite,"fragments.priority")
                    if f.exclusiveGroup~=nil then G.Required(f.exclusiveGroup,U.String,"fragments.exclusiveGroup") end
                    local covers=R.Ids(f.coversFacts,"fragments.coversFacts")
                    for factId in pairs(covers) do G.Need(definitions[factId]~=nil,"CONFIG_INVALID","fragments.coversFacts","覆盖事实未声明") end
                    R.Ids(f.overrides,"fragments.overrides",true)
                    all[id]=f
                end
            end
            -- 配置覆盖图必须无环；优先选无上游覆盖者，再压掉其目标，遍历顺序不会改变结果。
            local visiting,visited={},{}
            local function visit(id)
                G.Need(not visiting[id],"NARRATIVE_CONFLICT","fragments.overrides","片段覆盖形成循环")
                if visited[id] then return end
                visiting[id]=true
                for _,target in ipairs(all[id].overrides or {}) do
                    G.Need(all[target]~=nil,"CONFIG_INVALID","fragments.overrides","覆盖目标不在模板中")
                    visit(target)
                end
                visiting[id]=nil; visited[id]=true
            end
            for id in pairs(all) do visit(id) end
            local function choose(pool)
                local groups,remaining={},{}
                for _,id in ipairs(pool) do
                    local f=all[id]
                    if not f then error(U.Error("CONFIG_INVALID","fragments","片段未声明"),0) end
                    if R.Matches(f,index,definitions,"fragments." .. id) then
                        if f.exclusiveGroup then
                            local current=groups[f.exclusiveGroup]
                            if not current or priority(f,current) then groups[f.exclusiveGroup]=f end
                        else remaining[id]=f end
                    elseif baseIds[id] then G.Need(false,"CONTENT_UNCOVERED","fragments." .. id,"基础片段条件与事实不符") end
                end
                for _,f in pairs(groups) do remaining[f.id]=f end
                local result={}
                while next(remaining) do
                    local suppressed={}
                    for _,f in pairs(remaining) do for _,id in ipairs(f.overrides or {}) do if remaining[id] then suppressed[id]=true end end end
                    local roots={}
                    for id,f in pairs(remaining) do if not suppressed[id] then roots[#roots+1]=f end end
                    table.sort(roots,fragmentOrder)
                    for _,f in ipairs(roots) do
                        result[#result+1]=f; remaining[f.id]=nil
                        for _,id in ipairs(f.overrides or {}) do remaining[id]=nil end
                    end
                end
                local chosen={}
                for _,f in ipairs(result) do chosen[f.id]=true end
                for id in pairs(baseIds) do G.Need(chosen[id],"NARRATIVE_CONFLICT","fragments." .. id,"基础片段被覆盖或互斥排除") end
                table.sort(result,fragmentOrder)
                return result
            end
            local primary={}
            for _,id in ipairs(template.baseFragmentIds) do primary[#primary+1]=id end
            for _,id in ipairs(template.fragmentIds) do primary[#primary+1]=id end
            local selected=choose(primary)
            local rendered,bindings,covered,missing={},{},{},{}
            local function render(f)
                -- coversFacts 是具体表达，不准片段声称不存在的事实。
                for _,id in ipairs(f.coversFacts) do G.Need(index[id]~=nil,"NARRATIVE_CONFLICT","fragments." .. f.id,"片段表达了未发生事实") end
                local result=G.Run(function()
                    local text,filled=R.Render(f.text,f.bindings,sources,content,"fragments." .. f.id)
                    return {text=text,filled=filled}
                end)
                if not result.ok then
                    if result.error.code=="FILL_SOURCE_MISSING" then missing[#missing+1]=result.error; return false end
                    error(result.error,0)
                end
                rendered[f.id]=result.value.text; bindings[f.id]=result.value.filled
                for _,id in ipairs(f.coversFacts) do covered[id]=true end
                return true
            end
            local optionalCount=0
            for _,f in ipairs(selected) do if render(f) and not baseIds[f.id] then optionalCount=optionalCount+1 end end
            local function uncovered()
                for id,fact in pairs(index) do if fact.important and not covered[id] then return true end end
                return false
            end
            if optionalCount==0 or #missing>0 or uncovered() then
                -- 兜底仍走同样的事实、覆盖与互斥检查；不会凭空补台词或绕过重要事实。
                local pool={}
                for _,f in ipairs(selected) do if rendered[f.id] then pool[#pool+1]=f.id end end
                for _,id in ipairs(template.fallbackFragmentIds) do pool[#pool+1]=id end
                -- 缺来源的基础片段也不能默默消失；仅允许真实可渲染基础段。
                for id in pairs(baseIds) do G.Need(rendered[id]~=nil,"FILL_SOURCE_MISSING","fragments." .. id,"基础片段缺少填充来源") end
                selected=choose(pool); rendered={}; bindings={}; covered={}
                for _,f in ipairs(selected) do render(f) end
            end
            if uncovered() then
                if #missing>0 then error(missing[1],0) end
                G.Need(false,"CONTENT_UNCOVERED","fragments.coversFacts","重要事实没有得到表达")
            end
            -- 即使缺失片段只表达普通事实，也要有成功的配置兜底，不能静默省略。
            if #missing>0 then
                local fallbackUsed=false
                for _,id in ipairs(template.fallbackFragmentIds) do if rendered[id] then fallbackUsed=true end end
                G.Need(fallbackUsed,"FILL_SOURCE_MISSING","fragments","来源缺失且无可用兜底")
            end
            local fragmentIds,texts={},{opening}
            local function append(id)
                if rendered[id] then fragmentIds[#fragmentIds+1]=id; texts[#texts+1]=rendered[id] end
            end
            for _,id in ipairs(template.baseFragmentIds) do append(id) end
            for _,f in ipairs(selected) do if not baseIds[f.id] then append(f.id) end end
            G.Need(#fragmentIds>0,"CONTENT_UNCOVERED","fragments","回信没有可用片段")
            texts[#texts+1]=closing
            return {letterId=template.letterId,fragmentIds=fragmentIds,bindings=bindings,renderedText=table.concat(texts,"\n\n")}
        end)
    end

    -- 只读正式 live。conditions 为 B2 预留参数；目前没有额外调度条件配置。
    function api.FindAvailable(live,conditions)
        return G.Run(function()
            G.Pure(live,"live")
            G.Keys(live,{gameFlow=true,letters=true,wordTokens=true,economy=true,world=true,narrative=true,orders=true},"live")
            if conditions~=nil then G.Need(type(conditions)=="table" and next(conditions)==nil,"CONFIG_INVALID","conditions","未声明额外调度条件") end
            G.Value(require("core.GameFlow").ValidateSnapshot(live.gameFlow))
            G.Value(letterApi.ValidateSnapshot(live.letters))
            -- 当前支持的 dayMin/dayMax 不读取世界字段；未知世界条件在下方明确拒绝。
            -- 完整 LiveState 的模块恢复校验仍由 GameState/B5 负责。
            G.Value(api.ValidateSnapshot(live.narrative))
            G.Required(content.letters,U.Array,"letters")
            local received,result={},{}
            for _,item in pairs(live.letters.byId) do if item.received then received[item.letterId]=true end end
            local ids={}
            for _,letter in ipairs(content.letters) do
                G.Need(U.String(letter.id) and not ids[letter.id],"CONFIG_INVALID","letters","信件 ID 缺失或重复")
                ids[letter.id]=true
                G.Need(letter.kind=="order" or letter.kind=="direct_followup","CONFIG_INVALID","letters.kind","未知信件类型")
                if letter.kind=="order" then
                    local c=G.Required(letter.appearCondition,G.Table,"letters." .. letter.id .. ".appearCondition")
                    G.Keys(c,{dayMin=true,dayMax=true},"letters." .. letter.id .. ".appearCondition","CONFIG_INVALID")
                    for key,value in pairs(c) do G.Need(U.Integer(value,1),"CONFIG_INVALID","appearCondition." .. key,"天数须为正整数") end
                    G.Need(c.dayMin==nil or c.dayMax==nil or c.dayMin<=c.dayMax,"CONFIG_INVALID","appearCondition","天数上下限颠倒")
                    if not received[letter.id] and (c.dayMin==nil or live.gameFlow.day>=c.dayMin) and (c.dayMax==nil or live.gameFlow.day<=c.dayMax) then result[#result+1]=letter.id end
                end
            end
            table.sort(result)
            return result
        end)
    end
    return api
end
local live=Narrative.New(require "data.content")
for _,name in ipairs({"InitialSnapshot","ValidateSnapshot","Restore","GetSnapshot","ResolveDirect","FindAvailable"}) do Narrative[name]=live[name] end
return Narrative
