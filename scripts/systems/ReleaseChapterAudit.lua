-- 校验冻结终局及其完整结束前快照；不重新生成或评分结局正文。
local U=require "core.StateUtil"
local G=require "systems.CalculationGuard"
local L=require "systems.ReleaseLedger"
local A={}
local function same(a,b,path) G.Need(U.Equal(a,b),"STATE_INVALID",path,"收尾状态与结束前快照不一致") end
function A.Validate(data,content)
    return G.Run(function()
        G.Need(content and content.release,"CONFIG_MISSING","release","缺少首发配置")
        local e=require("systems.ReleaseEndings").New(content);local c=data.chapter
        local phases={operating=true,closing_prepare=true,closing=true,wish=true,ended=true}
        G.Need(phases[c.phase] and data.live.gameFlow.day<=content.release.finalDay,"STATE_INVALID","chapter.phase","阶段或最终日期不合法")
        G.Array(c.wishDraftSourceIds,"wishDraftSourceIds","STATE_INVALID")
        local tickets=0
        for _,row in ipairs(data.live.economy.itemPurchases) do if row.itemId==content.release.ticket.id then tickets=tickets+1 end end
        if c.phase=="operating" then
            same(c,L.EmptyChapter(),"chapter");G.Need(tickets==0,"STATE_INVALID","itemPurchases","船票必须随终局提交")
            return true
        end
        local cp=c.checkpoint
        G.Need(type(cp)=="table" and type(cp.chapter)=="table" and cp.chapter.checkpoint==false,"STATE_INVALID","checkpoint","快照不可缺失或嵌套")
        same(cp.chapter,L.EmptyChapter(),"checkpoint.chapter")
        G.Need(cp.contentVersion==data.contentVersion and U.Integer(cp.revision) and cp.revision<data.revision,"STATE_INVALID","checkpoint.revision","结束前快照版本不符")
        -- 完整业务审计一次；子快照chapter为经营态，不再递归包含快照。
        G.Value(require("systems.OrderTrial").Wrap(require("systems.Order").New(content,{schema4Projection=true}),content,
            (content.gameplay or require("data.gameplay")).salvageDailyLimit,4).ValidateEnvelope(cp))
        G.Value(e.RequireClear(cp));G.Value(e.RequireClear(data))
        same(data.currentOrder,cp.currentOrder,"currentOrder");same(data.nextOrderSerial,cp.nextOrderSerial,"nextOrderSerial");same(data.journal,cp.journal,"journal")
        for _,key in ipairs({"world","narrative","orders"}) do same(data.live[key],cp.live[key],"live."..key) end
        local departure=c.phase=="ended" and type(c.ending)=="table" and c.ending.kind=="departure"
        if not departure then G.Need(G.Value(e.GetProgress(cp)).canClose,"STATE_INVALID","checkpoint.day","快照尚未达到收尾条件") end
        local beforeSamples=G.Value(e.GetWishSamples(cp));local samples=G.Value(e.GetWishSamples(data))
        if #beforeSamples>0 or departure then
            same(data.live.gameFlow,cp.live.gameFlow,"gameFlow");same(data.live.letters,cp.live.letters,"letters");same(data.live.wordTokens,cp.live.wordTokens,"wordTokens")
        else
            -- 零词准备仅允许补读所选真实来信，最多正常接收一信、剪取一词。
            G.Need(#samples<=1,"STATE_INVALID","wordTokens","补读准备只允许获得一个样本")
            local prep=G.Value(e.Preparation(cp));local selected=prep.letterInstanceId or "letter:"..prep.letterId
            local added=0
            for id,row in pairs(data.live.letters.byId) do
                local old=cp.live.letters.byId[id]
                if not old then G.Need(prep.needsReceive and id==selected,"STATE_INVALID","letters","收尾不能补收其它信");added=added+1
                elseif id~=selected then same(row,old,"letters."..id)
                else
                    local expected=U.Copy(old);expected.read=row.read;expected.cutSpans=U.Copy(row.cutSpans)
                    same(row,expected,"letters."..id)
                end
            end
            for id in pairs(cp.live.letters.byId) do G.Need(data.live.letters.byId[id],"STATE_INVALID","letters","收尾不能删除旧信") end
            local queue=U.Copy(cp.live.letters.bottleQueue);if added==1 then queue[#queue+1]=selected end
            same(data.live.letters.bottleQueue,queue,"bottleQueue");same(data.live.letters.directArchive,cp.live.letters.directArchive,"directArchive")
            local flow=U.Copy(cp.live.gameFlow)
            flow.salvageUsedToday=flow.salvageUsedToday+added;flow.canSalvage=data.live.gameFlow.canSalvage
            same(data.live.gameFlow,flow,"gameFlow")
            for _,sample in ipairs(samples) do G.Need(sample.sourceLetterInstanceId==selected,"STATE_INVALID","sample.source","样本不属于准备来信") end
        end
        if departure then
            local ticket=content.release.ticket
            local expected=G.Value(L.New(content).PlanPurchase(cp.live.economy,
                {itemId=ticket.id,expectedDay=cp.live.gameFlow.day,expectedPrice=ticket.price,expectedRevision=cp.revision},
                {day=cp.live.gameFlow.day,deliveredOrders=cp.live.gameFlow.deliveredOrders,revision=cp.revision,kind="departure"}))
            G.Need(not expected.alreadyPurchased and tickets==1,"STATE_INVALID","ticket","启程票款不合法")
            same(data.live.economy,expected.state,"economy")
        else
            G.Need(tickets==0,"STATE_INVALID","ticket","非离开结局不能扣票款");same(data.live.economy,cp.live.economy,"economy")
        end
        G.Value(e.WishText(data,c.wishDraftSourceIds,true))
        if c.phase~="ended" then
            G.Need(c.ending==false and c.endingTransactionId==false,"STATE_INVALID","ending","未确认阶段不能保存结局")
            if c.phase=="closing_prepare" then G.Need(#samples==0 and #beforeSamples==0 and #c.wishDraftSourceIds==0,"STATE_INVALID","samples","准备阶段尚不能拼贴")
            elseif c.phase=="closing" then G.Need(#samples>0 and #c.wishDraftSourceIds==0,"STATE_INVALID","samples","选择阶段须有样本且无愿望草稿")
            else G.Need(#samples>0,"STATE_INVALID","samples","拼贴须有真实样本") end
            return true
        end
        local ending=c.ending
        G.Keys(ending,{kind=true,title=true,text=true,wishText=true,sourceTokenIds=true,allThreeStar=true},"ending","STATE_INVALID")
        G.Need(({departure=true,apprentice=true,wish=true})[ending.kind] and U.String(ending.title) and U.String(ending.text)
            and utf8.len(ending.title) and utf8.len(ending.text),"STATE_INVALID","ending.text","缺少冻结终局正文")
        G.Need(c.endingTransactionId=="ending:"..ending.kind..":"..data.revision,"STATE_INVALID","endingTransactionId","终局事务不符")
        local progress=G.Value(e.GetProgress(data))
        G.Need(ending.allThreeStar==(progress.completedCount==progress.requiredCount and progress.threeStarCount==progress.requiredCount),"STATE_INVALID","allThreeStar","认可标志与正式成绩不符")
        if ending.kind=="wish" then
            same(ending.sourceTokenIds,c.wishDraftSourceIds,"ending.sources")
            local text=G.Value(e.WishText(data,c.wishDraftSourceIds,false))
            G.Need(ending.wishText==text and ending.text:sub(-#text)==text,"STATE_INVALID","wishText","愿望原句与真实来源不符")
        else
            G.Need(ending.wishText==false and U.Equal(ending.sourceTokenIds,{}) and #c.wishDraftSourceIds==0,"STATE_INVALID","wishText","该结局不能带拼贴草稿")
            if ending.kind=="apprentice" then G.Need(progress.canApprentice,"STATE_INVALID","progress","学徒资格不成立") end
        end
        return true
    end)
end
return A
