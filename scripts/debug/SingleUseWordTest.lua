-- W-P1/W-P2 专项。TECHNICAL 标记内容副本与正式 W01 门禁分别输出。
local U=require "core.StateUtil"
local W=require "debug.fixtures.SingleUseFixtures"
local F=require "debug.fixtures.B5Fixtures"
local C=require "debug.fixtures.B4Fixtures"
local T={}
-- 正式验收默认直接复制当前内容；--technical 才改策略/版本。
local function testContent()
    return rawget(_G,"SINGLE_USE_TECHNICAL_ONLY") and W.Content() or C.Content()
end

local function flows(check)
    for _,id in ipairs({"A","B","C","D"}) do
        local x=F.New(testContent()); x.Prepare()
        local before=x.state.GetSnapshot()
        local request=x.Request(id)
        local pending=x.Pending(id).currentOrder.pending
        check(id .. " preview keeps formal cards",x.state.GetSnapshot().live,before.live)
        W.CheckConsumption(check,x.content,before.live.wordTokens,pending.candidateLive.wordTokens,request,pending.consumption.consumedTokenIds)
        local original=x.state.GetSnapshot(); assert(x.Reload())
        check(id .. " pending reload stable",x.state.GetSnapshot(),original)
        for _=1,2 do
            W.Must(x.Reset()); check(id .. " reset cards and cuts",x.state.GetSnapshot().live,before.live)
            x.Pending(id)
        end
        pending=x.state.GetSnapshot().currentOrder.pending
        local view=W.Must(x.order.GetView({orderId=x.orderId}))
        check(id .. " view saved consumption",view.pending.consumption,pending.consumption)
        W.Must(x.Confirm())
        local after=x.state.GetSnapshot()
        W.CheckConsumption(check,x.content,before.live.wordTokens,after.live.wordTokens,request,pending.consumption.consumedTokenIds)
        check(id .. " source gaps retained",after.live.letters.byId,before.live.letters.byId)
        check(id .. " available excludes consumed",W.Must(x.modules.wordTokens.GetInventoryView()).availableCount,
            #W.Must(x.modules.wordTokens.GetInventory())-#pending.consumption.consumedTokenIds)
        local writes,events=x.writes,#x.events
        W.Must(x.order.GetView({orderId=x.orderId})); W.Must(x.Confirm())
        check(id .. " repeated view/confirm no extra effects",{x.writes,#x.events},{writes,events})
        assert(x.Reload()); W.Must(x.Confirm())
        check(id .. " confirmed reload stable",x.state.GetSnapshot(),after)
    end
    local x=F.New(testContent()); x.Prepare()
    for _,id in ipairs({"E","F"}) do
        local before=x.state.GetSnapshot(); local files=U.Copy(x.files)
        local result=W.Must(x.order.Preview(x.Request(id)))
        check(id .. " literal failure",result.requirementResult.canShip,false)
        check(id .. " failed calculation no permanent use",x.state.GetSnapshot(),before)
        check(id .. " failed calculation no save",x.files,files)
    end
    local before=x.state.GetSnapshot()
    x.content.orderRatings={}
    check("content failure diagnosed",x.order.Preview(x.Request("D")).error.code,"RATING_UNCOVERED")
    check("content failure no card used",x.state.GetSnapshot(),before)
end

local function twoSources(check)
    local x=F.New(W.TwoSources())
    local sourceA=W.Receive(x,"letter_pa_01")
    local sourceB=W.Receive(x,"letter_technical_second")
    local a,b=W.Select(x,"word_sleep",sourceA),W.Select(x,"word_sleep",sourceB)
    check("two same words retain both instances",#x.tokensByWord.word_sleep,2)
    check("two same words unique token IDs",a~=b,true)
    W.Begin(x,"letter_pa_01")
    local recipe=W.ById(x.content.stage1.sampleCases,"D").recipe
    local request=W.Request(x,recipe,sourceA)
    local duplicate=U.Copy(request); duplicate.auxTokenIds={a}
    check("same card two slots rejected",x.order.Preview(duplicate).error.code,"DUPLICATE_TOKEN")
    duplicate.auxTokenIds={b}
    check("two cards still follow repeat policy",x.order.Preview(duplicate).error.code,"DUPLICATE_NOT_ALLOWED")
    x.transactionId=W.Must(x.order.Preview(request)).transactionId
    W.Must(x.Confirm())
    local first=x.state.GetSnapshot()
    check("A used",first.live.wordTokens.byId[a].available,false)
    check("B retained",first.live.wordTokens.byId[b].available,true)
    check("available selection skips A",W.Select(x,"word_sleep"),b)
    local recut=W.Must(x.state.CutWord({letterInstanceId=sourceA,spanId=first.live.wordTokens.byId[a].sourceSpanId}))
    check("recut same token id",recut.tokenId,a)
    check("recut no revival",x.state.GetSnapshot(),first)
    W.Begin(x,"letter_technical_second")
    request=W.Request(x,recipe,sourceB)
    local reused=U.Copy(request); reused.mainTokenId=a
    check("used A rejected next order",x.order.Preview(reused).error.code,"TOKEN_UNAVAILABLE")
    local baseline=x.state.GetSnapshot()
    x.transactionId=W.Must(x.order.Preview(request)).transactionId
    local stale=x.transactionId
    W.Must(x.Reset()); check("second reset does not revive first order cards",x.state.GetSnapshot().live,baseline.live)
    x.transactionId=W.Must(x.order.Preview(request)).transactionId
    local prior=x.state.GetSnapshot()
    check("stale confirm rejected",x.order.Confirm({orderId=x.orderId,transactionId=stale}).ok,false)
    check("stale confirm keeps all cards",x.state.GetSnapshot(),prior)
    W.Must(x.Confirm())
    local confirmed=x.state.GetSnapshot()
    check("A belongs first order",confirmed.live.wordTokens.byId[a].consumedByOrderId,"order:1")
    check("B belongs second order",confirmed.live.wordTokens.byId[b].consumedByOrderId,"order:2")
    assert(x.Reload()); check("same name separate histories load",x.state.GetSnapshot(),confirmed)
    local bad=U.Copy(confirmed)
    bad.live.orders.confirmedById["order:2"].recipe.mainTokenId=a
    local record=bad.live.orders.confirmedById["order:2"]
    for i,id in ipairs(record.consumption.consumedTokenIds) do if id==b then record.consumption.consumedTokenIds[i]=a end end
    check("same card twice in history rejected",x.order.ValidateEnvelope(bad).ok,false)
    assert(x.save.Save("b5_flow",bad,2))
    local data,status=x.state.Load("b5_flow")
    check("bad history load rejected",data,nil); check("bad history diagnosed",status.status,"corrupt")
    check("bad history no partial state",x.state.GetSnapshot(),confirmed)
end

local function oldVersions(check)
    for _,phase in ipairs({"pending","confirmed"}) do
        -- r3 相比 r2 只改 words.reusable 与 contentVersion，保留真实旧策略/版本。
        local old=C.Content(); old.contentVersion="story-v0.3-r2"
        for _,word in ipairs(old.words) do word.reusable=true end
        local x=F.New(old); x.Prepare(); x.Pending("D")
        if phase=="confirmed" then W.Must(x.Confirm()) end
        local originalFiles=U.Copy(x.files); local events=#x.events
        local fresh=require("core.GameSession").New(testContent(),{saveSystem=x.save,eventBus=x.bus})
        local before=fresh.state.GetSnapshot()
        local data,status=fresh.state.Load("b5_flow")
        check(phase .. " old reusable refused",data,nil)
        check(phase .. " explicit migration required",status.status,"migration_required")
        check(phase .. " version error",status.error.code,"CONTENT_VERSION_MISMATCH")
        check(phase .. " disk bytes retained",x.files,originalFiles)
        check(phase .. " no partial installation",fresh.state.GetSnapshot(),before)
        check(phase .. " no rewards",#x.events,events)
        check(phase .. " locked save",fresh.state.Save("b5_flow"),false)
        check(phase .. " locked command",fresh.state.NextDay().ok,false)
        check(phase .. " locked disk retained",x.files,originalFiles)
        assert(x.Reload()); check(phase .. " old version still loads own files",x.state.GetSnapshot().contentVersion,old.contentVersion)
    end
end

local function uncertainAllCards(check)
    local x=F.New(testContent()); x.Prepare(); x.Pending("D")
    local before=x.state.GetSnapshot(); local pending=before.currentOrder.pending
    check("D has main plus two auxiliary cards",#pending.consumption.consumedTokenIds,3)
    x.fault="uncertain"; x.commitWritten=false
    check("uncertain D confirmation rejected for reconciliation",x.Confirm().ok,false)
    check("uncertain D no partial memory consumption",x.state.GetSnapshot(),before)
    check("uncertain D no delivery notification",x.Events("PotionDelivered"),0)
    x.fault=false; assert(x.Reload())
    check("uncertain D recovered committed candidate",x.state.GetSnapshot().live,pending.candidateLive)
    W.CheckConsumption(check,x.content,before.live.wordTokens,x.state.GetSnapshot().live.wordTokens,
        before.currentOrder.recipe,pending.consumption.consumedTokenIds)
    check("uncertain D retry already committed",W.Must(x.Confirm()).alreadyConfirmed,true)
    check("uncertain D no replay notification",x.Events("PotionDelivered"),0)
end

local function exhaustedCrossOrder(check)
    local x=F.New(testContent())
    W.Receive(x,"letter_pa_01"); W.Must(x.state.NextDay()); W.Receive(x,"letter_n01")
    W.Begin(x,"letter_pa_01")
    local first=W.Request(x,W.ById(x.content.stage1.sampleCases,"C").recipe)
    local forgotten=first.auxTokenIds[1]
    x.transactionId=W.Must(x.order.Preview(first)).transactionId; W.Must(x.Confirm())
    W.Begin(x,"letter_n01")
    local data=require "data.content"
    local second=W.Request(x,W.ById(data.recipes,"recipe_n01_a").recipe)
    second.auxTokenIds={forgotten}
    local before=x.state.GetSnapshot()
    check("first C cannot reuse forget for N01",x.order.Preview(second).error.code,"TOKEN_UNAVAILABLE")
    check("missing card does not clear order or refill",x.state.GetSnapshot(),before)
    local selected=pcall(W.Select,x,"word_forget")
    check("test selector refuses exhausted definition",selected,false)
    check("available view omits used card",W.Must(x.modules.wordTokens.GetInventoryView()).availableCount,8)
end

function T.Run()
    local total,failed=0,0
    local function check(name,actual,expected)
        total=total+1
        if not U.Equal(actual,expected) then
            failed=failed+1; print("[SingleUse] FAIL " .. name .. " actual=" .. cjson.encode(actual) .. " expected=" .. cjson.encode(expected))
        end
    end
    local flow=require "core.GameFlow"; local original=flow.GetSnapshot()
    local data=require "data.content"
    local contentBefore=U.Copy({data.words,data.letters,data.contentVersion})
    local ok,err=pcall(function()
        print(rawget(_G,"SINGLE_USE_TECHNICAL_ONLY") and "[SingleUse] TECHNICAL all-word-false copies"
            or "[SingleUse] FORMAL current policy/version; two-source fixture is explicitly technical")
        flows(check); twoSources(check); oldVersions(check); uncertainAllCards(check); exhaustedCrossOrder(check)
        require("debug.OrderRecoveryTest").Run(check,testContent)
    end)
    if not ok then check("runtime " .. (type(err)=="table" and cjson.encode(err) or tostring(err)),false,true) end
    flow.Restore(original)
    check("formal content unchanged",{data.words,data.letters,data.contentVersion},contentBefore)
    print("[SingleUse] behavioral checks=" .. total .. " failures=" .. failed)
    if not rawget(_G,"SINGLE_USE_TECHNICAL_ONLY") then
        local reusable={}
        ---@type table[]
        local formalWords=U.Copy(data.words)
        for _,word in ipairs(formalWords) do if word.reusable~=false then reusable[#reusable+1]=word.id end end
        table.sort(reusable)
        check("W01 all formal words single use",reusable,{})
        check("W01 version differs from known reusable r1/r2",data.contentVersion~="story-v0.3-r1" and data.contentVersion~="story-v0.3-r2",true)
        print("[SingleUse] FORMAL contentVersion=" .. data.contentVersion .. " non-single-use=" .. #reusable)
    else print("[SingleUse] W01 formal gate NOT RUN (--technical)") end
    print("[SingleUse] checks=" .. total .. " failures=" .. failed)
    return failed==0
end
return T
