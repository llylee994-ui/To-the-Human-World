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
    return {requirement=summary.requirementDesc and summary.requirementDesc~="" and summary.requirementDesc or "请先接下想回应的委托。",
        status=status,ready=hint.canShip==true,primary=rows[1] or false,companions=companions,rows=rows}
end
function N.Number(value) return string.format("%.3g",value) end
return N
