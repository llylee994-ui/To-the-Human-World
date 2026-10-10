local U=require "core.StateUtil"
local F=require "debug.fixtures.B5Fixtures"
local T={}
function T.Run(check,contentFactory)
    local function new() return F.New(contentFactory and contentFactory() or nil) end
    for _,fault in ipairs({"encode","write","readback","before_commit"}) do
        for _,command in ipairs({"Preview","Confirm","Reset"}) do
            local x=new(); x.Prepare()
            if command~="Preview" then x.Pending("D") end
            local before=x.state.GetSnapshot(); local events=#x.events
            x.fault=fault; x.snapshotWritten=false
            local result
            if command=="Preview" then result=x.order.Preview(x.Request("A")) elseif command=="Confirm" then result=x.Confirm() else result=x.Reset() end
            check(fault .. " " .. command .. " fails",result.ok,false)
            check(fault .. " " .. command .. " memory",x.state.GetSnapshot(),before)
            check(fault .. " " .. command .. " events",#x.events,events)
            x.fault=false
            check(fault .. " " .. command .. " disk",select(1,x.save.Load("b5_flow")),before)
        end
    end
    local x=new(); x.Prepare(); x.Pending("A")
    x.fault="uncertain"; x.commitWritten=false
    check("uncertain returns failure",x.Confirm().ok,false)
    check("uncertain locks",x.state.CanMutate(),false)
    check("uncertain no event",x.Events("PotionDelivered"),0)
    x.fault=false
    local _,wrong=x.state.Load("b5_other")
    check("uncertain reconcile same slot",wrong.error.code,"RECOVERY_SLOT_MISMATCH")
    local loaded=x.state.Load("b5_flow")
    check("uncertain resolved as committed",loaded.currentOrder,false)
    check("retry after uncertain no duplicate",F.Must(x.Confirm()).alreadyConfirmed,true)
    check("reconcile no replay",x.Events("PotionDelivered"),0)
    x=new(); x.Prepare(); x.Pending("A")
    local restore=x.modules.world.Restore; local injected=false
    x.modules.world.Restore=function(v) if not injected then injected=true; return U.Fail("TEST_FAIL","world","injected") end; return restore(v) end
    check("install failure is committed",x.Confirm().error.code,"COMMIT_RECOVERY_REQUIRED")
    check("install failure locks",x.state.CanMutate(),false)
    x.modules.world.Restore=restore
    check("install reconcile succeeds",x.state.Load("b5_flow")~=nil,true)
    check("install retry no duplicate",F.Must(x.Confirm()).alreadyConfirmed,true)
    x=new(); x.Prepare(); x.Pending("A")
    ---@type table|nil
    local nested
    x.onEvent=function(name) if name=="PotionDelivered" then nested=x.Confirm(); error("injected observer") end end
    local result=F.Must(x.Confirm())
    check("observer failure still confirmed",result.phase,"confirmed")
    check("observer errors recorded",#result.notificationErrors,1)
    check("nested confirmation refused",assert(nested).error.code,"COMMAND_BUSY")
    check("observer failure no duplicate",F.Must(x.Confirm()).alreadyConfirmed,true)
    -- 损坏已存结果：所有恢复器保持原状态，不能部分安装。
    x=new(); x.Prepare(); local pending=x.Pending("D")
    local mutations={
        function(v) v.currentOrder.pending.reward.currency=999 end,
        function(v) v.currentOrder.pending.followup.renderedText="伪造回信" end,
        function(v) v.currentOrder.pending.candidateLive.world.npcs.npc_passerby_a.memories.mem_mother.state="intact" end,
        function(v) v.currentOrder.pending.candidateLive.gameFlow.day=99 end,
        function(v) v.currentOrder.pending.candidateLive.wordTokens.byId[x.tokens.word_sleep].available=not v.currentOrder.pending.candidateLive.wordTokens.byId[x.tokens.word_sleep].available end,
        function(v) v.currentOrder.pending.facts[1].inputs.potionEffects.sleep=999 end,
        function(v) v.currentOrder.baseline.revision=v.revision+1 end,
        function(v) v.contentVersion="unknown" end,
        function(v) v.currentOrder.nextAttemptSerial=1 end,
    }
    for i,mutate in ipairs(mutations) do
        local bad=U.Copy(pending); mutate(bad)
        local valid=x.order.ValidateEnvelope(bad)
        check("bad snapshot " .. i .. " rejected",valid.ok,false)
        check("bad snapshot " .. i .. " unchanged",x.state.GetSnapshot(),pending)
    end
    -- 加载不得调用业务生成器；已保存文本/星级继续使用。
    local oldWorld,oldNarrative=require("systems.WorldState").New,require("systems.Narrative").New
    require("systems.WorldState").New=function(c) local w=oldWorld(c); w.Simulate=function() error("must not simulate on load") end; return w end
    require("systems.Narrative").New=function(c) local n=oldNarrative(c); n.ResolveDirect=function() error("must not regenerate on load") end; return n end
    local ok,status=pcall(function() return x.Reload() end)
    require("systems.WorldState").New=oldWorld; require("systems.Narrative").New=oldNarrative
    check("load does not generate story",ok and type(status)=="table",true)
    check("load preserves pending bytes",x.state.GetSnapshot(),pending)
    local rate=x.order.Rate
    x.order.Rate=function() error("must not rate on load") end
    check("load does not rate again",x.state.Load("b5_flow")~=nil,true)
    x.order.Rate=rate
    -- 同时篡改重复投影，先证明结构校验会放行，再由真实审计拒绝。
    local function coherentBad(edit)
        local bad=U.Copy(pending)
        local p=bad.currentOrder.pending
        edit(p)
        local record=p.candidateLive.orders.confirmedById[x.orderId]
        for _,key in ipairs({"reward","followup","rating","facts","worldChanges","consumption"}) do record[key]=U.Copy(p[key]) end
        local archive=p.candidateLive.letters.directArchive[x.orderId]
        archive.renderedText=p.followup.renderedText; archive.rating=U.Copy(p.rating)
        return bad
    end
    local bad=coherentBad(function(p) p.followup.renderedText="结构一致但伪造的回信" end)
    check("tampered text passes shape",require("core.SaveSchema").ValidateV2(bad,{contentVersion=x.content.contentVersion,synthesisVersion=x.content.synthesis.version,economy=x.modules.economy,letters=x.modules.letters,wordTokens=x.modules.wordTokens}).ok,true)
    check("audit rejects coherent fake text",x.order.ValidateEnvelope(bad).ok,false)
    local good=U.Copy(x.state.GetSnapshot())
    assert(x.save.Save("b5_flow",bad,2))
    local data,corrupt=x.state.Load("b5_flow")
    check("corrupt load rejected",data,nil); check("corrupt load locks",x.state.CanMutate(),false)
    check("corrupt load no partial install",x.state.GetSnapshot(),good)
    check("corrupt load diagnosed",corrupt.status,"corrupt")
    assert(x.save.Save("b5_flow",good,2)); assert(x.state.Load("b5_flow"))
    bad=coherentBad(function(p)
        p.reward.currency=p.reward.currency+50
        p.candidateLive.economy.currency=p.candidateLive.economy.currency+50
    end)
    check("audit rejects coherent extra reward",x.order.ValidateEnvelope(bad).ok,false)
    -- 迁移保留 false，已有旧发货数不伪造明细；真实 v2 恢复器必须完整。
    local legacy={gameFlow={day=3,phase="day",canSalvage=false,mainStoryStage="prologue",deliveredOrders=0}}
    x=new(); assert(x.save.Save("b5_flow",legacy,1))
    local migrated,migration=x.state.Load("b5_flow")
    check("v1 migration status",migration.status,"migrated")
    check("v1 migration keeps false",migrated.live.gameFlow.canSalvage,false)
    check("v1 migration initial currency",migrated.live.economy.currency,x.content.stage1.initialEconomy.currency)
    check("migration no rewards",x.Events("PotionDelivered"),0)
    assert(x.state.Save("b5_flow"))
    check("migrated save schema",select(2,x.save.Load("b5_flow")).schema,2)
    legacy.gameFlow.deliveredOrders=1
    assert(x.save.Save("b5_flow",legacy,1))
    local _,unsupported=x.state.Load("b5_flow")
    check("v1 history waits for migration",unsupported.status,"migration_required")
    check("v1 bad history file retained",select(2,x.save.Load("b5_flow")).schema,1)
    check("v1 bad history locked",x.state.CanMutate(),false)
    -- 接单与首次基准写入失败：既不分配正式编号，也不提前进入下一阶段。
    x=new()
    local received=F.Must(x.state.ReceiveLetter({letterId=x.content.letters[1].id}))
    check("unread cannot accept",x.order.Accept({letterInstanceId=received.letterInstanceId}).ok,false)
    F.Must(x.state.ReadLetter({letterInstanceId=received.letterInstanceId}))
    local before=x.state.GetSnapshot(); x.fault="write"
    check("accept write failure",x.order.Accept({letterInstanceId=received.letterInstanceId}).ok,false)
    check("accept failure no serial",x.state.GetSnapshot(),before)
    x.fault=false
    local id=F.Must(x.order.Accept({letterInstanceId=received.letterInstanceId})).orderId
    before=x.state.GetSnapshot(); x.fault="write"
    check("begin write failure",x.order.BeginBrew({orderId=id}).ok,false)
    check("begin failure stays accepted",x.state.GetSnapshot(),before)
    x.fault=false
    F.Must(x.order.BeginBrew({orderId=id}))
    check("brewing shop locked",x.state.Shop({}).error.code,"ORDER_LOCKED")
    check("brewing attachment locked",x.state.ClaimAttachment({}).error.code,"ORDER_LOCKED")
    -- 实际 SaveSystem.EngineStorage 经 runner 的独立 File 目录写盘；不是 Maker V13。
    local save=require "core.SaveSystem"
    local slot="b5_file_roundtrip"
    save.Delete(slot)
    x=new(); x.Prepare(); local incompatible=x.Pending("A")
    incompatible.contentVersion="unknown-content"
    assert(x.save.Save("b5_flow",incompatible,2))
    local originalFiles=U.Copy(x.files)
    local _,versionStatus=x.state.Load("b5_flow")
    check("incompatible content needs migration",versionStatus.status,"migration_required")
    check("incompatible content remains locked",x.state.CanMutate(),false)
    check("incompatible content preserves file",x.files,originalFiles)
    x=new(); x.Prepare(); local stored=x.Pending("C")
    assert(save.Save(slot,stored,2))
    local session=require("core.GameSession").New(x.content,{saveSystem=save,eventBus=x.bus,targetSchema=2})
    local read=session.state.Load(slot)
    check("File adapter complete pending restore",read,stored)
    local fileConfirmation=F.Must(session.order.Confirm({orderId=x.orderId,transactionId=x.transactionId}))
    check("File adapter confirmation",fileConfirmation.phase,"confirmed")
    local again=require("core.GameSession").New(x.content,{saveSystem=save,eventBus=x.bus,targetSchema=2})
    assert(again.state.Load(slot))
    check("File adapter new session duplicate confirmation",F.Must(again.order.Confirm({orderId=x.orderId,transactionId=x.transactionId})).alreadyConfirmed,true)
    check("File adapter no duplicate reward",again.state.GetSnapshot().live.economy.currency,x.base.live.economy.currency+x.content.letters[1].reward.currency)
    save.Delete(slot)
end
return T
