-- 首发永久商品的纯计划；不持有状态、不写文件。
local U=require "core.StateUtil"
local G=require "systems.CalculationGuard"
local L={}
function L.EmptyChapter() return {phase="operating",wishDraftSourceIds={},ending=false,endingTransactionId=false,checkpoint=false} end
function L.New(content)
    local api={}
    local function catalog()
        G.Need(type(content.release)=="table","CONFIG_MISSING","release","未配置首发商品")
        local rows={};G.Array(content.release.homeItems,"homeItems","CONFIG_INVALID")
        for _,item in ipairs(content.release.homeItems) do
            G.Need(U.String(item.id) and U.Integer(item.price,1) and not rows[item.id],"CONFIG_INVALID","homeItems","商品ID或价格错误")
            rows[item.id]={id=item.id,price=item.price,kind="home"}
        end
        local t=content.release.ticket
        G.Need(type(t)=="table" and U.String(t.id) and U.Integer(t.price,1) and not rows[t.id] and U.Integer(t.offerStartDay,1)
            and U.Integer(t.lastPurchaseDay,t.offerStartDay),"CONFIG_INVALID","ticket","船票报价错误")
        rows[t.id]={id=t.id,price=t.price,kind="departure",firstDay=t.offerStartDay,lastDay=t.lastPurchaseDay}
        return rows
    end
    function api.Validate(rows)
        return G.Run(function()
            G.Array(rows,"itemPurchases","STATE_INVALID")
            local items=catalog();local owned,transactions={},{};local day,delivered=1,0
            for _,row in ipairs(rows) do
                G.Keys(row,{itemId=true,unitPrice=true,day=true,afterDeliveredOrders=true,transactionId=true},"itemPurchases","STATE_INVALID")
                local item=items[row.itemId]
                G.Need(item and row.unitPrice==item.price and not owned[row.itemId] and not transactions[row.transactionId]
                    and row.transactionId=="purchase:"..row.itemId and U.Integer(row.day,day) and U.Integer(row.afterDeliveredOrders,delivered),
                    "STATE_INVALID","itemPurchases","商品、价格、时序或唯一事务不合法")
                if item.kind=="departure" then G.Need(row.day>=item.firstDay and row.day<=item.lastDay,"STATE_INVALID","itemPurchases.day","船票超出销售窗口") end
                owned[row.itemId]=true;transactions[row.transactionId]=true;day,delivered=row.day,row.afterDeliveredOrders
            end
            return owned
        end)
    end
    function api.PlanPurchase(base,request,context)
        return G.Run(function()
            G.Value(require("systems.Economy").New(content).ValidateSnapshot(base))
            G.Need(base.itemPurchases~=nil,"STATE_INVALID","itemPurchases","需要首发永久采购账")
            G.Keys(request,{itemId=true,expectedDay=true,expectedPrice=true,expectedRevision=true},"purchase.request")
            G.Need(U.String(request.itemId) and U.Integer(request.expectedDay,1) and U.Integer(request.expectedPrice,1) and U.Integer(request.expectedRevision),"INVALID_REQUEST","purchase.request","缺少完整报价")
            local item=catalog()[request.itemId];G.Need(item,"UNKNOWN_ID","itemId","未知永久商品")
            G.Need(type(context)=="table" and U.Integer(context.day,1) and U.Integer(context.deliveredOrders) and U.Integer(context.revision)
                and context.kind==item.kind,"INVALID_REQUEST","purchase.context","购买类型或正式进度错误")
            G.Need(request.expectedPrice==item.price,"STALE_PRICE","expectedPrice","商品价格已变化")
            local owned=G.Value(api.Validate(base.itemPurchases));local transactionId="purchase:"..item.id
            -- 永久商品每件一次；重复确认优先于旧日期/revision。
            if owned[item.id] then return {state=U.Copy(base),cost=0,itemId=item.id,transactionId=transactionId,alreadyPurchased=true} end
            G.Need(request.expectedDay==context.day,"STALE_DAY","expectedDay","购买日期已变化")
            G.Need(request.expectedRevision==context.revision,"STALE_REVISION","expectedRevision","存档已变化，请重新查看报价")
            if item.kind=="departure" then G.Need(context.day>=item.firstDay and context.day<=item.lastDay,"OFFER_EXPIRED","day","船票已停售") end
            for _,row in ipairs(base.itemPurchases) do G.Need(row.day<=context.day and row.afterDeliveredOrders<=context.deliveredOrders,"STATE_INVALID","itemPurchases","购买记录超出当前进度") end
            G.Need(base.currency>=item.price,"CURRENCY_SHORT","currency","金币不足")
            local candidate=U.Copy(base);candidate.currency=candidate.currency-item.price
            candidate.itemPurchases[#candidate.itemPurchases+1]={itemId=item.id,unitPrice=item.price,day=context.day,afterDeliveredOrders=context.deliveredOrders,transactionId=transactionId}
            G.Value(require("systems.Economy").New(content).ValidateSnapshot(candidate))
            return {state=candidate,cost=item.price,itemId=item.id,transactionId=transactionId,alreadyPurchased=false}
        end)
    end
    return api
end
return L
