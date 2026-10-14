local U=require "core.StateUtil"
local F=require "debug.fixtures.B5Fixtures"
local T={}
local W=require "debug.fixtures.SingleUseFixtures"
local function flows(check)
    for _,id in ipairs({"A","B","C","D","G1","G2","G3","G4"}) do
        local x=F.New(); x.Prepare()
        local base=x.state.GetSnapshot(); local writes=x.writes
        check(id .. " begin idempotent",F.Must(x.order.BeginBrew({orderId=x.orderId})).baselineId,x.baselineId)
        check(id .. " duplicate begin no write",x.writes,writes)
        check(id .. " accept idempotent",F.Must(x.order.Accept({letterInstanceId=x.letterId})).orderId,x.orderId)
        local pending=x.Pending(id)
        check(id .. " pending live unchanged",pending.live,base.live)
        W.CheckConsumption(check,x.content,base.live.wordTokens,pending.currentOrder.pending.candidateLive.wordTokens,
            x.Request(id),pending.currentOrder.pending.consumption.consumedTokenIds)
        check(id .. " preview one notification",x.Events("DeliveryPreviewReady"),1)
        local before=x.writes
        check(id .. " preview repeat same tx",F.Must(x.order.Preview(x.Request(id))).transactionId,x.transactionId)
        check(id .. " repeated preview no write",x.writes,before)
        check(id .. " no delivery before confirm",x.Events("PotionDelivered"),0)
        local view=F.Must(x.order.GetView({orderId=x.orderId}))
        check(id .. " saved view",view.pending,pending.currentOrder.pending)
        check(id .. " pending cannot next day",view.actions.NextDay.enabled,false)
        local loaded,status=x.Reload()
        check(id .. " reload pending",loaded,pending); check(id .. " reload status",status.status,"loaded")
        local confirmed=F.Must(x.Confirm())
        check(id .. " confirmed phase",confirmed.phase,"confirmed")
        check(id .. " candidate installed exactly",x.state.GetSnapshot().live,pending.currentOrder.pending.candidateLive)
        W.CheckConsumption(check,x.content,base.live.wordTokens,x.state.GetSnapshot().live.wordTokens,
            x.Request(id),confirmed.record.consumption.consumedTokenIds)
        check(id .. " current cleared",x.state.GetSnapshot().currentOrder,false)
        check(id .. " one delivery",x.Events("PotionDelivered"),1)
        local expectedStars=(id=="C" and 2) or (id=="D" and 1) or 3
        check(id .. " rating",confirmed.record.rating.stars,expectedStars)
        check(id .. " same fixed reward",confirmed.record.reward,x.content.letters[1].reward)
        local after=x.state.GetSnapshot(); before=x.writes
        check(id .. " duplicate confirm",F.Must(x.Confirm()).alreadyConfirmed,true)
        check(id .. " duplicate no write",x.writes,before)
        check(id .. " duplicate state",x.state.GetSnapshot(),after)
        check(id .. " duplicate no events",x.Events("PotionDelivered"),1)
        x.Reload(); check(id .. " restart already confirmed",F.Must(x.Confirm()).alreadyConfirmed,true)
        check(id .. " restart no reward replay",x.Events("PotionDelivered"),1)
        check(id .. " confirmed cannot reset",x.Reset().ok,false)
    end
    local x=F.New(); x.Prepare()
    for _,id in ipairs({"E","F"}) do
        local before=x.state.GetSnapshot(); local writes=x.writes
        local failed=F.Must(x.order.Preview(x.Request(id)))
        check(id .. " stays brewing",failed.phase,"brewing"); check(id .. " literal failure",failed.requirementResult.canShip,false)
        check(id .. " unchanged",x.state.GetSnapshot(),before); check(id .. " no save",x.writes,writes)
    end
    local base=x.state.GetSnapshot(); x.Pending("A"); local old=x.transactionId
    F.Must(x.Reset())
    check("reset live exact baseline",x.state.GetSnapshot().live,base.live)
    check("reset retains baseline",x.state.GetSnapshot().currentOrder.baseline,base.currentOrder.baseline)
    check("reset discards pending",x.state.GetSnapshot().currentOrder.pending,false)
    check("reset repeat no change",F.Must(x.Reset()).alreadyReset,true)
    x.Pending("D"); check("new attempt ID",x.transactionId~=old,true)
    check("stale confirm rejected",x.order.Confirm({orderId=x.orderId,transactionId=old}).ok,false)
    check("stale reset rejected",x.order.Reset({orderId=x.orderId,baselineId=x.baselineId,transactionId=old}).ok,false)
    check("new pending day locked",x.state.NextDay().error.code,"ORDER_LOCKED")
    check("pending cut locked",x.state.CutWord({letterInstanceId=x.letterId,spanId="body:1"}).error.code,"ORDER_LOCKED")
    check("pending receive locked",x.state.ReceiveLetter({letterId=x.content.letters[1].id}).error.code,"ORDER_LOCKED")
    check("pending alternate recipe locked",x.order.Preview(x.Request("A")).error.code,"ORDER_LOCKED")
    local _,locked=x.state.Load("b5_other")
    check("pending other slot locked",locked.error.code,"ORDER_LOCKED")
    F.Must(x.Confirm()); check("A reset then D one reward",x.state.GetSnapshot().live.economy.currency,base.live.economy.currency+x.content.letters[1].reward.currency)
    local before=x.state.GetSnapshot(); F.Must(x.state.NextDay())
    check("next day saved",select(1,x.save.Load("b5_flow")),x.state.GetSnapshot())
    check("next day increments once",x.state.GetSnapshot().live.gameFlow.day,before.live.gameFlow.day+1)
    local content=require("debug.fixtures.B4Fixtures").Content()
    for _,word in ipairs(content.words) do if word.id=="word_sleep" then word.reusable=false end end
    x=F.New(content); x.Prepare(); local tokens=U.Copy(x.state.GetSnapshot().live.wordTokens)
    local p=x.Pending("A")
    check("nonreusable preview formal tokens unchanged",x.state.GetSnapshot().live.wordTokens,tokens)
    check("nonreusable candidate marked",p.currentOrder.pending.candidateLive.wordTokens.byId[x.tokens.word_sleep].available,false)
    F.Must(x.Reset()); check("nonreusable reset preserves token",x.state.GetSnapshot().live.wordTokens,tokens)
    x.Pending("A"); F.Must(x.Confirm())
    check("nonreusable confirm consumes once",x.state.GetSnapshot().live.wordTokens.byId[x.tokens.word_sleep].consumedByOrderId,x.orderId)
    x.Reload(); check("nonreusable restore stable",x.state.GetSnapshot().live.wordTokens.byId[x.tokens.word_sleep].available,false)
end
function T.Run()
    local check,finish=F.Checks()
    local flow=require "core.GameFlow"; local before=flow.GetSnapshot()
    local ok,err=pcall(function() flows(check); require("debug.OrderRecoveryTest").Run(check) end)
    flow.Restore(before)
    if not ok then print("[B5] ERROR " .. (type(err)=="table" and cjson.encode(err) or tostring(err))); check("runtime",false,true) end
    return finish()
end
return T
