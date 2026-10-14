-- 捕捉真实扣款、旧报价、重复提交、草稿边界及前端只选不买的回归。
local U=require "core.StateUtil"
local R=require "debug.fixtures.ReleaseFixtures"
local must=R.Must
local T={}
local function reject(x,q,code)
    local before=x.state.GetSnapshot();local r=x.state.PurchaseHomeItem(q)
    assert(not r.ok and r.error.code==code,cjson.encode(r))
    assert(U.Equal(before,x.state.GetSnapshot()))
end
function T.Run()
    local check,done=R.Checks("ReleasePurchase")
    check("schema4 real purchase, single ledger and idempotent retry",function()
        local x=R.New(100);local before=x.state.GetSnapshot()
        assert(before.chapter.phase=="operating" and U.Array(before.live.economy.itemPurchases))
        local q=R.Quote(x,"decor_chair",100);local result=must(x.state.PurchaseHomeItem(q))
        local after=x.state.GetSnapshot()
        assert(result.cost==100 and result.itemId=="decor_chair" and result.currency==0)
        assert(after.revision==before.revision+1 and #after.live.economy.itemPurchases==1)
        assert(after.live.economy.furniturePurchases==nil and after.live.economy.ownedFurnitureIds==nil)
        local writes=x.writes
        assert(must(x.state.PurchaseHomeItem(q)).alreadyPurchased and x.writes==writes)
        assert(x.Reload() and U.Equal(after,x.state.GetSnapshot()))
        assert(must(x.session.queries.GetFurnitureShopView()).items[2].owned)
    end)
    check("exact price/date/revision and no future money",function()
        local x=R.New(99);reject(x,R.Quote(x,"decor_chair",100),"CURRENCY_SHORT")
        x=R.New(600)
        reject(x,R.Quote(x,"unknown_home",100),"UNKNOWN_ID")
        reject(x,R.Quote(x,"decor_chair",99),"STALE_PRICE")
        local q=R.Quote(x,"decor_chair",100);must(x.state.NextDay());reject(x,q,"STALE_DAY")
        q=R.Quote(x,"decor_chair",100);must(x.state.Shop({ingredientId="ing_sea_salt",quantity=1}));reject(x,q,"STALE_REVISION")
        reject(x,R.Quote(x,"travel_ticket",666),"INVALID_REQUEST")
    end)
    check("all four permanent homes cost 480 and remain owned after reload",function()
        local x=R.New(480)
        for _,row in ipairs({{"decor_tablecloth",60},{"decor_chair",100},{"decor_lamp",140},{"decor_bookshelf",180}}) do
            must(x.state.PurchaseHomeItem(R.Quote(x,row[1],row[2])))
        end
        assert(x.Reload());local d=x.state.GetSnapshot()
        assert(d.live.economy.currency==0 and #d.live.economy.itemPurchases==4)
        for _,item in ipairs(must(x.session.queries.GetFurnitureShopView()).items) do assert(item.owned) end
    end)
    check("pure departure ledger honors D10/D11; no ending is committed",function()
        local x=R.New(666)
        for _=1,9 do must(x.state.NextDay()) end
        local before=x.state.GetSnapshot();local ledger=require("systems.ReleaseLedger").New(x.content)
        local context={day=10,deliveredOrders=0,revision=before.revision,kind="departure"}
        local quote=R.Quote(x,"travel_ticket",666);local plan=must(ledger.PlanPurchase(before.live.economy,quote,context))
        assert(plan.state.currency==0 and plan.state.itemPurchases[1].itemId=="travel_ticket")
        assert(U.Equal(before,x.state.GetSnapshot()),"pure ticket plan cannot buy or end game")
        must(x.state.NextDay());local d=x.state.GetSnapshot();context.day=11;context.revision=d.revision
        local expired=ledger.PlanPurchase(d.live.economy,R.Quote(x,"travel_ticket",666),context)
        assert(not expired.ok and expired.error.code=="OFFER_EXPIRED")
    end)
    check("nonempty draft and pending reject; clearing permits purchase",function()
        local x=R.New(600);local request=R.Accept(x,1)
        must(x.order.UpdateDraft({orderId=request.orderId,draft=require("systems.RecipeDraft").Project(request)}))
        reject(x,R.Quote(x,"decor_chair",100),"DRAFT_NOT_EMPTY")
        local pending=must(x.order.Preview(request));reject(x,R.Quote(x,"decor_chair",100),"ORDER_LOCKED")
        local d=x.state.GetSnapshot().currentOrder
        must(x.order.Reset({orderId=request.orderId,transactionId=pending.transactionId,baselineId=d.baseline.id}))
        must(x.state.PurchaseHomeItem(R.Quote(x,"decor_chair",100)))
    end)
    check("actual shop selection is read-only; purchase and ownership survive reload",function()
        package.loaded["debug.DeveloperMode"]=false
        require("ui.landscape.tests.ZoomTestHost").New()
        local x=R.New(600);local view=require("ui.PlayView").New(x.session,x.content)
        local function click(id)
            local w=assert(view.root:FindById(id));assert(not w.props.disabled);w.props.onClick();view.Update()
        end
        view.Open("shop");view.Update();local before=x.state.GetSnapshot();local writes=x.writes
        click("shopTab_furniture");click("shop_select_decor_chair")
        assert(U.Equal(before,x.state.GetSnapshot()) and x.writes==writes)
        local stale=assert(view.root:FindById("buy_decor_chair")).props.onClick
        must(x.state.NextDay());stale();view.Update()
        assert(x.state.GetSnapshot().live.economy.currency==600 and view.model.message:find("购买日期",1,true),"old rendered quote cannot purchase after crossing day")
        click("buy_decor_chair")
        assert(x.state.GetSnapshot().live.economy.currency==500)
        assert(view.root:FindById("buy_decor_chair").props.disabled)
        assert(x.state.ReloadCurrent());view.Refresh();view.Update()
        assert(view.root:FindById("buy_decor_chair").props.disabled);view.root:Destroy()
    end)
    check("real interleaved material, delivery, home and second delivery audit",function()
        local x=R.New(30)
        must(x.state.Shop({ingredientId="ing_sea_salt",quantity=1}))
        R.Ship(x,1);must(x.state.PurchaseHomeItem(R.Quote(x,"decor_tablecloth",60)))
        must(x.state.NextDay());R.Ship(x,2)
        must(x.state.PurchaseHomeItem(R.Quote(x,"decor_chair",100)))
        assert(x.Reload());local d=x.state.GetSnapshot()
        assert(d.live.economy.currency==65 and d.live.gameFlow.deliveredOrders==2)
        assert(#d.journal.attemptIds==2 and #d.live.economy.itemPurchases==2)
    end)
    return done()
end
return T
