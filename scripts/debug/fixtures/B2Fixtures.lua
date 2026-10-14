-- B2 仅测试：使用真实 B4 来信筛选；剩余订单/世界替身绝不装入生产 main。
local U = require "core.StateUtil"
local F = {}
function F.Content(extension)
    local Data = require "data.content"
    assert(Data.Load())
    local content = {contentVersion=Data.contentVersion,letters=U.Copy(Data.letters),words=U.Copy(Data.words),
        ingredients=U.Copy(Data.ingredients),equipment=U.Copy(Data.equipment),npcs=U.Copy(Data.npcs),
        fragments=U.Copy(Data.fragments),stage1=U.Copy(Data.stage1),synthesis=U.Copy(Data.synthesis)}
    if extension then
        ---@type table<string, any>
        local extra = require "data.extension_test"
        assert(extra.marker=="TECHNICAL_EXTENSION_TEST")
        for _, key in ipairs({"letters","words","npcs","fragments"}) do
            for _, item in ipairs(extra[key]) do content[key][#content[key]+1]=U.Copy(item) end
        end
        content.contentVersion=extra.suggestedContentVersion
    end
    local function byId(list,id) for _, item in ipairs(list) do if item.id == id then return item end end end
    content.GetLetter=function(id) return byId(content.letters,id) end
    content.GetWord=function(id) return byId(content.words,id) end
    content.GetWordByText=function(text) for _, item in ipairs(content.words) do if item.displayText == text then return item end end end
    content.GetNpc=function(id) return byId(content.npcs,id) end
    content.GetFragment=function(id) return byId(content.fragments,id) end
    return content
end
function F.Setup(content,saveSystem,slot)
    local Letter = require "systems.Letter"
    local Words = require "systems.WordToken"
    local Economy = require "systems.Economy"
    local Flow = require "core.GameFlow"
    local EventBus = require "core.EventBus"
    local Save = saveSystem or require "core.SaveSystem"
    slot=slot or "b2_flow"
    assert(slot:match("^b2_[%w_]+$"))
    require("core.SaveSystem").Delete(slot)
    local letters,words,economy=Letter.New(content),Words.New(content),Economy.New(content)
    ---@type table<string, any>
    local initial=require("debug.fixtures.B1Fixtures").V2("accepted")
    initial.contentVersion=content.contentVersion; initial.currentOrder=false; initial.revision=0
    initial.live.gameFlow.deliveredOrders=0; initial.live.gameFlow.day=1; initial.live.gameFlow.canSalvage=true
    initial.live.letters=letters.InitialSnapshot().value; initial.live.wordTokens=words.InitialSnapshot().value
    initial.live.economy=economy.InitialSnapshot().value
    initial.live.orders={acceptedById={},confirmedById={}}
    assert(letters.Restore(initial.live.letters).ok and words.Restore(initial.live.wordTokens).ok and economy.Restore(initial.live.economy).ok)
    local adapters={gameFlow=Flow,letters=letters,wordTokens=words,economy=economy}
    for _, key in ipairs({"world","narrative","orders","currentOrder"}) do
        local holder=U.Copy(key=="currentOrder" and initial.currentOrder or initial.live[key])
        adapters[key]={GetSnapshot=function() return U.Copy(holder) end,ValidateSnapshot=function(v) return U.Ok(U.Copy(v)) end,
            Restore=function(v) holder=U.Copy(v); return U.Ok(U.Copy(v)) end}
    end
    local calls=0
    local save={Load=Save.Load,Save=function(... ) calls=calls+1; return Save.Save(...) end}
    local narrative=require("systems.Narrative").New(content)
    initial.live.narrative=narrative.InitialSnapshot().value
    assert(narrative.Restore(initial.live.narrative).ok)
    adapters.narrative=narrative
    local options={gameFlow=Flow,saveSystem=save,eventBus=EventBus,targetSchema=2,dataReady=true,contentVersion=content.contentVersion,
        synthesisVersion=content.synthesis.version,economy=economy,letters=letters,wordTokens=words,adapters=adapters,initialState=initial,narrative=narrative}
    local state=require("core.GameState").New(options)
    local data,status=state.Load(slot)
    assert(data and status.status=="new")
    return {state=state,letters=letters,words=words,economy=economy,options=options,slot=slot,initial=initial,
        saveCalls=function() return calls end,content=content}
end
function F.Pending(data,letterInstanceId,tokenId)
    local base=U.Copy(data)
    local id="test_order"
    base.live.orders.acceptedById[id]={letterInstanceId=letterInstanceId,letterId=base.live.letters.byId[letterInstanceId].letterId,acceptedDay=1}
    local equipmentId=next(base.live.economy.ownedEquipmentIds)
    local ingredientId=next(base.live.economy.ingredients)
    local technical=require("debug.fixtures.B1Fixtures").V2("pending").currentOrder
    local order={orderId=id,letterInstanceId=letterInstanceId,phase="pending",
        baseline={id="b2_base",revision=base.revision,contentVersion=base.contentVersion,live=U.Copy(base.live)},
        recipe={orderId=id,baselineId="b2_base",equipmentId=equipmentId,mainTokenId=tokenId,auxTokenIds={},ingredients={{ingredientId=ingredientId,quantity=1}},specialItemIds={}},pending=U.Copy(technical.pending)}
    local p=order.pending; p.candidateLive=nil
    local content=require "data.content"
    p.contentVersion=base.contentVersion; p.synthesisVersion=content.synthesis.version
    p.potion.contentVersion=p.contentVersion; p.potion.synthesisVersion=p.synthesisVersion
    p.followup.letterId=content.letters[2].id; p.followup.fragmentIds={content.fragments[1].id}
    p.consumption.ingredients=U.Copy(order.recipe.ingredients)
    local candidate=U.Copy(base.live)
    candidate.economy=require("systems.Economy").New(content).PlanSettlement(base.live.economy,p.consumption.ingredients,{},p.reward).value.state
    candidate.gameFlow.deliveredOrders=candidate.gameFlow.deliveredOrders+1
    local record=U.Copy(p); record.status=nil; record.letterInstanceId=letterInstanceId; record.recipe=U.Copy(order.recipe)
    candidate.orders.confirmedById[id]=record
    candidate.letters.directArchive[id]={transactionId=p.transactionId,letterId=p.followup.letterId,renderedText=p.followup.renderedText,fragmentIds=U.Copy(p.followup.fragmentIds),rating=U.Copy(p.rating)}
    p.candidateLive=candidate; base.currentOrder=order
    return base
end
return F
