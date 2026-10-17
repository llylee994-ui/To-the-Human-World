-- UI commands only: saved draft changes choose one sound, independent of BGM.
local U=require "core.StateUtil"
local A={}
local function amount(draft,kind,id)
    if kind=="word" then
        if draft.mainTokenId==id then return 1 end
        for _,token in ipairs(draft.auxTokenIds) do if token==id then return 1 end end
    elseif kind=="ingredient" then
        for _,item in ipairs(draft.ingredients) do if item.ingredientId==id then return item.quantity end end
    end
    return 0
end
local function nonempty(draft)
    return draft.mainTokenId or #draft.auxTokenIds>0 or #draft.ingredients>0 or #draft.specialItemIds>0
end
function A.New(model,play,allowed)
    local api={}
    local function emit(id) if play then play(id) end end
    function api.Drop(kind,id,defer)
        if not allowed() then return false end
        local before=amount(model.GetDraft(),kind,id)
        local result=model.Drop(kind,id)
        local after=model.GetDraft()
        if not result.ok or amount(after,kind,id)<=before then return result end
        local state=model.Refresh()
        local orderId=state.currentOrder and state.currentOrder.orderId
        local revision=state.revision
        local pending=true
        local function arrived()
            if not pending then return end
            pending=false
            if not allowed() then return end
            local current=model.Refresh()
            if not current or current.revision~=revision or not current.currentOrder or current.currentOrder.orderId~=orderId then return end
            if U.Equal(model.GetDraft(),after) then emit(kind=="word" and "word_add" or "ingredient_add") end
        end
        if defer then return result,arrived end
        arrived()
        return result
    end
    function api.TakeOut(kind,id,origin)
        if not allowed() then return false end
        local before=amount(model.GetDraft(),kind,id)
        local result=model.TakeOut(kind,id)
        if result.ok and amount(model.GetDraft(),kind,id)<before then
            emit(kind=="ingredient" and "ingredient_remove" or (origin=="tray" and "word_remove" or "word_withdraw"))
        end
        return result
    end
    function api.Clear()
        if not allowed() then return false end
        local hadInput=nonempty(model.GetDraft())
        local result=model.Edit("clear")
        if result.ok and hadInput and not nonempty(model.GetDraft()) then emit("draft_clear") end
        return result
    end
    return api
end
return A
