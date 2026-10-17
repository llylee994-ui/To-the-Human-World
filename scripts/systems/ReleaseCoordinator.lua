-- 纯终局命令计划与门禁；候选统一交给GameState提交，查询不触发保存。
local U=require "core.StateUtil"
local G=require "systems.CalculationGuard"
local L=require "systems.ReleaseLedger"
local Epilogue=require "systems.ReleaseEpilogue"
local Collage=require "systems.WishCollage"
local Records=require "systems.JourneyRecord"
local C={}
function C.New(content)
    local api={};local endings=require("systems.ReleaseEndings").New(content)
    local function revision(data,request) G.Need(request.expectedRevision==data.revision,"STALE_REVISION","expectedRevision","进度已变化，请重新确认") end
    local function planned(data,value,changed) return {data=data,value=value,changed=changed~=false,events={"ReleasePhaseChanged"}} end
    local function endedResult(result)
        return {ending=U.Copy(result.ending),departed=result.ending.kind=="departure",alreadyEnded=result.alreadyEnded,transactionId=result.data.chapter.endingTransactionId}
    end
    function api.GetAction(data,name)
        local phase=data.chapter.phase
        local readonly=({GetView=true,Save=true})[name]
        if readonly then return U.Ok(true) end
        if name=="RestoreEndingCheckpoint" then return data.chapter.checkpoint and U.Ok(true) or U.Fail("NO_ENDING_CHECKPOINT","checkpoint","尚无结束前快照") end
        if name=="StartNewPlaythrough" then return U.Ok(true) end
        if phase=="ended" then return U.Fail("RELEASE_ENDED","phase","旅程已结束，请返回结束前或开始新周目") end
        if phase~="operating" and not G.Value(endings.GetProgress(data)).canClose then
            return U.Fail("CLOSING_NOT_READY","progress","请返回收尾前，完成全部委托后再选择结局。")
        end
        if phase=="closing_prepare" then
            local prep=G.Value(endings.Preparation(data))
            if (name=="ReadLetter" or name=="CutWord") and prep.letterInstanceId then return U.Ok(true) end
            if name=="ReceiveLetter" and prep.needsReceive and data.live.gameFlow.canSalvage then return U.Ok(true) end
            return U.Fail("PREPARE_WORD_REQUIRED","phase","请先补读来信并剪下一个词")
        end
        if phase~="operating" then
            if ({BeginClosing=true,BeginWish=true,UpdateWishDraft=true,UpdateWishLayout=true,AdvanceEpilogue=true,ConfirmEnding=true})[name] then return U.Ok(true) end
            return U.Fail("RELEASE_CLOSED","phase","已进入收尾，不能继续经营")
        end
        if name=="NextDay" then return endings.RequireDayComplete(data) end
        if name=="BeginClosing" and not G.Value(endings.GetProgress(data)).canClose then return U.Fail("CLOSING_NOT_READY","progress","完成全部委托后才可进入收尾。") end
        if ({BeginWish=true,UpdateWishDraft=true,UpdateWishLayout=true,AdvanceEpilogue=true,ConfirmEnding=true})[name] then return U.Fail("INVALID_CHAPTER_STATE","phase","请先进入收尾") end
        return U.Ok(true)
    end
    function api.CheckPreparationRequest(data,name,request)
        return G.Run(function()
            if data.chapter.phase~="closing_prepare" then return true end
            local prep=G.Value(endings.Preparation(data))
            if name=="receive" then G.Need(prep.needsReceive and request.letterId==prep.letterId,"INVALID_REQUEST","letterId","只能补收首封来信")
            else G.Need(request.letterInstanceId==prep.letterInstanceId,"SOURCE_INVALID","letterInstanceId","请操作收尾准备页所用的真实来信") end
            return true
        end)
    end
    function api.AfterPreparation(data)
        if data.chapter.phase=="closing_prepare" and #G.Value(endings.GetWishSamples(data))>0 then
            data.chapter.phase="closing";data.chapter.epilogue=Epilogue.Begin(data,content)
        end
    end
    function api.GetTravelTicketView(data)
        return G.Run(function()
            local ticket=content.release.ticket;local day=data.live.gameFlow.day
            local gate=api.GetAction(data,"PurchaseTravelTicket")
            if gate.ok then gate=endings.RequireClear(data) end
            if gate.ok and (day<ticket.offerStartDay or day>ticket.lastPurchaseDay) then gate=U.Fail("OFFER_EXPIRED","day","船票已停售") end
            if gate.ok and data.live.economy.currency<ticket.price then gate=U.Fail("CURRENCY_SHORT","currency","金币不足") end
            if gate.ok and not endings.TextReady("departure") then gate=U.Fail("ENDING_TEXT_UNAVAILABLE","ending.text","这趟航程尚未开放。") end
            return {itemId=ticket.id,name="人间单程船票",price=ticket.price,offerStartDay=ticket.offerStartDay,lastPurchaseDay=ticket.lastPurchaseDay,
                currentDay=day,remainingDays=math.max(0,ticket.lastPurchaseDay-day+1),revision=data.revision,enabled=gate.ok,canDepart=gate.ok,
                departed=data.chapter.phase=="ended" and data.chapter.ending.kind=="departure",reasonCode=gate.ok and "" or gate.error.code,message=gate.ok and "" or gate.error.message}
        end)
    end
    function api.GetWishView(data)
        return G.Run(function()
            local ids=U.Copy(data.chapter.wishDraftSourceIds);local text=G.Value(endings.WishText(data,ids,true))
            local ready=G.Value(endings.GetProgress(data)).canClose
            return {phase=data.chapter.phase,samples=G.Value(endings.GetWishSamples(data)),draftSourceIds=ids,draftText=text,
                placements=Collage.Get(data),
                canConfirm=ready and data.chapter.phase=="wish" and #ids>0 and endings.TextReady("wish"),
                needsStoryCompletion=not ready,preparation=G.Value(endings.Preparation(data))}
        end)
    end
    function api.GetEndingView(data)
        return U.Ok({phase=data.chapter.phase,ending=U.Copy(data.chapter.ending),transactionId=data.chapter.endingTransactionId,
            canRestore=data.chapter.checkpoint~=false,canStartNew=true,hasProgress=data.chapter.started==true or data.revision>0,
            memories=Records.Remember(data)})
    end
    function api.GetEpilogueView(data)
        return G.Run(function()
            local ep=Epilogue.Get(data,content)
            ep.needsStoryCompletion=not G.Value(endings.GetProgress(data)).canClose
            return ep
        end)
    end
    function api.Plan(kind,data,request,initial)
        return G.Run(function()
            G.Pure(request,"request");G.Need(U.Integer(request.expectedRevision),"INVALID_REQUEST","expectedRevision","缺少确认时的存档版本")
            local keys={expectedRevision=true}
            if kind=="PurchaseTravelTicket" then keys={itemId=true,expectedDay=true,expectedPrice=true,expectedRevision=true}
            elseif kind=="ConfirmEnding" then keys.kind=true;keys.placements=true
            elseif kind=="UpdateWishDraft" then keys.sourceTokenIds=true
            elseif kind=="UpdateWishLayout" then keys.placements=true
            elseif kind=="AdvanceEpilogue" then keys.expectedStep=true end
            G.Keys(request,keys,"release.request")
            local phase=data.chapter.phase;local candidate=U.Copy(data)
            if ({BeginClosing=true,BeginWish=true,UpdateWishDraft=true,UpdateWishLayout=true,AdvanceEpilogue=true})[kind] then
                G.Need(G.Value(endings.GetProgress(data)).canClose,"CLOSING_NOT_READY","progress","请完成全部委托后再进入收尾；旧收尾进度可先返回收尾前。")
            end
            if kind=="StartJourney" then
                G.Need(phase=="operating","INVALID_CHAPTER_STATE","phase","请继续已保存的旅程。")
                if data.chapter.started or data.revision>0 then return planned(candidate,{phase=phase},false) end
                revision(data,request);candidate.chapter.started=true
            elseif kind=="PurchaseTravelTicket" then
                G.Need(request.itemId==content.release.ticket.id and U.Integer(request.expectedDay,1) and U.Integer(request.expectedPrice,1),"INVALID_REQUEST","ticket","船票报价不合法")
                if phase=="ended" then
                    local result=G.Value(endings.PlanEnding(data,{kind="departure",expectedRevision=request.expectedRevision}))
                    return planned(result.data,endedResult(result),false)
                end
                G.Need(phase=="operating","INVALID_CHAPTER_STATE","phase","收尾开始后不能购票")
                G.Value(endings.RequireClear(data));G.Need(request.expectedDay==data.live.gameFlow.day,"STALE_DAY","expectedDay","购买日期已变化")
                revision(data,request);G.Need(request.expectedPrice==content.release.ticket.price,"STALE_PRICE","expectedPrice","商品价格已变化")
                local result=G.Value(endings.PlanEnding(data,{kind="departure",expectedRevision=request.expectedRevision}))
                local out=planned(result.data,endedResult(result));out.events={"EndingConfirmed","MoneyChanged"};return out
            elseif kind=="ConfirmEnding" then
                G.Need(request.kind=="apprentice" or request.kind=="wish","INVALID_REQUEST","kind","离开请使用购买并启程")
                local result=G.Value(endings.PlanEnding(data,request));local out=planned(result.data,endedResult(result),not result.alreadyEnded)
                out.events={"EndingConfirmed"};return out
            elseif kind=="BeginClosing" then
                if phase=="closing_prepare" or phase=="closing" or phase=="wish" then return planned(candidate,{phase=phase},false) end
                G.Need(phase=="operating","INVALID_CHAPTER_STATE","phase","当前不能开始收尾")
                revision(data,request);G.Value(endings.RequireClear(data))
                candidate.chapter=L.EmptyChapter();candidate.chapter.checkpoint=U.Copy(data);candidate.chapter.checkpoint.chapter.checkpoint=false
                candidate.chapter.memories=Records.List(data);candidate.chapter.started=true
                candidate.chapter.phase=#G.Value(endings.GetWishSamples(data))==0 and "closing_prepare" or "closing"
                candidate.chapter.epilogue=Epilogue.Begin(data,content)
                if candidate.chapter.phase=="closing_prepare" then candidate.chapter.epilogue.step="prepare" end
            elseif kind=="AdvanceEpilogue" then
                G.Need(phase=="closing","INVALID_CHAPTER_STATE","phase","请继续当前旅程。")
                revision(data,request);local ep=Epilogue.Get(data,content)
                G.Need(request.expectedStep==ep.step,"STALE_EPILOGUE","expectedStep","这一步已经结束，请继续。")
                G.Need(ep.step=="dawn" or (ep.route=="wish" and ep.step=="shore"),"EPILOGUE_STEP_REQUIRED","step","请完成当前的尾声步骤。")
                ep.step=ep.step=="dawn" and (ep.route=="apprentice" and "letter" or "shore") or "bottle"
                candidate.chapter.epilogue=ep
            elseif kind=="BeginWish" then
                if phase=="wish" then return planned(candidate,{phase=phase},false) end
                G.Need(phase=="closing","PREPARE_WORD_REQUIRED","phase","请先进入收尾并获得真实词样本")
                local ep=Epilogue.Get(data,content)
                G.Need(ep.route=="wish","ENDING_ROUTE_LOCKED","route","请继续当前的尾声。")
                G.Need(ep.step=="bottle","EPILOGUE_STEP_REQUIRED","step","请先打开捞到的瓶子。")
                revision(data,request);candidate.chapter.phase="wish";candidate.chapter.epilogue={route="wish",step="compose"}
            elseif kind=="UpdateWishDraft" then
                G.Need(phase=="wish","INVALID_CHAPTER_STATE","phase","请先进入拼贴页")
                G.Value(endings.WishText(data,request.sourceTokenIds,true))
                revision(data,request)
                if U.Equal(request.sourceTokenIds,data.chapter.wishDraftSourceIds) then return planned(candidate,{phase=phase},false) end
                candidate.chapter.wishDraftSourceIds=U.Copy(request.sourceTokenIds);candidate.chapter.wishLayout=Collage.FromIds(request.sourceTokenIds)
            elseif kind=="UpdateWishLayout" then
                G.Need(phase=="wish","INVALID_CHAPTER_STATE","phase","请先打开愿望信纸。")
                revision(data,request)
                local known={};for _,row in ipairs(G.Value(endings.GetWishSamples(data))) do known[row.sourceTokenId]=true end
                local layout=G.Value(Collage.Validate(request.placements,known))
                if U.Equal(layout,Collage.Get(data)) then return planned(candidate,{phase=phase},false) end
                candidate.chapter.wishLayout=layout;candidate.chapter.wishDraftSourceIds=Collage.Order(layout)
            elseif kind=="RestoreEndingCheckpoint" then
                G.Need(data.chapter.checkpoint~=false,"NO_ENDING_CHECKPOINT","checkpoint","没有结束前快照")
                revision(data,request);candidate=U.Copy(data.chapter.checkpoint)
                candidate.chapter.memories=Records.Remember(data);candidate.chapter.started=true
            elseif kind=="StartNewPlaythrough" then
                revision(data,request);G.Need(initial and initial.contentVersion==data.contentVersion,"CONFIG_INVALID","initialState","缺少本版本新周目初态")
                candidate=U.Copy(initial)
                candidate.chapter.memories=Records.Remember(data);candidate.chapter.started=true
            else return G.Value(U.Fail("INVALID_REQUEST","command","未知终局命令")) end
            candidate.revision=data.revision+1
            return planned(candidate,{phase=candidate.chapter.phase,restored=kind=="RestoreEndingCheckpoint",startedNew=kind=="StartNewPlaythrough"})
        end)
    end
    return api
end
return C
