-- Real GameSession/Economy/OrderAudit/SaveSystem; only file media are isolated.
local U=require "core.StateUtil"
local Data=require "data.content"
local F=require "debug.fixtures.B5Fixtures"
local T={}
local function must(r) assert(r.ok,cjson.encode(r.error)); return r.value end
local catalog={
    {id="decor_tablecloth",name="桌布",price=60},
    {id="decor_chair",name="椅子",price=100},
    {id="decor_lamp",name="挂灯",price=140},
    {id="decor_bookshelf",name="书架",price=180},
}
local function content(money)
    local c=U.Copy(Data); c.furniture=U.Copy(catalog)
    c.stage1.initialEconomy.currency=money or 600
    return c
end
local function reject(x,request,code)
    local before=x.state.GetSnapshot(); local events=#x.events
    local result=x.state.PurchaseFurniture(request)
    assert(not result.ok and result.error.code==code,cjson.encode(result))
    assert(U.Equal(before,x.state.GetSnapshot()),"rejected purchase changed formal state")
    assert(#x.events==events,"rejected purchase emitted business events")
end
local function prepare(x)
    local id=must(x.state.ReceiveLetter({letterId="letter_pa_01"})).letterInstanceId
    must(x.state.ReadLetter({letterInstanceId=id}))
    ---@type string|nil
    local token
    for _,span in ipairs(must(x.modules.letters.ParseDefinition("letter_pa_01")).spans) do
        if span.wordId=="word_candidate_elias_sleep" then
            token=must(x.state.CutWord({letterInstanceId=id,spanId=span.spanId})).tokenId
        end
    end
    local oid=must(x.order.Accept({letterInstanceId=id})).orderId
    local recipe={equipmentId="kit_old_cauldron",mainTokenId=assert(token),auxTokenIds={},ingredients={{ingredientId="ing_sea_salt",quantity=1}},specialItemIds={}}
    if x.state.GetStatus().schema==3 then must(x.order.UpdateDraft({orderId=oid,draft=recipe}))
    else recipe.baselineId=must(x.order.BeginBrew({orderId=oid})).baselineId end
    recipe.orderId=oid
    local pending=must(x.order.Preview(recipe))
    return oid,pending.transactionId,x.state.GetSnapshot().currentOrder.baseline.id
end
function T.Run()
    local x=F.New(content(),{targetSchema=3})
    assert(U.Equal(require("data.furniture"),catalog),"confirmed catalog differs from test expectations")
    assert(type(x.state.PurchaseFurniture)=="function","missing real furniture transaction")
    local before=x.state.GetSnapshot()
    local view=must(x.session.queries.GetFurnitureShopView())
    assert(view.enabled and view.currency==600 and #view.items==4)
    for i,item in ipairs(view.items) do
        assert(item.furnitureId==catalog[i].id and item.name==catalog[i].name and item.price==catalog[i].price and item.owned==false)
    end
    local value=must(x.state.PurchaseFurniture({furnitureId="decor_tablecloth"}))
    local bought=x.state.GetSnapshot()
    assert(value.cost==60 and value.furnitureId=="decor_tablecloth" and value.owned==true)
    assert(bought.live.economy.currency==540 and bought.live.economy.ownedFurnitureIds.decor_tablecloth)
    assert(#bought.live.economy.furniturePurchases==1 and bought.revision==before.revision+1)
    assert(U.Equal(bought.live.world,before.live.world) and U.Equal(bought.live.economy.ownedEquipmentIds,before.live.economy.ownedEquipmentIds))
    assert(x.Reload() and U.Equal(x.state.GetSnapshot(),bought),"purchase not durable")
    assert(must(x.session.queries.GetFurnitureShopView()).items[1].owned)
    reject(x,{furnitureId="decor_tablecloth"},"FURNITURE_ALREADY_OWNED")
    reject(x,{furnitureId="unknown"},"UNKNOWN_ID")
    reject(x,{furnitureId="decor_chair",quantity=2},"UNKNOWN_FIELD")
    must(x.state.Shop({ingredientId="ing_sea_salt",quantity=1}))
    must(x.state.NextDay())
    must(x.state.PurchaseFurniture({furnitureId="decor_chair"}))
    must(x.state.PurchaseFurniture({furnitureId="decor_lamp"}))
    must(x.state.PurchaseFurniture({furnitureId="decor_bookshelf"}))
    assert(x.state.GetSnapshot().live.economy.currency==115)
    assert(x.Reload() and #x.state.GetSnapshot().live.economy.furniturePurchases==4,"cross-day furniture lost")
    local poor=F.New(content(59),{targetSchema=3})
    reject(poor,{furnitureId="decor_tablecloth"},"CURRENCY_SHORT")
    for _,fault in ipairs({"write","readback","encode"}) do
        local y=F.New(content(),{targetSchema=3}); y.fault=fault
        local old=y.state.GetSnapshot()
        assert(not y.state.PurchaseFurniture({furnitureId="decor_tablecloth"}).ok)
        assert(U.Equal(old,y.state.GetSnapshot()),fault.." changed formal state")
        y.fault=false; assert(y.Reload()); assert(y.state.GetSnapshot().live.economy.currency==600)
    end
    local uncertain=F.New(content(),{targetSchema=3}); uncertain.fault="uncertain"
    local original=uncertain.state.GetSnapshot()
    assert(not uncertain.state.PurchaseFurniture({furnitureId="decor_tablecloth"}).ok)
    assert(U.Equal(original,uncertain.state.GetSnapshot()) and not uncertain.state.CanMutate())
    reject(uncertain,{furnitureId="decor_chair"},"STATE_LOCKED")
    uncertain.fault=false; assert(uncertain.Reload())
    assert(uncertain.state.GetSnapshot().live.economy.currency==540 and uncertain.state.GetSnapshot().live.economy.ownedFurnitureIds.decor_tablecloth)
    local reentry=F.New(content(),{targetSchema=3})
    ---@type table|nil
    local nested
    reentry.onEvent=function(name)
        if name=="FurniturePurchased" then nested=reentry.state.PurchaseFurniture({furnitureId="decor_chair"}) end
    end
    must(reentry.state.PurchaseFurniture({furnitureId="decor_tablecloth"}))
    assert(nested and not nested.ok and nested.error.code=="COMMAND_BUSY")
    assert(reentry.state.GetSnapshot().live.economy.currency==540 and not reentry.state.GetSnapshot().live.economy.ownedFurnitureIds.decor_chair)
    local installation=F.New(content(),{targetSchema=3})
    local beforeInstallation=installation.state.GetSnapshot()
    local restore=installation.modules.economy.Restore; local injected=false
    installation.modules.economy.Restore=function(s)
        if not injected then injected=true; return U.Fail("TEST_FAIL","economy","injected installation failure") end
        return restore(s)
    end
    local failedInstall=installation.state.PurchaseFurniture({furnitureId="decor_tablecloth"})
    assert(not failedInstall.ok and failedInstall.error.code=="COMMIT_RECOVERY_REQUIRED" and not installation.state.CanMutate())
    assert(U.Equal(beforeInstallation,installation.state.GetSnapshot()),"failed installation did not roll back memory")
    installation.modules.economy.Restore=restore; assert(installation.Reload())
    assert(installation.state.GetSnapshot().live.economy.currency==540 and installation.state.GetSnapshot().live.economy.ownedFurnitureIds.decor_tablecloth)
    reject(installation,{furnitureId="decor_tablecloth"},"FURNITURE_ALREADY_OWNED")
    local observer=F.New(content(),{targetSchema=3})
    observer.onEvent=function(name) if name=="FurniturePurchased" then error("injected observer failure") end end
    local observed=must(observer.state.PurchaseFurniture({furnitureId="decor_tablecloth"}))
    assert(observed.notificationErrors and observer.state.GetSnapshot().live.economy.currency==540)
    assert(observer.Reload() and observer.state.GetSnapshot().live.economy.ownedFurnitureIds.decor_tablecloth)
    -- Existing result preview/reset/confirmation must keep furniture and reject purchases while pending.
    local flow=F.New(content(),{targetSchema=3})
    must(flow.state.PurchaseFurniture({furnitureId="decor_tablecloth"}))
    local oid,tid,bid=prepare(flow)
    reject(flow,{furnitureId="decor_chair"},"ORDER_LOCKED")
    assert(not must(flow.session.queries.GetFurnitureShopView()).enabled)
    must(flow.order.Reset({orderId=oid,transactionId=tid,baselineId=bid}))
    must(flow.state.PurchaseFurniture({furnitureId="decor_chair"}))
    local draft=must(flow.order.GetView()).draft
    -- Use the surviving real token ID, never inject tokens into formal state.
    for id,token in pairs(flow.state.GetSnapshot().live.wordTokens.byId) do if token.wordId=="word_candidate_elias_sleep" then draft.mainTokenId=id end end
    draft.ingredients={{ingredientId="ing_sea_salt",quantity=1}}
    must(flow.order.UpdateDraft({orderId=oid,draft=draft})); draft.orderId=oid
    tid=must(flow.order.Preview(draft)).transactionId
    must(flow.order.Confirm({orderId=oid,transactionId=tid}))
    local shipped=flow.state.GetSnapshot()
    assert(shipped.live.economy.ownedFurnitureIds.decor_chair and shipped.live.gameFlow.deliveredOrders==1)
    must(flow.state.PurchaseFurniture({furnitureId="decor_lamp"}))
    assert(flow.Reload() and flow.state.GetSnapshot().live.economy.ownedFurnitureIds.decor_lamp)
    -- Old economies omit both fields; do not normalize historical pending baselines on load.
    for _,schema in ipairs({2,3}) do
        local oldContent=content(); oldContent.furniture=nil
        local old=F.New(oldContent,{targetSchema=schema})
        must(old.state.Shop({ingredientId="ing_sea_salt",quantity=1}))
        local legacy=old.state.GetSnapshot()
        oldContent.furniture=U.Copy(catalog)
        assert(old.Reload() and U.Equal(old.state.GetSnapshot(),legacy),"old economy did not load unchanged")
        assert(not must(old.session.queries.GetFurnitureShopView()).items[1].owned)
        must(old.state.PurchaseFurniture({furnitureId="decor_tablecloth"}))
        assert(old.Reload() and old.state.GetSnapshot().live.economy.currency==535)
        local pendingContent=content(); pendingContent.furniture=nil
        local pendingOld=F.New(pendingContent,{targetSchema=schema})
        local pendingOid,pendingTid=prepare(pendingOld)
        local historical=pendingOld.state.GetSnapshot()
        pendingContent.furniture=U.Copy(catalog)
        assert(pendingOld.Reload() and U.Equal(pendingOld.state.GetSnapshot(),historical),"old pending baseline was altered")
        reject(pendingOld,{furnitureId="decor_tablecloth"},"ORDER_LOCKED")
        must(pendingOld.order.Confirm({orderId=pendingOid,transactionId=pendingTid}))
        must(pendingOld.state.PurchaseFurniture({furnitureId="decor_tablecloth"}))
        assert(pendingOld.Reload() and pendingOld.state.GetSnapshot().live.economy.ownedFurnitureIds.decor_tablecloth)
    end
    local unsupported=content(); unsupported.furniture=nil
    local absent=F.New(unsupported,{targetSchema=3})
    reject(absent,{furnitureId="decor_tablecloth"},"NOT_IMPLEMENTED")
    assert(not must(absent.session.queries.GetFurnitureShopView()).enabled)
    local migratingContent=content(); migratingContent.furniture=nil
    local migrating=F.New(migratingContent,{targetSchema=2})
    local migratingOid,migratingTid=prepare(migrating)
    migratingContent.furniture=U.Copy(catalog)
    local migratedSession=require("core.GameSession").New(migratingContent,{targetSchema=3,saveSystem=migrating.save,eventBus=migrating.bus})
    local migratedData,migratedStatus=migratedSession.state.Load("b5_flow")
    assert(migratedData and migratedStatus.status=="migrated" and migratedData.live.economy.ownedFurnitureIds==nil,"old v2 pending migration failed")
    must(migratedSession.order.Confirm({orderId=migratingOid,transactionId=migratingTid}))
    must(migratedSession.state.PurchaseFurniture({furnitureId="decor_tablecloth"}))
    assert(migratedSession.state.ReloadCurrent() and must(migratedSession.queries.GetFurnitureShopView()).items[1].owned)
    local clean=F.New(content(),{targetSchema=3})
    local function forged(change)
        local raw=clean.state.GetSnapshot(); change(raw)
        assert(not clean.order.ValidateEnvelope(raw).ok,"forged furniture ledger was accepted")
        assert(clean.save.Save("b5_flow",raw,3))
        local loaded,status=clean.Reload()
        assert(not loaded and status.status=="corrupt","forged raw file was loaded")
        -- Fresh fixture for next independent corruption.
        clean=F.New(content(),{targetSchema=3})
    end
    forged(function(d) d.live.economy.ownedFurnitureIds.decor_chair=true end)
    forged(function(d) d.live.economy.currency=540; d.live.economy.furniturePurchases={{day=1,afterDeliveredOrders=0,furnitureId="decor_tablecloth",unitPrice=60}} end)
    forged(function(d) d.live.economy.currency=599; d.live.economy.ownedFurnitureIds.decor_tablecloth=true; d.live.economy.furniturePurchases={{day=1,afterDeliveredOrders=0,furnitureId="decor_tablecloth",unitPrice=1}} end)
    forged(function(d) d.live.economy.currency=540; d.live.economy.ownedFurnitureIds.decor_tablecloth=true; d.live.economy.furniturePurchases={{day=1,afterDeliveredOrders=1,furnitureId="decor_tablecloth",unitPrice=60}} end)
    forged(function(d) d.live.economy.currency=540; d.live.economy.ownedFurnitureIds.decor_tablecloth=true; d.live.economy.furniturePurchases={{day=2,afterDeliveredOrders=0,furnitureId="decor_tablecloth",unitPrice=60}} end)
    forged(function(d) d.live.economy.ownedFurnitureIds.decor_tablecloth=true; d.live.economy.furniturePurchases={{day=1,afterDeliveredOrders=0,furnitureId="decor_tablecloth",unitPrice=60}} end)
    forged(function(d) d.live.economy.currency=480; d.live.economy.ownedFurnitureIds.decor_tablecloth=true; d.live.economy.furniturePurchases={{day=1,afterDeliveredOrders=0,furnitureId="decor_tablecloth",unitPrice=60},{day=1,afterDeliveredOrders=0,furnitureId="decor_tablecloth",unitPrice=60}} end)
    local bad=content(); bad.furniture[2].id=bad.furniture[1].id
    assert(not require("core.GameSession").New(bad,{targetSchema=3}).ready,"duplicate catalog IDs accepted")
    print("[FurnitureShop] PASS durable debit/ownership, cross-day, old v2/v3, pending/reset/confirm, failure/uncertainty/reentry, malicious raw ledger")
    return true
end
return T
