-- Real projections only. Every mutation goes through the supplied PlayModel.
local UI=require "urhox-libs/UI"
local Widget=require "urhox-libs/UI/Core/Widget"
local IngredientArt=require "ui.landscape.IngredientArt"
local Harbor=require "ui.landscape.HarborStyle"
local LetterPresentation=require "ui.landscape.LetterPresentation"
local ReaderOrder=require "ui.landscape.ReaderOrder"
local P={}
function P.Text(parent,value,size,id)
    local label=UI.Label {id=id,text=tostring(value or ""),alignSelf="stretch",fontSize=size or 16,fontFamily=Harbor.fontFamily,
        whiteSpace="normal",lineHeight=1.55,flexShrink=0,fontColor={62,49,36,255},pointerEvents="none"}
    parent:AddChild(label); return label
end
function P.Button(parent,id,title,click,allowed,reason)
    local b=Harbor.Button {id=id,text=title,width="100%",maxWidth=420,alignSelf="flex-start",minWidth=0,minHeight=44,flexShrink=0,fontSize=15,
        disabled=allowed==false,onClick=click,backgroundColor={64,85,70,255},textColor={255,247,225,255},borderRadius=6}
    parent:AddChild(b)
    if allowed==false and reason and reason~="" then P.Text(parent,reason,13) end
    return b
end
local function query(ctx,parent,name,...)
    local result=ctx.session.queries[name](...)
    if not result.ok then P.Text(parent,result.error.message,16,"queryError"); return nil end
    return result.value
end
local function gate(ctx,name) return ctx.model.Action(name) end
local orderNames={unaccepted="未接单",accepted="已接单",pending="待处理结果",confirmed="已完成"}
local attemptNames={pending="待处理",reset="已重置",shipped="已发货"}
function P.IntroText(text,name)
    text=tostring(text or ""):match("^%s*(.-)%s*$")
    local first,rest=text:match("^([^\n]*)\n?(.*)$")
    local value=first:match("^来信人：%s*(.-)%s*$") or first:match("^来信人:%s*(.-)%s*$")
        or first:match("^寄信人：%s*(.-)%s*$") or first:match("^寄信人:%s*(.-)%s*$")
    if value==name then return rest:match("^%s*(.-)%s*$") end
    return text
