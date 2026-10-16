-- B3 配方/字面计算与 B4 评分；B5 生命周期由 OrderLifecycle 经 GameState 提交。
local U = require "core.StateUtil"
local G = require "systems.CalculationGuard"
local Potion = require "systems.Potion"
local Story = require "systems.StoryRules"
local Order = {}

function Order.New(content,options)
    local words=require("systems.WordToken").New(content)
    local letters=require("systems.Letter").New(content)
    local economy=require("systems.Economy").New(content)
    local api={}

    -- baseline 为 B0 的 {id,revision,contentVersion,live} 副本，不读取任何模块内部状态。
    -- value={orderId,baselineId,contentVersion,equipment,main,aux,ingredients,specialItems}。
    -- main/aux 沿用 WordToken 引用，ingredients 行附 definition；本批 specialItems 只能为空。
    function api.ResolveRecipe(request,baseline)
        return G.Run(function()
            G.Pure(request,"recipe")
            G.Keys(request,{orderId=true,baselineId=true,equipmentId=true,mainTokenId=true,auxTokenIds=true,ingredients=true,specialItemIds=true},"recipe")
            for _, key in ipairs({"orderId","baselineId","equipmentId","mainTokenId"}) do
                G.Need(U.String(request[key]),"INVALID_REQUEST","recipe." .. key,"请求缺少有效 ID")
            end
            G.Array(request.auxTokenIds,"recipe.auxTokenIds")
            G.Array(request.ingredients,"recipe.ingredients")
            G.Array(request.specialItemIds,"recipe.specialItemIds")
            G.Pure(baseline,"baseline")
            G.Keys(baseline,{id=true,revision=true,contentVersion=true,live=true},"baseline")
            G.Need(U.String(baseline.id) and U.Integer(baseline.revision) and type(baseline.live)=="table","INVALID_REQUEST","baseline","基准结构不完整")
            G.Need(request.baselineId==baseline.id,"STALE_BASELINE","recipe.baselineId","请求不是当前基准")
            G.Required(content.contentVersion,U.String,"contentVersion")
            G.Need(baseline.contentVersion==content.contentVersion,"CONTENT_VERSION_MISMATCH","baseline.contentVersion","基准内容版本不相容")
            local live=baseline.live
            G.Need(type(live.orders)=="table" and type(live.orders.acceptedById)=="table" and type(live.orders.confirmedById)=="table","INVALID_ORDER_STATE","baseline.live.orders","缺少基准订单记录")
            local accepted=live.orders.acceptedById[request.orderId]
            G.Need(type(accepted)=="table" and live.orders.confirmedById[request.orderId]==nil,"INVALID_ORDER_STATE","recipe.orderId","订单未接取或已确认")
            G.Keys(accepted,{letterInstanceId=true,letterId=true,acceptedDay=true},"acceptedOrder")
            G.Need(U.String(accepted.letterInstanceId) and U.String(accepted.letterId) and U.Integer(accepted.acceptedDay,1),"INVALID_ORDER_STATE","acceptedOrder","接单记录不完整")
            local letterState=G.Value(letters.ValidateSnapshot(live.letters))
            local letter=letterState.byId[accepted.letterInstanceId]
            G.Need(letter and letter.read and letter.letterId==accepted.letterId,"INVALID_ORDER_STATE","acceptedOrder.letterInstanceId","订单信尚未收到/阅读或引用不符")
            G.Value(require("core.SaveSchema").ValidateLetterTokens(live.letters,live.wordTokens,{letters=letters,wordTokens=words}))
            local ledger=G.Value(economy.ValidateSnapshot(live.economy))
            local equipment=G.Known(content,"equipment",request.equipmentId,"recipe.equipmentId")
            G.Need(ledger.ownedEquipmentIds[request.equipmentId]==true,"INVALID_REQUEST","recipe.equipmentId","尚未拥有这台设备",{equipmentId=request.equipmentId})
            local refs=G.Value(words.ResolveRecipe(live.wordTokens,request))
            local ingredients,seen={},{}
            for i, item in ipairs(request.ingredients) do
                local path="recipe.ingredients." .. i
                G.Keys(item,{ingredientId=true,quantity=true},path)
                G.Need(U.Integer(item.quantity,1),"INVALID_REQUEST",path .. ".quantity","原料份数须为正整数")
                local definition=G.Known(content,"ingredients",item.ingredientId,path .. ".ingredientId")
                G.Need(not seen[item.ingredientId],"INVALID_REQUEST",path,"原料必须按 ID 聚合成一行")
                seen[item.ingredientId]=true
                ingredients[#ingredients+1]={ingredientId=item.ingredientId,quantity=item.quantity,definition=U.Copy(definition)}
            end
            -- 聚合原料没有语义顺序，按 ID 规范化；辅助词保持玩家给定顺序以遵守第 2 步。
            table.sort(ingredients,function(a,b) return a.ingredientId<b.ingredientId end)
            local specials,used={},{ }
            for i, id in ipairs(request.specialItemIds) do
                G.Need(U.String(id) and not used[id],"SPECIAL_ITEM_UNAVAILABLE","recipe.specialItemIds." .. i,"特殊物品 ID 非法或重复")
                used[id]=true
                local item=ledger.specialItems[id]
                G.Need(item and item.available and item.sourceLetterInstanceId==accepted.letterInstanceId,"SPECIAL_ITEM_UNAVAILABLE","recipe.specialItemIds." .. i,"物品不可用或不属于本信附件",{instanceId=id})
                local claimed=false
                for _, attachmentId in ipairs(letter.claimedAttachmentIds) do if attachmentId==item.itemId then claimed=true end end
                G.Need(claimed,"SPECIAL_ITEM_UNAVAILABLE","recipe.specialItemIds." .. i,"本信附件尚未领取")
                specials[#specials+1]={instanceId=id,item=U.Copy(item)}
            end
            local resolved={orderId=request.orderId,baselineId=request.baselineId,contentVersion=baseline.contentVersion,
                equipment=U.Copy(equipment),main=refs.main,aux=refs.aux,ingredients=ingredients,specialItems=specials}
            G.Value(Potion.ValidateResolvedRecipe(resolved,content))
            for _, item in ipairs(ingredients) do
                local available=ledger.ingredients[item.ingredientId] or 0
                G.Need(available>=item.quantity,"INVENTORY_SHORT","recipe.ingredients." .. item.ingredientId,"原料库存不足",{ingredientId=item.ingredientId,needed=item.quantity,available=available})
            end
            -- 使用 Economy 的公共纯候选验证消耗；零奖励为试算单位元，绝不安装候选。
            G.Value(economy.PlanSettlement(ledger,request.ingredients,request.specialItemIds,{currency=0}))
            return U.Copy(resolved)
        end)
    end

    -- 字面失败是 ok=true/canShip=false；无法求值的配置错误是 ok=false。
    -- tags 依 ID 排序，其余检查保留配置顺序。普通剧情只用主药效作门槛；
    -- 额外检查仍如实记录，以保留药性信息并兼容此前已保存的成功试做。
    function api.Evaluate(requirement,potion)
        return G.Run(function()
            G.Pure(requirement,"requirement","CONFIG_INVALID")
            G.Keys(requirement,{desc=true,tags=true,conditions=true,forbiddenEffects=true},"requirement","CONFIG_INVALID")
            G.Required(requirement.desc,U.String,"requirement.desc")
            G.Required(requirement.tags,G.Table,"requirement.tags")
            G.Required(requirement.conditions,U.Array,"requirement.conditions")
            G.Required(requirement.forbiddenEffects,U.Array,"requirement.forbiddenEffects")
            G.Value(Potion.ValidateResult(potion,content))
            local checks,failures,ids={},{},{}
            local primaryOnly=content.release and content.release.primaryEffectsOnly==true
            local function add(id,kind,passed,expected,actual,unit,message)
                G.Need(U.String(id) and not ids[id],"CONFIG_INVALID","requirement.id","判定 ID 缺失或重复",{id=id})
                ids[id]=true
                local check={id=id,kind=kind,passed=passed,expected=expected,actual=actual,unit=unit,message=message}
                checks[#checks+1]=check
                if not passed and (not primaryOnly or kind=="tag") then failures[#failures+1]=U.Copy(check) end
            end
            for id, minimum in pairs(requirement.tags) do
                G.Known(content,"effects",id,"requirement.tags." .. tostring(id))
                G.Need(G.Nonnegative(minimum),"CONFIG_INVALID","requirement.tags." .. id,"标签最低权重须为非负有限数")
            end
            for _, id in ipairs(G.Sorted(requirement.tags)) do
                local minimum,actual=requirement.tags[id],potion.effects[id] or 0
                add("tag." .. id,"tag",actual>=minimum,{min=minimum},actual,"weight",string.format("%s 权重至少 %g，实际 %g",id,minimum,actual))
            end
            local fields={
                duration={id=true,kind=true,minHours=true,maxHours=true},
                onset={id=true,kind=true,maxDelayHours=true},
                workReady={id=true,kind=true,workAfterDoseHours=true},
                residualAt={id=true,kind=true,effectId=true,atAfterDoseHours=true,maxWeight=true},
                forbiddenEffect={id=true,kind=true,effectId=true,maxWeight=true},
            }
            for i, condition in ipairs(requirement.conditions) do
                local path="requirement.conditions." .. i
                G.Need(type(condition)=="table" and U.String(condition.kind) and fields[condition.kind]~=nil,"CONFIG_INVALID",path,"未知判定类型")
                G.Keys(condition,fields[condition.kind],path,"CONFIG_INVALID")
                G.Required(condition.id,U.String,path .. ".id")
                local function number(key) return G.Required(condition[key],G.Nonnegative,path .. "." .. key) end
                if condition.kind=="duration" then
                    local minimum,maximum=number("minHours"),number("maxHours")
                    G.Need(minimum<=maximum,"CONFIG_INVALID",path,"持续时间上下限颠倒")
                    local actual=potion.durationHours
                    add(condition.id,condition.kind,actual>=minimum and actual<=maximum,{min=minimum,max=maximum},actual,"game_hour",string.format("持续时间须为 %g～%g 小时，实际 %g 小时",minimum,maximum,actual))
                elseif condition.kind=="onset" then
                    local maximum,actual=number("maxDelayHours"),potion.onsetDelayHours
                    add(condition.id,condition.kind,actual<=maximum,{max=maximum},actual,"game_hour",string.format("须在 %g 小时内生效，实际 %g 小时",maximum,actual))
                elseif condition.kind=="workReady" then
                    local maximum=number("workAfterDoseHours")
                    local actual=potion.onsetDelayHours+potion.durationHours+potion.recoveryAfterEndHours
                    add(condition.id,condition.kind,actual<=maximum,{max=maximum},actual,"game_hour",string.format("须在服药后 %g 小时前恢复，实际 %g 小时",maximum,actual))
                else
                    G.Known(content,"effects",condition.effectId,path .. ".effectId")
                    local maximum=number("maxWeight")
                    local actual=potion.effects[condition.effectId] or 0
                    if condition.kind=="residualAt" then actual=G.Value(Potion.SampleResidual(potion,condition.effectId,number("atAfterDoseHours"),content)) end
                    add(condition.id,condition.kind,actual<=maximum,{max=maximum},actual,"weight",string.format("%s 的%s权重至多 %g，实际 %g",condition.effectId,condition.kind=="residualAt" and "残留" or "最终",maximum,actual))
                end
            end
            for i, id in ipairs(requirement.forbiddenEffects) do
                G.Known(content,"effects",id,"requirement.forbiddenEffects." .. i)
                local actual=potion.effects[id] or 0
                add("forbidden." .. id,"forbiddenEffect",actual<=0,{max=0},actual,"weight",string.format("订单禁止 %s，实际权重 %g",id,actual))
            end
            return {canShip=#failures==0,checks=checks,failures=failures}
        end)
    end
    -- facts 来自已通过字面检查的 WorldState.Simulate；本函数不发货、不改变报酬。
    -- ratingConfig 为 ratingSetId，或该评分集的完整规则数组；不读取 sampleCases.expect。
    function api.Rate(facts,ratingConfig)
        return G.Run(function()
            local index,_,definitions=Story.Facts(facts,content)
            local rules={}
            G.Required(content.orderRatings,U.Array,"orderRatings")
            if type(ratingConfig)=="string" then
                for _,rule in ipairs(content.orderRatings) do if rule.ratingSetId==ratingConfig then rules[#rules+1]=rule end end
            else
                G.Pure(ratingConfig,"ratingConfig","CONFIG_INVALID")
                G.Array(ratingConfig,"ratingConfig","CONFIG_INVALID")
                G.Need(#ratingConfig>0,"RATING_UNCOVERED","ratingConfig","评分规则为空")
                G.Need(type(ratingConfig[1])=="table","CONFIG_INVALID","ratingConfig","评分规则须为对象")
                local setId=ratingConfig[1].ratingSetId
                for _,rule in ipairs(content.orderRatings) do if rule.ratingSetId==setId then rules[#rules+1]=rule end end
                G.Need(U.Equal(rules,ratingConfig),"CONFIG_INVALID","ratingConfig","须传入配置中的完整评分集")
            end
            G.Need(#rules>0,"RATING_UNCOVERED","ratingConfig","没有配置评分规则")
            local matches,ids={},{}
            for _,rule in ipairs(rules) do
                G.Pure(rule,"orderRatings","CONFIG_INVALID")
                G.Keys(rule,{id=true,ratingSetId=true,priority=true,stars=true,desc=true,requiresFacts=true,excludesFacts=true,feedback=true},"orderRatings","CONFIG_INVALID")
                G.Need(U.String(rule.id) and not ids[rule.id],"CONFIG_INVALID","orderRatings.id","评分规则 ID 无效或重复")
                ids[rule.id]=true
                G.Need(U.Integer(rule.stars,1) and rule.stars<=3 and G.Finite(rule.priority),"CONFIG_INVALID","orderRatings","评分只能是一至三星且须声明优先级")
                if Story.Matches(rule,index,definitions,"orderRatings." .. rule.id) then matches[#matches+1]=rule end
            end
            table.sort(matches,function(a,b)
                if a.stars~=b.stars then return a.stars>b.stars end
                if a.priority~=b.priority then return a.priority>b.priority end
                return a.id<b.id
            end)
            G.Need(#matches>0,"RATING_UNCOVERED","orderRatings","没有事实兼容的评分规则")
            local rule=matches[1]
            if not rule then error(U.Error("RATING_UNCOVERED","orderRatings","没有评分覆盖"),0) end
            if type(rule.feedback)~="string" or rule.feedback=="" then error(U.Error("RATING_UNCOVERED","orderRatings." .. rule.id .. ".feedback","没有配置评分反馈"),0) end
            G.Need(#rule.requiresFacts>0,"FILL_SOURCE_MISSING","orderRatings." .. rule.id,"反馈没有事实来源")
            -- 当前 RatingRule 无 bindings 字段；含占位符即缺来源，不能自动降星。
            G.Need(not rule.feedback:find("{{",1,true) and not rule.feedback:find("}}",1,true),"FILL_SOURCE_MISSING","orderRatings.feedback","评分反馈存在无来源占位符")
            return {stars=rule.stars,feedback=rule.feedback,ruleId=rule.id,factIds=U.Copy(rule.requiresFacts)}
        end)
    end
    require("systems.OrderLifecycle").Attach(api,content,options)
    return api
end

local live=Order.New(require "data.content")
Order.ResolveRecipe=live.ResolveRecipe
Order.Evaluate=live.Evaluate
Order.Rate=live.Rate
return Order
