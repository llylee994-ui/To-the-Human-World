-- 独立八步求值。输入由 Order.ResolveRecipe 解析；本模块仍独立检查槽位与配置。
-- 所有公开接口返回 Result；不持有/安装状态，不读取库存，不保存或发送事件。
local U = require "core.StateUtil"
local G = require "systems.CalculationGuard"
local Potion = {}
local MODS={intensity=true,duration=true,speed=true,stability=true,sideEffect=true}

local function weights(values,content,path,positive)
    G.Required(values,G.Table,path)
    for id, weight in pairs(values) do
        G.Known(content,"effects",id,path .. "." .. tostring(id))
        G.Need(G.Finite(weight) and (not positive or weight>0),"CONFIG_INVALID",path .. "." .. id,"效果权重须为有限数值")
    end
end
local function policy(content,key,repeated)
    local rules=content.stage1 and content.stage1.recipePolicy
    ---@type boolean|nil
    local value
    -- false 是合法的显式禁止，不能用 and/or 取值覆盖它。
    if type(rules)=="table" then value=rules[key] end
    if repeated then
        G.Need(value~=nil,"DUPLICATE_POLICY_MISSING","stage1.recipePolicy." .. key,"缺少重复投料策略")
        G.Need(type(value)=="boolean","CONFIG_INVALID","stage1.recipePolicy." .. key,"重复策略须为布尔值")
        G.Need(value,"DUPLICATE_NOT_ALLOWED","recipe","当前配置禁止同种投料",{policy=key})
    elseif value~=nil then
        G.Need(type(value)=="boolean","CONFIG_INVALID","stage1.recipePolicy." .. key,"重复策略须为布尔值")
    end
