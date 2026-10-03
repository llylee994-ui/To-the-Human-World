-- B3 技术基准：真实收到/阅读/剪词、真实账本，接单记录仅为纯计算输入，不冒充 B5 接单。
local U=require "core.StateUtil"
local F={}
function F.Must(result)
    if not result.ok then error(result.error.code .. " @ " .. result.error.path .. ": " .. result.error.message,0) end
    return result.value
end
function F.Content(extension)
    local content=require("debug.fixtures.B2Fixtures").Content(extension)
    local data=require "data.content"
    local valid,errors=data.ValidateStage1()
    assert(valid,table.concat(errors or {},"\n"))
    content.effects=U.Copy(data.effects)
    content.attributeProfiles=content.stage1.attributeProfiles
    content.specialItems={}
    return content
end
function F.Setup(content)
    content=content or F.Content()
    local letters=require("systems.Letter").New(content)
    local words=require("systems.WordToken").New(content)
    local economy=require("systems.Economy").New(content)
    local letterState,wordState=F.Must(letters.InitialSnapshot()),F.Must(words.InitialSnapshot())
    local byWord={}
    for _, definition in ipairs(content.letters) do
        if definition.kind=="order" then
            local received=F.Must(letters.PlanReceive(letterState,definition.id))
            letterState=F.Must(letters.PlanMarkRead(received.state,received.instanceId)).state
            for _, span in ipairs(F.Must(letters.ParseDefinition(definition.id)).spans) do
                local cut=F.Must(letters.PlanMarkCut(letterState,received.instanceId,span.spanId))
                local token=F.Must(words.PlanCut(wordState,cut.source))
                letterState,wordState=cut.state,token.state
                byWord[span.wordId]=byWord[span.wordId] or {}
                byWord[span.wordId][#byWord[span.wordId]+1]=token.tokenId
            end
        end
    end
    local ledger=F.Must(economy.InitialSnapshot())
    F.Must(letters.Restore(letterState)); F.Must(words.Restore(wordState)); F.Must(economy.Restore(ledger))
    local first=content.letters[1]
    local baseline={id=content.stage1.baseline.id,revision=0,contentVersion=content.contentVersion,
        live={letters=letterState,wordTokens=wordState,economy=ledger,
            orders={acceptedById={b3_order={letterInstanceId="letter:" .. first.id,letterId=first.id,acceptedDay=1}},confirmedById={}}}}
    local x={content=content,baseline=baseline,byWord=byWord,letters=letters,words=words,economy=economy,order=require("systems.Order").New(content)}
    function x.Request(recipe)
        local aux={}
        for _, wordId in ipairs(recipe.auxWordIds) do aux[#aux+1]=assert(byWord[wordId])[1] end
        return {orderId="b3_order",baselineId=baseline.id,equipmentId=recipe.equipmentId,
            mainTokenId=assert(byWord[recipe.mainWordId])[1],auxTokenIds=aux,
            ingredients=U.Copy(recipe.ingredients),specialItemIds=U.Copy(recipe.specialItemIds)}
    end
    function x.Sample(id)
        for _, sample in ipairs(content.stage1.sampleCases) do if sample.id==id then return sample end end
        error("未知样例 " .. id)
    end
    function x.Calculate(sampleId)
        local request=x.Request(x.Sample(sampleId).recipe)
        local resolved=F.Must(x.order.ResolveRecipe(request,baseline))
        return F.Must(require("systems.Potion").Calculate(resolved,content)),resolved
    end
    return x
end
local function near(a,b)
    if type(a)~=type(b) then return false end
    if type(a)=="number" then return a==b or math.abs(a-b)<=1e-9*math.max(1,math.abs(a),math.abs(b)) end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not near(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
function F.Checks()
    local total,failed=0,0
    local function check(name,actual,expected)
        total=total+1
        local ok=near(actual,expected)
        if not ok then failed=failed+1 end
        print("[B3] " .. (ok and "PASS " or "FAIL ") .. name .. (ok and "" or " actual=" .. tostring(actual) .. " expected=" .. tostring(expected)))
    end
    local function finish() print("[B3] checks=" .. total .. " failed=" .. failed); return failed==0 end
    return check,finish
end
return F
