-- 真实双提交协议故障与同内容迁移，捕捉只改最终余额或丢失历史基准的错误。
local U=require "core.StateUtil"
local R=require "debug.fixtures.ReleaseFixtures"
local must=R.Must
local T={}
function T.Run()
    local check,done=R.Checks("ReleaseSave")
    for _,fault in ipairs({"encode","write","readback","before_commit"}) do
        check("purchase failure preserves state "..fault,function()
            local x=R.New(600);local before=x.state.GetSnapshot();x.fault=fault
            assert(not x.state.PurchaseHomeItem(R.Quote(x,"decor_chair",100)).ok)
            assert(U.Equal(before,x.state.GetSnapshot()) and x.state.CanMutate())
            x.fault=false;assert(x.Reload() and x.state.GetSnapshot().live.economy.currency==600)
        end)
    end
    check("uncertain commit locks, wrong slot refused, same-slot reload charges once",function()
        local x=R.New(600);local q=R.Quote(x,"decor_chair",100);x.fault="uncertain"
        assert(not x.state.PurchaseHomeItem(q).ok and not x.state.CanMutate())
        assert(not x.state.Load("other_slot"));x.fault=false
        assert(x.state.ReloadCurrent());assert(x.state.GetSnapshot().live.economy.currency==500)
        local writes=x.writes;assert(must(x.state.PurchaseHomeItem(q)).alreadyPurchased and x.writes==writes)
    end)
    check("observer failure and nested purchase cannot charge again",function()
        local x=R.New(600)
        ---@type table|nil
        local nested
        x.onEvent=function(name) if name=="FurniturePurchased" then nested=x.state.PurchaseHomeItem(R.Quote(x,"decor_lamp",140));error("observer") end end
        local result=must(x.state.PurchaseHomeItem(R.Quote(x,"decor_chair",100)))
        assert(result.notificationErrors and not nested.ok and nested.error.code=="COMMAND_BUSY")
        x.onEvent=nil;assert(x.Reload() and x.state.GetSnapshot().live.economy.currency==500)
    end)
    check("committed purchase with failed install reloads once",function()
        local x=R.New(600);local original=x.modules.economy.Restore;local calls=0
        x.modules.economy.Restore=function(value)
            local result=original(value);calls=calls+1
            if calls==1 then error("install after mutation") end
            return result
        end
        local q=R.Quote(x,"decor_chair",100);local r=x.state.PurchaseHomeItem(q)
        assert(not r.ok and r.error.code=="COMMIT_RECOVERY_REQUIRED" and not x.state.CanMutate())
        x.modules.economy.Restore=original
        assert(x.state.ReloadCurrent() and x.state.GetSnapshot().live.economy.currency==500)
        assert(must(x.state.PurchaseHomeItem(q)).alreadyPurchased)
    end)
    for _,kind in ipairs({"cash","price","future_count","future_day","duplicate","transaction","missing_ledger","chapter","projection"}) do
        check("bad saved purchase rejected "..kind,function()
            local x=R.New(600);must(x.state.PurchaseHomeItem(R.Quote(x,"decor_chair",100)))
            local d=x.state.GetSnapshot();local row=d.live.economy.itemPurchases[1]
            if kind=="cash" then d.live.economy.currency=599
            elseif kind=="price" then row.unitPrice=1
            elseif kind=="future_count" then row.afterDeliveredOrders=1
            elseif kind=="future_day" then row.day=2
            elseif kind=="duplicate" then d.live.economy.itemPurchases[2]=U.Copy(row);d.live.economy.currency=400
            elseif kind=="transaction" then row.transactionId="forged"
            elseif kind=="missing_ledger" then d.live.economy.itemPurchases=nil
            elseif kind=="chapter" then d.chapter.ending={kind="apprentice"}
            elseif kind=="projection" then d.live.economy.itemPurchases={};d.live.economy.ownedFurnitureIds={decor_chair=true};d.live.economy.furniturePurchases={{day=1,afterDeliveredOrders=0,furnitureId="decor_chair",unitPrice=100}} end
            assert(x.save.Save("b5_flow",d,4));assert(not x.Reload(),"forged schema4 accepted "..kind)
        end)
    end
    check("same-content schema3 pending plus furniture migrates atomically",function()
        local x=R.New(600,3);must(x.state.PurchaseFurniture({furnitureId="decor_chair"}))
        local request=R.Accept(x,1);local pending=R.Preview(x,request);local before=x.state.GetSnapshot()
        local session=require("core.GameSession").New(x.content,{targetSchema=4,saveSystem=x.save,eventBus=x.bus})
        local d,status=session.state.Load("b5_flow");assert(d and status.schema==4 and status.status=="migrated")
        assert(#d.live.economy.itemPurchases==1 and #d.currentOrder.baseline.live.economy.itemPurchases==1)
        assert(d.currentOrder.pending.transactionId==pending.transactionId and U.Equal(d.journal,before.journal))
        must(session.order.Confirm({orderId=request.orderId,transactionId=pending.transactionId}))
        assert(session.state.ReloadCurrent() and session.state.GetSnapshot().live.economy.currency==600)
    end)
    check("different content version refuses migration without rewriting old bytes",function()
        local x=R.New(600,3);assert(x.state.Save("b5_flow"));local files=U.Copy(x.files)
        x.content.contentVersion="different-content"
        local session=require("core.GameSession").New(x.content,{targetSchema=4,saveSystem=x.save,eventBus=x.bus})
        local loaded,status=session.state.Load("b5_flow")
        assert(not loaded and status.error.code=="CONTENT_VERSION_MISMATCH" and U.Equal(files,x.files))
    end)
    for _,fault in ipairs({"write","uncertain"}) do
        check("migration failure obeys commit protocol "..fault,function()
            local x=R.New(600,3);must(x.state.PurchaseFurniture({furnitureId="decor_chair"}));local old=U.Copy(x.files)
            x.fault=fault
            local session=require("core.GameSession").New(x.content,{targetSchema=4,saveSystem=x.save,eventBus=x.bus})
            local loaded,status=session.state.Load("b5_flow");assert(not loaded);x.fault=false
            if fault=="write" then assert(status.error.code=="SAVE_WRITE_FAILED" and U.Equal(old,x.files))
            else assert(not session.state.CanMutate() and session.state.ReloadCurrent()) end
        end)
    end
    check("schema3 cannot smuggle schema4 permanent ledger into migration",function()
        local x=R.New(600);must(x.state.PurchaseHomeItem(R.Quote(x,"decor_chair",100)))
        local d=x.state.GetSnapshot();d.chapter=nil
        assert(x.save.Save("b5_flow",d,3));local files=U.Copy(x.files)
        local old=require("core.GameSession").New(x.content,{targetSchema=3,saveSystem=x.save,eventBus=x.bus})
        assert(not old.state.Load("b5_flow"),"schema3 accepted permanent fields from newer schema4")
        assert(not x.Reload() and U.Equal(files,x.files),"downgraded ledger accepted as old schema3")
    end)
    return done()
end
return T
