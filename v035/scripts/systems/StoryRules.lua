-- B4 共享纯规则：显式来源、事实存在性与文字绑定。没有状态或事件。
local U=require "core.StateUtil"
local G=require "systems.CalculationGuard"
local R={}

function R.Ids(value,path,optional)
    if value==nil and optional then return {} end
    G.Required(value,U.Array,path)
    local seen={}
    for _,id in ipairs(value) do
        G.Need(U.String(id) and not seen[id],"CONFIG_INVALID",path,"ID 缺失或重复")
        seen[id]=true
    end
    return seen
end

function R.Path(path)
    G.Need(U.String(path) and not path:find("^%.") and not path:find("%.$") and not path:find("%.%."),"CONFIG_INVALID","path","字段路径无效")
    local parts={}
    for part in path:gmatch("[^.]+") do parts[#parts+1]=part end
    return parts
end

function R.Read(root,path,code)
    local value=root
    for _,part in ipairs(R.Path(path)) do
        G.Need(type(value)=="table" and value[part]~=nil,code or "FILL_SOURCE_MISSING",path,"缺少字段来源")
        value=value[part]
    end
    return value
end

function R.Source(binding,sources,content)
    G.Keys(binding,{source=true,path=true},"binding","CONFIG_INVALID")
    local allowed={ ["potion.effects"]=true,["world.npcs"]=true,context=true,facts=true }
    G.Need(allowed[binding.source]==true,"CONFIG_INVALID","binding.source","不支持的来源")
    local parts=R.Path(binding.path)
    if binding.source=="potion.effects" then
        G.Need(#parts==1,"CONFIG_INVALID",binding.path,"效果路径须为标签 ID")
        G.Known(content,"effects",binding.path,"binding.path")
        local effects=R.Read(sources,"potion.effects")
        local value=effects[binding.path]
        if value==nil then return 0 end -- 仅已声明但本锅缺失的效果允许零权重。
        return value
    end
    return R.Read(R.Read(sources,binding.source),binding.path)
end

function R.Conditions(conditions,sources,content,path,optional)
    if conditions==nil and optional then return true,false,{} end
    G.Required(conditions,U.Array,path)
    local all,any,evidence=true,false,{}
    for i,c in ipairs(conditions) do
        local p=path .. "." .. i
        G.Keys(c,{source=true,path=true,op=true,value=true},p,"CONFIG_INVALID")
        G.Need(c.value~=nil and type(c.value)~="table","CONFIG_INVALID",p,"比较值须为标量")
        local actual=R.Source({source=c.source,path=c.path},sources,content)
        G.Need(type(actual)==type(c.value),"CONFIG_INVALID",p,"比较来源和值类型不符")
        local matched=false
        if c.op=="eq" then matched=actual==c.value
        elseif c.op=="ne" then matched=actual~=c.value
        elseif c.op=="gte" or c.op=="lte" then
            G.Need(G.Finite(actual) and G.Finite(c.value),"CONFIG_INVALID",p,"范围比较须使用有限数值")
            matched=c.op=="gte" and actual>=c.value or c.op=="lte" and actual<=c.value
        else G.Need(false,"CONFIG_INVALID",p .. ".op","未知比较运算") end
        all=all and matched; any=any or matched
        evidence[#evidence+1]={source=c.source,path=c.path,op=c.op,expected=U.Copy(c.value),actual=U.Copy(actual),matched=matched}
    end
    return all,any,evidence
end

function R.FactDefinitions(content)
    ---@type table<string, table>
    local result={}
    local ruleIds={}
    G.Required(content.directRules,U.Array,"directRules")
    for _,rule in ipairs(content.directRules) do
        G.Need(type(rule)=="table" and U.String(rule.id) and not ruleIds[rule.id],"CONFIG_INVALID","directRules","规则 ID 无效或重复")
        ruleIds[rule.id]=true
        G.Required(rule.facts,U.Array,"directRules." .. rule.id .. ".facts")
        for _,fact in ipairs(rule.facts) do
            G.Keys(fact,{id=true,subjectId=true,objectId=true,value=true,important=true},"facts","CONFIG_INVALID")
            G.Need(U.String(fact.id) and type(fact.important)=="boolean" and fact.value~=nil,"CONFIG_INVALID","facts","事实定义不完整")
            G.Pure(fact,"facts","CONFIG_INVALID")
            local npc=G.Known(content,"npcs",fact.subjectId,"facts.subjectId")
            if fact.objectId~=nil then
                G.Need(U.String(fact.objectId) and type(npc.initialState)=="table" and type(npc.initialState.memories)=="table" and npc.initialState.memories[fact.objectId]~=nil,"CONFIG_INVALID","facts.objectId","私人记忆对象未声明")
            end
            local entry=rawget(result,fact.id)
            if entry then
                G.Need(U.Equal(entry.definition,fact),"NARRATIVE_CONFLICT","facts." .. fact.id,"同名事实定义冲突")
            else entry={definition=fact,rules={}}; result[fact.id]=entry end
            entry.rules[rule.id]=true
        end
    end
    return result
end

function R.Facts(facts,content)
    G.Pure(facts,"facts"); G.Array(facts,"facts")
    local definitions=R.FactDefinitions(content)
    local index,values={},{}
    for _,fact in ipairs(facts) do
        G.Keys(fact,{id=true,subjectId=true,objectId=true,value=true,important=true,sourceRuleId=true,inputs=true},"facts")
        local entry=definitions[fact.id]
        G.Need(entry~=nil and not index[fact.id],"NARRATIVE_CONFLICT","facts","事实未知或重复")
        if not entry then error(U.Error("NARRATIVE_CONFLICT","facts","事实未声明"),0) end
        local definition=U.Copy(fact); definition.sourceRuleId=nil; definition.inputs=nil
        G.Need(U.Equal(definition,entry.definition) and entry.rules[fact.sourceRuleId]==true,"FILL_SOURCE_MISSING","facts." .. fact.id,"事实与声明或规则来源不符")
        G.Need(type(fact.inputs)=="table" and next(fact.inputs)~=nil,"FILL_SOURCE_MISSING","facts." .. fact.id .. ".inputs","缺少事实输入依据")
        index[fact.id]=fact; values[fact.id]=U.Copy(fact.value)
    end
    G.Required(content.factExclusionGroups,U.Array,"factExclusionGroups")
    for _,group in ipairs(content.factExclusionGroups) do
        local ids=R.Ids(group.factIds,"factExclusionGroups.factIds")
        local count=0
        for id in pairs(ids) do
            G.Need(definitions[id]~=nil,"CONFIG_INVALID","factExclusionGroups","互斥事实未声明")
            if index[id]~=nil then count=count+1 end
        end
        G.Need(count<=1,"NARRATIVE_CONFLICT","factExclusionGroups." .. tostring(group.id),"互斥事实同时成立")
    end
    return index,values,definitions
end

---@return boolean
function R.Matches(rule,index,definitions,path)
    local required=R.Ids(rule.requiresFacts,path .. ".requiresFacts")
    local excluded=R.Ids(rule.excludesFacts,path .. ".excludesFacts",true)
    local matched=true
    for id in pairs(required) do
        G.Need(definitions[id]~=nil and not excluded[id],"CONFIG_INVALID",path,"事实引用不存在或条件矛盾")
        if index[id]==nil then matched=false end
    end
    for id in pairs(excluded) do
        G.Need(definitions[id]~=nil,"CONFIG_INVALID",path,"排除事实未声明")
        if index[id]~=nil then matched=false end
    end
    return matched
end

-- 成功返回已经填好的文本及实际采用的绑定值；false 也是真实来源。
function R.Render(text,bindings,sources,content,path)
    G.Need(U.String(text),"CONTENT_UNCOVERED",path,"缺少正文")
    if bindings==nil then bindings={} end
    G.Keys(bindings,bindings,path .. ".bindings","CONFIG_INVALID")
    local used,values={},{}
    local rendered=text:gsub("{{(.-)}}",function(name)
        local binding=bindings[name]
        G.Need(U.String(name) and binding~=nil,"FILL_SOURCE_MISSING",path .. "." .. name,"占位符缺少绑定")
        local value=R.Source(binding,sources,content)
        G.Need((type(value)=="string" and value~="") or type(value)=="boolean" or G.Finite(value),"FILL_SOURCE_MISSING",path .. "." .. name,"填充值不能是空值或对象")
        used[name]=true; values[name]=U.Copy(value)
        return tostring(value)
    end)
    for name in pairs(bindings) do G.Need(used[name],"CONFIG_INVALID",path .. ".bindings","绑定没有对应占位符") end
    G.Need(not rendered:find("{{",1,true) and not rendered:find("}}",1,true),"FILL_SOURCE_MISSING",path,"存在未解决占位符")
    return rendered,values
end

return R
