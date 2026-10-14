local U = require "core.StateUtil"
local F = require "debug.fixtures.B1Fixtures"
local Test = {}
function Test.Run(check)
    local e = require("systems.Economy").New(F.Content())
    local initial = e.InitialSnapshot()
    check("V8 fixture init", initial.ok, true)
    assert(e.Restore(initial.value).ok)
    local before = assert(e.GetSnapshot())
    local uses = {{ingredientId="test_ingredient",quantity=1}}
    local copy = U.Copy(uses)
    local a = e.PlanSettlement(before, uses, {}, {currency=2})
    local b = e.PlanSettlement(before, uses, {}, {currency=2})
    check("V8 repeat deterministic", U.Equal(a, b), true)
    check("V8 candidate delta", a.ok and a.value.state.currency == 19 and a.value.state.ingredients.test_ingredient == 2, true)
    check("V8 no input mutation", U.Equal(uses, copy) and U.Equal(before, e.GetSnapshot()), true)
    for _, qty in ipairs({-1,0,0.5,4}) do
        check("V8 invalid quantity " .. qty, e.PlanSettlement(before, {{ingredientId="test_ingredient",quantity=qty}}, {}, {currency=2}).ok, false)
    end
    check("V8 unknown ingredient", e.PlanSettlement(before, {{ingredientId="unknown",quantity=1}}, {}, {currency=2}).ok, false)
    check("V8 duplicate rows", e.PlanSettlement(before, {uses[1],uses[1]}, {}, {currency=2}).ok, false)
    check("V8 invalid reward", e.PlanSettlement(before, {}, {}, {currency=-1}).ok, false)
    local specials = U.Copy(before)
    specials.specialItems.test_instance = {itemId="test_special",sourceLetterInstanceId="test_letter_instance",available=true}
    check("V8 duplicate special", e.PlanSettlement(specials, {}, {"test_instance","test_instance"}, {currency=0}).ok, false)
    check("V8 special availability", e.PlanSettlement(specials, {}, {"test_instance"}, {currency=0}).value.state.specialItems.test_instance.available, false)
    local snapshot = assert(e.GetSnapshot()); snapshot.ingredients.test_ingredient = 999
    check("V9 deep snapshot", assert(e.GetSnapshot()).ingredients.test_ingredient, 3)
    local restored = e.Restore(before)
    restored.value.ingredients.test_ingredient = 888
    check("V9 restore result isolated", assert(e.GetSnapshot()).ingredients.test_ingredient, 3)
    local bad = U.Copy(before); bad.currency = -1
    check("V9 restore rejected", e.Restore(bad).ok, false)
    check("V9 state preserved", U.Equal(before, e.GetSnapshot()), true)
    local content = F.Content(); content.stage1.initialEconomy.currency = nil
    check("V7 missing C1 currency", require("systems.Economy").New(content).InitialSnapshot().ok, false)
    Test.RunContent(check)
end

-- 正式 C1 数据的接入检查；错误样例只施加在副本，绝不修改 data 模块。
function Test.RunContent(check)
    local Data = require "data.content"
    local Economy = require "systems.Economy"
    local loaded, loadErrors = Data.Load()
    check("C1 Data.Load", loaded, true)
    assert(loaded, table.concat(loadErrors, "; "))
    local ready, errors = Data.ValidateStage1()
    check("C1 Data.ValidateStage1", ready, true)
    assert(ready, table.concat(errors, "; "))
    local original = U.Copy(Data.stage1)
    local e = Economy.New(Data)
    local initial = e.InitialSnapshot()
    check("C1 actual init", initial.ok, true)
    assert(initial.ok)
    check("C1 currency from config", initial.value.currency, Data.stage1.initialEconomy.currency)
    check("C1 ingredients from config", U.Equal(initial.value.ingredients, Data.stage1.initialEconomy.ingredients), true)
    check("C1 equipment from config", U.Equal(initial.value.ownedEquipmentIds, {[Data.stage1.initialEquipmentId]=true}), true)
    check("C1 no attachments", next(initial.value.specialItems) == nil, true)
    check("C1 init is pure", e.GetSnapshot() == nil, true)
    for _, sample in ipairs(Data.stage1.errorSamples) do
        local content = {contentVersion=Data.contentVersion,ingredients=Data.ingredients,equipment=Data.equipment,
            stage1=U.Copy(original)}
        ---@type table
        local mutation = sample.mutation
        local parent, keys = content.stage1, {}
        for key in sample.path:gmatch("[^.]+") do keys[#keys + 1] = key end
        for i = 1, #keys - 1 do parent = assert(parent[keys[i]]) end
        if mutation.op == "remove" then parent[keys[#keys]] = nil
        else
            assert(mutation.op == "set" or mutation.op == "add")
            parent[keys[#keys]] = mutation.value
        end
        local result = Economy.New(content).InitialSnapshot()
        check("C1 " .. sample.id .. " code", result.error and result.error.code or "OK", sample.expectCode)
        check("C1 " .. sample.id .. " path", result.error and result.error.path or "", "stage1." .. sample.path)
    end
    check("C1 config unchanged", U.Equal(Data.stage1, original), true)
end
return Test
