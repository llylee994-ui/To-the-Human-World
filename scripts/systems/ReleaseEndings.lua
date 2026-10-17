-- 纯资格、真实词来源和终局候选；不访问存档介质，不把消耗词变回可用。
local U=require "core.StateUtil"
local G=require "systems.CalculationGuard"
local L=require "systems.ReleaseLedger"
local E={}
function E.New(content)
    local api={}
    local function known(data)
        G.Need(type(data)=="table" and data.contentVersion==content.contentVersion,"CONTENT_VERSION_MISMATCH","contentVersion","结局只能使用当前内容存档")
        G.Need(type(content.release)=="table" and data.live,"CONFIG_MISSING","release","首发内容未接入")
    end
    local function completion(data)
        known(data)
        local required={};for _,id in ipairs(content.release.requiredOrderIds) do required[id]=true end
        local completed,three,seen=0,0,{}
        for _,oid in ipairs(G.Sorted(data.live.orders.confirmedById)) do
            local record=data.live.orders.confirmedById[oid];local accepted=data.live.orders.acceptedById[oid]
            G.Need(accepted and record.contentVersion==data.contentVersion,"STATE_INVALID","orders","确认来源或版本不符")
            if required[accepted.letterId] and not seen[accepted.letterId] then
                seen[accepted.letterId]=true;completed=completed+1
                if record.rating.stars==3 then three=three+1 end
            end
        end
        return seen,completed,three
    end
    function api.GetProgress(data)
        return G.Run(function()
            local _,completed,three=completion(data)
            local owned=G.Value(L.New(content).Validate(data.live.economy.itemPurchases))
            local homes,missing={},{}
            for _,item in ipairs(content.release.homeItems) do
                if owned[item.id] then homes[#homes+1]=item.id else missing[#missing+1]=item.id end
            end
            local count=#content.release.requiredOrderIds
            return {completedCount=completed,threeStarCount=three,requiredCount=count,requiredThreeStarCount=content.release.minThreeStarOrders,
                homeItemIds=homes,missingHomeItemIds=missing,canClose=completed==count,
                canApprentice=completed==count and three>=content.release.minThreeStarOrders and #missing==0}
        end)
    end
    function api.GetWishSamples(data)
        return G.Run(function()
            known(data)
            G.Value(require("core.SaveSchema").ValidateLetterTokens(data.live.letters,data.live.wordTokens,
                {letters=require("systems.Letter").New(content),wordTokens=require("systems.WordToken").New(content)}))
            local rows={}
            for _,id in ipairs(G.Sorted(data.live.wordTokens.byId)) do
                local token=data.live.wordTokens.byId[id];local word=G.Known(content,"words",token.wordId,"wordId")
                rows[#rows+1]={sourceTokenId=id,wordId=token.wordId,text=word.displayText,sourceLetterInstanceId=token.sourceLetterInstanceId,
                    sourceSpanId=token.sourceSpanId,available=token.available}
            end
            return rows
        end)
    end
    function api.WishText(data,ids,allowEmpty)
        return G.Run(function()
            G.Array(ids,"sourceTokenIds");G.Need(allowEmpty or #ids>0,"WISH_EMPTY","sourceTokenIds","至少拼贴一个词")
            local samples={};for _,row in ipairs(G.Value(api.GetWishSamples(data))) do samples[row.sourceTokenId]=row end
            local seen,pieces={},{}
            for _,id in ipairs(ids) do
                G.Need(U.String(id) and samples[id] and not seen[id],"SOURCE_INVALID","sourceTokenIds","只能使用已获得且不重复的来源")
                seen[id]=true;pieces[#pieces+1]=samples[id].text
            end
            return "我想"..table.concat(pieces)
        end)
    end
    function api.Preparation(data)
        return G.Run(function()
            known(data)
            local first=content.release.requiredOrderIds[1];local selected=false;local earliest=math.huge
            for id,row in pairs(data.live.letters.byId) do
                local def=G.Known(content,"letters",row.letterId,"letterId")
                local day=(def.appearCondition or {}).dayMin or 1
                if row.letterId==first then selected=id;break end
                if day<earliest or (day==earliest and (not selected or id<selected)) then selected=id;earliest=day end
            end
            return {letterId=selected and data.live.letters.byId[selected].letterId or first,letterInstanceId=selected,
                needsReceive=not selected,needsRead=selected and not data.live.letters.byId[selected].read or not selected}
        end)
    end
    function api.TextReady(kind)
        local row=content.releaseEndings and content.releaseEndings[kind]
        return type(row)=="table" and U.String(row.title) and U.String(row.text) and utf8.len(row.title)~=nil and utf8.len(row.text)~=nil
    end
    function api.RequireClear(data)
        return G.Run(function()
            local order=data.currentOrder
            G.Need(not order or not order.pending,"ORDER_LOCKED","currentOrder","请先发货或重置")
            G.Need(not order or require("systems.RecipeDraft").IsEmpty(order.draft),"DRAFT_NOT_EMPTY","draft","请先清空投料")
            return true
        end)
    end
    -- 只读正式发货事实。旧漏日档仍按每日额度补信，不要求一天打捞全部积压。
    function api.RequireDayComplete(data)
        return G.Run(function()
            known(data);G.Value(api.RequireClear(data))
            local completed=completion(data)
            local received={}
            for _,letter in pairs(data.live.letters.byId) do received[letter.letterId]=true end
            for _,id in ipairs(content.release.requiredOrderIds) do
                local definition=G.Known(content,"letters",id,"letterId")
                G.Need(not received[id] or completed[id],"DAY_ORDER_UNFINISHED","letterId",
                    "请先完成《"..(definition.title or id).."》的发货，再结束今天。")
            end
            if data.live.gameFlow.canSalvage then
                local available=G.Value(require("systems.Narrative").New(content).FindAvailable(data.live))
                G.Need(#available==0,"DAY_LETTER_UNRECEIVED","letters","今天还有来信，请先打捞并完成发货，再结束今天。")
            end
            return true
        end)
    end
    function api.PlanEnding(data,request)
        return G.Run(function()
            known(data);G.Keys(request,{kind=true,expectedRevision=true,sourceTokenIds=true,placements=true},"ending.request")
            G.Need(({departure=true,apprentice=true,wish=true})[request.kind] and U.Integer(request.expectedRevision),"INVALID_REQUEST","ending.request","请选择有效结局")
            if request.sourceTokenIds~=nil then
                G.Need(request.kind=="wish","INVALID_REQUEST","sourceTokenIds","只有拼贴结局可指定词来源")
                G.Value(api.WishText(data,request.sourceTokenIds,false))
                if data.chapter.phase=="ended" then G.Need(U.Equal(request.sourceTokenIds,data.chapter.ending.sourceTokenIds),"ALREADY_ENDED","sourceTokenIds","已保存的愿望不可作为重试改写") end
            end
            if request.placements~=nil then G.Need(request.kind=="wish","INVALID_REQUEST","placements","只有拼贴结局可保存信纸版式。") end
            if data.chapter.phase=="ended" then
                if request.placements~=nil then G.Need(data.chapter.ending.collage and U.Equal(request.placements,data.chapter.ending.collage.placements),"ALREADY_ENDED","placements","已寄出的信纸不能改写。") end
                G.Need(data.chapter.ending.kind==request.kind,"ALREADY_ENDED","kind","当前旅程已选择另一结局")
                return {data=U.Copy(data),ending=U.Copy(data.chapter.ending),alreadyEnded=true}
            end
            G.Need(request.expectedRevision==data.revision,"STALE_REVISION","expectedRevision","进度已变化，请重新确认")
            G.Value(api.RequireClear(data))
            local departure=request.kind=="departure"
            G.Need(departure and data.chapter.phase=="operating" or not departure and (data.chapter.phase=="closing" or data.chapter.phase=="wish"),
                "INVALID_CHAPTER_STATE","phase","请先进入对应收尾步骤")
            local progress=G.Value(api.GetProgress(data))
            if not departure then G.Need(progress.canClose,"CLOSING_NOT_READY","progress","尚未达到收尾条件") end
            if not departure then
                local ep=require("systems.ReleaseEpilogue").Get(data,content)
                G.Need(ep.route==request.kind,"ENDING_ROUTE_LOCKED","kind","请继续当前的尾声。")
                G.Need(request.kind=="wish" and ep.step=="compose" or request.kind=="apprentice" and ep.step=="letter",
                    "EPILOGUE_STEP_REQUIRED","phase","请先完成当前的尾声步骤。")
            end
            if request.kind=="apprentice" then G.Need(progress.canApprentice,"APPRENTICE_NOT_ELIGIBLE","progress","订单、三星数或家居尚不满足留下条件") end
            G.Need(api.TextReady(request.kind),"ENDING_TEXT_UNAVAILABLE","ending.text","这个选择暂时还无法确认。")
            local ids=request.kind=="wish" and (request.sourceTokenIds or data.chapter.wishDraftSourceIds) or {}
            if request.kind=="wish" then
                G.Need(U.Equal(ids,data.chapter.wishDraftSourceIds),"STALE_WISH_DRAFT","sourceTokenIds","请先保存当前拼贴，再封好瓶子。")
            end
            local visibleLayout
            if request.placements~=nil then
                local Collage=require "systems.WishCollage"
                local known={};for _,sample in ipairs(G.Value(api.GetWishSamples(data))) do known[sample.sourceTokenId]=true end
                visibleLayout=G.Value(Collage.Validate(request.placements,known))
                local order=Collage.Order(visibleLayout);local selected={}
                for _,id in ipairs(ids) do selected[id]=true end
                G.Need(#order==#ids,"STALE_WISH_DRAFT","placements","请先保存词条取用，再寄出信纸。")
                for _,id in ipairs(order) do G.Need(selected[id],"STALE_WISH_DRAFT","placements","预览中出现了未保存的词条。") end
                ids=order
            end
            local wishText=request.kind=="wish" and G.Value(api.WishText(data,ids,false)) or false
            local def=content.releaseEndings[request.kind];local all=progress.completedCount==progress.requiredCount and progress.threeStarCount==progress.requiredCount
            local text=def.text
            if wishText then text=text.."\n\n"..wishText end
            if request.kind=="apprentice" and all and U.String(def.allThreeStarText) then text=text.."\n\n"..def.allThreeStarText end
            local ending={kind=request.kind,title=def.title,text=text,wishText=wishText,sourceTokenIds=U.Copy(ids),allThreeStar=all}
            local candidate=U.Copy(data)
            if request.kind=="wish" then
                local Collage=require "systems.WishCollage"
                local samples=G.Value(api.GetWishSamples(data))
                if visibleLayout then candidate.chapter.wishLayout=visibleLayout end
                ending.collage=Collage.Freeze(candidate,samples)
            end
            if departure then
                candidate.chapter.checkpoint=U.Copy(data);candidate.chapter.checkpoint.chapter.checkpoint=false
                local ticket=content.release.ticket
                local purchase=G.Value(L.New(content).PlanPurchase(data.live.economy,
                    {itemId=ticket.id,expectedDay=data.live.gameFlow.day,expectedPrice=ticket.price,expectedRevision=data.revision},
                    {day=data.live.gameFlow.day,deliveredOrders=data.live.gameFlow.deliveredOrders,revision=data.revision,kind="departure"}))
                G.Need(not purchase.alreadyPurchased,"STATE_INVALID","ticket","船票不能重复入账")
                candidate.live.economy=purchase.state
            end
            candidate.revision=data.revision+1;candidate.chapter.phase="ended";candidate.chapter.ending=ending
            candidate.chapter.endingTransactionId="ending:"..request.kind..":"..candidate.revision
            candidate.chapter.wishDraftSourceIds=U.Copy(ids)
            if not departure then candidate.chapter.epilogue={route=request.kind,step="ended"} end
            candidate.chapter.memories=require("systems.JourneyRecord").Remember(candidate)
            return {data=candidate,ending=ending,alreadyEnded=false}
        end)
    end
    return api
end
return E
