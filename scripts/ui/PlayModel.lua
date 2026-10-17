-- B6 交互状态：仅保存导航与未提交选料；正式状态全部经 GameSession 公共接口。
local U=require "core.StateUtil"
local M={}
function M.New(session,content,enabled)
    ---@class PlayModel
    ---@field selectedResult string|false 已确认订单 ID；false 表示当前待确认结果。
    ---@field letterEdited boolean 当前信纸可局部刷新。
    local api={
        page="mail" --[[@as string]],
        selectedLetter=false --[[@as string|false]],
        selectedResult=false --[[@as string|false]],
        letterEdited=false,
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
            if result.error.code=="SAVE_WRITE_FAILED" or result.error.code=="SAVE_ENCODE_FAILED" then
                print("[PlaySaveFailure] " .. cjson.encode(result.error))
                api.message="保存失败，本次操作未生效。请检查存储空间或写入权限，再重试。"
            elseif result.error.code=="SAVE_COMMIT_UNCERTAIN" or result.error.code=="COMMIT_RECOVERY_REQUIRED" then
                print("[PlayRecoveryRequired] "..cjson.encode(result.error))
                api.message="本次保存结果需要核对，请重新读取原存档；核对前暂时不能继续操作。"
            else
                print("[PlayActionFailure] " .. cjson.encode(result.error))
                api.message=result.error.message
            end
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
        if order and order.draft then draft=U.Copy(order.draft)
        elseif order and order.recipe then draft=U.Copy(order.recipe) end
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
        local result=session.state.CutWord({letterInstanceId=api.selectedLetter,spanId=spanId})
        -- 失败时信纸仍在原位置，玩家可原地重试；状态锁定由View统一处理。
        api.letterEdited=true
        return api.Notify(result,"词卡已收好，信纸上留下了剪痕。")
    end
    function api.Accept()
        if not active() then return api.Notify(fail("STATE_LOCKED","当前为隔离调试模式")) end
        local result=session.order.Accept({letterInstanceId=api.selectedLetter})
        if result.ok then api.page="brew" end
        return api.Notify(result,"接单成功。选料期间可继续剪词、采购；开始熬制后等待发货或重置。")
    end
    function api.NextDay()
        if not active() then return api.Notify(fail("STATE_LOCKED","当前为隔离调试模式")) end
        local result=session.state.NextDay()
        local closing=result.ok and result.value and (result.value.phase=="closing" or result.value.phase=="closing_prepare")
        return api.Notify(result,closing and "已进入收尾。" or "已进入新的一天。")
    end
    function api.Buy(ingredientId)
        if not active() then return api.Notify(fail("STATE_LOCKED","当前为隔离调试模式")) end
        return api.Notify(session.state.Shop({ingredientId=ingredientId,quantity=1}),"原料已购入并保存。")
    end
    function api.BuyFurniture(furnitureId,quote)
        if not active() then return api.Notify(fail("STATE_LOCKED","当前为隔离调试模式")) end
        if session.state.GetStatus().schema==4 then
            if not quote then return api.Notify(fail("STALE_QUOTE","请重新查看家居报价。")) end
            return api.Notify(session.state.PurchaseHomeItem(quote),"家具已购入并保存，暂未布置到小屋。")
        end
        return api.Notify(session.state.PurchaseFurniture({furnitureId=furnitureId}),"家具已购入并保存，暂未布置到小屋。")
    end
    local function releaseCommand(name,extra,message)
        if not active() then return api.Notify(fail("STATE_LOCKED","当前为隔离调试模式")) end
        local data=api.Refresh()
        if not data or not data.chapter then return api.Notify(fail("STATE_LOCKED","请先读取本次旅程的进度。")) end
        local request={expectedRevision=data.revision}
        for k,v in pairs(extra or {}) do request[k]=v end
        return api.Notify(session.state[name](request),message)
    end
    function api.BeginClosing() return releaseCommand("BeginClosing",nil,"已进入收尾。") end
    function api.StartJourney() return releaseCommand("StartJourney") end
    function api.AdvanceEpilogue(step,expectedRevision)
        return releaseCommand("AdvanceEpilogue",{expectedStep=step,expectedRevision=expectedRevision})
    end
    function api.BeginWish() return releaseCommand("BeginWish",nil,"把自己的愿望放到纸上。") end
    function api.UpdateWishDraft(ids,expectedRevision)
        return releaseCommand("UpdateWishDraft",{sourceTokenIds=U.Copy(ids),expectedRevision=expectedRevision},"愿望草稿已保存。")
    end
    function api.UpdateWishLayout(placements,expectedRevision)
        return releaseCommand("UpdateWishLayout",{placements=U.Copy(placements),expectedRevision=expectedRevision},"已收好这张愿望。")
    end
    function api.ConfirmEnding(kind,expectedRevision,placements)
        return releaseCommand("ConfirmEnding",{kind=kind,expectedRevision=expectedRevision,placements=placements and U.Copy(placements) or nil},"这段旅程已保存。")
    end
    local function clearNavigation()
        draftOrder=false;api.selectedLetter=false;api.selectedResult=false;api.selectedAttempt=false
        api.failure=nil;api.trialPotion=nil;api.page="home"
        api.Refresh()
    end
    function api.RestoreEndingCheckpoint()
        local result=releaseCommand("RestoreEndingCheckpoint",nil,"已返回结束前的进度。")
        if result.ok then clearNavigation() end
        return result
    end
    function api.StartNewPlaythrough(confirmed)
        if confirmed~=true then return api.Notify(fail("CONFIRMATION_REQUIRED","请先确认开始新旅程。已完成的结局留念会保留。")) end
        local result=releaseCommand("StartNewPlaythrough",nil,"新旅程已开始。")
        if result.ok then clearNavigation() end
        return result
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
        if order.draft then
            local result=session.order.UpdateDraft({orderId=order.orderId,draft=nextDraft})
            if result.ok then draft=U.Copy(nextDraft); api.failure=nil; api.trialPotion=nil end
            return api.Notify(result,"选料已保存，尚未消耗；开始熬制才冻结本次状态。")
        end
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
    -- 选词只编辑试用配方；首次有效投料仍经 Edit 建立基准。
    function api.SelectToken(tokenId)
        local current=api.GetDraft()
        if current.mainTokenId==tokenId then return api.Notify(fail("DUPLICATE_TOKEN","这张词卡已在药槽中，点击槽内卡片可取出。")) end
        for _,id in ipairs(current.auxTokenIds) do
            if id==tokenId then return api.Notify(fail("DUPLICATE_TOKEN","这张词卡已在药槽中，点击槽内卡片可取出。")) end
        end
        return api.Edit(current.mainTokenId and "aux" or "main",tokenId)
    end
    function api.RemoveToken(tokenId)
        local current=api.GetDraft()
        if current.mainTokenId==tokenId then return api.Edit("removeMain") end
        for _,id in ipairs(current.auxTokenIds) do
            if id==tokenId then return api.Edit("removeAux",tokenId) end
        end
        return api.Notify(fail("INVALID_REQUEST","这张词卡不在当前药槽中。"))
    end
    function api.CancelBrew()
        local data=api.Refresh(); local order=data and data.currentOrder
        if order and order.draft then api.ReturnHome(); return U.Ok({phase=order.phase}) end
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
        local request=U.Copy(draft)
        request.orderId=data.currentOrder.orderId
        if data.currentOrder.draft then request.baselineId=nil end
        local result=session.order.Preview(request)
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
        return api.Notify(result,confirm and "已发货，词卡和原料已消耗，报酬已到账。" or "本次试做已记入历史，正式资源保留；可重新剪词、采购和选料。")
    end
    function api.Drop(kind,id)
        if kind=="word" then return api.SelectToken(id) end
        if kind=="ingredient" then return api.Edit("ingredient",id,1) end
        return api.Notify(fail("INVALID_REQUEST","未知投料类型"))
    end
    function api.TakeOut(kind,id)
        if kind=="word" then return api.RemoveToken(id) end
        if kind=="ingredient" then return api.Edit("ingredient",id,-1) end
        return api.Notify(fail("INVALID_REQUEST","未知取出类型"))
    end
    function api.ReturnHome() api.page="home"; api.dirty=true end
    function api.OpenAttempt(transactionId)
        local result=session.queries.GetAttempt(transactionId)
        if result.ok then api.selectedAttempt=transactionId; api.page="journal"; api.dirty=true end
        return result
    end
    api.Refresh()
    local initial=session.state.GetSnapshot()
    if initial and initial.currentOrder and initial.currentOrder.phase=="pending" then api.page="result" end
    local status=session.state.GetStatus()
    if status.migrationNotice then api.message=status.migrationNotice end
    return api
end
return M
