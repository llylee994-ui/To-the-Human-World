-- B6 准备阶段回退与失败药效投影；真实事务和内存文件介质，不代替引擎退出验收。
local U=require "core.StateUtil"
local F=require "debug.fixtures.B5Fixtures"
local Model=require "ui.PlayModel"
local T={}
---@param fixture table
---@return table
local function playModel(fixture)
    return Model.New(fixture.session,fixture.content)
end
function T.Run(report)
    local total,failed=0,0
    local function check(name,actual,expected)
        total=total+1
        if not U.Equal(actual,expected) then failed=failed+1 end
        if report then report("preparation " .. name,actual,expected)
        elseif not U.Equal(actual,expected) then print("[B6 preparation] FAIL " .. name) end
    end
    local flow=require "core.GameFlow"; local original=flow.GetSnapshot()
    local ok,err=pcall(function()
        ---@param wordId string?
        ---@return table context
        ---@return table model
        ---@return table<string, string> spans
        ---@return string|false token
        local function setup(wordId)
            local x=F.New()
            local model=Model.New(x.session,x.content)
            local received=F.Must(model.Receive("letter_pa_01"))
            F.Must(model.Read(received.letterInstanceId))
            local spans={}
            for _,span in ipairs(F.Must(x.modules.letters.ParseDefinition("letter_pa_01")).spans) do spans[span.wordId]=span.spanId end
            local token=wordId and F.Must(model.Cut(spans[wordId])).tokenId or false
            F.Must(model.Accept())
            return x,model,spans,token
        end
        -- 空锅的准备操作不能保存基准，玩家仍然可以回信剪词。
        ---@type table, table
        local x,model=setup()
        local before=x.state.GetSnapshot(); local writes=x.writes
        F.Must(model.Edit("clear")); F.Must(model.Edit("removeMain")); F.Must(model.Edit("removeAux","missing-token"))
        F.Must(model.Edit("equipment",model.GetDraft().equipmentId))
        check("empty edits keep accepted snapshot",x.state.GetSnapshot(),before)
        check("empty edits do not write",x.writes,writes)
        check("empty edits permit cutting",model.Action("CutWord").enabled,true)
        check("accepted cancellation is idempotent",F.Must(x.order.CancelBrew({orderId=before.currentOrder.orderId})).alreadyPrepared,true)
        check("accepted cancellation does not write",x.writes,writes)

        -- 首次放入原料但尚无词：返回准备必须原子保存，失败不得偷偷解锁。
        for _,fault in ipairs({"write","encode","readback","before_commit"}) do
            x,model=setup()
            F.Must(model.Edit("ingredient","ing_sea_salt",1))
            before=x.state.GetSnapshot()
            local draft=model.GetDraft(); local events=#x.events
            check(fault .. " zero-card brewing",before.currentOrder.phase,"brewing")
            check(fault .. " return preparation available",F.Must(x.order.GetView()).actions.CancelBrew.enabled,true)
            x.fault=fault; x.snapshotWritten=false
            check(fault .. " cancellation fails",model.CancelBrew().ok,false)
            check(fault .. " failed cancellation memory",x.state.GetSnapshot(),before)
            check(fault .. " failed cancellation draft",model.GetDraft(),draft)
            check(fault .. " failed cancellation no event",#x.events,events)
            x.fault=false
            check(fault .. " failed cancellation disk",select(1,x.save.Load("b5_flow")),before)
            F.Must(model.Reload())
            check(fault .. " reload current nondefault slot",x.state.GetSnapshot(),before)
            F.Must(model.CancelBrew())
            local prepared=x.state.GetSnapshot()
            check(fault .. " returned accepted",prepared.currentOrder.phase,"accepted")
            check(fault .. " formal live preserved",prepared.live,before.live)
            check(fault .. " attempts not rewound",prepared.currentOrder.nextAttemptSerial,before.currentOrder.nextAttemptSerial)
            check(fault .. " baseline cleared",prepared.currentOrder.baseline,false)
            check(fault .. " return opens source letter",model.selectedLetter,prepared.currentOrder.letterInstanceId)
            check(fault .. " return opens reader",model.page,"letter")
            F.Must(model.Reload())
            check(fault .. " prepared state persists",x.state.GetSnapshot(),prepared)
            check(fault .. " cutting unlocked",model.Action("CutWord").enabled,true)
        end

        -- 只剪了无法满足本单的词也能安全回去补剪；失败下锅同样可观察药效。
        ---@type table<string, string>, string|false
        local spans,token={},false
        x,model,spans,token=setup("word_quiet")
        F.Must(model.Edit("main",token))
        before=x.state.GetSnapshot(); writes=x.writes
        local trial=F.Must(model.Preview())
        ---@type table
        local observed=assert(model.trialPotion,"失败试做必须提供药效")
        check("wrong word is literal failure",trial.requirementResult.canShip,false)
        check("failed potion displayed",model.trialPotion,trial.potion)
        check("failed potion carries duration",type(observed.durationHours),"number")
        check("failed preview does not write",x.writes,writes)
        check("failed preview does not consume",x.state.GetSnapshot(),before)
        trial.potion.effects.calm=999
        check("returned potion does not alias model",observed.effects.calm==999,false)
        F.Must(model.Edit("ingredient","ing_sea_salt",1))
        check("editing clears observed result",model.trialPotion,nil)
        F.Must(model.Preview()); F.Must(model.Reload())
        check("loading clears transient potion",model.trialPotion,nil)
        F.Must(model.CancelBrew())
        check("preparation clears failure",model.failure,nil)
        local sleep=F.Must(model.Cut(spans.word_sleep)).tokenId
        F.Must(model.Edit("main",sleep)); F.Must(model.Edit("ingredient","ing_sea_salt",1))
        local shipped=F.Must(model.Preview())
        check("corrected word can ship",shipped.phase,"pending")
        check("successful potion projected",model.trialPotion,x.state.GetSnapshot().currentOrder.pending.potion)
        before=x.state.GetSnapshot(); writes=x.writes
        check("pending gate forbids preparation",model.Action("CancelBrew").enabled,false)
        check("pending direct cancellation denied",model.CancelBrew().ok,false)
        check("pending preserved",x.state.GetSnapshot(),before)
        check("pending rejection no write",x.writes,writes)
        F.Must(model.Resolve(false))
        check("reset clears observed result",model.trialPotion,nil)
        before=x.state.GetSnapshot(); writes=x.writes
        check("reset keeps attempt history",before.currentOrder.nextAttemptSerial,2)
        check("reset gate forbids preparation",model.Action("CancelBrew").enabled,false)
        check("reset direct cancellation denied",model.CancelBrew().ok,false)
        check("reset rejection no write",x.writes,writes)
        F.Must(model.Reload())
        check("reset denial survives reload",model.Action("CancelBrew").enabled,false)
        check("reset baseline preserved",x.state.GetSnapshot(),before)

        -- 已确认单不受下一单返回准备影响；旧结果不能被回退命令撤销。
        x=F.New(); x.Prepare(); x.Pending("A"); F.Must(x.Confirm())
        local confirmed=x.state.GetSnapshot()
        check("confirmed cannot be cancelled",x.order.CancelBrew({orderId=x.orderId}).ok,false)
        check("confirmed ledger unchanged",x.state.GetSnapshot(),confirmed)
        F.Must(x.state.NextDay())
        model=playModel(x)
        local received=F.Must(model.Receive("letter_n01")); F.Must(model.Read(received.letterInstanceId)); F.Must(model.Accept())
        F.Must(model.Edit("ingredient","ing_night_dew",1)); before=x.state.GetSnapshot()
        F.Must(model.CancelBrew())
        check("later preparation keeps prior live",x.state.GetSnapshot().live,before.live)
        check("later preparation keeps first record",x.state.GetSnapshot().live.orders.confirmedById[x.orderId],confirmed.live.orders.confirmedById[x.orderId])

        -- 提交结果不确定时，恢复按钮必须读取 b5_flow，不能误读默认 slot1。
        x=F.New(); x.Prepare(); x.Pending("A"); model=playModel(x)
        x.fault="uncertain"; x.commitWritten=false
        check("uncertain confirm returns failure",model.Resolve(true).ok,false)
        check("uncertain commit locks gameplay",x.state.CanMutate(),false)
        x.fault=false
        local defaultData,defaultStatus=x.save.Load(nil)
        F.Must(model.Reload())
        check("current-slot reload unlocks",x.state.CanMutate(),true)
        check("current-slot reload reconciles confirmation",x.state.GetSnapshot().currentOrder,false)
        check("current-slot reload counts confirmation once",x.state.GetSnapshot().live.gameFlow.deliveredOrders,1)
        check("reload did not replace default slot data",select(1,x.save.Load(nil)),defaultData)
        check("reload did not create default slot",select(2,x.save.Load(nil)).status,defaultStatus.status)
        check("reconciled duplicate confirmation idempotent",F.Must(x.Confirm()).alreadyConfirmed,true)
        check("reconcile emits no second delivery",x.Events("PotionDelivered"),0)
    end)
    flow.Restore(original)
    if not ok then check("runtime " .. tostring(err),false,true) end
    print("[B6 preparation] checks=" .. total .. " failures=" .. failed .. "; isolated storage/model checks")
    return failed==0
end
return T
