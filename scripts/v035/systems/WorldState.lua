-- 正式状态仅由 Restore 安装；Simulate 始终返回副本，不派发试做事件。
local U=require "v035.core.StateUtil"
local G=require "v035.systems.CalculationGuard"
local R=require "v035.systems.StoryRules"
local WorldState={}

---@type fun(value: any, schema: table, path: string)
local validateFields
local function validateValue(value,schema,path)
    G.Required(schema,G.Table,path .. ".schema")
    local kind=schema.type
    local valid=false
    if kind=="enum" then
        G.Required(schema.values,U.Array,path .. ".values")
        for _,allowed in ipairs(schema.values) do if value==allowed then valid=true end end
    elseif kind=="text" then valid=U.String(value)
    elseif kind=="number" then valid=G.Finite(value)
    elseif kind=="integer" then valid=G.Finite(value) and value==math.floor(value)
    elseif kind=="boolean" then valid=type(value)=="boolean"
    elseif kind=="map" then
        local keys=R.Ids(schema.keys,path .. ".keys")
        G.Keys(value,keys,path,"STATE_INVALID")
        for key in pairs(keys) do validateFields(value[key],schema.entry,path .. "." .. key) end
        valid=true
    else G.Need(false,"CONFIG_INVALID",path .. ".type","未支持的字段类型") end
    G.Need(valid,"STATE_INVALID",path,"字段不符合人物类型或允许值")
end
validateFields=function(value,schema,path)
    G.Required(schema,G.Table,path .. ".schema")
    G.Keys(value,schema,path,"STATE_INVALID")
    for key,field in pairs(schema) do validateValue(value[key],field,path .. "." .. key) end
end

