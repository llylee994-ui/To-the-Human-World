local U = require "core.StateUtil"
local F = require "debug.fixtures.B2Fixtures"
local Tests = {}
function Tests.Run(check)
    local content=F.Content(true)
    local letters=require("systems.Letter").New(content)
    local words=require("systems.WordToken").New(content)
    local id="letter_pa_ext_01" -- 队友提供的技术扩展包，仅此测试使用。
    local l=letters.PlanReceive(letters.InitialSnapshot().value,id).value
    local read=letters.PlanMarkRead(l.state,l.instanceId).value.state
    local source=letters.PlanMarkCut(read,l.instanceId,"body:1").value.source
    local base=words.InitialSnapshot().value
    local a=words.PlanCut(base,source)
    assert(a.ok)
    local b=words.PlanCut(a.value.state,source)
    check("T5 token retry",not b.value.changed and b.value.tokenId==a.value.tokenId,true)
    local source2=letters.PlanMarkCut(read,l.instanceId,"body:2").value.source
    local c=words.PlanCut(b.value.state,source2)
    check("T2 two same words independent",c.value.tokenId~=a.value.tokenId,true)
    check("T5 input immutable",next(base.byId)==nil,true)
    assert(words.Restore(c.value.state).ok)
    check("T8 inventory count",#words.GetInventory().value,2)
    local inventory=words.GetInventory().value
    inventory[1].definition.effects.calm=999; inventory[1].source.sourceSpanId="fake"
    local restored=words.Restore(c.value.state); restored.value.byId[a.value.tokenId].available=false
    check("T8 inventory/restore copies",assert(words.GetSnapshot()).byId[a.value.tokenId].available,true)
    local recipe={orderId="b2_order",mainTokenId=a.value.tokenId,auxTokenIds={c.value.tokenId}}
    local resolved=words.ResolveRecipe(c.value.state,recipe)
    check("T10 same definition distinct instance",resolved.ok,true)
    local planned=words.PlanConsumption(c.value.state,resolved.value)
    check("T10 reusable",planned.ok and #planned.value.consumedTokenIds==0 and U.Equal(planned.value.state,c.value.state),true)
    recipe.auxTokenIds={a.value.tokenId}
    check("T10 repeated instance",words.ResolveRecipe(c.value.state,recipe).error.code,"DUPLICATE_TOKEN")
    recipe.mainTokenId="unknown"; recipe.auxTokenIds={}
    check("T10 unavailable",words.ResolveRecipe(c.value.state,recipe).error.code,"TOKEN_UNAVAILABLE")
    for _, key in ipairs({"wordId","sourceSpanId","sourceNpcId","sourceLetterInstanceId"}) do
        local bad=U.Copy(source); bad[key]="fake"
        check("T6 forged " .. key,words.PlanCut(base,bad).ok,false)
    end
    local once=content.GetWord(source.wordId); once.reusable=false -- 仅内容副本的技术覆盖。
    local fresh=require("systems.WordToken").New(content)
    local cut=fresh.PlanCut(base,source)
    local request={orderId="b2_consume",mainTokenId=cut.value.tokenId,auxTokenIds={}}
    local refs=fresh.ResolveRecipe(cut.value.state,request)
    local consumed=fresh.PlanConsumption(cut.value.state,refs.value)
    check("T10 consumable",consumed.value.state.byId[cut.value.tokenId].available,false)
    check("T10 consumed source retained",consumed.value.state.byId[cut.value.tokenId].sourceSpanId,source.sourceSpanId)
    check("T10 consumed by order",consumed.value.state.byId[cut.value.tokenId].consumedByOrderId,"b2_consume")
    check("T10 plan not live",cut.value.state.byId[cut.value.tokenId].available,true)
    check("T10 consumed ref denied",fresh.ResolveRecipe(consumed.value.state,request).ok,false)
    local tampered=U.Copy(refs.value); tampered.main.definition.reusable=true
    check("T10 tampered resolved denied",fresh.PlanConsumption(cut.value.state,tampered).ok,false)
    local bad=U.Copy(cut.value.state); bad.byId[cut.value.tokenId].consumedByOrderId=nil
    check("T9 false mandatory",fresh.Restore(bad).ok,false)
    -- 同名两张独立一次性卡：只扣指定来源；历史不能冒充可用库存。
    local pair=U.Copy(c.value.state)
    local one={orderId="b2_pair",mainTokenId=a.value.tokenId,auxTokenIds={}}
    local used=fresh.PlanConsumption(pair,fresh.ResolveRecipe(pair,one).value).value
    check("W05 consume one keeps other",used.state.byId[c.value.tokenId].available,true)
    assert(fresh.Restore(used.state).ok)
    local view=fresh.GetInventoryView().value
    check("W05 collected cards retained",#view.cards,2)
    check("W05 available cards only",view.availableCount,1)
    check("W05 available definitions",view.availableDefinitionCount,1)
    check("W05 available categories",view.availableCategoryCount,1)
    check("W05 group collected",view.groups[1].collectedCount,2)
    check("W05 group available ids",U.Equal(view.groups[1].availableTokenIds,{c.value.tokenId}),true)
    view.groups[1].availableTokenIds[1]="tampered"
    check("W05 view isolated",U.Equal(fresh.GetInventoryView().value.groups[1].availableTokenIds,{c.value.tokenId}),true)
    local again=fresh.PlanCut(used.state,source).value
    check("W05 recut cannot revive",U.Equal(again.state,used.state),true)
    check("W05 recut keeps token",again.tokenId,a.value.tokenId)
    one.mainTokenId=c.value.tokenId
    local exhausted=fresh.PlanConsumption(used.state,fresh.ResolveRecipe(used.state,one).value).value
    assert(fresh.Restore(exhausted.state).ok)
    view=fresh.GetInventoryView().value
    check("W05 exhausted history not counted",U.Equal({view.availableCount,view.availableDefinitionCount,view.availableCategoryCount,#view.cards},{0,0,0,2}),true)
end
return Tests
