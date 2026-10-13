-- 可保存的选料投影；允许主词暂空，不消耗任何正式资源。
local U=require "core.StateUtil"
local G=require "systems.CalculationGuard"
local D={}
function D.Empty(equipmentId)
    return {equipmentId=equipmentId,mainTokenId=false,auxTokenIds={},ingredients={},specialItemIds={}}
end
function D.Project(recipe)
    local draft={}
    for _,key in ipairs({"equipmentId","mainTokenId","auxTokenIds","ingredients","specialItemIds"}) do draft[key]=U.Copy(recipe[key]) end
    return draft
end
function D.IsEmpty(draft)
    return not draft.mainTokenId and #draft.auxTokenIds==0 and #draft.ingredients==0 and #draft.specialItemIds==0
end
function D.Validate(draft,live,content)
    return G.Run(function()
        G.Pure(draft,"draft")
        G.Keys(draft,{equipmentId=true,mainTokenId=true,auxTokenIds=true,ingredients=true,specialItemIds=true},"draft")
        local kit=G.Known(content,"equipment",draft.equipmentId,"draft.equipmentId")
        G.Need(live.economy.ownedEquipmentIds[kit.id],"INVALID_REQUEST","equipmentId","尚未拥有设备")
        G.Need(draft.mainTokenId==false or U.String(draft.mainTokenId),"INVALID_REQUEST","mainTokenId","主词须为卡片 ID 或 false")
        G.Array(draft.auxTokenIds,"auxTokenIds"); G.Array(draft.ingredients,"ingredients"); G.Array(draft.specialItemIds,"specialItemIds")
        G.Need(#draft.specialItemIds==0,"NOT_IMPLEMENTED","specialItemIds","特殊物品尚未接入")
        G.Need(#draft.auxTokenIds<=kit.slots.auxWord,"SLOT_OVERFLOW","auxTokenIds","辅助词槽已满")
        local ids=U.Copy(draft.auxTokenIds)
        if draft.mainTokenId then ids[#ids+1]=draft.mainTokenId end
        local seen,definitions={},{}
        local policy=content.stage1.recipePolicy
        for _,id in ipairs(ids) do
            G.Need(U.String(id),"INVALID_REQUEST","tokenId","词卡 ID 错误")
            local token=live.wordTokens.byId[id]
            G.Need(token and token.available,"TOKEN_UNAVAILABLE","tokenId","词卡不存在或已消耗")
            G.Need(not seen[id],"DUPLICATE_TOKEN","tokenId","同一卡片不能重复使用")
            G.Need(not definitions[token.wordId] or policy.repeatWordDefinition==true,"DUPLICATE_NOT_ALLOWED","wordId","不允许重复同名词")
            seen[id]=true; definitions[token.wordId]=true
        end
        local ingredients,total={},0
        for _,row in ipairs(draft.ingredients) do
            G.Keys(row,{ingredientId=true,quantity=true},"ingredients")
            G.Known(content,"ingredients",row.ingredientId,"ingredientId")
            G.Need(U.Integer(row.quantity,1),"INVALID_REQUEST","quantity","原料份数须为正整数")
            G.Need(not ingredients[row.ingredientId],"DUPLICATE_NOT_ALLOWED","ingredients","同原料须合并份数")
            G.Need(row.quantity==1 or policy.repeatIngredient==true,"DUPLICATE_NOT_ALLOWED","quantity","不允许重复原料")
            G.Need(row.quantity<=(live.economy.ingredients[row.ingredientId] or 0),"INVENTORY_SHORT","quantity","原料库存不足")
            ingredients[row.ingredientId]=true; total=total+row.quantity
        end
        G.Need(total<=kit.slots.ingredient,"SLOT_OVERFLOW","ingredients","原料槽已满")
        return U.Copy(draft)
    end)
end
return D
