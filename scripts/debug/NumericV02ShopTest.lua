local U=require "core.StateUtil"
local Data=require "data.content"
local F=require "debug.fixtures.B5Fixtures"
local T={}
local function must(r) assert(r.ok,cjson.encode(r.error));return r.value end
function T.Run()
    local x=F.New(Data)
    local before=x.state.GetSnapshot()
    local view=require("ui.PlayView").New(x.session,Data)
    local function click(id)
        local widget=assert(view.root:FindById(id),id)
        assert(not widget:GetProps().disabled,id)
        widget:GetProps().onClick();view.Update()
    end
    click("tab_shop");click("buy_ing_sea_salt");click("buy_ing_sea_salt")
    local bought=x.state.GetSnapshot()
    assert(bought.live.economy.currency==20)
    assert(bought.live.economy.ingredients.ing_sea_salt==5)
    assert(x.Reload())
    assert(U.Equal(x.state.GetSnapshot(),bought),"购买必须保存且可对账")
    local function reject(request,code)
        local old=x.state.GetSnapshot()
        local r=x.state.Shop(request)
        assert(not r.ok and r.error.code==code,cjson.encode(r))
        assert(U.Equal(old,x.state.GetSnapshot()),"失败购买不能改账本")
    end
    reject({ingredientId="ing_sea_salt",quantity=5},"SHOP_STOCK_SHORT")
    reject({ingredientId="ing_night_dew",quantity=2},"CURRENCY_SHORT")
    reject({ingredientId="unknown",quantity=1},"UNKNOWN_ID")
    reject({ingredientId="ing_sea_salt",quantity=0},"INVALID_REQUEST")
    x.fault="write"
    reject({ingredientId="ing_sea_salt",quantity=1},"SAVE_WRITE_FAILED")
    x.fault=false
    local instance=must(x.state.ReceiveLetter({letterId="letter_pa_01"})).letterInstanceId
    must(x.state.ReadLetter({letterInstanceId=instance}))
    local oid=must(x.order.Accept({letterInstanceId=instance})).orderId
    must(x.order.BeginBrew({orderId=oid}))
    reject({ingredientId="ing_sea_salt",quantity=1},"ORDER_LOCKED")
    local lockedView=require("ui.PlayView").New(x.session,Data)
    lockedView.model.Navigate("shop");lockedView.Update()
    assert(lockedView.root:FindById("buy_ing_sea_salt"):GetProps().disabled,"真实购买按钮受基准锁控制")
    must(x.order.CancelBrew({orderId=oid}))
    assert(x.state.CheckAction("Shop").enabled,"未试做时返回准备可补货")
    must(x.state.Shop({ingredientId="ing_night_dew",quantity=1}))
    local prepared=x.state.GetSnapshot().live
    must(x.order.BeginBrew({orderId=oid}))
    assert(U.Equal(x.state.GetSnapshot().currentOrder.baseline.live,prepared),"重新投料基准包含新购买")
    local restock=F.New(Data)
    must(restock.state.Shop({ingredientId="ing_sea_salt",quantity=6}))
    assert(not restock.state.Shop({ingredientId="ing_sea_salt",quantity=1}).ok)
    must(restock.state.NextDay())
    assert(restock.state.CheckAction("Shop").enabled)
    -- 下一日库存已重置；钱已花完，仍应先通过库存门槛，再报金币不足。
    local poor=restock.state.Shop({ingredientId="ing_sea_salt",quantity=1})
    assert(not poor.ok and poor.error.code=="CURRENCY_SHORT")
    -- 正式账本不能被直接加金币绕过购买/订单记录。
    local forged=x.state.GetSnapshot();forged.live.economy.currency=forged.live.economy.currency+1
    assert(not x.order.ValidateEnvelope(forged).ok)
    print("[NumericV02Shop] PASS saved purchase + price + stock + insufficient money + failure rollback + baseline lock")
    return true
end
return T
