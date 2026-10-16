-- 首发日程、漏日补收与报酬：真实 schema 3 业务，仅隔离 File 介质。
local U=require "core.StateUtil"
local Data=require "data.content"
local F=require "debug.fixtures.B5Fixtures"
local T={}
local IDS={"letter_pa_01","letter_n01","letter_n02","letter_n03","letter_n04","letter_n05",
    "letter_n06","letter_n07","letter_n08","letter_n09","letter_n10"}
local function must(result)
    assert(result.ok,cjson.encode(result.error))
    return result.value
end
local function advance(x,day)
    while x.state.GetSnapshot().live.gameFlow.day<day do must(x.state.NextDay()) end
end
local function fresh() return F.New(Data,{targetSchema=3}) end
local function available(x) return must(x.session.queries.GetSalvageView()) end
local function read(x,id)
    local instance=must(x.state.ReceiveLetter({letterId=id})).letterInstanceId
    must(x.state.ReadLetter({letterInstanceId=instance}))
    return instance
end
function T.Run()
    local passed,failed=0,0
    local function scenario(name,callback)
        local ok,err=pcall(callback)
        if ok then passed=passed+1 else failed=failed+1 end
        print("[ReleaseSchedule] "..(ok and "PASS " or "FAIL ")..name..(ok and "" or " "..tostring(err)))
    end
    scenario("one new order daily D1-D11; reading cannot spend salvage",function()
        local x=fresh()
        for day,id in ipairs(IDS) do
            advance(x,day)
            local view=available(x)
            assert(U.Equal(view.availableLetterIds,{id}),"D"..day.." expected only "..id)
            assert(view.enabled and view.remaining==1)
            local instance=read(x,id)
            local before=x.state.GetSnapshot()
            local writes=x.writes
            must(x.state.ReadLetter({letterInstanceId=instance}))
            must(x.state.ReceiveLetter({letterId=id})) -- 同一实例幂等，不再花次数。
            assert(x.writes==writes and U.Equal(before,x.state.GetSnapshot()))
            view=available(x)
            assert(not view.enabled and view.remaining==0)
        end
        assert(x.state.GetSnapshot().live.gameFlow.day==11)
        assert(x.Reload())
        assert(not available(x).enabled)
    end)
    scenario("miss D1-D2, oldest first; daily limit and future rejection",function()
        local x=fresh();advance(x,3)
        assert(U.Equal(available(x).availableLetterIds,{"letter_pa_01","letter_n01","letter_n02"}),"missed letters must stay in chronological order")
        read(x,"letter_pa_01")
        local before=x.state.GetSnapshot()
        local r=x.state.ReceiveLetter({letterId="letter_n01"})
        assert(not r.ok and r.error.code=="SALVAGE_DISABLED")
        assert(U.Equal(before,x.state.GetSnapshot()))
        advance(x,4)
        assert(U.Equal(available(x).availableLetterIds,{"letter_n01","letter_n02","letter_n03"}))
        before=x.state.GetSnapshot()
        r=x.state.ReceiveLetter({letterId="letter_n10"})
        assert(not r.ok and r.error.code=="LETTER_NOT_AVAILABLE")
        assert(U.Equal(before,x.state.GetSnapshot()) and available(x).remaining==1)
        read(x,"letter_n01")
        assert(x.Reload())
        advance(x,5)
        assert(available(x).availableLetterIds[1]=="letter_n02")
        read(x,"letter_n02")
    end)
    scenario("all 11 orders remain collectible after D11 without expiry",function()
        local x=fresh();advance(x,12)
        assert(U.Equal(available(x).availableLetterIds,IDS))
        read(x,"letter_pa_01");advance(x,13)
        assert(available(x).availableLetterIds[1]=="letter_n01")
    end)
    scenario("one/two/three-star confirmation each pays 100 once",function()
        local cases=require "debug.fixtures.NumericV02Cases"
        for _,choice in ipairs({{index=1,stars=3},{index=3,stars=2},{index=4,stars=1}}) do
            local x=fresh();local instance=read(x,"letter_pa_01")
            local tokens={}
            for _,span in ipairs(must(x.modules.letters.ParseDefinition("letter_pa_01")).spans) do
                tokens[span.wordId]=must(x.state.CutWord({letterInstanceId=instance,spanId=span.spanId})).tokenId
            end
            local recipe=assert(rawget(cases,choice.index),"missing registration").recipe
            local oid=must(x.order.Accept({letterInstanceId=instance})).orderId
            local aux={};for _,id in ipairs(recipe.auxWordIds) do aux[#aux+1]=assert(tokens[id]) end
            local request={orderId=oid,equipmentId=recipe.equipmentId,mainTokenId=assert(tokens[recipe.mainWordId]),
                auxTokenIds=aux,ingredients=U.Copy(recipe.ingredients),specialItemIds={}}
            must(x.order.UpdateDraft({orderId=oid,draft=require("systems.RecipeDraft").Project(request)}))
            local preview=must(x.order.Preview(request))
            local pending=x.state.GetSnapshot().currentOrder.pending
            assert(pending.rating.stars==choice.stars)
            assert(pending.reward.currency==100,"all stars must receive fixed reward 100")
            assert(x.state.GetSnapshot().live.economy.currency==30,"trial must not pay")
            local baseline=x.state.GetSnapshot().currentOrder.baseline.id
            must(x.order.Reset({orderId=oid,baselineId=baseline,transactionId=preview.transactionId}))
            assert(x.state.GetSnapshot().live.economy.currency==30,"reset must not pay")
            must(x.order.UpdateDraft({orderId=oid,draft=require("systems.RecipeDraft").Project(request)}))
            preview=must(x.order.Preview(request))
            must(x.order.Confirm({orderId=oid,transactionId=preview.transactionId}))
            assert(x.state.GetSnapshot().live.economy.currency==130)
            local writes=x.writes
            assert(must(x.order.Confirm({orderId=oid,transactionId=preview.transactionId})).alreadyConfirmed)
            assert(x.writes==writes and x.state.GetSnapshot().live.economy.currency==130)
            assert(x.Reload())
            assert(x.state.GetSnapshot().live.economy.currency==130)
        end
    end)
    scenario("formal release content rejects prior content without overwriting it",function()
        assert(Data.contentVersion=="ordinary-release-v3")
        assert(Data.saveSlotId=="ordinary_release_v3")
        local x=fresh()
        local old=x.state.GetSnapshot();old.contentVersion="story-numeric-v02-r1"
        assert(x.save.Save("b5_flow",old,3))
        local files=U.Copy(x.files)
        local loaded,status=x.Reload()
        assert(not loaded and status.status=="migration_required" and status.error.code=="CONTENT_VERSION_MISMATCH")
        assert(U.Equal(files,x.files),"old data must not be cleared or rewritten")
    end)
    print("[ReleaseSchedule] scenarios="..passed.." passed; "..failed.." failed; Lua File/UI adapters, not window acceptance")
    return failed==0
end
return T
