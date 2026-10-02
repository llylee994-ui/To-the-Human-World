-- 技术测试数据，不是正式初始金币/剧情；只供显式 B1 检查使用。
local Fixtures = {}
Fixtures.SLOT = "b1_recovery"
function Fixtures.Flow()
    return { day = 5, phase = "day", canSalvage = false,
        mainStoryStage = "b1_fixture", deliveredOrders = 2 }
end
-- 以下仅供技术测试，所有 ID/金额/世界字段均不进入 data.content。
function Fixtures.Content()
    return {contentVersion="b1_fixture_v1",synthesisVersion="b1_synthesis_v1",
        ingredients={{id="test_ingredient"}},equipment={{id="test_equipment",owned=true}},specialItems={{id="test_special"}},
        stage1={initialEquipmentId="test_equipment",initialEconomy={currency=17,ingredients={test_ingredient=3},specialItems={}}}}
end
function Fixtures.Economy()
    return {currency=17,ingredients={test_ingredient=3},specialItems={},ownedEquipmentIds={test_equipment=true}}
end
function Fixtures.V2(phase)
    local U = require "core.StateUtil"
    local flow = Fixtures.Flow(); flow.deliveredOrders = 0
    local live = {gameFlow=flow,
        letters={byId={test_letter_instance={letterId="test_letter",senderId="test_npc",received=true,read=true,
            cutSpans={test_span=true},claimedAttachmentIds={}}},bottleQueue={},directArchive={}},
        wordTokens={byId={test_token={wordId="test_word",sourceLetterInstanceId="test_letter_instance",sourceSpanId="test_span",sourceNpcId="test_npc",available=true,consumedByOrderId=false}}},
        economy=Fixtures.Economy(),world={npcs={test_npc={testFlag=false}},flags={}},
        narrative={unlockedLetterIds={},delayedQueue={},resolvedEventIds={}},
        orders={acceptedById={test_order={letterInstanceId="test_letter_instance",letterId="test_letter",acceptedDay=5}},confirmedById={}}}
    ---@type {orderId:string,letterInstanceId:string,phase:string,baseline:false|table,recipe:false|table,pending:false|table}
    local order = {orderId="test_order",letterInstanceId="test_letter_instance",phase=phase,baseline=false,recipe=false,pending=false}
    local data = {contentVersion="b1_fixture_v1",revision=7,nextOrderSerial=2,live=live,currentOrder=order}
    if phase == "accepted" then return data end
    order.baseline = {id="test_baseline",revision=7,contentVersion=data.contentVersion,live=U.Copy(live)}
    order.recipe = {orderId="test_order",baselineId="test_baseline",equipmentId="test_equipment",mainTokenId="test_token",auxTokenIds={},ingredients={{ingredientId="test_ingredient",quantity=1}},specialItemIds={}}
    if phase == "brewing" then return data end
    local candidate = U.Copy(live)
    candidate.economy.currency = 19; candidate.economy.ingredients.test_ingredient = 2
    candidate.gameFlow.deliveredOrders = 1
    local potion = {contentVersion=data.contentVersion,synthesisVersion="b1_synthesis_v1",effects={test_effect=1},intensityByEffect={test_effect="test_grade"},
        mods={intensity=0,duration=0,speed=0,stability=0,sideEffect=0},durationHours=1,onsetDelayHours=0,recoveryAfterEndHours=0,
        residuals={},stability=0,unstable=false,sideEffects={},trace={}}
    for step = 1, 8 do potion.trace[step] = {step=step,inputs={},outputs={},sourceIds={"test_source"}} end
    local pending = {transactionId="test_transaction",status="pending",contentVersion=data.contentVersion,synthesisVersion="b1_synthesis_v1",
        potion=potion,requirementResult={canShip=true,checks={},failures={}},facts={test_fact=true},worldChanges={},
        followup={letterId="test_reply",fragmentIds={"test_fragment"},bindings={},renderedText="技术夹具文本：不是正式剧情"},
        rating={stars=1,feedback="技术夹具反馈",ruleId="test_rule",factIds={"test_fact"}},
        consumption={ingredients={{ingredientId="test_ingredient",quantity=1}},consumedTokenIds={},specialItemIds={}},reward={currency=2}}
    local record = U.Copy(pending); record.status = nil
    record.letterInstanceId = order.letterInstanceId; record.recipe = U.Copy(order.recipe)
    candidate.orders.confirmedById.test_order = record
    candidate.letters.directArchive.test_order = {transactionId=pending.transactionId,letterId=pending.followup.letterId,
        renderedText=pending.followup.renderedText,fragmentIds=U.Copy(pending.followup.fragmentIds),rating=U.Copy(pending.rating)}
    pending.candidateLive = candidate
    order.pending = pending
    return data
end
return Fixtures
