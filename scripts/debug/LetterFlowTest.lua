-- 完整技术 Envelope 联调；仅 Letter/WordToken/Economy/Flow 是真实模块。
local U = require "core.StateUtil"
local F = require "debug.fixtures.B2Fixtures"
local Save = require "core.SaveSystem"
local Schema = require "core.SaveSchema"
local Bus = require "core.EventBus"
local Tests = {}
local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
local function files()
    local io,result=Save.EngineStorage(),{}
    for _, suffix in ipairs({".json","_a.json","_b.json","_a.commit","_b.commit"}) do
        local path="save_slot1" .. suffix; result[path]=io.exists(path) and io.read(path) or false
    end
    return result
end
local function receiveRead(x,id)
    local received=x.state.ReceiveLetter({letterId=id or x.content.letters[1].id})
    assert(received.ok,received.error and received.error.message)
    local read=x.state.ReadLetter({letterInstanceId=received.value.letterInstanceId})
    assert(read.ok)
    return received.value.letterInstanceId
end
function Tests.Run(context)
    local check,finish=require("debug.fixtures.B2Check").New()
    local beforeFlow=require("core.GameFlow").Serialize()
    local beforeFiles=files()
    local listeners={}
    local function listen(name,fn)
        local id=Bus.On(name,fn,0,"B2"); listeners[#listeners+1]={name,id}; return id
    end
    local ok,problem=pcall(function()
        require("debug.LetterTest").Run(check)
        require("debug.WordTokenTest").Run(check)
        local content=F.Content()
        local x=F.Setup(content)
        local notices={LetterReceived=0,LetterRead=0,WordCut=0,WordStored=0,SaveLoaded=0}
        for name in pairs(notices) do listen(name,function(event) notices[event]=notices[event]+1 end) end
        local storedWord
        listen("WordCut",function(_,payload) payload.source.wordId="B2 listener mutation" end)
        listen("WordStored",function(_,payload) storedWord=payload.source.wordId end)
        local id=receiveRead(x)
        local writes,revision=x.saveCalls(),x.state.GetSnapshot().revision
        check("T3 same receive",x.state.ReceiveLetter({letterId=content.letters[1].id}).value.changed,false)
        check("T4 same read",x.state.ReadLetter({letterInstanceId=id}).value.changed,false)
        check("T3/T4 no writes",x.saveCalls(),writes)
        check("T3/T4 no revision",x.state.GetSnapshot().revision,revision)
        check("T3 receive once",notices.LetterReceived,1)
        check("T4 read once",notices.LetterRead,1)
        local cut=x.state.CutWord({letterInstanceId=id,spanId="body:1"})
        check("T5 command cut",cut.ok,true); assert(cut.ok)
        check("T5 one Save call",x.saveCalls(),writes+1)
        check("T5 revision once",cut.value.revision,revision+1)
        local disk=assert(Save.Load(x.slot))
        check("T5 gap and token on disk",disk.live.letters.byId[id].cutSpans["body:1"] and count(disk.live.wordTokens.byId)==1,true)
        check("T5 WordCut once",notices.WordCut,1)
        check("T5 WordStored once",notices.WordStored,1)
        check("T8 event payload copies",storedWord,content.GetWordByText(content.letters[1].body:match("{{(.-)}}")).id)
        local exposed=cut.value; exposed.source.wordId="fake"
        check("T8 command result isolated",assert(x.words.GetSnapshot()).byId[cut.value.tokenId].wordId,content.GetWordByText(content.letters[1].body:match("{{(.-)}}")).id)
        check("T5 duplicate cut unchanged",x.state.CutWord({letterInstanceId=id,spanId="body:1"}).value.changed,false)
        check("T5 duplicate cut no save",x.saveCalls(),writes+1)
        check("T5 duplicate no WordStored",notices.WordStored,1)
        assert(x.state.CutWord({letterInstanceId=id,spanId="body:2"}).ok)
        check("T5 second position",count(assert(x.words.GetSnapshot()).byId),2)
        for i=3,6 do assert(x.state.CutWord({letterInstanceId=id,spanId="body:" .. i}).ok) end
        check("T5 six sources",count(assert(x.words.GetSnapshot()).byId),6)
        local before=x.state.GetSnapshot(); local oldNotices=U.Copy(notices); local oldCalls=x.saveCalls()
        for _, req in ipairs({{letterInstanceId=id,spanId="unknown"},{letterInstanceId="unknown",spanId="body:1"},{letterInstanceId=id,spanId="body:1",wordId="fake"}}) do
            check("T6 invalid command",x.state.CutWord(req).ok,false)
        end
        check("T6 no partial changes",U.Equal(before,x.state.GetSnapshot()) and U.Equal(oldNotices,notices) and x.saveCalls()==oldCalls,true)
        for _, mutate in ipairs({
            function(d) d.live.letters.byId[id]=nil; d.live.letters.bottleQueue={} end,
            function(d) d.live.letters.byId[id].senderId="fake" end,
            function(d) d.live.letters.byId[id].read=false end,
            function(d) d.live.wordTokens.byId[cut.value.tokenId].wordId=content.words[1].id end,
            function(d) d.live.wordTokens.byId[cut.value.tokenId].sourceSpanId="body:99" end,
            function(d) d.live.wordTokens.byId[cut.value.tokenId]=nil end,
            function(d) d.live.wordTokens.byId.other=U.Copy(d.live.wordTokens.byId[cut.value.tokenId]) end,
        }) do
            local bad=U.Copy(before); mutate(bad)
            check("T9 joined bad snapshot",Schema.ValidateV2(bad,x.options).ok,false)
            Save.Delete("b2_invalid")
            assert(Save.Save("b2_invalid",bad,2))
            local reader=require("core.GameState").New(x.options)
            local notifications=notices.SaveLoaded
            local _,badStatus=reader.Load("b2_invalid")
            check("T9 Load rejected",badStatus.status,"corrupt")
            check("T9 no partial restore",U.Equal(x.state.GetSnapshot(),before),true)
            local notificationsAfter=notices.SaveLoaded
            check("T9 no success event",notificationsAfter,notifications)
            check("T9 bad disk preserved",U.Equal(Save.Load("b2_invalid"),bad),true)
            check("T9 cannot overwrite invalid",reader.Save("b2_invalid"),false)
        end
        check("T7 restore complete",x.state.Load(x.slot)~=nil,true)
        check("T7 restore no WordStored",notices.WordStored,6)
        check("T7 token identity retained",assert(x.words.GetSnapshot()).byId[cut.value.tokenId].sourceSpanId,"body:1")
        local wrong=U.Copy(before); wrong.contentVersion="future"
        check("T14 content version",Schema.ValidateV2(wrong,x.options).error.code,"CONTENT_VERSION_MISMATCH")
        local v1=require("core.GameState").New({gameFlow=require "core.GameFlow",saveSystem=Save,eventBus=Bus,dataReady=true})
        check("T14 v1 rejects",v1.ReceiveLetter({letterId=content.letters[1].id}).error.code,"V2_REQUIRED")
        local missing=U.Copy(x.options); missing.adapters=nil; missing.letters=nil; missing.wordTokens=nil
        local noAdapters=require("core.GameState").New(missing)
        local _,status=noAdapters.Load(x.slot)
        check("T14 missing adapters",status.status,"migration_required")
        check("T14 missing adapters command",noAdapters.CutWord({letterInstanceId=id,spanId="body:1"}).ok,false)
        -- brewing/pending 的结构由已通过 B1 的夹具构建，替换为真实 B2 来源。
        local orderId="test_order"
        local locked=U.Copy(before)
        locked.live.orders.acceptedById[orderId]={letterInstanceId=id,letterId=content.letters[1].id,acceptedDay=1}
        locked.currentOrder={orderId=orderId,letterInstanceId=id,phase="brewing",baseline={id="b2_base",revision=locked.revision,contentVersion=content.contentVersion,live=U.Copy(locked.live)},recipe=false,pending=false}
        assert(Save.Save(x.slot,locked,2)); assert(x.state.Load(x.slot))
        check("T15 brewing cut locked",x.state.CutWord({letterInstanceId=id,spanId="body:1"}).error.code,"ORDER_LOCKED")
        check("T15 brewing read locked",x.state.ReadLetter({letterInstanceId=id}).error.code,"ORDER_LOCKED")
        check("T15 brewing day locked",x.state.NextDay().error.code,"ORDER_LOCKED")
        check("T15 pure view allowed",x.letters.GetView(id).ok,true)
        local pending=F.Pending(before,id,cut.value.tokenId)
        assert(Save.Save(x.slot,pending,2)); assert(x.state.Load(x.slot))
        check("T15 pending cut locked",x.state.CutWord({letterInstanceId=id,spanId="body:1"}).error.code,"ORDER_LOCKED")
        check("T15 pending read locked",x.state.ReadLetter({letterInstanceId=id}).error.code,"ORDER_LOCKED")
        check("T15 pending receive locked",x.state.ReceiveLetter({letterId=content.letters[1].id}).error.code,"ORDER_LOCKED")
        check("T15 pending day locked",x.state.NextDay().error.code,"ORDER_LOCKED")
        check("T15 pending pure view",x.letters.GetView(id).ok,true)
        Tests.RunExtension(check)
        Tests.RunFaults(check)
        Tests.RunInstallFailure(check)
        if context and context.buttons then
            local buttons=context.buttons()
            check("T17 all actual callbacks found",#buttons,3)
            for _, button in ipairs(buttons) do button:GetProps().onClick() end
        end
        check("T17 default files unchanged",U.Equal(files(),beforeFiles),true)
    end)
    for _, entry in ipairs(listeners) do Bus.Off(entry[1],entry[2]) end
    require("core.GameFlow").Restore(beforeFlow)
    if not ok then
        local errorInfo=type(problem)=="table" and (problem.error or problem) or nil
        print("[B2] ERROR " .. (errorInfo and (tostring(errorInfo.code) .. ": " .. tostring(errorInfo.path) .. " " .. tostring(errorInfo.message)) or tostring(problem)))
    end
    return finish() and ok
end
function Tests.RunExtension(check)
    local content=F.Content(true)
    local x=F.Setup(content,nil,"b2_extension")
    local extra=require "data.extension_test"
    local id=extra.letters[1].id
    check("T16 day1 unavailable",x.state.ReceiveLetter({letterId=id}).error.code,"LETTER_NOT_AVAILABLE")
    local data=x.state.GetSnapshot(); data.live.gameFlow.day=2
    assert(Save.Save(x.slot,data,2)); assert(x.state.Load(x.slot))
    local instance=receiveRead(x,id)
    local a=x.state.CutWord({letterInstanceId=instance,spanId="body:1"})
    local b=x.state.CutWord({letterInstanceId=instance,spanId="body:2"})
    check("T16 same word two tokens",a.ok and b.ok and a.value.tokenId~=b.value.tokenId,true)
    check("T16 unprofiled word cuts",x.state.CutWord({letterInstanceId=instance,spanId="body:3"}).ok,true)
    check("T16 three tokens",count(assert(x.words.GetSnapshot()).byId),3)
    local view=x.letters.GetView(instance).value
    check("T16 three stable gaps",view.spans[1].cut and view.spans[2].cut and view.spans[3].cut,true)
    local initial=x.letters.InitialSnapshot().value
    local followup={orderId="b2_order",transactionId="b2_tx",letterId=extra.letters[2].id,renderedText="技术归档文本",fragmentIds={extra.fragments[1].id},
        rating={stars=1,feedback="技术反馈",ruleId="b2_rating",factIds={}}}
    local archive=x.letters.PlanArchive(initial,followup)
    check("T11 archive pure",archive.ok and next(initial.directArchive)==nil,true)
    check("T11 archive repeated",x.letters.PlanArchive(archive.value.state,followup).value.changed,false)
    followup.transactionId="conflict"
    check("T11 archive conflict",x.letters.PlanArchive(archive.value.state,followup).error.code,"ARCHIVE_CONFLICT")
    check("T11 direct cut rejected",x.state.CutWord({letterInstanceId="letter:" .. extra.letters[2].id,spanId="body:1"}).ok,false)
    local phase=x.state.GetSnapshot(); local instanceId=instance
    -- 缺筛选器、打捞禁用均不能首次收到另一封信。
    local original=x.options.narrative; x.options.narrative=nil
    check("T16 missing scheduling",x.state.ReceiveLetter({letterId=content.letters[1].id}).error.code,"RESTORER_MISSING")
    x.options.narrative=original
    phase.live.gameFlow.canSalvage=false
    assert(Save.Save(x.slot,phase,2)); assert(x.state.Load(x.slot))
    check("T16 salvage gate",x.state.ReceiveLetter({letterId=content.letters[1].id}).error.code,"SALVAGE_DISABLED")
    check("T16 repeat receive no fresh scheduling",x.state.ReceiveLetter({letterId=id}).value.letterInstanceId,instanceId)
end
function Tests.RunFaults(check)
    local content=F.Content()
    ---@type string[]
    local modes={"encode","write","readback","before_commit","uncertain","notification"}
    for _, mode in ipairs(modes) do
        local raw=Save.EngineStorage()
        ---@type boolean
        local armed=false
        ---@type string|nil
        local candidate
        local io={exists=raw.exists,delete=raw.delete,
            write=function(path,value)
                if armed and path:match("%.json$") then
                    candidate=path
                    if mode=="write" then raw.write(path,value:sub(1,#value//2)); return false end
                end
                return raw.write(path,value)
            end,
            read=function(path)
                if armed and candidate==path and mode=="readback" then return "bad" end
                if armed and candidate and mode=="uncertain" and path==candidate:gsub("%.json$",".commit") then error("B2 injected unreadable commit") end
                return raw.read(path)
            end,
            checkpoint=function(stage) if armed and mode=="before_commit" and stage=="before_commit" then error("B2 interruption") end end}
        local protocol=Save.New(io)
        local service={Load=protocol.Load,Save=function(...)
            if armed and mode=="encode" then return false,U.Error("SAVE_ENCODE_FAILED","encode","B2 injected encoder rejection") end
            return protocol.Save(...)
        end}
        local x=F.Setup(content,service,"b2_fault_" .. mode)
        local id=receiveRead(x)
        local before=x.state.GetSnapshot()
        local emitted=0
        local eventBus={Emit=function(name,payload)
            if armed and mode=="notification" and (name=="WordCut" or name=="WordStored") then error("B2 interruption before observer") end
            if name=="WordStored" then emitted=emitted+1 end
            return Bus.Emit(name,payload)
        end}
        x.options.eventBus=eventBus
        armed=true
        local result=x.state.CutWord({letterInstanceId=id,spanId="body:1"})
        local committed=mode=="uncertain" or mode=="notification"
        check("T12/13 " .. mode .. " outcome",result.ok,mode=="notification")
        if not committed then
            check("T12 " .. mode .. " memory intact",U.Equal(x.state.GetSnapshot(),before),true)
            check("T12 " .. mode .. " disk intact",U.Equal(Save.New().Load(x.slot),before),true)
        elseif mode=="uncertain" then
            check("T12 uncertain explicit",result.error.code,"SAVE_COMMIT_UNCERTAIN")
            check("T12 uncertain lock",x.state.CutWord({letterInstanceId=id,spanId="body:1"}).error.code,"STATE_LOCKED")
            check("T12 uncertainty memory not installed",U.Equal(x.state.GetSnapshot(),before),true)
        else check("T13 notifications report",#result.value.notificationErrors,2) end
        armed=false
        ---@type table<string, any>
        local readerOptions={}
        for k,v in pairs(x.options) do readerOptions[k]=v end
        readerOptions.saveSystem=Save.New()
        local reader=require("core.GameState").New(readerOptions)
        assert(x.letters.Restore(x.letters.InitialSnapshot().value).ok)
        assert(x.words.Restore(x.words.InitialSnapshot().value).ok)
        assert(reader.Load(x.slot))
        check("T12/13 " .. mode .. " restore count",count(assert(x.words.GetSnapshot()).byId),committed and 1 or 0)
        check("T12/13 " .. mode .. " no restore reward",emitted,0)
        if committed then
            local writes=x.saveCalls()
            check("T13 replay same token",reader.CutWord({letterInstanceId=id,spanId="body:1"}).value.changed,false)
            check("T13 no replay save",x.saveCalls(),writes)
        end
    end
end
function Tests.RunInstallFailure(check)
    local x=F.Setup(F.Content(),nil,"b2_install")
    local id=receiveRead(x)
    local before=x.state.GetSnapshot()
    local original=x.words.Restore
    local once=true
    ---@type table|nil
    local nested
    x.words.Restore=function(value)
        if once then
            once=false
            nested=x.state.CutWord({letterInstanceId=id,spanId="body:2"})
            original(value)
            return U.Fail("TEST_INSTALL_FAILURE","wordTokens","B2 injected install failure")
        end
        return original(value)
    end
    local result=x.state.CutWord({letterInstanceId=id,spanId="body:1"})
    check("T12 install committed error",result.error.code,"COMMIT_RECOVERY_REQUIRED")
    check("T12 install locked",x.state.CanMutate(),false)
    check("T12 install rolls back memory",U.Equal(x.state.GetSnapshot(),before),true)
    check("T12 nested install blocked",assert(nested).error.code,"COMMAND_BUSY")
    check("T12 submitted disk retained",count(assert(Save.Load(x.slot)).live.wordTokens.byId),1)
    check("T12 Load reconciles",x.state.Load(x.slot)~=nil and x.state.CanMutate(),true)
    check("T12 reconciled single token",count(assert(x.words.GetSnapshot()).byId),1)
end
return Tests
