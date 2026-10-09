-- B6 交互状态：仅保存导航与未提交选料；正式状态全部经 GameSession 公共接口。
local U=require "core.StateUtil"
local M={}
function M.New(session,content,enabled)
    local api={
        page="mail" --[[@as string]],
        selectedLetter=false --[[@as string|false]],
        selectedResult=false --[[@as string|false]],
        message="",dirty=true --[[@as boolean]],
        failure=nil --[[@as table?]],
        trialPotion=nil --[[@as table?]],
    }
    ---@type table
    local draft={equipmentId=false,mainTokenId=false,auxTokenIds={},ingredients={},specialItemIds={}}
    local draftOrder=false
    local function fail(code,message) return U.Fail(code,"play",message) end
    local function active()
        return not enabled or enabled()
    end
    function api.Notify(result,message)
        api.dirty=true
        if not result.ok then
            if result.error.code=="SAVE_WRITE_FAILED" then
                print("[PlaySaveFailure] " .. cjson.encode(result.error))
                api.message="保存失败，本次操作未生效。请检查存储空间或写入权限，再重试。"
            else api.message=result.error.message .. "（" .. result.error.code .. "）" end
        elseif result.value and result.value.notificationErrors then api.message="进度已保存，部分通知失败；请重新读取进度核对。"
        else api.message=message or "" end
        return result
    end
    function api.Navigate(page) api.page=page; api.dirty=true end
    function api.Refresh()
        local data=session.state.GetSnapshot()
        if not data or not data.live then return nil end
        local order=data.currentOrder
        local id=order and order.orderId or false
        if draftOrder~=id then
            draftOrder=id
            draft={equipmentId=false,mainTokenId=false,auxTokenIds={},ingredients={},specialItemIds={}}
            api.failure=nil; api.trialPotion=nil
        end
        if order and order.recipe then draft=U.Copy(order.recipe) end
        if not draft.equipmentId then
            for _,equipment in ipairs(content.equipment) do
                if data.live.economy.ownedEquipmentIds[equipment.id] then draft.equipmentId=equipment.id; break end
            end
        end
        return data
    end
    function api.GetDraft() api.Refresh(); return U.Copy(draft) end
    function api.Action(name)
        if not active() then return {enabled=false,message="当前为隔离调试模式，请重启返回正式进度。"} end
        return session.state.CheckAction(name)
    end
    function api.Receive(id)
        if not active() then return api.Notify(fail("STATE_LOCKED","当前为隔离调试模式")) end
        local result=session.state.ReceiveLetter({letterId=id})
        if result.ok then api.selectedLetter=result.value.letterInstanceId end
        return api.Notify(result,"信件已打捞。点击阅读信件。")
    end
    function api.Read(id)
        local data=api.Refresh()
        local item=data and data.live.letters.byId[id]
        local result
        if item and item.read then result=U.Ok({})
        elseif active() then result=session.state.ReadLetter({letterInstanceId=id})
        else result=fail("STATE_LOCKED","当前为隔离调试模式") end
        if result.ok then api.selectedLetter=id; api.page="letter" end
        return api.Notify(result)
    end
    function api.Cut(spanId)
        if not active() then return api.Notify(fail("STATE_LOCKED","当前为隔离调试模式")) end
        return api.Notify(session.state.CutWord({letterInstanceId=api.selectedLetter,spanId=spanId}),"词卡已收入库存；原信保留缺口。")
    end
    function api.Accept()
        if not active() then return api.Notify(fail("STATE_LOCKED","当前为隔离调试模式")) end
        local result=session.order.Accept({letterInstanceId=api.selectedLetter})
        if result.ok then api.page="brew" end
        return api.Notify(result,"接单成功。首次投料前，请先剪好要用的词并补齐原料。")
    end
    function api.NextDay()
        if not active() then return api.Notify(fail("STATE_LOCKED","当前为隔离调试模式")) end
        return api.Notify(session.state.NextDay(),"已进入新的一天。")
    end
    function api.Buy(ingredientId)
        if not active() then return api.Notify(fail("STATE_LOCKED","当前为隔离调试模式")) end
        return api.Notify(session.state.Shop({ingredientId=ingredientId,quantity=1}),"原料已购入并保存。")
    end
    function api.Reload()
        if not active() then return api.Notify(fail("STATE_LOCKED","当前为隔离调试模式")) end
        local data,status=session.state.ReloadCurrent()
        if not data then return api.Notify({ok=false,error=status.error}) end
        api.failure=nil; api.trialPotion=nil
        draftOrder=false; api.Refresh()
        api.page=data.currentOrder and data.currentOrder.phase=="pending" and "result" or "mail"
        return api.Notify(U.Ok(data),"已读取保存的进度。")
    end
    local function equipment(id)
        for _,item in ipairs(content.equipment) do if item.id==id then return item end end
    end
    function api.Edit(kind,id,delta)
        local data=api.Refresh()
        local order=data and data.currentOrder
        if not data or not active() or not session.state.CanMutate() or not order or order.phase=="pending" then
            return api.Notify(fail("ORDER_LOCKED","请先接单；待确认时只能确认或重置。"))
        end
        if kind~="clear" and kind~="removeMain" and not U.String(id) then return api.Notify(fail("INVALID_REQUEST","请明确选择投料来源")) end
        local nextDraft=U.Copy(draft)
        if kind=="equipment" then
            if not data.live.economy.ownedEquipmentIds[id] then return api.Notify(fail("INVALID_REQUEST","尚未拥有该设备")) end
            nextDraft.equipmentId=id
        elseif kind=="main" then nextDraft.mainTokenId=id
        elseif kind=="aux" then nextDraft.auxTokenIds[#nextDraft.auxTokenIds+1]=id
        elseif kind=="removeMain" then nextDraft.mainTokenId=false
        elseif kind=="removeAux" then
            for i,token in ipairs(nextDraft.auxTokenIds) do if token==id then table.remove(nextDraft.auxTokenIds,i); break end end
        elseif kind=="ingredient" then
            if type(delta)~="number" or (delta~=1 and delta~=-1) then return api.Notify(fail("INVALID_REQUEST","每次放入或移出一份原料")) end
            local found=false
            for i,item in ipairs(nextDraft.ingredients) do
                if item.ingredientId==id then
                    item.quantity=item.quantity+delta; found=true
                    if item.quantity<=0 then table.remove(nextDraft.ingredients,i) end
                    break
                end
            end
            if not found and delta>0 then nextDraft.ingredients[#nextDraft.ingredients+1]={ingredientId=id,quantity=delta} end
        elseif kind=="clear" then
            nextDraft.mainTokenId=false; nextDraft.auxTokenIds={}; nextDraft.ingredients={}; nextDraft.specialItemIds={}
        else return api.Notify(fail("INVALID_REQUEST","未知投料操作")) end
        local kit=equipment(nextDraft.equipmentId)
        if not kit then return api.Notify(fail("CONFIG_MISSING","没有可用设备")) end
        local total=0
        for _,item in ipairs(nextDraft.ingredients) do
            total=total+item.quantity
            if item.quantity>(data.live.economy.ingredients[item.ingredientId] or 0) then return api.Notify(fail("INVENTORY_SHORT","原料库存不足")) end
            if item.quantity>1 and content.stage1.recipePolicy.repeatIngredient~=true then return api.Notify(fail("DUPLICATE_NOT_ALLOWED","当前规则不允许重复原料")) end
        end
        if #nextDraft.auxTokenIds>kit.slots.auxWord or total>kit.slots.ingredient then return api.Notify(fail("SLOT_OVERFLOW","已达到设备槽位上限，请先移出投料")) end
        local ids=U.Copy(nextDraft.auxTokenIds)
        if nextDraft.mainTokenId then ids[#ids+1]=nextDraft.mainTokenId end
        local seen,definitions={},{}
        for _,token in ipairs(ids) do
            local card=data.live.wordTokens.byId[token]
            if not card or not card.available then return api.Notify(fail("TOKEN_UNAVAILABLE","这张词卡已消耗或不存在")) end
            if seen[token] then return api.Notify(fail("DUPLICATE_TOKEN","同一张词卡不能占多个槽")) end
            if definitions[card.wordId] and content.stage1.recipePolicy.repeatWordDefinition~=true then return api.Notify(fail("DUPLICATE_NOT_ALLOWED","当前规则不允许同名词重复投料")) end
            seen[token]=true; definitions[card.wordId]=true
        end
        -- 空锅清空、移出和只换设备不算投料；保存失败不接受本次选料。
        local hasInput=nextDraft.mainTokenId or #nextDraft.auxTokenIds>0 or #nextDraft.ingredients>0 or #nextDraft.specialItemIds>0
        if hasInput or order.baseline~=false then
            local begun=session.order.BeginBrew({orderId=order.orderId})
            if not begun.ok then return api.Notify(begun) end
            nextDraft.orderId=order.orderId; nextDraft.baselineId=begun.value.baselineId
        end
        draft=nextDraft
        api.failure=nil; api.trialPotion=nil
        return api.Notify(U.Ok(U.Copy(draft)),"试用投料尚未消耗；确认结果并保存成功后才扣除。")
    end
    function api.CancelBrew()
        local data=api.Refresh(); local order=data and data.currentOrder
        if not active() or not order then return api.Notify(fail("INVALID_ORDER_STATE","没有可返回准备的订单")) end
        local result=session.order.CancelBrew({orderId=order.orderId})
        if result.ok then
            draft={equipmentId=draft.equipmentId,mainTokenId=false,auxTokenIds={},ingredients={},specialItemIds={}}
            api.failure=nil; api.trialPotion=nil
            api.selectedLetter=order.letterInstanceId; api.page="letter"
        end
        return api.Notify(result,"已返回剪词准备，已取得的词卡与已确认订单保留。")
    end
    function api.Preview()
        local data=api.Refresh()
        if not active() or not data or not data.currentOrder or not draft.mainTokenId then return api.Notify(fail("INVALID_REQUEST","请先接单并投入主词")) end
        local result=session.order.Preview(U.Copy(draft))
        api.trialPotion=result.ok and result.value.potion and U.Copy(result.value.potion) or nil
        if result.ok and result.value.phase=="pending" then api.page="result"; api.selectedResult=false
        elseif result.ok and result.value.requirementResult then
            api.failure=U.Copy(result.value.requirementResult)
            return api.Notify(result,"字面要求未满足，没有消耗或发货。请调整投料。")
        end
        api.failure=nil
        return api.Notify(result,result.ok and "后续已保存，等待确认或重置。" or nil)
    end
    function api.Resolve(confirm)
        local data=api.Refresh(); local order=data and data.currentOrder
        if not active() or not order or not order.pending then return api.Notify(fail("INVALID_ORDER_STATE","没有待确认结果")) end
        local request={orderId=order.orderId,transactionId=order.pending.transactionId}
        if not confirm then request.baselineId=order.baseline.id end
        local result=confirm and session.order.Confirm(request) or session.order.Reset(request)
        if result.ok then
            if confirm then api.selectedResult=order.orderId; api.page="result"
            else api.page="brew"; draft={equipmentId=draft.equipmentId,mainTokenId=false,auxTokenIds={},ingredients={},specialItemIds={},orderId=order.orderId,baselineId=order.baseline.id} end
            api.failure=nil; api.trialPotion=nil
        end
        return api.Notify(result,confirm and "已正式确认，词卡和原料已消耗，报酬已到账。" or "已回到首次投料基准；此前剪词与已确认订单保留。")
    end
    api.Refresh()
    local initial=session.state.GetSnapshot()
    if initial and initial.currentOrder and initial.currentOrder.phase=="pending" then api.page="result" end
    return api
end
return M
