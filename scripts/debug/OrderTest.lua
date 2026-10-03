local U=require "core.StateUtil"
local F=require "debug.fixtures.B3Fixtures"
local Potion=require "systems.Potion"
local Tests={}
function Tests.Run(check)
    local x=F.Setup()
    local original=x.Request(x.Sample("A").recipe)
    local before=U.Copy(x.baseline)
    local function reject(name,change,code)
        local request,base=U.Copy(original),U.Copy(x.baseline)
        change(request,base)
        local requestBefore,baseBefore=U.Copy(request),U.Copy(base)
        local result=x.order.ResolveRecipe(request,base)
        check(name .. " code",not result.ok and result.error.code,code)
        check(name .. " pure",U.Equal(request,requestBefore) and U.Equal(base,baseBefore),true)
    end
    reject("stale baseline",function(r) r.baselineId="old" end,"STALE_BASELINE")
    reject("content version",function(_,b) b.contentVersion="old" end,"CONTENT_VERSION_MISMATCH")
    reject("not accepted",function(r) r.orderId="not-accepted" end,"INVALID_ORDER_STATE")
    reject("already confirmed",function(_,b) b.live.orders.confirmedById.b3_order={} end,"INVALID_ORDER_STATE")
    reject("unread order",function(_,b) b.live.letters.byId["letter:letter_pa_01"].read=false end,"STATE_INVALID")
    reject("unknown equipment",function(r) r.equipmentId="missing" end,"UNKNOWN_ID")
    reject("not owned",function(r) r.equipmentId="kit_copper_cauldron" end,"INVALID_REQUEST")
    reject("unavailable token",function(r) r.mainTokenId="missing" end,"TOKEN_UNAVAILABLE")
    reject("duplicate token",function(r) r.auxTokenIds={r.mainTokenId} end,"DUPLICATE_TOKEN")
    reject("aux slots",function(r) r.auxTokenIds={x.byWord.word_dream[1],x.byWord.word_forget[1],x.byWord.word_quiet[1]} end,"SLOT_LIMIT")
    reject("ingredient slots",function(r) r.ingredients[1].quantity=3 end,"SLOT_LIMIT")
    reject("fractional quantity",function(r) r.ingredients[1].quantity=1.5 end,"INVALID_REQUEST")
    reject("zero quantity",function(r) r.ingredients[1].quantity=0 end,"INVALID_REQUEST")
    reject("unknown ingredient",function(r) r.ingredients[1].ingredientId="missing" end,"UNKNOWN_ID")
    reject("unaggregated",function(r) r.ingredients[2]=U.Copy(r.ingredients[1]) end,"INVALID_REQUEST")
    reject("short stock",function(_,b) b.live.economy.ingredients.ing_sea_salt=0 end,"INVENTORY_SHORT")
    local short=U.Copy(x.baseline); short.live.economy.ingredients.ing_sea_salt=0
    check("short details",x.order.ResolveRecipe(original,short).error.details,{ingredientId="ing_sea_salt",needed=1,available=0})
    reject("phantom special",function(r) r.specialItemIds={"not-owned"} end,"SPECIAL_ITEM_UNAVAILABLE")
    reject("extra request key",function(r) r.success=true end,"INVALID_REQUEST")
    reject("sparse aux",function(r) r.auxTokenIds={[2]=x.byWord.word_dream[1]} end,"INVALID_REQUEST")
    reject("orphan gap",function(_,b) b.live.wordTokens.byId[original.mainTokenId]=nil end,"SOURCE_INVALID")

    local function repeatIngredient(value)
        local c=F.Content(); c.stage1.recipePolicy.repeatIngredient=value
        local y=F.Setup(c); local r=y.Request(y.Sample("A").recipe); r.ingredients[1].quantity=2
        return y.order.ResolveRecipe(r,y.baseline)
    end
    check("explicit repeat true",repeatIngredient(true).ok,true)
    check("explicit repeat false",repeatIngredient(false).error.code,"DUPLICATE_NOT_ALLOWED")
    check("missing repeat policy",repeatIngredient(nil).error.code,"DUPLICATE_POLICY_MISSING")
    local c=F.Content(true)
    local y=F.Setup(c)
    ---@type string[]|nil
    local repeated
    for _, ids in pairs(y.byWord) do if #ids>1 then repeated=ids; break end end
    assert(repeated)
    local r=y.Request(y.Sample("A").recipe); r.auxTokenIds={repeated[1],repeated[2]}
    check("same definition denied",y.order.ResolveRecipe(r,y.baseline).error.code,"DUPLICATE_NOT_ALLOWED")
    c.stage1.recipePolicy.repeatWordDefinition=nil
    check("same definition missing policy",y.order.ResolveRecipe(r,y.baseline).error.code,"DUPLICATE_POLICY_MISSING")
    c.stage1.recipePolicy.repeatWordDefinition=true
    check("same definition explicitly allowed",y.order.ResolveRecipe(r,y.baseline).ok,true)
    local same=Potion.Calculate(F.Must(y.order.ResolveRecipe(r,y.baseline)),c)
    check("same definition Potion explicit policy",same.ok,true)
    check("same definition trace sources unique",#same.value.trace[2].sourceIds,1)
    check("same definition result valid",Potion.ValidateResult(same.value,c).ok,true)
    local request=x.Request(x.Sample("G1").recipe)
    local reversed=U.Copy(request); reversed.ingredients={request.ingredients[2],request.ingredients[1]}
    check("ingredient order canonical",F.Must(x.order.ResolveRecipe(request,x.baseline)),F.Must(x.order.ResolveRecipe(reversed,x.baseline)))
    local resolved=F.Must(x.order.ResolveRecipe(original,x.baseline))
    resolved.main.source.wordId="mutated"; resolved.ingredients[1].definition.mods.stability=500
    check("resolved copy isolation",x.baseline,before)
    check("config copy isolation",x.content.ingredients[1].mods.stability,1)

    -- 技术附件：只验证来源/库存/槽位门禁，不补造尚未声明的特殊物品炼药机制。
    local specialContent=F.Content()
    specialContent.specialItems={{id="b3_attachment"}}
    specialContent.letters[1].attachments={{id="b3_attachment"}}
    local special=F.Setup(specialContent)
    local specialBase=U.Copy(special.baseline)
    local letterId="letter:" .. specialContent.letters[1].id
    specialBase.live.letters.byId[letterId].claimedAttachmentIds={"b3_attachment"}
    specialBase.live.economy.specialItems.test_item={itemId="b3_attachment",sourceLetterInstanceId=letterId,available=true}
    local sr=special.Request(special.Sample("A").recipe); sr.specialItemIds={"test_item"}
    check("valid special lacks synthesis rule",special.order.ResolveRecipe(sr,specialBase).error.code,"CONFIG_MISSING")
    specialBase.live.economy.specialItems.test_item.sourceLetterInstanceId="other_letter"
    check("special wrong letter",special.order.ResolveRecipe(sr,specialBase).error.code,"SPECIAL_ITEM_UNAVAILABLE")
    specialBase.live.economy.specialItems.test_item.sourceLetterInstanceId=letterId
    specialBase.live.economy.specialItems.test_item.available=false
    check("special unavailable",special.order.ResolveRecipe(sr,specialBase).error.code,"SPECIAL_ITEM_UNAVAILABLE")
    specialBase.live.economy.specialItems.test_item.available=true
    specialBase.live.letters.byId[letterId].claimedAttachmentIds={}
    check("special not claimed",special.order.ResolveRecipe(sr,specialBase).error.code,"SPECIAL_ITEM_UNAVAILABLE")
    specialBase.live.letters.byId[letterId].claimedAttachmentIds={"b3_attachment"}
    specialBase.live.economy.specialItems.test_item2=U.Copy(specialBase.live.economy.specialItems.test_item)
    sr.specialItemIds={"test_item","test_item2"}
    check("special slots read from equipment",special.order.ResolveRecipe(sr,specialBase).error.code,"SLOT_LIMIT")
    local copper=U.Copy(x.baseline); copper.live.economy.ownedEquipmentIds.kit_copper_cauldron=true
    local cr=x.Request(x.Sample("D").recipe); cr.equipmentId="kit_copper_cauldron"; cr.auxTokenIds[#cr.auxTokenIds+1]=x.byWord.word_quiet[1]
    check("owned upgraded equipment reads actual slots",x.order.ResolveRecipe(cr,copper).ok,true)

    local potion=x.Calculate("A")
    local requirement=U.Copy(x.content.letters[1].requirement)
    local function conditionResult(condition)
        local req=U.Copy(requirement); req.conditions={condition}
        return x.order.Evaluate(req,potion)
    end
    check("duration endpoints",F.Must(conditionResult({id="boundary",kind="duration",minHours=8,maxHours=8})).canShip,true)
    check("duration below range",F.Must(conditionResult({id="boundary",kind="duration",minHours=8.01,maxHours=9})).canShip,false)
    check("duration above range",F.Must(conditionResult({id="boundary",kind="duration",minHours=6,maxHours=7.99})).canShip,false)
    check("onset endpoint",F.Must(conditionResult({id="boundary",kind="onset",maxDelayHours=2})).canShip,true)
    check("onset exceeded",F.Must(conditionResult({id="boundary",kind="onset",maxDelayHours=1.99})).canShip,false)
    check("work endpoint",F.Must(conditionResult({id="boundary",kind="workReady",workAfterDoseHours=11})).canShip,true)
    check("work exceeded",F.Must(conditionResult({id="boundary",kind="workReady",workAfterDoseHours=10.99})).canShip,false)
    check("residual endpoint",F.Must(conditionResult({id="boundary",kind="residualAt",effectId="sleep",atAfterDoseHours=12,maxWeight=0.1})).canShip,true)
    check("residual exceeded",F.Must(conditionResult({id="boundary",kind="residualAt",effectId="sleep",atAfterDoseHours=12,maxWeight=0.099})).canShip,false)
    check("no undeclared ban",F.Must(x.order.Evaluate(requirement,x.Calculate("D"))).canShip,true)
    local banned=U.Copy(requirement); banned.forbiddenEffects={"dream"}
    check("explicit forbidden set",F.Must(x.order.Evaluate(banned,x.Calculate("B"))).canShip,false)
    check("absent forbidden effect",F.Must(x.order.Evaluate(banned,potion)).canShip,true)
    check("forbidden threshold equal",F.Must(conditionResult({id="ban",kind="forbiddenEffect",effectId="sleep",maxWeight=1})).canShip,true)
    check("forbidden threshold exceeded",F.Must(conditionResult({id="ban",kind="forbiddenEffect",effectId="sleep",maxWeight=0.99})).canShip,false)
    check("unknown kind",conditionResult({id="bad",kind="randomSuccess"}).error.code,"CONFIG_INVALID")
    check("missing limit",conditionResult({id="bad",kind="duration",minHours=1}).error.code,"CONFIG_MISSING")
    check("unknown condition field",conditionResult({id="bad",kind="onset",maxDelayHours=3,success=true}).error.code,"CONFIG_INVALID")
    check("reversed interval",conditionResult({id="bad",kind="duration",minHours=8,maxHours=6}).error.code,"CONFIG_INVALID")
    check("missing residual rule",conditionResult({id="bad",kind="residualAt",effectId="dream",atAfterDoseHours=12,maxWeight=1}).error.code,"CONFIG_MISSING")
    check("unknown condition effect",conditionResult({id="bad",kind="forbiddenEffect",effectId="missing",maxWeight=0}).error.code,"UNKNOWN_ID")
    local duplicate=U.Copy(requirement); duplicate.conditions[1].id="tag.sleep"
    check("duplicate check IDs",x.order.Evaluate(duplicate,potion).error.code,"CONFIG_INVALID")
    local bad=U.Copy(potion); bad.durationHours=nil
    check("incomplete potion",x.order.Evaluate(requirement,bad).error.code,"INVALID_REQUEST")
    bad=U.Copy(potion); bad.residuals[2]=nil
    check("sparse residual data",x.order.Evaluate(requirement,bad).error.code,"INVALID_REQUEST")
    local output=F.Must(x.order.Evaluate(requirement,potion)); output.checks[1].expected.min=999
    check("requirement copy isolation",requirement.tags.sleep,0.8)
    check("baseline remains unchanged",x.baseline,before)
end
return Tests
