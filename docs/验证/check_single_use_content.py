"""W-T1/W-T2 content checks using real Lua modules and real letter sources.

Candidate states only: NO B5 confirm/reset transaction, file save or engine UI.
All 64 A-D combinations start fresh; within a route inventory is never replenished.
"""
from pathlib import Path
import argparse
import json
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.tmp/b1-python'))
from lupa.lua54 import LuaRuntime, lua_type


def validate_policy(words):
    for word in words:
        assert word.get('reusable') is False, f"{word['id']}: formal words must explicitly set reusable=false"


def plain(value):
    if lua_type(value) != 'table':
        return value
    keys = list(value.keys())
    if keys and set(keys) == set(range(1, len(keys) + 1)):
        return [plain(value[i]) for i in range(1, len(keys) + 1)]
    return {str(key): plain(value[key]) for key in keys}


def run():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('package.path = ... .. "/scripts/?.lua;" .. package.path', ROOT.as_posix())
    data = lua.execute('local D=require "data.content"; local ok,e=D.Load(); assert(ok,table.concat(e or {},"\\n")); ok,e=D.ValidateStage1(); assert(ok,table.concat(e or {},"\\n")); return D')
    words = plain(data.words)
    validate_policy(words)
    assert len(words) == 30 and data.contentVersion == 'story-v0.3-r3'
    # Guard future additions too; demonstrate rejection without changing real data.
    for accidental in (True, None):
        try:
            future = {'id': 'future_formal_word'}
            if accidental is not None:
                future['reusable'] = accidental
            validate_policy(words + [future])
        except AssertionError:
            pass
        else:
            raise AssertionError('new reusable or missing-policy word was accepted')
    previous_words = lua.execute(subprocess.check_output(['git', 'show', '8589b0a:scripts/data/words.lua'], cwd=ROOT, text=True, encoding='utf-8'))
    before = plain(previous_words)
    assert [word['id'] for word in before] == [word['id'] for word in words]
    for old, new in zip(before, words):
        assert old['reusable'] is True and new['reusable'] is False
        assert {k: v for k, v in old.items() if k != 'reusable'} == {k: v for k, v in new.items() if k != 'reusable'}
    old_stage = subprocess.check_output(['git', 'show', '8589b0a:scripts/data/stage1.lua'], cwd=ROOT, text=True, encoding='utf-8')
    assert old_stage.replace('story-v0.3-r2', 'story-v0.3-r3') == (ROOT / 'scripts/data/stage1.lua').read_text(encoding='utf-8')
    frozen = ['letters.lua', 'ordinary_orders.lua', 'recipes.lua', 'word_profiles.lua',
              'synthesis.lua', 'ingredients.lua', 'equipment.lua', 'effects.lua', 'npcs.lua', 'followup.lua']
    for filename in frozen:
        old = subprocess.check_output(['git', 'show', f'8589b0a:scripts/data/{filename}'], cwd=ROOT)
        assert old.replace(b'\r\n', b'\n') == (ROOT / 'scripts/data' / filename).read_bytes().replace(b'\r\n', b'\n'), filename
    result = plain(lua.execute(r'''
local D=require "data.content"
local U=require "core.StateUtil"
local L=require("systems.Letter").New(D)
local W=require("systems.WordToken").New(D)
local E=require("systems.Economy").New(D)
local O=require("systems.Order").New(D)
local World=require("systems.WorldState").New(D)
local N=require("systems.Narrative").New(D)
local P=require "systems.Potion"
local function must(r) assert(r.ok, r.error and (r.error.code .. " @ " .. r.error.path)); return r.value end
local function count(s)
    local n=0; for _,t in pairs(s.byId) do if t.available then n=n+1 end end; return n
end
local ids={"letter_pa_01","letter_n01","letter_n02"}
local days={1,2,4}
local mains={"word_sleep","word_steady_hands","word_smile"}
local aux={
    {A={},B={"word_dream"},C={"word_forget"},D={"word_dream","word_forget"}},
    {A={},B={"word_lookup"},C={"word_forget"},D={"word_lookup","word_forget"}},
    {A={},B={"word_soup"},C={"word_forget"},D={"word_lookup","word_forget"}},
}
local function route(choices)
    local ls,ws,es=must(L.InitialSnapshot()),must(W.InitialSnapshot()),must(E.InitialSnapshot())
    local world=must(World.InitialSnapshot())
    local byWord,steps,acquired={}, {},0
    for i,letterId in ipairs(ids) do
        local definition=D.GetLetter(letterId)
        assert(days[i]>=definition.appearCondition.dayMin)
        local rec=must(L.PlanReceive(ls,letterId))
        ls=must(L.PlanMarkRead(rec.state,rec.instanceId)).state
        local gained={}
        for _,span in ipairs(must(L.ParseDefinition(letterId)).spans) do
            local cut=must(L.PlanMarkCut(ls,rec.instanceId,span.spanId))
            local token=must(W.PlanCut(ws,cut.source))
            assert(token.changed)
            ls,ws=cut.state,token.state
            byWord[span.wordId]=byWord[span.wordId] or {}
            table.insert(byWord[span.wordId],token.tokenId)
            table.insert(gained,{tokenId=token.tokenId,letterId=letterId,spanId=span.spanId,wordId=span.wordId,quantity=1})
            acquired=acquired+1
        end
        local function pick(wordId)
            for _,tokenId in ipairs(byWord[wordId] or {}) do if ws.byId[tokenId].available then return tokenId end end
        end
        local selected={{role="main",wordId=mains[i]}}
        for j,wordId in ipairs(aux[i][choices[i]]) do table.insert(selected,{role="aux:" .. j,wordId=wordId}) end
        local auxIds={}
        for _,item in ipairs(selected) do
            item.tokenId=pick(item.wordId)
            if not item.tokenId then return {choices=table.concat(choices,"→"),reachable=false,blockedLetterId=letterId,missingWordId=item.wordId,priorSteps=steps} end
            if item.role~="main" then table.insert(auxIds,item.tokenId) end
        end
        local orderId="content-route:" .. letterId
        local baseline={id="content-baseline:" .. letterId,revision=i-1,contentVersion=D.contentVersion,
            live={letters=ls,wordTokens=ws,economy=es,orders={acceptedById={[orderId]={letterId=letterId,letterInstanceId=rec.instanceId,acceptedDay=days[i]}},confirmedById={}}}}
        -- Acceptance is a pure input record; it does not claim B5 accepted/saved.
        local request={orderId=orderId,baselineId=baseline.id,equipmentId="kit_old_cauldron",mainTokenId=selected[1].tokenId,
            auxTokenIds=auxIds,ingredients={{ingredientId="ing_night_dew",quantity=1},{ingredientId="ing_sea_salt",quantity=1}},specialItemIds={}}
        local resolved=must(O.ResolveRecipe(request,baseline))
        local potion=must(P.Calculate(resolved,D))
        assert(must(O.Evaluate(definition.requirement,potion)).canShip)
        local context={letterId=letterId,orderId=orderId,day=days[i]}
        local simulated=must(World.Simulate(world,potion,context))
        context.world,context.potion=simulated.world,potion
        local reply=must(N.ResolveDirect(simulated.facts,context))
        local rating=must(O.Rate(simulated.facts,definition.ratingSetId))
        assert(#reply.renderedText>0)
        local refs=must(W.ResolveRecipe(ws,request))
        local before=U.Copy(ws)
        local consumed=must(W.PlanConsumption(ws,refs))
        assert(U.Equal(ws,before))
        assert(#consumed.consumedTokenIds==#selected)
        local selectedIds={}; for _,item in ipairs(selected) do selectedIds[item.tokenId]=true end
        for tokenId,t in pairs(before.byId) do
            local after=consumed.state.byId[tokenId]
            if selectedIds[tokenId] then assert(not after.available and after.consumedByOrderId==orderId)
            else assert(U.Equal(t,after)) end
        end
        ws=must(W.ValidateSnapshot(consumed.state))
        es=must(E.PlanSettlement(es,request.ingredients,{},definition.reward)).state
        world=simulated.world
        for _,item in ipairs(selected) do
            local unavailable=W.ResolveRecipe(ws,{orderId="next-order",mainTokenId=item.tokenId,auxTokenIds={}})
            assert(not unavailable.ok and unavailable.error.code=="TOKEN_UNAVAILABLE")
            local t=ws.byId[item.tokenId]
            local reclip=must(W.PlanCut(ws,{wordId=t.wordId,sourceLetterInstanceId=t.sourceLetterInstanceId,sourceSpanId=t.sourceSpanId,sourceNpcId=t.sourceNpcId}))
            assert(not reclip.changed and not reclip.token.available and U.Equal(reclip.state,ws))
        end
        table.insert(steps,{letterId=letterId,choice=choices[i],gained=gained,used=selected,availableAfter=count(ws),currencyAfter=es.currency,stars=rating.stars})
    end
    return {choices=table.concat(choices,"→"),reachable=true,steps=steps,acquired=acquired,available=count(ws),currency=es.currency}
end
local matrix={}; for _,a in ipairs({"A","B","C","D"}) do for _,b in ipairs({"A","B","C","D"}) do for _,c in ipairs({"A","B","C","D"}) do table.insert(matrix,route({a,b,c})) end end end
local minimal=route({"A","A","A"})
assert(minimal.reachable and minimal.acquired==14 and minimal.available==11 and minimal.currency==270)
for _,s in ipairs(minimal.steps) do assert(s.stars==3) end
-- Same recipe under an old content version must be refused before calculation.
local old={id="old",revision=0,contentVersion="story-v0.3-r2",live={}}
local rejected=O.ResolveRecipe({orderId="old-order",baselineId="old",equipmentId="kit_old_cauldron",mainTokenId="old-token",auxTokenIds={},ingredients={},specialItemIds={}},old)
assert(not rejected.ok and rejected.error.code=="CONTENT_VERSION_MISMATCH")
return {version=D.contentVersion,minimal=minimal,matrix=matrix,oldBaselineGate=rejected.error.code}
'''))
    result['scope'] = 'real letter/token/potion/world/narrative/rating/economy candidate modules; NO B5 confirm/reset/save or engine'
    assert len(result['matrix']) == 64
    result['reachableCombinations'] = sum(row['reachable'] for row in result['matrix'])
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--export', type=Path)
    args = parser.parse_args()
    report = run()
    if args.export:
        args.export.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f"PASS: {report['version']}; 30 formal words explicitly single-use; future true/nil rejected; frozen definitions/sources/rules unchanged.")
    print(f"Real-module candidate A→A→A: 14 acquired, 3 consumed, 11 available, 270 coins, 3/3/3 stars. {report['reachableCombinations']}/64 combinations have continuous word supply.")
    print('Old baseline gate: CONTENT_VERSION_MISMATCH. B5 transactions, saves and engine UI remain unverified.')