end
function P.PaperText(view)
    local parts={}
    for _,segment in ipairs(view.segments or {}) do
        parts[#parts+1]=segment.cut and "〔"..string.rep("　",utf8.len(segment.text) or 1).."〕"
            or (segment.kind=="word" and "【"..segment.text.."】" or segment.text)
    end
    return table.concat(parts)
end
function P.Reader(ctx,body)
    body.props.id="readerBody"
    local result=ctx.session.modules.letters.GetView(ctx.model.selectedLetter)
    if not result.ok then P.Text(body,result.error.message); return end
    local view=result.value; local definition=ctx.content.GetLetter(view.letterId)
    if not definition then P.Text(body,"未找到信件正式定义。"); return end
    local sender=ctx.content.GetNpc(definition.senderId)
    P.Text(body,definition.title,23,"readerTitle")
    P.Text(body,"寄信人："..(sender and sender.name or "未记录"),16,"readerSender")
    local intro=P.IntroText(view.selfIntro,sender and sender.name)
    if intro~="" then P.Text(body,intro,16,"readerIntro") end
    local presentation=LetterPresentation.New(ctx,body,view)
    local cache={id=ctx.model.selectedLetter,label=presentation.paper.root,presentation=presentation}
    ctx.readerCache=cache
    ReaderOrder.Summary(body,view,definition)
    presentation.Refresh(view)
    local data=ctx.model.Refresh(); local existing=false
    for id,entry in pairs(data.live.orders.acceptedById) do if entry.letterInstanceId==ctx.model.selectedLetter then existing=id; break end end
    if existing then
        local confirmed=data.live.orders.confirmedById[existing]
        ReaderOrder.Action(body,"openOrder",confirmed and "查看已完成委托的记录" or "查看当前委托",function()
            if confirmed then ctx.storyId=definition.id; ctx.Open("journal") else ctx.Navigate("brew") end
        end)
    elseif definition.requirement then
        local action=gate(ctx,"Accept")
        ReaderOrder.Action(body,"acceptOrder","接下这份委托",function()
            if ctx.model.Accept().ok then ctx.Navigate("brew") end
        end,action.enabled,action.message)
    end
end
function P.RefreshReader(ctx)
    local cache=ctx.readerCache
    if not cache or cache.id~=ctx.model.selectedLetter then return false end
    local r=ctx.session.modules.letters.GetView(cache.id); if not r.ok then return false end
    cache.presentation.Refresh(r.value)
    return true
end
function P.Shop(ctx,body)
    local view=query(ctx,body,"GetShopView"); if not view then return end
    P.Text(body,"商队商店",22); P.Text(body,"金币 "..view.currency,16)
    if #view.items==0 then P.Text(body,"目前没有可购买的原料。") end
    for _,item in ipairs(view.items) do
        P.Text(body,item.name,18)
        P.Text(body,"已有 "..item.ownedQuantity.." 份 · 今日余量 "..item.remainingToday,14)
        local allowed=view.enabled and item.remainingToday>0 and view.currency>=item.price
        local reason=not view.enabled and view.message or item.remainingToday<=0 and "今日已售完。" or "金币不足。"
        P.Button(body,"buy_"..item.ingredientId,"购买一份 · "..item.price.." 金币",function() ctx.model.Buy(item.ingredientId) end,allowed,reason)
    end
end
function P.Case(ctx,body)
    local view=query(ctx,body,"GetCaseBoard"); if not view then return end
    if view.availability~="ready" then P.Text(body,"案件板尚未开放，暂无已解锁的案件资料。",16,"caseEmpty"); return end
    for _,node in ipairs(view.nodes) do P.Text(body,node.title,18); P.Text(body,node.summary) end
    for _,edge in ipairs(view.edges) do P.Text(body,edge.label,14) end
end
function P.Attempt(ctx,body)
    local record=query(ctx,body,"GetAttempt",ctx.model.selectedAttempt); if not record then return end
    P.Text(body,"试做记录 · "..(attemptNames[record.status] or record.status),22)
    P.Text(body,"第 "..record.attemptDay.." 天 · "..record.rating.stars.." 星",16)
    P.Text(body,record.followup.renderedText,18,"historyBody")
    P.Text(body,record.rating.feedback,16)
    local display=record.recipeDisplay
    if display.main then P.Text(body,"主词："..display.main.text) end
    for _,card in ipairs(display.aux) do P.Text(body,"辅词："..card.text) end
    for _,item in ipairs(display.ingredients) do P.Text(body,item.name.." × "..item.quantity) end
end
function P.Seaside(ctx,body)
    local view=query(ctx,body,"GetSalvageView"); if not view then return end
    P.Text(body,"海边捕捞",22)
    P.Text(body,"去码头看看漂流瓶，或登上商船采购。",14,"seasideStage")
    P.Text(body,"今日剩余 "..view.remaining.." / "..view.dailyLimit.." 次",18)
    if #view.availableLetterIds==0 then P.Text(body,"目前海面上没有可打捞的新信。") end
    P.Button(body,"startSalvage","开始捕捞",function()
        -- Re-query at click time; opening the scene never receives anything.
        local current=ctx.session.queries.GetSalvageView()
        if not current.ok then ctx.model.Notify(current); return end
        local id=current.value.availableLetterIds[1]
        if not current.value.enabled or not id then ctx.model.message=current.value.message or "目前没有可捕捞信件。"; ctx.model.dirty=true; return end
        local result=ctx.model.Receive(id)
        if result.ok then ctx.Read(result.value.letterInstanceId) end
    end,view.enabled,view.message)
    P.Button(body,"seasideShop","查看商队商店",function() ctx.Open("shop") end)
end
function P.Brew(ctx,body)
    local actions=ctx.brew and ctx.brew.actions or require("ui.landscape.BrewActionSounds").New(ctx.model,ctx.PlayObjectSound,
        function() return not ctx.destroyed and ctx.model.Action("UpdateDraft").enabled end)
    if ctx.session.state.GetStatus().migrationNotice then
        P.Text(body,"进度已更新。继续炼药前，请重新选择词与材料。",14,"migrationRecipeHint")
    end
    local summary=query(ctx,body,"GetOrderSummary"); if not summary then return end
    P.Text(body,"炼药工作区",22)
    P.Text(body,"选择词条和原料，为委托调制魔药。",14,"brewStage")
    if not summary.orderId then
        P.Text(body,"尚未接下委托。可先查看来信及现有词卡。")
        P.Button(body,"brewLetters","查看来信",function() ctx.Open("letters") end)
        P.Button(body,"brewWords","查看词条",function() ctx.Open("words") end); return
    end
    P.Text(body,summary.title,20); P.Text(body,"委托要求："..summary.requirementDesc,17)
    if summary.pending then
        P.Text(body,"试做结果已保存，等待决定。返回主页会保留这份结果。")
        P.Button(body,"openPending","查看待处理结果",function() ctx.Open("result") end); return
    end
    local draft=ctx.model.GetDraft()
    local words=query(ctx,body,"GetWordTray"); if not words then return end
    local names={}; for _,card in ipairs(words.cards) do names[card.tokenId]=card.text end
    local action=summary.actions.UpdateDraft
    P.Text(body,"已保存投料",18)
    P.Button(body,"slot_main",draft.mainTokenId and "主词 · "..(names[draft.mainTokenId] or "来源词卡").." · 取出" or "主词未选择",function()
        actions.TakeOut("word",draft.mainTokenId,"slot")
    end,action.enabled and not not draft.mainTokenId)
    for i,id in ipairs(draft.auxTokenIds) do P.Button(body,"slot_aux_"..i,"辅词 · "..(names[id] or "来源词卡").." · 取出",function() actions.TakeOut("word",id,"slot") end,action.enabled) end
    P.Button(body,"brewWords","选择来源词卡",function() ctx.Open("words") end)
    local data=ctx.model.Refresh()
    for _,item in ipairs(ctx.content.ingredients) do
        local selected=0; for _,line in ipairs(draft.ingredients) do if line.ingredientId==item.id then selected=line.quantity end end
        local owned=data.live.economy.ingredients[item.id] or 0
        local ingredientRow=UI.Panel {width="100%",flexDirection="row",gap=12,alignItems="center",pointerEvents="box-none"}
        ingredientRow:AddChild(IngredientArt.Panel(item.id,{id="brewArt_"..item.id,width=68,height=68}))
        local ingredientInfo=UI.Panel {flexGrow=1,flexShrink=1,flexBasis=0,minWidth=0,pointerEvents="box-none"}
        ingredientRow:AddChild(ingredientInfo)
        P.Text(ingredientInfo,item.name.." · 库存 "..owned.." · 已放 "..selected,15)
        P.Text(ingredientInfo,item.desc,13,"brewDesc_"..item.id)
        body:AddChild(ingredientRow)
        P.Button(body,"add_"..item.id,"放入一份",function() actions.Drop("ingredient",item.id) end,action.enabled and owned>selected)
        if selected>0 then P.Button(body,"minus_"..item.id,"取出一份",function() actions.TakeOut("ingredient",item.id) end,action.enabled) end
    end
    if summary.requirementHint.evaluated then
        if summary.potionPreview then
            P.Text(body,"当前药效",18,"brewEffectsTitle")
            for _,effect in ipairs(ctx.content.effects) do
                local weight=summary.potionPreview.effects[effect.id]
                if weight then P.Text(body,string.format("%s · %.2f · %s",effect.name,weight,
                    summary.potionPreview.intensityByEffect[effect.id]),14,"brewEffect_"..effect.id) end
            end
            P.Text(body,"辅料可不放；效果更强并不一定更合适。",13,"brewIngredientHint")
        end
        P.Text(body,summary.requirementHint.canShip and "当前投料满足字面要求。" or "当前投料尚未满足字面要求。",15)
        for _,failure in ipairs(summary.requirementHint.failures or {}) do P.Text(body,failure.message,14) end
    end
    P.Button(body,"clearDraft","移出全部投料",actions.Clear,action.enabled,action.message)
    local preview=summary.actions.Preview
    P.Button(body,"previewOrder","开始试做 · 保存后续结果",function()
        local r=ctx.model.Preview()
        if r.ok and r.value.phase=="pending" then ctx.Open("result") end
    end,preview.enabled and not not draft.mainTokenId,not draft.mainTokenId and "请先选择一张主词卡。" or preview.message)
    if ctx.model.failure then for _,failure in ipairs(ctx.model.failure.failures or {}) do P.Text(body,failure.message,15) end end
end
function P.Result(ctx,body)
    local summary=query(ctx,body,"GetOrderSummary"); if not summary then return end
    if not summary.pending then P.Text(body,"当前没有待处理结果。"); return end
    local record=query(ctx,body,"GetAttempt",summary.pending.transactionId); if not record then return end
    P.Text(body,"待处理的试做结果",22)
    P.Text(body,record.followup.renderedText,18,"pendingBody")
    P.Text(body,record.rating.stars.." 星 · "..record.rating.feedback,17)
    P.Text(body,"关闭或返回主页都会保留结果。只有点击发货并保存成功才会消耗投料、结算报酬。",14)
    P.Button(body,"confirmOrder","确认发货",function()
        if ctx.model.Resolve(true,summary.pending.transactionId).ok then ctx.storyId=record.sourceLetterId; ctx.Open("journal") end
    end,summary.actions.Confirm.enabled,summary.actions.Confirm.message)
    P.Button(body,"resetOrder","重置本次试做",function()
        if ctx.model.Resolve(false,summary.pending.transactionId).ok then ctx.Navigate("brew") end
    end,summary.actions.Reset.enabled,summary.actions.Reset.message)
end
P.Renderers={reader=P.Reader,shop=P.Shop,case=P.Case,
    attempt=P.Attempt,seaside=P.Seaside,brew=P.Brew,result=P.Result}
return P
