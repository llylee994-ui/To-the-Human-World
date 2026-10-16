-- Read-only presentation shared by every commission and configured effect.
local N={}
---@class PotionNoteEffect
---@field id string
---@field name string
---@field desc string
---@field weight number
---@field index number
---@field tier string
---@class PotionNoteProjection
---@field requirement string
---@field status string
---@field ready boolean
---@field primary PotionNoteEffect|false
---@field companions PotionNoteEffect[]
---@field rows PotionNoteEffect[]
---@field gaps string[]
---@field gapDetails string[]
---@return PotionNoteProjection
function N.Project(summary,definitions,draft)
    local potion=summary.potionPreview
    ---@type PotionNoteEffect[]
    local rows={}
    for index,effect in ipairs(definitions or {}) do
        local weight=potion and potion.effects and potion.effects[effect.id]
        if type(weight)=="number" and weight>0 then
            rows[#rows+1]={id=effect.id,name=effect.name,desc=effect.desc or "",weight=weight,index=index,
                tier=(potion.intensityByEffect or {})[effect.id] or "未分级"}
        end
    end
    table.sort(rows,function(a,b)
        if a.weight==b.weight then return a.index<b.index end
        return a.weight>b.weight
    end)
    local status="等待投料"
    local hint=summary.requirementHint or {}
    if not summary.orderId then status="待接委托"
    elseif summary.pending then status="结果已保存"
    elseif hint.evaluated then status=hint.canShip and "已满足" or "尚未满足" end
    local companions={};for i=2,#rows do companions[#companions+1]=rows[i] end
    local names,conditions,gaps,details={},{},{},{}
    for _,effect in ipairs(definitions or {}) do names[effect.id]=effect.name end
    for _,condition in ipairs((summary.requirement or {}).conditions or {}) do conditions[condition.id]=condition end
    for _,failure in ipairs(hint.failures or {}) do
        local effectId=failure.id:match("^tag%.(.+)$")
        local condition=conditions[failure.id]
        local effectName=names[effectId or (condition and condition.effectId)] or "药效"
        local message="尚有委托要求未满足"
        local detail=failure.message or message
        if failure.kind=="tag" then
            message=effectName.."还不足"
            detail=effectName.."：当前 "..N.Number(failure.actual).."，需要至少 "..N.Number(failure.expected.min)
        elseif failure.kind=="forbiddenEffect" then message=effectName.."作用过强"
        elseif failure.kind=="workReady" then message="药效结束太晚，来不及恢复"
        elseif failure.kind=="duration" then message=failure.actual<failure.expected.min and "持续时间还不够" or "持续时间太长"
        elseif failure.kind=="onset" then message="起效太慢"
        elseif failure.kind=="residualAt" then message=effectName.."残留过多"
        elseif failure.kind=="forbidden" then message="不宜带有"..effectName.."作用" end
        if condition and condition.effectId then detail=detail:gsub("^"..condition.effectId,effectName) end
        gaps[#gaps+1]=message;details[#details+1]=detail
    end
    return {requirement=summary.requirementDesc and summary.requirementDesc~="" and summary.requirementDesc or "请先接下想回应的委托。",
        status=status,ready=hint.canShip==true,primary=rows[1] or false,companions=companions,rows=rows,gaps=gaps,gapDetails=details}
end
function N.Number(value) return string.format("%.3g",value) end
return N
