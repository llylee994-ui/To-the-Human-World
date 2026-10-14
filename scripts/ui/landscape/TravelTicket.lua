-- Frontend quote and departure boundary; never changes money, days or saved endings.
local U=require "core.StateUtil"
---@alias TravelTicketQuote {itemId:string,name:string,price:integer,offerStartDay:integer,lastPurchaseDay:integer,currentDay:integer,remainingDays:integer,revision:integer,enabled:boolean,canDepart:boolean,reasonCode:string,message:string,departed?:boolean,ending?:table}
local T={id="travel_ticket",price=666,offerStartDay=1,lastPurchaseDay=10,
    image="image/商品_人间单程船票_透明_v01_20261013040555.png"}
function T.Get(ctx)
    local data=ctx.model.Refresh()
    if not data then return U.Fail("STATE_LOCKED","ticket","请先恢复进度，再查看船票。") end
    local quote={itemId=T.id,name="人间单程船票",price=T.price,offerStartDay=T.offerStartDay,
        lastPurchaseDay=T.lastPurchaseDay,currentDay=data.live.gameFlow.day,enabled=true,
        remainingDays=0,revision=data.revision,canDepart=false,reasonCode="",message=""} --[[@as TravelTicketQuote]]
    local query=rawget(ctx.session.queries,"GetTravelTicketView")
    if query then
        local result=query()
        if not result.ok then return result end
        if type(result.value)~="table" then return U.Fail("TICKET_VIEW_INVALID","ticket","暂时无法读取船票信息。") end
        quote=U.Copy(result.value)
        if not U.String(quote.itemId) or not U.String(quote.name) or not U.Integer(quote.price,1)
            or not U.Integer(quote.offerStartDay,1) or not U.Integer(quote.lastPurchaseDay,quote.offerStartDay)
            or not U.Integer(quote.currentDay,1) then
            return U.Fail("TICKET_VIEW_INVALID","ticket","暂时无法读取船票信息。")
        end
        if quote.currentDay~=data.live.gameFlow.day then return U.Fail("TICKET_VIEW_STALE","ticket","船票日期已更新，请重新查看。") end
    end
    quote.remainingDays=math.max(0,quote.lastPurchaseDay-quote.currentDay+1)
    quote.revision=data.revision
    local gate=ctx.model.Action("Shop")
    local enabled,code,message=true,"",""
    if quote.departed then enabled,code,message=false,"TRAVEL_ENDED","已经乘船启程。"
    elseif quote.currentDay<quote.offerStartDay then enabled,code,message=false,"TICKET_NOT_ON_SALE","第 "..quote.offerStartDay.." 天开始出售。"
    elseif quote.currentDay>quote.lastPurchaseDay then enabled,code,message=false,"TICKET_EXPIRED","船票已过期，无法购买。"
    elseif not gate.enabled then enabled,code,message=false,gate.reasonCode,gate.message
    elseif quote.enabled==false then enabled,code,message=false,quote.reasonCode or "TICKET_UNAVAILABLE",quote.message or "这趟航程暂时无法购买。"
    elseif data.live.economy.currency<quote.price then enabled,code,message=false,"CURRENCY_SHORT","金币不足，需要 "..quote.price.." 金币。" end
    quote.enabled,quote.reasonCode,quote.message=enabled,code,message
    quote.canDepart=enabled and type(rawget(ctx.session.state,"PurchaseTravelTicket"))=="function"
    return U.Ok(quote)
end
---@param quote TravelTicketQuote
function T.Expiry(quote)
    if quote.currentDay>quote.lastPurchaseDay then return "已过期，无法购买" end
    return quote.remainingDays.." 天后过期，过期后无法购买"
end
function T.Purchase(ctx)
    local result=T.Get(ctx)
    if not result.ok then return result end
    local quote=result.value
    if not quote.enabled then return U.Fail(quote.reasonCode,"ticket",quote.message) end
    local displayed=ctx.ticketQuote
    if not displayed then return U.Fail("TICKET_CONFIRMATION_REQUIRED","ticket","请先确认是否购买并启程。") end
    if quote.itemId~=displayed.itemId or quote.price~=displayed.price or quote.currentDay~=displayed.currentDay or quote.revision~=displayed.revision then
        return U.Fail("TICKET_QUOTE_CHANGED","ticket","船票信息或进度已更新，请核对后再确认。")
    end
    local command=rawget(ctx.session.state,"PurchaseTravelTicket")
    if type(command)~="function" then return U.Fail("NOT_IMPLEMENTED","ticket","这趟航程尚未开放。") end
    -- The dedicated coordinator owns revalidation, checkpoint, debit, ending and idempotency.
    return command({itemId=quote.itemId,expectedDay=quote.currentDay,expectedPrice=quote.price,expectedRevision=quote.revision})
end
return T