function WorldState.New(content)
    local api={}
    ---@type table|nil
    local state
    function api.ValidateSnapshot(snapshot)
        return G.Run(function()
            G.Pure(snapshot,"world","STATE_INVALID")
            G.Keys(snapshot,{npcs=true,flags=true},"world","STATE_INVALID")
            G.Need(type(snapshot.npcs)=="table" and type(snapshot.flags)=="table","STATE_INVALID","world","缺少世界集合")
            -- 当前包没有任何世界 flag 声明。后续需先交付 schema，不能吞掉未知档字段。
            G.Need(next(snapshot.flags)==nil,"CONFIG_MISSING","world.flags","尚无世界标记字段配置")
            G.Required(content.npcs,U.Array,"npcs")
            local allowed={}
            for _,npc in ipairs(content.npcs) do
                G.Need(U.String(npc.id) and not allowed[npc.id],"CONFIG_INVALID","npcs","人物 ID 重复或缺失")
                allowed[npc.id]=true
                validateFields(snapshot.npcs[npc.id],npc.initialStateSchema,"world.npcs." .. npc.id)
            end
            G.Keys(snapshot.npcs,allowed,"world.npcs","STATE_INVALID")
            return U.Copy(snapshot)
        end)
    end
    function api.InitialSnapshot()
        return G.Run(function()
            G.Required(content.npcs,U.Array,"npcs")
            local initial={npcs={},flags={}}
            for _,npc in ipairs(content.npcs) do
                G.Required(npc.initialState,G.Table,"npcs.initialState")
                initial.npcs[npc.id]=U.Copy(npc.initialState)
            end
            return G.Value(api.ValidateSnapshot(initial))
        end)
    end
    function api.Restore(snapshot)
        local valid=api.ValidateSnapshot(snapshot)
        if valid.ok then state=U.Copy(valid.value) end
        return valid
    end
    function api.GetSnapshot() return state and U.Copy(state) or nil end

    -- context={letterId,orderId,day,facts?}；facts 是此前输入事实，绝非本批生成事实。
    -- rules 可省略，省略时使用统一 content.directRules；显式值必须等于配置中的该规则集。
    function api.Simulate(snapshot,potion,context,rules)
        return G.Run(function()
            local world=G.Value(api.ValidateSnapshot(snapshot))
            G.Pure(context,"context")
            G.Keys(context,{letterId=true,orderId=true,day=true,facts=true},"context")
            G.Need(U.String(context.orderId) and U.Integer(context.day,1),"INVALID_REQUEST","context","缺少订单 ID 或正式天数")
            local letter=G.Known(content,"letters",context.letterId,"context.letterId")
            G.Need(letter.kind=="order","INVALID_ORDER_STATE","context.letterId","只有订单可计算发货后果")
            local evaluation=G.Value(require("v035.systems.Order").New(content).Evaluate(letter.requirement,potion))
            G.Need(evaluation.canShip,"INVALID_ORDER_STATE","potion","字面失败不能产生发货后果",{failures=evaluation.failures})
            G.Required(letter.directRuleSetId,U.String,"letter.directRuleSetId")
            local selected={}
            G.Required(content.directRules,U.Array,"directRules")
            for _,rule in ipairs(content.directRules) do
                if rule.ruleSetId==letter.directRuleSetId then selected[#selected+1]=rule end
            end
            G.Need(#selected>0,"CONTENT_UNCOVERED","directRules","订单事实规则集为空")
            if rules~=nil then G.Need(U.Equal(rules,selected),"CONFIG_INVALID","rules","显式规则须对应订单的配置规则集") end
            G.Pure(selected,"directRules","CONFIG_INVALID")
            local priorFacts=context.facts
            if priorFacts==nil then priorFacts={} end
            local _,priorValues=R.Facts(priorFacts,content)
            local sources={world=world,potion=potion,context=context,facts=priorValues}
            local facts,writes={},{}
            table.sort(selected,function(a,b)
                G.Required(a.priority,G.Finite,"directRules.priority"); G.Required(b.priority,G.Finite,"directRules.priority")
                if a.priority~=b.priority then return a.priority>b.priority end
                return a.id<b.id
            end)
            for _,rule in ipairs(selected) do
                local path="directRules." .. rule.id
                G.Keys(rule,{id=true,ruleSetId=true,priority=true,desc=true,when=true,unless=true,facts=true,changes=true},path,"CONFIG_INVALID")
                G.Required(rule.priority,G.Finite,path .. ".priority")
                local matched,_,whenEvidence=R.Conditions(rule.when,sources,content,path .. ".when")
                local _,excluded,unlessEvidence=R.Conditions(rule.unless,sources,content,path .. ".unless",true)
                G.Required(rule.changes,U.Array,path .. ".changes")
                if matched and not excluded then
                    for _,definition in ipairs(rule.facts) do
                        local fact=U.Copy(definition)
                        fact.sourceRuleId=rule.id
                        fact.inputs={potionEffects=U.Copy(potion.effects),subjectState=U.Copy(world.npcs[fact.subjectId]),
                            context=U.Copy(context),when=whenEvidence,unless=unlessEvidence}
                        facts[#facts+1]=fact
                    end
                    for _,change in ipairs(rule.changes) do
                        G.Keys(change,{path=true,op=true,value=true},path .. ".changes","CONFIG_INVALID")
                        G.Need(U.String(change.path) and change.path:sub(1,11)=="world.npcs.","CONFIG_INVALID",path .. ".changes.path","只能修改已声明人物字段")
                        local before=R.Read({world=world},change.path,"CONFIG_INVALID")
                        G.Need(type(before)~="table" and change.value~=nil and type(change.value)~="table","CONFIG_INVALID",change.path,"变化须指向已声明标量字段")
                        G.Need(change.op=="set" or change.op=="add","CONFIG_INVALID",change.path,"未知变化运算")
                        local write=writes[change.path]
                        if write then
                            G.Need(write.op==change.op and (change.op=="add" or U.Equal(write.value,change.value)),"NARRATIVE_CONFLICT",change.path,"同字段变化冲突")
                        else write={path=change.path,op=change.op,value=change.op=="add" and 0 or U.Copy(change.value),before=U.Copy(before),sourceRuleIds={}}; writes[change.path]=write end
                        if change.op=="add" then
                            G.Need(G.Finite(before) and G.Finite(change.value),"CONFIG_INVALID",change.path,"add 只支持已声明数值字段")
                            write.value=write.value+change.value
                            G.Need(G.Finite(write.value),"CONFIG_INVALID",change.path,"变化累计溢出")
                        end
                        write.sourceRuleIds[#write.sourceRuleIds+1]=rule.id
                    end
                end
            end
            R.Facts(facts,content)
            G.Need(#facts>0,"CONTENT_UNCOVERED","facts","没有事实规则覆盖此结果")
            table.sort(facts,function(a,b) return a.id<b.id end)
            local candidate=U.Copy(world)
            local changes={}
            for _,path in ipairs(G.Sorted(writes)) do
                local write=writes[path]
                local parts=R.Path(path)
                local owner={world=candidate}
                for i=1,#parts-1 do owner=owner[parts[i]] end
                local after
                if write.op=="add" then after=write.before+write.value else after=U.Copy(write.value) end
                owner[parts[#parts]]=after
                write.after=U.Copy(after)
                changes[#changes+1]=write
            end
            G.Value(api.ValidateSnapshot(candidate))
            return {world=candidate,facts=U.Copy(facts),worldChanges=changes}
        end)
    end
    return api
end

local live=WorldState.New(require "v035.data.content")
for _,name in ipairs({"InitialSnapshot","ValidateSnapshot","Restore","GetSnapshot","Simulate"}) do WorldState[name]=live[name] end
return WorldState
