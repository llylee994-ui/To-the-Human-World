-- Real game-day/money gates. Explicit departure adapters test frontend only.
local U=require "core.StateUtil"
local Data=require "data.content"
local F=require "debug.fixtures.B5Fixtures"
local View=require "ui.PlayView"
local T={}
local count=0
local function check(value,message) count=count+1;assert(value,message) end
local function must(r) assert(r.ok,cjson.encode(r.error));return r.value end
function T.Run()
    package.loaded["debug.DeveloperMode"]=false
    require("ui.landscape.tests.ZoomTestHost").New()
    local content=U.Copy(Data);content.stage1.initialEconomy.currency=666
    local x=F.New(content,{targetSchema=3});local view=View.New(x.session,content)
    local function control(id) return assert(view.root:FindById(id),"missing "..id) end
    local function click(id)
        if id=="shop_select_travel_ticket" and not view.root:FindById(id) then
            control("shopTab_tickets").props.onClick();view.Update()
        end
        local node=control(id);check(not node.props.disabled,"disabled "..id);node.props.onClick();view.Update()
    end
    view.Open("shop");view.Update()
    click("shopTab_tickets")
    check(view.root:FindById("shop_select_travel_ticket"),"ticket category keeps the travel product visible")
    click("shop_select_travel_ticket")
    local ticket=require "ui.landscape.TravelTicket"
    check(control("shopItemPrice"):GetText():find("666",1,true),"new confirmed price")
    check(control("ticketExpiry"):GetText():find("10",1,true),"day one includes ten purchasable days")
    check(not control("buy_travel_ticket").props.disabled,"exactly 666 can open confirmation")
    local before,writes=x.state.GetSnapshot(),x.writes
    click("buy_travel_ticket")
    check(control("ticketConfirmText"):GetText():find("直接进入结局",1,true),"explicit ending warning")
    check(control("confirmTravelTicket").props.disabled,"missing departure transaction cannot pretend to sell")
    check(control("ticketUnavailable"),"missing departure clearly shown")
    check(U.Equal(before,x.state.GetSnapshot()) and writes==x.writes,"opening does not buy/save")
    click("cancelTravelTicket")
    check(control("shopItemName"):GetText()=="人间单程船票","cancel returns selected ticket")
    check(U.Equal(before,x.state.GetSnapshot()) and writes==x.writes,"cancel never consumes/saves")
    -- With a departure endpoint, send a revision/day/price quote and present returned result.
    local commandRequest=false --[[@as table|false]]
    rawset(x.session.state,"PurchaseTravelTicket",function(request)
        commandRequest=U.Copy(request)
        return U.Fail("SAVE_WRITE_FAILED","ticket","模拟写盘失败")
    end)
    click("buy_travel_ticket");check(not control("confirmTravelTicket").props.disabled,"wired endpoint permits confirm")
    click("confirmTravelTicket")
    check(commandRequest.itemId=="travel_ticket" and commandRequest.expectedDay==1 and commandRequest.expectedPrice==666 and commandRequest.expectedRevision==before.revision,"quoted contract goes to dedicated departure command")
    check(view.ticketConfirm and control("panelMessage"):GetText():find("失败",1,true),"failure stays in confirmation")
    check(U.Equal(before,x.state.GetSnapshot()) and x.writes==writes,"frontend does not debit currency on failure")
    click("cancelTravelTicket")
    -- Revalidate a dialog after a real day advance, not a cached enable bit.
    click("buy_travel_ticket")
    for _=1,10 do must(x.state.NextDay()) end
    control("confirmTravelTicket").props.onClick();view.Update()
    check(commandRequest.expectedDay==1,"expired dialog must not invoke endpoint again")
    check(control("confirmTravelTicket").props.disabled,"day eleven blocks confirmation")
    check(control("ticketExpiry"):GetText():find("过期",1,true),"expiry warning visible in confirmation")
    click("cancelTravelTicket");check(control("buy_travel_ticket").props.disabled,"expired ticket remains visible but not saleable")
    -- Fresh exact-boundary checks use real NextDay and real currency snapshots.
    local days=F.New(content,{targetSchema=3})
    local ctx={session=days.session,model=require("ui.PlayModel").New(days.session,content)}
    local q=must(ticket.Get(ctx));check(q.remainingDays==10 and q.enabled,"day one offer")
    must(days.state.NextDay());q=must(ticket.Get(ctx));check(q.remainingDays==9,"cross day decreases once")
    for _=3,10 do must(days.state.NextDay()) end
    q=must(ticket.Get(ctx));check(q.remainingDays==1 and q.enabled,"last day still valid")
    must(days.state.NextDay());q=must(ticket.Get(ctx));check(q.remainingDays==0 and not q.enabled,"day eleven expired")
    local poorContent=U.Copy(Data);poorContent.stage1.initialEconomy.currency=665
    local poor=F.New(poorContent,{targetSchema=3});view=View.New(poor.session,poorContent);view.Open("shop");view.Update()
    click("shop_select_travel_ticket");check(control("buy_travel_ticket").props.disabled,"665 cannot buy")
    check(control("shopItemReason"):GetText():find("金币不足",1,true),"insufficient balance reason")
    check(not view.root:FindById("ticketConfirmText"),"insufficient balance cannot open confirmation")
    -- An authoritative query failure must not fall back to an apparently purchasable local offer.
    rawset(poor.session.queries,"GetTravelTicketView",function() return U.Fail("STATE_LOCKED","ticket","票务暂停") end)
    view.Refresh();view.Update();check(control("ticketQueryError"),"ticket query error shown")
    check(not view.root:FindById("buy_travel_ticket"),"failed quote has no purchase button")
    -- Recovery button refreshes the existing view rather than constructing another view.
    local recovery=F.New(content,{targetSchema=3})
    local savedEnding=false --[[@as boolean]]
    rawset(recovery.session.queries,"GetTravelTicketView",function()
        return U.Ok({itemId="travel_ticket",name="人间单程船票",price=666,offerStartDay=1,lastPurchaseDay=10,currentDay=1,
            enabled=not savedEnding,departed=savedEnding,ending=savedEnding and {title="已保存结局",text="读回的结局正文。"} or nil})
    end)
    rawset(recovery.session.state,"PurchaseTravelTicket",function() return U.Fail("COMMIT_RECOVERY_REQUIRED","ticket","需要重读进度") end)
    view=View.New(recovery.session,content);view.Open("shop");view.Update()
    click("shop_select_travel_ticket");click("buy_travel_ticket");click("confirmTravelTicket")
    check(view.ticketConfirm,"uncertain endpoint response stays in dialog before recovery")
    savedEnding=true;view.Refresh();view.Update()
    check(view.panel=="ticketEnding" and control("travelEndingText"):GetText()=="读回的结局正文。","existing view refresh restores committed departure ending")
    -- The frontend renders actual endpoint text, rather than inventing an ending.
    local success=F.New(content,{targetSchema=3});view=View.New(success.session,content)
    rawset(success.session.state,"PurchaseTravelTicket",function() return U.Ok({departed=true,ending={title="适配器结局标题",text="适配器返回的结局正文。"}}) end)
    view.Open("shop");view.Update();click("shop_select_travel_ticket");click("buy_travel_ticket");click("confirmTravelTicket")
    check(view.panel=="ticketEnding" and control("travelEndingText"):GetText()=="适配器返回的结局正文。","only render supplied ending result")
    check(not view.root:FindById("nextDay").props.visible,"frontend hides day action in ending presentation")
    print("[TravelTicketTest] PASS assertions="..count.."; real day/balance gates, cancel/no writes, dedicated endpoint adapters; actual departure persistence NOT implemented/tested")
    return true
end
return T
