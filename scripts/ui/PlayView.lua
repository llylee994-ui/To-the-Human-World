-- B6 普通按钮与文字界面。只投影保存结果；不计算剧情、消耗或奖励。
local UI=require "urhox-libs/UI"
local Model=require "ui.PlayModel"
local View={}
function View.New(session,content,enabled)
    local model=Model.New(session,content,enabled)
    local root=UI.Panel {id="playPanel",width="100%",flexGrow=1,flexShrink=1,flexBasis=0,gap=8}
    local heading=UI.Label {id="playLedger",width="100%",fontSize=16,whiteSpace="normal"}
    local nav=UI.Panel {width="100%",flexDirection="row",flexWrap="wrap",gap=6}
    local message=UI.Label {id="playMessage",width="100%",fontSize=14,whiteSpace="normal",fontColor={245,205,150,255}}
    local scroll=UI.ScrollView {id="playScroll",width="100%",flexGrow=1,flexShrink=1,flexBasis=0,scrollY=true}
    -- 滚动内容按父级内宽拉伸，留出滚动条；长文字不能压缩进可视高度。
    local body=UI.Panel {alignSelf="stretch",gap=10,padding=8,paddingRight=20,flexShrink=0}
    scroll:AddChild(body)
    root:AddChild(heading); root:AddChild(nav); root:AddChild(message); root:AddChild(scroll)
    local function text(parent,value,size,id)
        parent:AddChild(UI.Label {id=id,text=value or "",alignSelf="stretch",fontSize=size or 16,whiteSpace="normal",lineHeight=1.5,flexShrink=0})
    end
    local function button(parent,id,title,click,allowed,reason)
        parent:AddChild(UI.Button {id=id,text=title,minHeight=44,disabled=allowed==false,fontSize=15,onClick=click})
        if allowed==false and reason and reason~="" then text(parent,reason,13) end
    end
    local function action(parent,id,title,name,click)
        local gate=model.Action(name)
        button(parent,id,title,click,gate.enabled,gate.message)
    end
    for _,tab in ipairs({{"mail","来信"},{"words","词卡"},{"brew","炼药"},{"result","后续"},{"shop","补货"}}) do
        button(nav,"tab_" .. tab[1],tab[2],function() model.Navigate(tab[1]); scroll:ScrollToTop() end)
    end
    local function find(list,id) for _,item in ipairs(list) do if item.id==id then return item end end end
    local function source(card,data)
        local item=data.live.letters.byId[card.source.sourceLetterInstanceId]
        local definition=item and content.GetLetter(item.letterId)
        local npc=content.GetNpc(card.source.sourceNpcId)
        local position=card.source.sourceSpanId:match("^body:(%d+)$")
        return (npc and npc.name or "寄信人") .. " · " .. (definition and definition.title or "来信") .. " · 正文第" .. (position or "？") .. "处"
    end
    local function cardName(id,data)
        local card=data.live.wordTokens.byId[id]
        local word=card and content.GetWord(card.wordId)
        return word and word.displayText or "未选择"
    end
    local function requirements(definition)
        text(body,"订单要求：" .. definition.requirement.desc)
        text(body,"固定报酬：" .. definition.reward.currency .. " 金币",14)
    end
    local function potionDetails(potion,prefix)
        text(body,string.format("药效 %.2g 小时后发作 · 持续 %.2g 小时",potion.onsetDelayHours,potion.durationHours),14)
        for _,effect in ipairs(content.effects) do
            local value=potion.effects[effect.id]
            if value then
                text(body,effect.name .. "：" .. potion.intensityByEffect[effect.id] .. "（" .. string.format("%.3g",value) .. "）",14,prefix .. effect.id)
            end
        end
    end
    local function mail(data)
        action(body,"nextDay","结束当天","NextDay",model.NextDay)
        local available=session.modules.narrative.FindAvailable(data.live)
        if not available.ok then text(body,available.error.message); return end
        text(body,"可打捞：" .. #available.value,18)
        for _,id in ipairs(available.value) do
            local definition=content.GetLetter(id)
            action(body,"receive_" .. id,"打捞 · " .. definition.title,"ReceiveLetter",function() model.Receive(id) end)
        end
        text(body,"已收到的信件",18)
        for _,id in ipairs(data.live.letters.bottleQueue) do
            local item=data.live.letters.byId[id]
            local definition=content.GetLetter(item.letterId)
            local gate=model.Action("ReadLetter")
            button(body,"read_" .. id,(item.read and "重读 · " or "阅读 · ") .. definition.title,
                function() model.Read(id); scroll:ScrollToTop() end,item.read or gate.enabled,gate.message)
        end
        if #data.live.letters.bottleQueue==0 then text(body,"先打捞一封来信，再阅读并剪下要用的词。") end
    end
    local function letter(data)
        if not model.selectedLetter then mail(data); return end
        local result=session.modules.letters.GetView(model.selectedLetter)
        if not result.ok then text(body,result.error.message); return end
        local view=result.value
        local definition=content.GetLetter(view.letterId)
        text(body,definition.title,20); text(body,view.selfIntro)
        local parts={}
        for _,segment in ipairs(view.segments) do
            parts[#parts+1]=segment.cut and "〔　缺口　〕" or (segment.kind=="word" and "【" .. segment.text .. "】" or segment.text)
        end
        text(body,table.concat(parts)); text(body,"寄往：" .. view.address)
        requirements(definition)
        text(body,"剪下标记词",18)
        local gate=model.Action("CutWord")
        for _,span in ipairs(view.spans) do
            button(body,"cut_" .. span.spanId,span.cut and span.text .. " · 已剪" or "剪下「" .. span.text .. "」",
                function() model.Cut(span.spanId) end,gate.enabled and span.canCut,not span.cut and gate.message or nil)
        end
        ---@type string|nil
        local existing
        for id,entry in pairs(data.live.orders.acceptedById) do if entry.letterInstanceId==model.selectedLetter then existing=id end end
        if existing then
            button(body,"openOrder","查看这封信的订单",function()
                if data.live.orders.confirmedById[existing] then model.selectedResult=existing; model.Navigate("result") else model.Navigate("brew") end
                scroll:ScrollToTop()
            end)
        else action(body,"acceptOrder","接下这份委托","Accept",function() model.Accept(); scroll:ScrollToTop() end) end
    end
    local function inventory(data,selecting)
        local result=session.modules.wordTokens.GetInventoryView()
        if not result.ok then text(body,result.error.message); return end
        local view=result.value
        text(body,string.format("可用 %d 张 · %d 种 / %d 类",view.availableCount,view.availableDefinitionCount,view.availableCategoryCount),18)
        if view.availableCount==0 then text(body,"没有可用词卡。可返回来信查看尚未剪下的词；已消耗的卡不能再次投入。") end
        for _,group in ipairs(view.groups) do
            text(body,string.format("%s · %s：剩 %d 张，曾收集 %d 张",group.definition.displayText,group.definition.category,group.availableCount,group.collectedCount),17,"wordGroup_" .. group.wordId)
            for _,card in ipairs(view.cards) do if card.definition.id==group.wordId then
                local used=not card.available and card.consumedByOrderId:match("^order:(%d+)$")
                text(body,source(card,data) .. (card.available and " · 可用" or " · 已用于第" .. (used or "？") .. "单"),13)
                if selecting and card.available then
                    local row=UI.Panel {width="100%",flexDirection="row",flexWrap="wrap",gap=6}
                    button(row,"main_" .. card.tokenId,"用作主词",function() model.Edit("main",card.tokenId) end)
                    button(row,"aux_" .. card.tokenId,"用作辅词",function() model.Edit("aux",card.tokenId) end)
                    body:AddChild(row)
                end
            end end
        end
    end
    local function brew(data)
        local order=data.currentOrder
        if not order then text(body,"先阅读来信并接单，再选择投料。"); return end
        local definition=content.GetLetter(data.live.orders.acceptedById[order.orderId].letterId)
        text(body,definition.title,20); requirements(definition)
        if order.phase=="pending" then
            text(body,"本单结果已保存，确认或重置后才能换料。")
            button(body,"openPending","查看待确认后续",function() model.selectedResult=false; model.Navigate("result"); scroll:ScrollToTop() end)
            return
        end
        local draft=model.GetDraft()
        local kit=find(content.equipment,draft.equipmentId)
        if not kit then text(body,"没有可用设备"); return end
        text(body,string.format("%s · 主词 %d / 辅词 %d / 原料 %d / 特殊 %d 槽",kit.name,kit.slots.mainWord,kit.slots.auxWord,kit.slots.ingredient,kit.slots.specialItem),14)
        text(body,"首次投料前请先剪好词并补齐原料。还未生成过待确认后续时，可以返回准备、剪词或补货。确认后才消耗；重置可取回本次试用的词和材料。",14)
        action(body,"cancelBrew","返回准备（剪词／补货）","CancelBrew",function() model.CancelBrew(); scroll:ScrollToTop() end)
        for _,item in ipairs(content.equipment) do if data.live.economy.ownedEquipmentIds[item.id] and item.id~=draft.equipmentId then
            button(body,"equipment_" .. item.id,"换用 " .. item.name,function() model.Edit("equipment",item.id) end)
        end end
        text(body,"主词：" .. cardName(draft.mainTokenId,data))
        if draft.mainTokenId then button(body,"removeMain","移出主词",function() model.Edit("removeMain") end) end
        for _,id in ipairs(draft.auxTokenIds) do button(body,"remove_" .. id,"移出辅词「" .. cardName(id,data) .. "」",function() model.Edit("removeAux",id) end) end
        text(body,"原料（每份占一槽）",18)
        for _,item in ipairs(content.ingredients) do
            local selected=0; for _,line in ipairs(draft.ingredients) do if line.ingredientId==item.id then selected=line.quantity end end
            text(body,string.format("%s · 库存 %d · 已放 %d",item.name,data.live.economy.ingredients[item.id] or 0,selected),14)
            local row=UI.Panel {width="100%",flexDirection="row",gap=6}
            button(row,"add_" .. item.id,"放入一份",function() model.Edit("ingredient",item.id,1) end)
            button(row,"minus_" .. item.id,"移出一份",function() model.Edit("ingredient",item.id,-1) end,selected>0)
            body:AddChild(row)
        end
        text(body,"特殊物品槽：当前没有可投入的物品。",14)
        button(body,"clearDraft","移出全部投料",function() model.Edit("clear") end)
        action(body,"previewOrder","炼药并发货，查看待确认后续","Preview",function() model.Preview(); scroll:ScrollToTop() end)
        if model.failure then for _,failure in ipairs(model.failure.failures) do text(body,failure.message,14) end end
        if model.trialPotion then
            text(body,"本次试做药效（未发货，未消耗）",18)
            potionDetails(model.trialPotion,"trialEffect_")
        end
        inventory(data,true)
    end
    local function results(data)
        local pending=data.currentOrder and data.currentOrder.pending
        local query=not pending and model.selectedResult and {orderId=model.selectedResult} or nil
        local saved=session.order.GetView(query)
        if not saved.ok then text(body,saved.error.message); return end
        local record=saved.value.pending or saved.value.record
        if record then
            text(body,pending and "等待你的决定" or "已确认的后续",20)
            potionDetails(record.potion,"resultEffect_")
            text(body,record.followup.renderedText)
            text(body,string.rep("★",record.rating.stars) .. " · " .. record.rating.feedback,18)
            text(body,pending and "本次将消耗" or "本次已消耗",18)
            local cards=session.modules.wordTokens.GetInventory().value or {}
            for _,id in ipairs(record.consumption.consumedTokenIds) do
                for _,card in ipairs(cards) do if card.tokenId==id then text(body,card.definition.displayText .. " ×1 · " .. source(card,data),14) end end
            end
            for _,item in ipairs(record.consumption.ingredients) do
                local definition=find(content.ingredients,item.ingredientId)
                text(body,(definition and definition.name or item.ingredientId) .. " ×" .. item.quantity,14)
            end
            text(body,"报酬：" .. record.reward.currency .. " 金币",16)
            if pending then
                text(body,"确认并保存成功后才正式消耗、发放报酬并改变人物。重置会回到首次投料前。",14)
                action(body,"confirmOrder","确认本单结果","Confirm",function() model.Resolve(true); scroll:ScrollToTop() end)
                action(body,"resetOrder","重置，重新投料","Reset",function() model.Resolve(false); scroll:ScrollToTop() end)
            else button(body,"continueGame","继续经营",function() model.Navigate("mail"); scroll:ScrollToTop() end) end
        else text(body,"尚无选中的后续。完成炼药发货后可在这里确认或重置。") end
        local ids={}; for id in pairs(data.live.orders.confirmedById) do ids[#ids+1]=id end; table.sort(ids)
        for _,id in ipairs(ids) do
            local accepted=data.live.orders.acceptedById[id]
            button(body,"history_" .. id,"重读后续 · " .. content.GetLetter(accepted.letterId).title,
                function() model.selectedResult=id; model.Navigate("result"); scroll:ScrollToTop() end,not pending)
        end
    end
    local api={root=root,model=model}
    local function shop(data)
        text(body,"原料补货",20)
        if not content.shop then text(body,"当前内容包未配置商店。");return end
        text(body,string.format("每种原料每日供应 %d 份，次日补齐。",content.shop.dailyStockPerIngredient))
        local gate=model.Action("Shop")
        for _,ingredient in ipairs(content.ingredients) do
            local sold=0
            for _,p in ipairs(data.live.economy.shopPurchases) do
                if p.day==data.live.gameFlow.day and p.ingredientId==ingredient.id then sold=sold+p.quantity end
            end
            local left=content.shop.dailyStockPerIngredient-sold
            text(body,string.format("%s · 库存 %d · 今日可购 %d",ingredient.name,data.live.economy.ingredients[ingredient.id] or 0,left))
            local allowed=gate.enabled and left>0 and data.live.economy.currency>=ingredient.price
            local reason=not gate.enabled and gate.message or left<=0 and "今日已售完，明天再来。" or "金币不足。"
            button(body,"buy_"..ingredient.id,string.format("购买一份 · %d 金币",ingredient.price),function() model.Buy(ingredient.id) end,allowed,reason)
        end
    end
    function api.Update()
        if not model.dirty then return end
        model.dirty=false
        -- 在 Update 中重建，避免点击回调/事务通知期间销毁正在派发事件的控件。
        for i=body:GetNumChildren(),1,-1 do
            local child=body:GetChildAt(i)
            if child then child:Destroy() end
        end
        local data=model.Refresh()
        message:SetText(model.message)
        if not data or not session.state.CanMutate() or not model.Action("GetView").enabled then
            local status=session.state.GetStatus()
            text(body,status.error and status.error.message or "当前进度不可操作，请重新读取。")
            button(body,"reloadProgress","重新读取原存档",model.Reload)
            return
        end
        heading:SetText(string.format("第 %d 天 · 金币 %d · 已确认 %d 单",data.live.gameFlow.day,data.live.economy.currency,data.live.gameFlow.deliveredOrders))
        if model.page=="letter" then letter(data)
        elseif model.page=="words" then inventory(data,false)
        elseif model.page=="brew" then brew(data)
        elseif model.page=="result" then results(data)
        elseif model.page=="shop" then shop(data)
        else mail(data) end
    end
    function api.Refresh() model.dirty=true end
    api.Update()
    return api
end
return View
