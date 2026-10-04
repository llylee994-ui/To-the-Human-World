-- 隔离文件介质；使用真实 SaveSystem 协议、所有真实模块和生产 GameSession 装配。
local U=require "core.StateUtil"
local F={}
F.Must=require("debug.fixtures.B4Fixtures").Must
function F.New(content)
    content=content or require("debug.fixtures.B4Fixtures").Content()
    ---@type table<string, any>
    local x={content=content,files={},events={},writes=0,fault=false,lastSnapshot=false}
    local io={}
    function io.exists(path) return x.files[path]~=nil end
    function io.read(path)
        if x.fault=="uncertain" and path:match("%.commit$") and x.commitWritten then error("injected unreadable commit") end
        if x.fault=="readback" and path==x.lastSnapshot and x.snapshotWritten then x.snapshotWritten=false; return "injected bad readback" end
        return assert(x.files[path],"missing test file")
    end
    function io.write(path,raw)
        x.writes=x.writes+1
        if x.fault=="write" and path:match("%.json$") then return false end
        x.files[path]=raw
        if path:match("%.json$") then x.lastSnapshot=path; x.snapshotWritten=true
        else x.commitWritten=true end
        return true
    end
    function io.delete(path) x.files[path]=nil; return true end
    function io.checkpoint(point) if x.fault==point then error("injected " .. point) end end
    local protocol=require("core.SaveSystem").New(io)
    x.save={Load=protocol.Load,Save=function(...)
        if x.fault~="encode" then return protocol.Save(...) end
        local encode=cjson.encode
        cjson.encode=function() error("injected encoder failure") end
        local called,ok,err=pcall(protocol.Save,...)
        cjson.encode=encode
        if not called then error(ok,0) end
        return ok,err
    end}
    x.bus={Emit=function(name,payload)
        x.events[#x.events+1]={name=name,payload=U.Copy(payload)}
        if x.onEvent then x.onEvent(name,payload) end
        return 0
    end}
    function x.Reload()
        local session=require("core.GameSession").New(content,{saveSystem=x.save,eventBus=x.bus})
        local loaded,status=session.state.Load("b5_flow")
        x.session=session; x.state=session.state; x.order=session.order; x.modules=session.modules
        return loaded,status
    end
    assert(x.Reload())
    function x.Prepare()
        local definition=require("debug.fixtures.B4Fixtures").ById(content.letters,"letter_pa_01")
        local received=F.Must(x.state.ReceiveLetter({letterId=definition.id}))
        x.letterId=received.letterInstanceId
        F.Must(x.state.ReadLetter({letterInstanceId=x.letterId}))
        x.tokens={}
        for _,span in ipairs(F.Must(x.modules.letters.ParseDefinition(definition.id)).spans) do
            x.tokens[span.wordId]=F.Must(x.state.CutWord({letterInstanceId=x.letterId,spanId=span.spanId})).tokenId
        end
        x.orderId=F.Must(x.order.Accept({letterInstanceId=x.letterId})).orderId
        x.baselineId=F.Must(x.order.BeginBrew({orderId=x.orderId})).baselineId
        x.base=x.state.GetSnapshot()
    end
    function x.Request(id)
        ---@type table|nil
        local recipe
        for _,sample in ipairs(content.stage1.sampleCases) do if sample.id==id then recipe=sample.recipe end end
        assert(recipe,"missing sample")
        local aux={}; for _,wordId in ipairs(recipe.auxWordIds) do aux[#aux+1]=assert(x.tokens[wordId]) end
        return {orderId=x.orderId,baselineId=x.baselineId,equipmentId=recipe.equipmentId,mainTokenId=assert(x.tokens[recipe.mainWordId]),
            auxTokenIds=aux,ingredients=U.Copy(recipe.ingredients),specialItemIds=U.Copy(recipe.specialItemIds)}
    end
    function x.Pending(id)
        local value=F.Must(x.order.Preview(x.Request(id or "A")))
        x.transactionId=value.transactionId
        return x.state.GetSnapshot()
    end
    function x.Confirm() return x.order.Confirm({orderId=x.orderId,transactionId=x.transactionId}) end
    function x.Reset() return x.order.Reset({orderId=x.orderId,baselineId=x.baselineId,transactionId=x.transactionId}) end
    function x.Events(name)
        local count=0; for _,event in ipairs(x.events) do if event.name==name then count=count+1 end end
        return count
    end
    return x
end
function F.Checks()
    local total,failed=0,0
    local function check(name,actual,expected)
        total=total+1; local ok=U.Equal(actual,expected)
        if not ok then failed=failed+1 end
        print("[B5] " .. (ok and "PASS " or "FAIL ") .. name .. (ok and "" or " actual=" .. tostring(actual) .. " expected=" .. tostring(expected)))
    end
    return check,function() print("[B5] checks=" .. total .. " failed=" .. failed); return failed==0 end
end
return F