end
local function validateResolved(recipe,content)
    G.Required(content,G.Table,"content")
    G.Pure(recipe,"resolvedRecipe")
    G.Keys(recipe,{orderId=true,baselineId=true,contentVersion=true,equipment=true,main=true,aux=true,ingredients=true,specialItems=true},"resolvedRecipe")
    G.Need(U.String(recipe.orderId) and U.String(recipe.baselineId),"INVALID_REQUEST","resolvedRecipe","缺少订单或基准 ID")
    G.Required(content.contentVersion,U.String,"contentVersion")
    G.Need(recipe.contentVersion==content.contentVersion,"CONTENT_VERSION_MISMATCH","resolvedRecipe.contentVersion","内容版本不相容")
    G.Need(type(recipe.equipment)=="table","INVALID_REQUEST","equipment","缺少设备定义")
    local equipment=G.Known(content,"equipment",recipe.equipment.id,"equipment.id")
    G.Need(U.Equal(recipe.equipment,equipment),"INVALID_REQUEST","equipment","设备定义与当前配置不符")
    local slots=G.Required(equipment.slots,G.Table,"equipment.slots")
    G.Keys(slots,{mainWord=true,auxWord=true,ingredient=true,specialItem=true},"equipment.slots","CONFIG_INVALID")
    for _, key in ipairs({"mainWord","auxWord","ingredient","specialItem"}) do G.Required(slots[key],U.Integer,"equipment.slots." .. key) end
    G.Array(recipe.aux,"aux"); G.Array(recipe.ingredients,"ingredients"); G.Array(recipe.specialItems,"specialItems")
    G.Need(type(recipe.main)=="table","INVALID_REQUEST","main","必须选择一个主词")
    G.Need(slots.mainWord>=1 and #recipe.aux<=slots.auxWord,"SLOT_LIMIT","words","词条槽位超限")
    G.Need(#recipe.specialItems<=slots.specialItem,"SLOT_LIMIT","specialItems","特殊物品槽位超限")
    local usedTokens,usedWords={},{}
    local function word(ref,path)
        G.Keys(ref,{tokenId=true,definition=true,source=true},path)
        G.Need(U.String(ref.tokenId) and type(ref.definition)=="table","INVALID_REQUEST",path,"词条引用不完整")
        G.Need(not usedTokens[ref.tokenId],"DUPLICATE_TOKEN",path,"同一实例不能同时占多个槽")
        usedTokens[ref.tokenId]=true
        local definition=G.Known(content,"words",ref.definition.id,path .. ".definition.id")
        G.Need(U.Equal(definition,ref.definition),"INVALID_REQUEST",path .. ".definition","词定义与当前配置不符")
        G.Keys(ref.source,{wordId=true,sourceLetterInstanceId=true,sourceSpanId=true,sourceNpcId=true},path .. ".source")
        for _, key in ipairs({"wordId","sourceLetterInstanceId","sourceSpanId","sourceNpcId"}) do
            G.Need(U.String(ref.source[key]),"INVALID_REQUEST",path .. ".source." .. key,"缺少词条来源")
        end
        G.Need(ref.source.wordId==definition.id,"SOURCE_INVALID",path .. ".source.wordId","词定义与来源不符")
        policy(content,"repeatWordDefinition",usedWords[definition.id]==true)
        usedWords[definition.id]=true
        weights(definition.effects,content,"words." .. definition.id .. ".effects")
    end
    word(recipe.main,"main")
    for i, ref in ipairs(recipe.aux) do word(ref,"aux." .. i) end
    local quantity,usedIngredients=0,{}
    for i, item in ipairs(recipe.ingredients) do
        local path="ingredients." .. i
        G.Keys(item,{ingredientId=true,quantity=true,definition=true},path)
        G.Need(U.Integer(item.quantity,1),"INVALID_REQUEST",path .. ".quantity","原料份数须为正整数")
        local definition=G.Known(content,"ingredients",item.ingredientId,path .. ".ingredientId")
        G.Need(not usedIngredients[item.ingredientId],"INVALID_REQUEST",path,"原料必须按 ID 聚合，不能重复行")
        usedIngredients[item.ingredientId]=true
        G.Need(U.Equal(definition,item.definition),"INVALID_REQUEST",path .. ".definition","原料定义与当前配置不符")
        quantity=quantity+item.quantity
        G.Need(U.Integer(quantity) and quantity<=slots.ingredient,"SLOT_LIMIT","ingredients","原料份数超过槽位",{used=quantity,limit=slots.ingredient})
        policy(content,"repeatIngredient",item.quantity>1)
        G.Required(definition.mods,G.Table,path .. ".mods")
        G.Keys(definition.mods,MODS,path .. ".mods","CONFIG_INVALID")
        for key, value in pairs(definition.mods) do
            G.Need(G.Finite(value) and value>=-4 and value<=4,"CONFIG_INVALID",path .. ".mods." .. key,"原料单项修正须在 -4～4 内")
        end
        weights(definition.addTags,content,path .. ".addTags")
    end
    G.Need(#recipe.specialItems==0,"CONFIG_MISSING","specialItems.synthesis","当前内容尚未声明特殊物品合成规则")
    return U.Copy(recipe)
end
function Potion.ValidateResolvedRecipe(recipe,content)
    return G.Run(function() return validateResolved(recipe,content) end)
end

local function synthesisConfig(content)
    local config=G.Required(content.synthesis,G.Table,"synthesis")
    G.Pure(config,"synthesis","CONFIG_INVALID")
    G.Required(config.version,function(v) return U.Integer(v,1) or U.String(v) end,"synthesis.version")
    for _, key in ipairs({"auxWeight","sameTagBonus","intensityScale","unstableThreshold"}) do G.Required(config[key],G.Finite,"synthesis." .. key) end
    G.Required(config.intensityTiers,U.Array,"synthesis.intensityTiers")
    G.Need(#config.intensityTiers>0,"CONFIG_MISSING","synthesis.intensityTiers","缺少强度区间")
    local previous=-math.huge
    for i, tier in ipairs(config.intensityTiers) do
        G.Need(type(tier)=="table" and G.Finite(tier.max) and tier.max>previous and U.String(tier.label),"CONFIG_INVALID","synthesis.intensityTiers." .. i,"区间必须递增且具有分级名称")
        previous=tier.max
    end
    G.Required(config.sideEffectRules,U.Array,"synthesis.sideEffectRules")
    local used={}
    for i, rule in ipairs(config.sideEffectRules) do
        local path="synthesis.sideEffectRules." .. i
        G.Need(type(rule)=="table" and U.String(rule.id) and not used[rule.id] and G.Finite(rule.minSideEffect),"CONFIG_INVALID",path,"副作用规则缺少唯一 ID 或阈值")
        used[rule.id]=true
        weights(rule.addTags,content,path .. ".addTags")
    end
    return config
end
local function grade(effects,config)
    local tiers={}
    for _, id in ipairs(G.Sorted(effects)) do
        local value=effects[id]
        G.Need(G.Finite(value),"CONFIG_INVALID","effects." .. id,"权重计算溢出")
        if value<=0 then effects[id]=nil
        else
            for _, tier in ipairs(config.intensityTiers) do if value<=tier.max then tiers[id]=tier.label; break end end
            G.Need(tiers[id]~=nil,"CONFIG_INVALID","synthesis.intensityTiers","强度区间未覆盖结果",{effectId=id,weight=value})
        end
    end
    return tiers
end
local function timeValues(main,mods,effects,content)
    local id=G.Required(main.definition.attributeProfileId,U.String,"words." .. main.definition.id .. ".attributeProfileId")
    local profiles=content.attributeProfiles or (content.stage1 and content.stage1.attributeProfiles)
    local profile=G.Known({attributeProfiles=profiles},"attributeProfiles",id,"attributeProfileId")
    G.Pure(profile,"attributeProfiles." .. id,"CONFIG_INVALID")
    for _, key in ipairs({"baseDurationHours","durationHoursPerPoint","recoveryAfterEndHours"}) do G.Required(profile[key],G.Nonnegative,"attributeProfiles." .. id .. "." .. key) end
    local duration=profile.baseDurationHours+mods.duration*profile.durationHoursPerPoint
    G.Need(G.Nonnegative(duration),"CONFIG_INVALID","durationHours","时间换算得到负数或溢出")
    G.Required(profile.speedToDelayHours,U.Array,"attributeProfiles." .. id .. ".speedToDelayHours")
    ---@type number|nil
    local delay
    local seen={}
    for i, item in ipairs(profile.speedToDelayHours) do
        local path="attributeProfiles." .. id .. ".speedToDelayHours." .. i
        G.Need(type(item)=="table" and G.Finite(item.speed) and G.Nonnegative(item.delayHours),"CONFIG_INVALID",path,"速度/延迟映射非法")
        G.Need(not seen[item.speed],"CONFIG_INVALID",path,"速度映射重复")
        seen[item.speed]=true
        if item.speed==mods.speed then delay=item.delayHours end
    end
    G.Need(delay~=nil,"CONFIG_MISSING","attributeProfiles." .. id .. ".speedToDelayHours","没有该速度的精确映射",{speed=mods.speed})
    local ending=assert(delay)+duration
    G.Need(G.Nonnegative(ending),"CONFIG_INVALID","time","药效结束时刻溢出")
    G.Required(profile.residualRules,U.Array,"attributeProfiles." .. id .. ".residualRules")
    local residuals,known={},{}
    for i, rule in ipairs(profile.residualRules) do
        local path="attributeProfiles." .. id .. ".residualRules." .. i
        G.Need(type(rule)=="table","CONFIG_INVALID",path,"残留规则须为对象")
        G.Known(content,"effects",rule.effectId,path .. ".effectId")
        G.Need(not known[rule.effectId],"CONFIG_INVALID",path,"残留标签重复")
        known[rule.effectId]=true
        G.Required(rule.points,U.Array,path .. ".points")
        G.Need(#rule.points>0,"CONFIG_MISSING",path .. ".points","残留采样点为空")
        local ratio=1
        for j, point in ipairs(rule.points) do
            G.Need(type(point)=="table" and point.hoursAfterEnd==j-1 and G.Nonnegative(point.ratio) and point.ratio<=ratio,"CONFIG_INVALID",path .. ".points." .. j,"残留点须从 0 逐小时连续、比例在 0～1 内且非增")
            ratio=point.ratio
            local weight=(effects[rule.effectId] or 0)*ratio
            local at=ending+point.hoursAfterEnd
            G.Need(G.Nonnegative(weight) and G.Nonnegative(at),"CONFIG_INVALID",path,"残留计算溢出")
            residuals[#residuals+1]={effectId=rule.effectId,weight=weight,untilAfterDoseHours=at}
        end
    end
    table.sort(residuals,function(a,b) if a.effectId==b.effectId then return a.untilAfterDoseHours<b.untilAfterDoseHours end return a.effectId<b.effectId end)
    return duration,delay,profile.recoveryAfterEndHours,residuals
end

function Potion.Calculate(resolvedRecipe,content)
    return G.Run(function()
        local recipe=validateResolved(resolvedRecipe,content)
        local config=synthesisConfig(content)
        local effects,trace={},{}
        local function record(step,inputs,outputs,sourceIds)
            local ids,seen={},{}
            for _, id in ipairs(sourceIds) do if not seen[id] then ids[#ids+1]=id; seen[id]=true end end
            trace[#trace+1]={step=step,inputs=U.Copy(inputs),outputs=U.Copy(outputs),sourceIds=ids}
        end
        effects=U.Copy(recipe.main.definition.effects)
        record(1,{main=recipe.main},effects,{recipe.main.definition.id})
        local before,sourceIds=U.Copy(effects),{}
        for _, ref in ipairs(recipe.aux) do
            sourceIds[#sourceIds+1]=ref.definition.id
            for _, id in ipairs(G.Sorted(ref.definition.effects)) do
                local bonus=effects[id]~=nil and config.sameTagBonus or 0
                effects[id]=(effects[id] or 0)+ref.definition.effects[id]*config.auxWeight+bonus
            end
        end
        record(2,{effects=before,aux=recipe.aux,auxWeight=config.auxWeight,sameTagBonus=config.sameTagBonus},effects,sourceIds)
        before,sourceIds=U.Copy(effects),{}
        for _, item in ipairs(recipe.ingredients) do
            sourceIds[#sourceIds+1]=item.ingredientId
            for _, id in ipairs(G.Sorted(item.definition.addTags)) do effects[id]=(effects[id] or 0)+item.definition.addTags[id]*config.auxWeight*item.quantity end
        end
        record(3,{effects=before,ingredients=recipe.ingredients,auxWeight=config.auxWeight},effects,sourceIds)
        ---@type table<string,number>
        local mods={intensity=0,duration=0,speed=0,stability=0,sideEffect=0}
        for _, item in ipairs(recipe.ingredients) do
            for key, value in pairs(item.definition.mods) do mods[key]=mods[key]+value*item.quantity end
        end
        for key, value in pairs(mods) do G.Need(G.Finite(value),"CONFIG_INVALID","mods." .. key,"属性计算溢出") end
        record(4,{ingredients=recipe.ingredients},mods,sourceIds)
        before=U.Copy(effects)
        local scale=1+mods.intensity*config.intensityScale
        G.Need(G.Nonnegative(scale),"CONFIG_INVALID","synthesis.intensityScale","强度缩放系数为负或溢出")
        for id, value in pairs(effects) do
            local scaled=value*scale
            G.Need(G.Finite(scaled),"CONFIG_INVALID","effects." .. id,"标签权重溢出")
            effects[id]=scaled>0 and scaled or nil
        end
        record(5,{effects=before,intensity=mods.intensity,intensityScale=config.intensityScale,scale=scale},effects,{})
        local tiers=grade(effects,config)
        record(6,{effects=effects,intensityTiers=config.intensityTiers},tiers,{})
        before,sourceIds=U.Copy(effects),{}
        local sideEffects={}
        for _, rule in ipairs(config.sideEffectRules) do
            if mods.sideEffect>=rule.minSideEffect then
                sourceIds[#sourceIds+1]=rule.id
                sideEffects[#sideEffects+1]={ruleId=rule.id,addTags=U.Copy(rule.addTags)}
                for _, id in ipairs(G.Sorted(rule.addTags)) do effects[id]=(effects[id] or 0)+rule.addTags[id] end
            end
        end
        tiers=grade(effects,config)
        record(7,{effects=before,sideEffect=mods.sideEffect,rules=config.sideEffectRules},{effects=effects,intensityByEffect=tiers,sideEffects=sideEffects},sourceIds)
        local unstable=mods.stability<config.unstableThreshold
        record(8,{stability=mods.stability,unstableThreshold=config.unstableThreshold},{stability=mods.stability,unstable=unstable},{})
        local duration,onset,recovery,residuals=timeValues(recipe.main,mods,effects,content)
        return {synthesisVersion=config.version,contentVersion=content.contentVersion,effects=effects,intensityByEffect=tiers,
            mods=mods,durationHours=duration,onsetDelayHours=onset,recoveryAfterEndHours=recovery,residuals=residuals,
            stability=mods.stability,unstable=unstable,sideEffects=sideEffects,trace=trace}
    end)
end

-- residuals 保留声明的采样点；untilAfterDoseHours 是该点的服药后时刻，不隐式插值。
local function residualPoints(potion,effectId)
    local points={}
    local ending=potion.onsetDelayHours+potion.durationHours
    for _, point in ipairs(potion.residuals) do if point.effectId==effectId then points[#points+1]=point end end
    table.sort(points,function(a,b) return a.untilAfterDoseHours<b.untilAfterDoseHours end)
    local previous=potion.effects[effectId] or 0
    for i, point in ipairs(points) do
        G.Need(G.Nonnegative(point.weight) and point.weight<=previous and point.untilAfterDoseHours==ending+i-1,"INVALID_REQUEST","potion.residuals","残留点不连续、为负或递增")
        previous=point.weight
    end
    return points
end
function Potion.ValidateResult(potion,content)
    return G.Run(function()
        G.Required(content,G.Table,"content")
        G.Pure(potion,"potion")
        G.Keys(potion,{synthesisVersion=true,contentVersion=true,effects=true,intensityByEffect=true,mods=true,durationHours=true,onsetDelayHours=true,recoveryAfterEndHours=true,residuals=true,stability=true,unstable=true,sideEffects=true,trace=true},"potion")
        G.Need(potion.contentVersion==content.contentVersion,"CONTENT_VERSION_MISMATCH","potion.contentVersion","内容版本不相容")
        local config=synthesisConfig(content)
        G.Need(potion.synthesisVersion==config.version,"CONTENT_VERSION_MISMATCH","potion.synthesisVersion","计算规则版本不相容")
        weights(potion.effects,content,"potion.effects",true)
        G.Need(U.Equal(grade(U.Copy(potion.effects),config),potion.intensityByEffect),"INVALID_REQUEST","potion.intensityByEffect","分级与最终权重不符")
        G.Keys(potion.mods,MODS,"potion.mods")
        for key in pairs(MODS) do G.Need(G.Finite(potion.mods[key]),"INVALID_REQUEST","potion.mods." .. key,"缺少有限修正值") end
        for _, key in ipairs({"durationHours","onsetDelayHours","recoveryAfterEndHours"}) do G.Need(G.Nonnegative(potion[key]),"INVALID_REQUEST","potion." .. key,"缺少非负时间") end
        G.Need(G.Nonnegative(potion.onsetDelayHours+potion.durationHours+potion.recoveryAfterEndHours),"INVALID_REQUEST","potion.time","时间总和溢出")
        G.Need(potion.stability==potion.mods.stability and potion.unstable==(potion.stability<config.unstableThreshold),"INVALID_REQUEST","potion.stability","稳定性提示与修正不符")
        G.Array(potion.residuals,"potion.residuals")
        local sampled={}
        for _, point in ipairs(potion.residuals) do
            G.Keys(point,{effectId=true,weight=true,untilAfterDoseHours=true},"potion.residuals")
            G.Known(content,"effects",point.effectId,"potion.residuals.effectId")
            G.Need(G.Nonnegative(point.weight) and G.Nonnegative(point.untilAfterDoseHours),"INVALID_REQUEST","potion.residuals","残留数值非法")
            sampled[point.effectId]=true
        end
        for id in pairs(sampled) do residualPoints(potion,id) end
        G.Array(potion.sideEffects,"potion.sideEffects")
        local rules={}
        for _, rule in ipairs(potion.sideEffects) do
            G.Keys(rule,{ruleId=true,addTags=true},"potion.sideEffects")
            local definition=G.Known({rules=config.sideEffectRules},"rules",rule.ruleId,"potion.sideEffects.ruleId")
            G.Need(not rules[rule.ruleId] and U.Equal(rule.addTags,definition.addTags),"INVALID_REQUEST","potion.sideEffects","副作用规则重复或定义不符")
            rules[rule.ruleId]=true
        end
        G.Array(potion.trace,"potion.trace")
        G.Need(#potion.trace==8,"INVALID_REQUEST","potion.trace","缺少八步计算记录")
        for i, row in ipairs(potion.trace) do
            G.Keys(row,{step=true,inputs=true,outputs=true,sourceIds=true},"potion.trace." .. i)
            G.Need(row.step==i and type(row.inputs)=="table" and type(row.outputs)=="table","INVALID_REQUEST","potion.trace." .. i,"计算记录顺序或结构错误")
            G.Array(row.sourceIds,"potion.trace.sourceIds")
            local seen={}
            for _, id in ipairs(row.sourceIds) do
                G.Need(U.String(id) and not seen[id],"INVALID_REQUEST","potion.trace.sourceIds","配置来源 ID 为空或重复")
                seen[id]=true
            end
        end
        return U.Copy(potion)
    end)
end
function Potion.SampleResidual(potion,effectId,atAfterDoseHours,content)
    return G.Run(function()
        G.Value(Potion.ValidateResult(potion,content))
        G.Known(content,"effects",effectId,"effectId")
        G.Need(G.Nonnegative(atAfterDoseHours),"INVALID_REQUEST","atAfterDoseHours","采样时间须为非负有限游戏小时")
        local points=residualPoints(potion,effectId)
        G.Need(#points>0,"CONFIG_MISSING","residuals." .. effectId,"没有该标签的残留配置")
        if atAfterDoseHours<points[1].untilAfterDoseHours then return potion.effects[effectId] or 0 end
        if atAfterDoseHours>points[#points].untilAfterDoseHours then return 0 end
        for _, point in ipairs(points) do if point.untilAfterDoseHours==atAfterDoseHours then return point.weight end end
        error(U.Error("CONFIG_MISSING","residuals." .. effectId,"采样时间不在已声明点上",{atAfterDoseHours=atAfterDoseHours}),0)
    end)
end
return Potion
