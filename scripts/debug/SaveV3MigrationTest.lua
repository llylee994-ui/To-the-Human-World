local U=require "core.StateUtil"
local F=require "debug.fixtures.B5Fixtures"
local Data=require "data.content"
local T={}
local checks=0
local function check(value,message) checks=checks+1; assert(value,message) end
local function must(result) assert(result.ok,cjson.encode(result.error)); return result.value end
local function old(phase)
    local x=F.New(Data,{targetSchema=2})
    assert(x.state.Save("b5_flow"))
    if phase=="idle" then return x end
    local id=must(x.state.ReceiveLetter({letterId="letter_pa_01"})).letterInstanceId
    must(x.state.ReadLetter({letterInstanceId=id}))
    local tokens={}
    for _,span in ipairs(must(x.modules.letters.ParseDefinition("letter_pa_01")).spans) do tokens[span.wordId]=must(x.state.CutWord({letterInstanceId=id,spanId=span.spanId})).tokenId end
    local oid=must(x.order.Accept({letterInstanceId=id})).orderId
    if phase=="accepted" then return x end
    local base=must(x.order.BeginBrew({orderId=oid})).baselineId
    if phase=="brewing" then return x end
    local recipe=assert(require("debug.fixtures.NumericV02Cases")[1]).recipe
    local result=must(x.order.Preview({orderId=oid,baselineId=base,equipmentId=recipe.equipmentId,mainTokenId=tokens[recipe.mainWordId],auxTokenIds={},ingredients=U.Copy(recipe.ingredients),specialItemIds={}}))
    if phase=="confirmed" then must(x.order.Confirm({orderId=oid,transactionId=result.transactionId}))
    elseif phase=="reset" then must(x.order.Reset({orderId=oid,baselineId=base,transactionId=result.transactionId})) end
    return x
end
local function migrate(x)
    local session=require("core.GameSession").New(Data,{targetSchema=3,saveSystem=x.save,eventBus=x.bus})
    local data,status=session.state.Load("b5_flow")
    return data,status,session
end
function T.Run()
    for _,phase in ipairs({"idle","accepted","brewing","pending","confirmed","reset"}) do
        local x=old(phase); local before=x.state.GetSnapshot()
        local data,status,session=migrate(x)
        check(data~=nil,status.error and cjson.encode(status.error) or phase)
        check(status.status=="migrated" and status.schema==3,"migration status")
        local saved,loaded=x.save.Load("b5_flow")
        check(loaded.schema==3 and U.Equal(saved,data),"migration committed to same slot")
        check(data.live.gameFlow.salvageUsedToday==1 and not data.live.gameFlow.canSalvage,"conservative migration quota")
        if phase=="pending" then
            check(data.currentOrder.pending.transactionId==before.currentOrder.pending.transactionId,"import transaction unchanged")
            check(U.Equal(data.currentOrder.pending.followup,before.currentOrder.pending.followup),"import text unchanged")
            check(U.Equal(data.currentOrder.pending.rating,before.currentOrder.pending.rating),"import rating unchanged")
            check(data.currentOrder.recipe.baselineId=="order:1:baseline","import keeps legacy baseline")
            must(session.order.Confirm({orderId="order:1",transactionId=data.currentOrder.pending.transactionId}))
            check(session.state.GetSnapshot().live.gameFlow.deliveredOrders==1,"import confirms once")
        elseif phase=="confirmed" then
            check(#data.journal.attemptIds==1 and data.journal.byAttemptId[data.journal.attemptIds[1]].status=="shipped","import real shipment only")
        else
            check(#data.journal.attemptIds==0,"no fabricated old trials")
            if data.currentOrder then
                check(data.currentOrder.phase=="accepted" and data.currentOrder.baseline==false,"old brewing returns preparation")
                check(data.currentOrder.nextAttemptSerial==before.currentOrder.nextAttemptSerial,"monotonic old serial")
            end
        end
        check(session.state.ReloadCurrent()~=nil,"v3 migration reload")
    end
    for _,fault in ipairs({"write","encode","readback","before_commit","after_commit","uncertain"}) do
        local x=old("pending"); local before=x.state.GetSnapshot(); x.fault=fault; x.commitWritten=false
        local data,_status,session=migrate(x)
        if fault=="after_commit" then check(data~=nil,"committed migration succeeds")
        else check(data==nil and not session.state.CanMutate(),"failed/uncertain migration locks") end
        x.fault=false
        local saved,loaded=x.save.Load("b5_flow")
        if fault=="after_commit" or fault=="uncertain" then check(loaded.schema==3,"committed migration recovery")
        else check(loaded.schema==2 and U.Equal(saved,before),"old valid generation retained") end
        check(session.state.ReloadCurrent()~=nil,"migration retry same slot")
    end
    local x=old("idle"); local bad=x.state.GetSnapshot(); bad.live.gameFlow.deliveredOrders=1
    assert(x.save.Save("b5_flow",bad,2)); local before=U.Copy(x.files)
    local data=migrate(x); check(data==nil and U.Equal(before,x.files),"invalid v2 never rewritten")
    local valid=old("idle"); local s=valid.state.GetSnapshot(); s.contentVersion="unknown-content"
    assert(valid.save.Save("b5_flow",s,2)); before=U.Copy(valid.files)
    check(migrate(valid)==nil and U.Equal(before,valid.files),"content mismatch protects file")
    local v1=old("idle"); assert(v1.save.Save("b5_flow",{gameFlow=require("core.GameFlow").ValidateSnapshot(nil).value},1))
    check(migrate(v1)~=nil,"valid v1 migrates through v2")
    local legacy=old("idle"); local flow=require("core.GameFlow").ValidateSnapshot(nil).value; flow.deliveredOrders=1
    assert(legacy.save.Save("b5_flow",{gameFlow=flow},1)); before=U.Copy(legacy.files)
    check(migrate(legacy)==nil and U.Equal(before,legacy.files),"legacy count without history remains protected")
    local future=old("idle")
    future.files["save_future.json"]=cjson.encode({schema=4,data={}})
    local session=require("core.GameSession").New(Data,{saveSystem=future.save,eventBus=future.bus})
    before=U.Copy(future.files)
    local loaded,status=session.state.Load("future")
    check(loaded==nil and status.status=="unsupported" and U.Equal(before,future.files),"future schema protected")
    future.files["save_corrupt.json"]="invalid json"
    before=U.Copy(future.files); loaded,status=session.state.Load("corrupt")
    check(loaded==nil and status.status=="corrupt" and U.Equal(before,future.files),"corrupt file protected")
    print("[MigrationV3] checks="..checks.." PASS")
    return true
end
return T
