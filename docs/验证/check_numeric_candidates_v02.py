"""Validate narrative numeric drafts against the actual Lua synthesis, without editing runtime data.

Run from the repository root: python -X utf8 docs/验证/check_numeric_candidates_v02.py
Requires lupa (a local .tmp/b1-python dependency directory is also supported).
"""
from pathlib import Path
from collections import Counter
from itertools import product,permutations,combinations,combinations_with_replacement
import json,re,sys,hashlib,copy

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/b1-python'))
from lupa import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('package.path="scripts/?.lua;scripts/?/init.lua;"..package.path')
def require(name):
    x=lua.eval('require')(name)
    return x[0] if isinstance(x,tuple) else x
def lt(x):
    if isinstance(x,dict):return lua.table_from({k:lt(v) for k,v in x.items()})
    if isinstance(x,list):return lua.table_from([lt(v) for v in x])
    return x
def py(x):return {k:py(v) for k,v in x.items()} if hasattr(x,'items') else x
def unwrap(x):
    assert x.ok,py(x.error)
    return x.value

content=require('core.StateUtil').Copy(require('data.content'))
potion=require('systems.Potion');order=require('systems.Order').New(content)
economy=require('systems.Economy').New(content)
docs=ROOT/'docs/文案'
sourcefiles=[docs/x for x in ['分支条件表_v02.md','词条数值表_v02.md','供给验算表_v02.md']]
hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sourcefiles}
wordtext=sourcefiles[1].read_text(encoding='utf-8')
known={x.id for _,x in content.effects.items()};profiles={x.id for _,x in content.attributeProfiles.items()}
words={};spans={};sourcecounts=Counter()
for line in wordtext.splitlines():
    cells=[s.strip() for s in line.split('|')[1:-1]]
    if len(cells)!=9 or not re.fullmatch(r'(?:N\d\d|E01)-[A-Z]\d',cells[0]):continue
    cid,source,paragraph,text,quote,wid,category,vector,profile=cells
    assert cid not in words,cid
    path=docs/re.search(r'\]\((.*?)\)',source).group(1)
    heading='## 首封来信正文' if cid.startswith('E01') else '## 完整来信'
    body=path.read_text(encoding='utf-8').split(heading,1)[1].split('\n## ',1)[0].strip()
    paragraphs=re.split(r'\n\s*\n',body);p=paragraphs[int(paragraph)-1]
    assert quote in p and text in quote,(cid,'literal')
    start=p.index(quote)+quote.index(text);end=start+len(text)
    assert not any(start<m.end() and end>m.start() for m in re.finditer(r'\*\*.*?\*\*',p,re.S)),(cid,'bold')
    location=(str(path),int(paragraph))
    for a,b,other in spans.get(location,[]):assert not(start<b and end>a),(cid,other,'overlap')
    spans.setdefault(location,[]).append((start,end,cid))
    e=json.loads(vector.strip('`'))
    assert set(e)<=known and sum(v==1 for v in e.values())==1
    assert 0<=sum(0<v<=.2 for v in e.values())<=3 and all(v==1 or 0<v<=.2 for v in e.values())
    assert profile in profiles,profile
    definition={'id':wid.strip('`'),'displayText':text,'category':category,'effects':e,'reusable':False,'attributeProfileId':profile}
    words[cid]=definition;content.words[len(content.words)+1]=lt(definition);sourcecounts[cid[:3]]+=1
assert len(words)==61 and len({x['id'] for x in words.values()})==61

blocks=[json.loads(x) for x in re.findall(r'```json\n(.*?)\n```',sourcefiles[0].read_text(encoding='utf-8'),re.S)]
rules={x.get('orderId','N10'):x for x in blocks}
assert set(rules)=={'E01',*[f'N{i:02d}' for i in range(1,11)]}
assert all(r['requirement']['conditions']==[] and r['requirement']['forbiddenEffects']==[] for r in rules.values())
registry=next(json.loads(x) for x in re.findall(r'```json\n(.*?)\n```',sourcefiles[2].read_text(encoding='utf-8'),re.S) if '"orders"' in x)
ordered=registry['orders'];assert [x['orderId'] for x in ordered]==['E01',*[f'N{i:02d}' for i in range(1,11)]]
assert sum(len(x['recipes']) for x in ordered)==58
# Ensure the human supply table and the machine recipe registry cannot silently diverge.
human=[]
for line in sourcefiles[2].read_text(encoding='utf-8').split('## 2. 登记配方',1)[1].splitlines():
    c=[s.strip() for s in line.split('|')[1:-1]]
    if len(c)==6 and c[0] in {f'N{i:02d}' for i in range(2,10)}:
        assert c[4]=='夜露＋海盐'
        human.append((c[0],c[1],c[2],[] if c[3]=='无' else c[3].split('＋'),c[5]))
registered=[(x['orderId'],r['name'],r['main'],r['aux'],r['expectedBranch']) for x in ordered if x['orderId'] in {f'N{i:02d}' for i in range(2,10)} for r in x['recipes']]
assert human==registered

def term_matches(term,e):
    assert set(term) in ({'effectId','minWeight'},{'effectId','maxWeightExclusive'}),term
    assert term['effectId'] in known,term
    value=e.get(term['effectId'],0)
    return value>=term['minWeight'] if 'minWeight' in term else value<term['maxWeightExclusive']

def row_matches(row,e):
    return all(term_matches(t,e) for t in row['allOf']) and all(not all(term_matches(t,e) for t in group) for group in row['noneOf'])

def predicates(oid,e,rows=None):
    # Evaluate the saved FULL conditions independently. No prefix/priority exclusion is added here.
    return [(row['branch'],row_matches(row,e)) for row in (rules[oid]['exclusiveBranches'] if rows is None else rows)]

def matching_rows(oid,e,rows=None):
    return [b for b,v in predicates(oid,e,rows) if v]

def select(oid,e):
    matches=matching_rows(oid,e)
    assert len(matches)==1,('coverage_or_overlap',oid,e,matches)
    return matches[0]

def breakpoints(oid):
    # Read every comparison in the COMPLETE conditions, including strict upper bounds/exclusion groups.
    out={}
    for row in rules[oid]['exclusiveBranches']:
        for term in row['allOf']+[t for group in row['noneOf'] for t in group]:
            assert set(term) in ({'effectId','minWeight'},{'effectId','maxWeightExclusive'})
            cut=term.get('minWeight',term.get('maxWeightExclusive'))
            assert cut>=0
            out.setdefault(term['effectId'],set()).add(cut)
    return {k:sorted(v) for k,v in out.items()}

def reps(oid,k,ts):
    minimum=rules[oid]['requirement']['tags'].get(k,0)
    return sorted(set([minimum,*[x for x in ts if x>=minimum]]))

# Every decision depends only on comparisons at these cuts. The final interval is unbounded.
# Irrelevant effects span the whole nonnegative finite domain without changing the selector.
def extreme_reps(oid,k,ts):
    return sorted(set(reps(oid,k,ts)+[1000000.0]))

logical={}
for oid,r in rules.items():
    assert r['conditionSchema']=='independent_conjunction_exclusions_v02'
    branch_rows=r['exclusiveBranches']
    assert len({x['branch'] for x in branch_rows})==len(branch_rows)
    order_checks=0
    pair_count=len(branch_rows)*(len(branch_rows)-1)//2
    cuts=breakpoints(oid);keys=list(cuts);counts=Counter();boundary=0
    for values in product(*[reps(oid,k,cuts[k]) for k in keys]):
        e={**r['requirement']['tags'],**dict(zip(keys,values))}
        rows=matching_rows(oid,e);assert rows==[select(oid,e)],(oid,e,rows)
        counts[rows[0]]+=1
        for i in range(len(branch_rows)):
            assert matching_rows(oid,e,branch_rows[i:]+branch_rows[:i])==rows
            order_checks+=1
        assert matching_rows(oid,e,list(reversed(branch_rows)))==rows
        order_checks+=1
        for left,right in combinations(branch_rows,2):
            assert not(row_matches(left,e) and row_matches(right,e)),('pair_overlap',oid,left['branch'],right['branch'],e)
    assert len(counts)==(8 if oid=='E01' else 5),(oid,counts)
    for k,ts in cuts.items():
        others=[x for x in keys if x!=k]
        for values in product(*[reps(oid,x,cuts[x]) for x in others]):
            for t in ts:
                for delta in [-1e-9,0,1e-9]:
                    e={**r['requirement']['tags'],**dict(zip(others,values)),k:t+delta}
                    assert matching_rows(oid,e)==[select(oid,e)]
                    # Exact threshold belongs to the upper interval; neighbours must match interval representatives.
                    index=ts.index(t);below=ts[index-1] if index else r['requirement']['tags'].get(k,0)
                    expected={**e,k:t if delta>=0 else below}
                    assert select(oid,e)==select(oid,expected),(oid,k,t,delta)
                    boundary+=1
    extremes=0
    for values in product(*[extreme_reps(oid,k,cuts[k]) for k in keys]):
        e={**r['requirement']['tags'],**dict(zip(keys,values))}
        assert matching_rows(oid,e)==[select(oid,e)]
        extremes+=1
    logical[oid]={'cells':sum(counts.values()),'byBranch':dict(counts),'boundaries':boundary,'extremeMixedSamples':extremes,'highestIntervalsUnbounded':True,'branchPairsChecked':pair_count,'orderPermutationChecks':order_checks,'overlapCells':0,'uncoveredCells':0}

equipment={x.id:x for _,x in content.equipment.items()};ingredients={x.id:x for _,x in content.ingredients.items()}
cache={};raw_results={}
def calculate(oid,main,aux,mat):
    key=(oid,main,tuple(aux),tuple(mat))
    if key in cache:return cache[key]
    def ref(cid):
        w=words[cid]
        return {'tokenId':'assumed-'+cid,'definition':w,'source':{'wordId':w['id'],'sourceLetterInstanceId':'assumed-'+cid[:3],'sourceSpanId':cid,'sourceNpcId':'assumed-npc-'+cid[:3]}}
    recipe={'orderId':'draft-'+oid,'baselineId':'assumed-final-candidate-marks','contentVersion':content.contentVersion,'equipment':py(equipment['kit_old_cauldron']),'main':ref(main),'aux':[ref(x) for x in aux],'ingredients':[{'ingredientId':k,'quantity':v,'definition':py(ingredients[k])} for k,v in Counter(mat).items()],'specialItems':[]}
    p=unwrap(potion.Calculate(lt(recipe),content));v=unwrap(order.Evaluate(lt(rules[oid]['requirement']),p))
    effects=py(p.effects);assert matching_rows(oid,effects)==[select(oid,effects)]
    assert bool(v.canShip)==all(effects.get(k,0)>=minimum for k,minimum in rules[oid]['requirement']['tags'].items())
    out={'effects':effects,'branch':select(oid,effects) if v.canShip else None,'canShip':bool(v.canShip),'onset':p.onsetDelayHours,'duration':p.durationHours,'stability':p.stability,'unstable':bool(p.unstable),'failed':[x.id for _,x in v.checks.items() if not x.passed]}
    cache[key]=out
    raw_results[key]=p
    return out

actual=[];alternates=[]
for item in ordered:
    oid=item['orderId']
    for r in item['recipes']:
        assert len(set([r['main'],*r['aux']]))==1+len(r['aux'])
        assert all(x[:3]=='E01' or int(x[1:3])<=int(oid[1:3]) for x in [r['main'],*r['aux']]) if oid!='E01' else all(x.startswith('E01') for x in [r['main'],*r['aux']])
        p=calculate(oid,r['main'],r['aux'],r['ingredients'])
        assert p['canShip'] and p['branch']==r['expectedBranch'] and not p['unstable'],(oid,r,p)
        actual.append({'orderId':oid,**r,**p})
        if oid=='E01':
            alt=calculate(oid,'E01-S2',r['aux'],r['ingredients'])
            assert alt['canShip'] and alt['branch']==r['expectedBranch'] and not alt['unstable']
            alternates.append({'orderId':oid,'main':'E01-S2',**alt})
assert len(actual)==58 and len(alternates)==8
shipping_boundaries=[]
for item in ordered:
    oid=item['orderId'];r=item['recipes'][0];axis,minimum=next(iter(rules[oid]['requirement']['tags'].items()))
    base=py(raw_results[(oid,r['main'],tuple(r['aux']),tuple(r['ingredients']))])
    # Valid result fixtures for Order.Evaluate, not claimed to be generated by a particular word recipe.
    for value in [minimum-1e-9,minimum,minimum+1e-9]:
        fixture=copy.deepcopy(base);fixture['effects'][axis]=value
        fixture['intensityByEffect'][axis]=next(t.label for _,t in content.synthesis.intensityTiers.items() if value<=t.max)
        evaluated=unwrap(order.Evaluate(lt(rules[oid]['requirement']),lt(fixture)))
        assert bool(evaluated.canShip)==(value>=minimum)
        shipping_boundaries.append({'orderId':oid,'axis':axis,'weight':value,'canShip':bool(evaluated.canShip)})
assert calculate('N08','N08-C1',['N08-R1','N08-C2'],['ing_night_dew','ing_sea_salt'])['effects']['calm']>2.2
# Synthetic selector check, not a supply witness: even strong physical warmth is not emotional care.
assert select('N02',{'happy':1,'warmth':2})==rules['N02']['fallback']
assert calculate('N02','N02-H1',['N02-S1'],['ing_night_dew','ing_sea_salt'])['branch']==rules['N02']['fallback']

mixed=[]
for oid,main,aux,mat,expected in [
    ('N10','N10-W1',['N10-W2','N10-W3'],['ing_night_dew','ing_sea_salt'],'n10_result_2b'),
    ('N06','N06-M1',['N06-P1','E01-S2'],['ing_night_dew','ing_sea_salt'],'n06_candidate_sleep'),
    ('N08','N08-C1',['N08-R1','N08-A1'],['ing_ashen_herb','ing_ashen_herb'],'n08_candidate_wait'),
]:
    p=calculate(oid,main,aux,mat)
    assert p['canShip'] and p['branch']==expected,(oid,p)
    matches=matching_rows(oid,p['effects']);assert matches==[expected]
    mixed.append({'orderId':oid,'main':main,'aux':aux,'ingredients':mat,'independentMatches':matches,**p})

negative=[];openchecks=[]
for oid,item in [(x['orderId'],x) for x in ordered if x['orderId']!='E01']:
    main=item['recipes'][0]['main']
    p=calculate(oid,main,[],['ing_sea_salt']);assert p['canShip']
    openchecks.append({'orderId':oid,'case':'未加速仍放行',**p})
    p=calculate(oid,main,[],['ing_dried_petal','ing_dried_petal']);assert p['canShip']
    openchecks.append({'orderId':oid,'case':'持续较长仍放行',**p})
    p=calculate(oid,main,['E01-S2'],['ing_night_dew','ing_sea_salt'])
    if oid=='N06':assert p['canShip'] and p['branch']==next(c['branch'] for c in rules[oid]['triggers'] if c['key']=='sleep')
    else:assert p['canShip'],(oid,p)
    openchecks.append({'orderId':oid,'case':'睡意达线仍放行',**p})
p=calculate('N06','N06-P1',['N06-M1'],['ing_night_dew','ing_ashen_herb'])
assert p['effects']['steady']>=.8 and p['duration']==1 and p['canShip']
openchecks.append({'orderId':'N06','case':'痛感主词只有1小时仍放行',**p})
p=calculate('E01','E01-S1',[],['ing_dried_petal']);assert p['canShip']
openchecks.append({'orderId':'E01','case':'整夜延长仍放行',**p})
p=calculate('N06','N06-M1',['E01-S1','E01-S2'],['ing_night_dew','ing_sea_salt'])
assert p['canShip'] and p['effects']['sleep']==1.6 and p['branch']=='n06_candidate_sleep'
openchecks.append({'orderId':'N06','case':'sleep1.6不拒绝，进入睡过头',**p})
for item in ordered:
    oid=item['orderId'];axis=next(iter(rules[oid]['requirement']['tags']))
    candidates=sorted(cid for cid in words if cid.startswith(oid) and words[cid]['effects'].get(axis,0)<.8)
    p=calculate(oid,candidates[0],[],[])
    assert not p['canShip'] and p['effects'].get(axis,0)<.8
    negative.append({'orderId':oid,'case':'主轴不足','main':candidates[0],**p})

materials=[[]]+[[x] for x in ingredients]+[list(x) for x in combinations_with_replacement(ingredients,2)]
scans={};audit=[];totals=Counter()
for item in ordered:
    oid=item['orderId'];main=item['recipes'][0]['main']
    pool={x for x in words if x.startswith(oid)}
    pool.update(x for r in item['recipes'] for x in [r['main'],*r['aux']])
    if oid!='E01':
        pool.update(['E01-M1','E01-S1','E01-T1'])
        if oid!='N01':pool.add('N01-A1')
    pool=sorted(pool-{main})
    scan=Counter();reached=Counter();observed=Counter();examples={}
    for n in range(3):
        for aux in permutations(pool,n):
            for mat in materials:
                p=calculate(oid,main,list(aux),mat);scan['total']+=1
                if not p['canShip']:scan['cannot_ship']+=1;continue
                scan['can_ship']+=1;scan['unstable']+=int(p['unstable']);reached[p['branch']]+=1
                used=set(breakpoints(oid))
                for k,t in [('forget',.6),('anger',.6),('trust',1.2),('sleep',.6),('dream',.4)]:
                    if k not in used and p['effects'].get(k,0)>=t:
                        observed[k]+=1;examples.setdefault(k,{'main':main,'aux':list(aux),'ingredients':mat,'weight':p['effects'][k],'branch':p['branch']})
    # Fixed-main scans need not hit the N08 high-calm case; its alternate-main witness already did.
    expected={x['expectedBranch'] for x in item['recipes']}
    assert set(reached)<=expected
    if oid!='N08':assert set(reached)==expected,(oid,reached)
    scans[oid]={'pool':pool,'scan':dict(scan),'byBranch':dict(reached),'unroutedEffects':dict(observed),'examples':examples}
    totals.update(scan)
    for k,ex in examples.items():audit.append({'orderId':oid,'effect':k,**ex})
    print(json.dumps({'order':oid,'scan':dict(scan),'registered':len(item['recipes'])},ensure_ascii=False),flush=True)

# Shop is a content-level paid purchase model, not a call to the unimplemented runtime Shop action.
initial=py(content.stage1.initialEconomy)
ledger0={'currency':initial['currency'],'ingredients':initial['ingredients'],'specialItems':{},'ownedEquipmentIds':{'kit_old_cauldron':True}}
unwrap(economy.ValidateSnapshot(lt(ledger0)))
letterdefs={x.id:x for _,x in content.letters.items()}
for oid,lid in [('E01','letter_pa_01'),('N01','letter_n01'),('N02','letter_n02')]:
    assert registry['shop']['rewardByOrder'][oid]==letterdefs[lid].reward.currency==80
future_refs=[]
for i in range(len(ordered)):
    future_refs.append({cid for item in ordered[i+1:] for r in item['recipes'] for cid in [r['main'],*r['aux']]})
states=[{'words':set(),'ledger':ledger0,'histories':1,'spent':0,'buys':Counter(),'sample':[]}]
stages=[]
for i,item in enumerate(ordered):
    oid=item['orderId'];merged={};edges=0
    for state in states:
        available=state['words']|{x for x in words if x.startswith(oid)}
        for r in item['recipes']:
            used={r['main'],*r['aux']};assert used<=available,(oid,r['name'],used-available)
            ledger={'currency':state['ledger']['currency'],'ingredients':state['ledger']['ingredients'].copy(),'specialItems':{},'ownedEquipmentIds':{'kit_old_cauldron':True}}
            buys=state['buys'].copy();spent=state['spent'];needed=Counter(r['ingredients'])
            # Buy before brewing, with only previous confirmed income; never spend this recipe's later reward.
            for k,q in needed.items():
                shortage=max(0,q-ledger['ingredients'][k]);assert shortage<=registry['shop']['dailyStockPerIngredient']
                cost=int(ingredients[k].price)*shortage
                assert ledger['currency']>=cost,(oid,r['name'],'insufficient pre-confirm currency')
                ledger['currency']-=cost;ledger['ingredients'][k]+=shortage;spent+=cost;buys[k]+=shortage
            reward=registry['shop']['rewardByOrder'].get(oid,registry['shop']['laterRewardForConservativeCheck'])
            settlement=unwrap(economy.PlanSettlement(lt(ledger),lt([{'ingredientId':k,'quantity':q} for k,q in needed.items()]),lt([]),lt({'currency':reward})))
            ledger=py(settlement.state)
            relevant=(available-used)&future_refs[i]
            key=(tuple(sorted(relevant)),ledger['currency'],tuple(sorted(ledger['ingredients'].items())),spent,tuple(sorted(buys.items())))
            if key not in merged:merged[key]={'words':relevant,'ledger':ledger,'histories':0,'spent':spent,'buys':buys,'sample':state['sample']+[f'{oid}:{r["name"]}']}
            merged[key]['histories']+=state['histories'];edges+=1
    states=list(merged.values());total=sum(x['histories'] for x in states)
    expect=8*5**i;assert total==expect,(oid,total,expect)
    if oid=='N02':assert total==200
    stages.append({'orderId':oid,'histories':total,'compressedStates':len(states),'edgesChecked':edges,'minCurrency':min(x['ledger']['currency'] for x in states),'maxSpent':max(x['spent'] for x in states)})
assert sum(x['histories'] for x in states)==78_125_000
assert all(x['ledger']['currency']==146 and x['spent']==124 and x['buys']['ing_sea_salt']==8 and x['buys']['ing_night_dew']==7 for x in states)
assert all(all(v>=0 for v in x['ledger']['ingredients'].values()) for x in states)

evidence={'policy':'axis_only_shipping_independent_exclusive_v02_2026-10-09','exclusiveBranches':{oid:r['exclusiveBranches'] for oid,r in rules.items()},'sourceSha256':hashes,'runtimeContentVersion':content.contentVersion,'candidatePositions':len(words),'sourceCounts':dict(sourcecounts),'logical':logical,'registeredWitnesses':actual,'firstAlternateWitnesses':alternates,'negativeChecks':negative,'openShippingChecks':openchecks,'shippingBoundaries':shipping_boundaries,'scans':scans,'scanTotals':dict(totals),'chain':{'stages':stages,'representedHistories':sum(x['histories'] for x in states),'finalStates':[{'histories':x['histories'],'ledger':x['ledger'],'purchaseCost':x['spent'],'purchases':dict(x['buys']),'sample':x['sample']} for x in states]},'unroutedCounterexamples':audit,'mixedIndependentChecks':mixed}
evidencepath=ROOT/'docs/验证/词值v02与互斥分支证据_2026-10-09.json'
evidencepath.write_text(json.dumps(evidence,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

lines=['# 词值v02与独立互斥分支验算 · 2026-10-09','',
'用户要求尽量少拒绝，主轴达标一般即可发货。首单＋普通十单统一只检查主轴≥0.8，取消额外时间、睡眠上限与禁用项；合法配方及词卡／材料可用性仍是正常前置。N06sleep≤1.0建议撤回。','',
'N03–N09剩余35支全部展开；现共普通N01–N10五十支＋埃利亚斯首单八篇，61个候选词位。候选不等于批准或运行接入；定稿正文、剪词标记、scripts与内容版本未改。',
'', '使用Lua 5.4与现行Potion.Calculate、Order.Evaluate、Economy.PlanSettlement。三表解析为候选；采购只是按用户授权的商店内容模型扣费，不调用尚未实现的Shop。未验正式来源实例Order.ResolveRecipe、事实／Narrative／评分／存档迁移。','',
f'- 61/61连续字面、段落、非加粗、不重叠、一主0～3副与显式profile通过；覆盖22种现有药效，未增新标签。',
f'- 注册58份基础锅（50普通＋8首单）全部字面可发货、稳定且命中预期；首单困主词另8份替代也通过。',
f'- 各单完整区间分区共{sum(x["cells"] for x in logical.values())}格、边界检查{sum(x["boundaries"] for x in logical.values())}点通过；不表示所有属性的叙事兼容已获批准。',
f'- {len(openchecks)}个开放发货检查通过：慢起效、较长持续、睡意达线、1小时痛感主词、首单延长与N06sleep1.6均不拒绝；{len(negative)}个主轴不足检查仍不放行。',
f'- {len(shipping_boundaries)}个主轴下限附近的求值器夹具通过，恰好0.8放行，小于0.8不放行；夹具不是具体配方来源见证。',
f'- 另测{sum(x["extremeMixedSamples"] for x in logical.values())}个高值混合选择器样本，最高档无后果上限。高值样本只验后果选择器，不冒充实际合成；成品合法性仍由现行求值器验证。数值分区不等于所有极端组合的正文相容。',
f'- 有限有序辅词扫描{totals["total"]}锅：{totals["can_ship"]}可发货、{totals["cannot_ship"]}不满足门槛；具体候选池逐单附证据。','',
'## 全部普通订单的主轴与分支','',
'| 单 | 主轴 | 候选后果键（触发键概括；完整条件另表） | 评分候选 |','|---|---|---|---|']
for i in range(1,11):
    oid=f'N{i:02d}';r=rules[oid]
    if 'triggers' in r:
        keys=' → '.join('＋'.join(f'{c["effectId"]}≥{c["minWeight"]:g}' for c in x['allOf']) for x in r['triggers'])
        shape='3★×1／2★×2／1★×2'
    else:
        keys=' → '.join(f'{k}≥{r["thresholds"][k]:g}' for k in r['designOrder']);shape='3★×2／2★×1／1★×2' if oid=='N01' else '3★×1／2★×2／1★×2'
    axis=next(iter(r['requirement']['tags']))
    lines.append(f'| {oid} | {axis}≥0.8 | {keys} → 兜底 | {shape} |')
lines+=['','N02更正：warmth在现行定义里仅是身体温暖，撤回上轮“过强温暖＝照料冲动”的解释。忙照料改过强快乐happy≥1.8，高兴＋笑着得2.0，不再需要用哭来强化温暖；普通身体温暖不进入该分流。','',
'## 独立匹配与排列不变检查','',f'检查完整条件的{sum(x["branchPairsChecked"] for x in logical.values())}对分支，分区代表格零交集；{sum(x["orderPermutationChecks"] for x in logical.values())}次循环换位与逆序检查结果相同。全196格、所有阈值邻点及高值样本均恰好一条。没有在判断时追加隐含排除条件。','', '[完整58条条件](../文案/分支条件表_v02.md)及机器证据exclusiveBranches为本版本唯一条件来源；旧触发键简写不是独立达成条件。','', '## 58份完整配方实算','','普通注册锅均旧锅、夜露＋海盐，稳定性0；首单用海盐，碎梦两篇另加灰烬草，稳定性1。N08强镇静换主词，不升级、不强化。','',
'| 单／目标 | 主词 | 辅词 | 关键成品属性 | 起效／持续 | 稳定性 |','|---|---|---|---|---|---|']
for x in actual:
    keys=set(breakpoints(x['orderId']))|set(rules[x['orderId']]['requirement']['tags'])
    weights='、'.join(f'{k} {x["effects"].get(k,0):.6g}' for k in sorted(keys))
    lines.append(f'| {x["orderId"]} {x["name"]} | {x["main"]} | {"＋".join(x["aux"]) or "无"} | {weights} | {x["onset"]:g}／{x["duration"]:g} | {x["stability"]:g} |')
lines+=['','## 实际混合配方的唯一命中','', '| 单 | 主词/辅词 | 独立完整条件命中 | 成品属性 |', '|---|---|---|---|',*[f'| {x["orderId"]} | {x["main"]} / {"＋".join(x["aux"])} | {x["branch"]}（1条） | '+ '、'.join(f'{k}={v:g}' for k,v in x['effects'].items())+' |' for x in mixed],'','N06该配方的数值归属唯一；2026-10-09用户确认三处正文小修已落实，正文不再断言腕子没闹/不疼，且提前交代睡意。其余强混合药效与时程相容仍未全量审定；N08例使用两份灰烬草，稳定性警告不等于拒绝。','', '## 分区、边界与扫描口径','',
'| 单 | 区间格数 | 边界点 | 注册锅数 | 局部扫描锅数 | 可发货 |','|---|---|---|---|---|---|']
for x in ordered:
    oid=x['orderId'];l=logical[oid];sc=scans[oid]['scan']
    lines.append(f'| {oid} | {l["cells"]} | {l["boundaries"]} | {len(x["recipes"])} | {sc["total"]} | {sc["can_ship"]} |')
lines+=['','数学范围为非负有限药效值。每个键在阈值两侧分段，最后一档无上限；多键分段的笛卡尔积直接独立判断已存储的完整条件，所有分支逐条匹配；零命中或多命中即失败。逐对交集检查与循环换位/逆序检查均通过，不按首项选择。无需枚举无限多个数值；没有参与本单分流的属性仍按当前主导键或兜底归属，明显正文矛盾列为后果补充需求，不作为拒绝项。','',
'扫描固定每单首份注册锅的主词，辅助池为本信全部候选、注册所需前信及早先遗忘／睡眠／信任／生气审计卡，去掉主词；0～2辅助有序排列、四原料0～2份允许重复。池不是某个历史一定还能拿到的全部卡，未扫描全部主词或全正式词库。N08固定放松主词扫描未必达高镇静；换主词注册见证独立证明该支可达。','',
'## 商店补货与跨单一次性账','',
'用户已授权按商店补料。价格沿当前配置，货架按既有内容候选每种每天6份，本轮每一步独立补货窗口；没有冻结剧情日数。只缺多少买多少，先检查本单确认前金币与库存，再消费，最后由现行Economy.PlanSettlement入账。前单消费不返卡，不买词卡。',
'', '候选投放：E01→N01→…→N10，每封最终表中的词各一张，首次都已正式标记并剪下的假设。每单只确认一份注册锅；情节后续不授卡。来源假设仍待正式剪词接入验证。',
'', '将已不参与任何后续注册锅的词卡从状态比较键中剔除，其余未来会用的卡、材料、现金与采购都保留；资源相同的状态合并并累加历史数量。此方法覆盖注册路线集合，不能覆盖任意玩家配方或未来剧情状态前置。','',
'| 完成至 | 表示的基础分支历史 | 压缩资源状态 | 确认后最低现金 | 累计最高采购费 |','|---|---|---|---|---|']
for x in stages:lines.append(f'| {x["orderId"]} | {x["histories"]:,} | {x["compressedStates"]} | {x["minCurrency"]} | {x["maxSpent"]} |')
lines+=['', '最终覆盖8×5^10＝78,125,000条注册分支历史的卡资源投影，全部无缺卡、无负材料与资金。首三单使用当前各80奖励，其后八单奖励保守置0；盐补8份、夜露补7份，总124，最终最低现金146。初始材料没有重复扣钱，未买升级或特殊物品。',
'', '重要留存：首信神志不清与N01新增漂亮话供N03；N01骂骂咧咧供N04；N01客套话供N05；首信恐惧和困供N06；N03比较词供N07；首信帮忙和N09第二怀疑词旁证供N10。这些在注册此前锅中不被提前消费，反例试验未使用未收到的未来词。',
'', '商店解决原料缺口；非注册配方仍可能用掉后续需要的词，不能用本证明宣称任意组合都能保留所有后果。若词位不采用、发卡时机改变、漏信或收费改价，需重算。该账没有冻结后八单奖励，更没有验证实际Shop界面或程序。','',
'## 必须保留的设计待审项','',
'- N06保留sleep≥0.6的无上限分流，sleep1.6仍可发货；故事将困倦与休息后入睡关联，不假称独立延迟接口。用户确认的三处通用小修已落实，其余强混合药效与时程细节仍须审，优先补后果，不拒绝。',
'- 本版试用已展示的删副值、7处换字面与盾牌换前信漂亮话，61位总数不变；N01 9位、N03 4位。关联语义按审定建议试用，不能把数值互斥当作全部混合正文相容。',
'- N03茫然、N04愤怒、N05怀疑、N06恐惧／睡眠、N07嫉妒的“本信＋先前”冗余仍不齐；本轮注册基础锅已有先前可用来源，本次已接受明确来源例外；任意用卡历史仍不保证全部后果可达。',
'- N01两条三星、首单五条三星保留原候选；其它普通按一三星、两二星、两一星。新事实ID只是候选，正式接入要保留已有事实契约或明确映射，不自动改存档含义。',
'- 强遗忘、生气、信任、梦及已取消的时程拦截产生的更多组合需补叙事承接；优先合并已有后果或另提后续候选，不能靠新增禁用／上限填补。下面是当前有明确数值归属但仍需语义审核的例子。','',
'| 单 | 未参与分流的强属性 | 辅词例 | 原料例 | 成品权重 | 当前候选归属 |','|---|---|---|---|---|---|']
for x in audit:lines.append(f'| {x["orderId"]} | {x["effect"]} | {"＋".join(x["aux"]) or "无"} | {"＋".join(x["ingredients"]) or "无"} | {x["weight"]:.6g} | {x["branch"]} |')
lines+=['','## 可复算证据','',
'- [互斥防退化检查](check_exclusive_branch_guards.py)：故意删除排除条件会检测两条命中，故意制造空白会检测零条命中；不以首条或兜底掩盖。',
'- [机器证据](词值v02与互斥分支证据_2026-10-09.json)：逐锅权重、开放发货检查、扫描池、边界计数、资金阶段账与三表哈希。',
'- [验证工具](check_numeric_candidates_v02.py)：从三表重新解析，依赖Lua运行桥lupa；仅写报告／证据，不修改runtime。',
'- [条件表](../文案/分支条件表_v02.md)、[词值表](../文案/词条数值表_v02.md)、[供给表](../文案/供给验算表_v02.md)是候选来源。','']
report=ROOT/'docs/验证/词值v02与互斥分支验算_2026-10-09.md';report.write_text('\n'.join(lines),encoding='utf-8')
# Replace the current N02 report so its latest version no longer presents physical warmth as an emotional effect.
n02=['# N02 开放发货验算 · 2026-10-09','','只要求主轴happy≥0.8，额外时间与睡眠条件为空；怀疑→害怕＋难过→害怕→happy≥1.8→吃成了。warmth只指身体暖感，不参与照料分流。第五本信词为“笑着”，不改定稿正文。','',
'五份本信旧锅基础配方均夜露＋海盐、稳定性0、起效1小时、持续2小时；高兴＋笑着happy=2.0达到忙照料档。高兴＋怕＋哭fear=0.6、sadness=1.06；单独难过不自动失败。','',
f'候选区间{logical["N02"]["cells"]}格与{logical["N02"]["boundaries"]}个阈值边界通过。局部有序扫描{scans["N02"]["scan"]["total"]}锅，{scans["N02"]["scan"]["can_ship"]}可发货；有限池不等于实际历史库存。','',
'首单八篇×N01五支×N02五支的200条基础资源历史按修订后配方通过，无重用卡；随后按用户授权商店补料。完整58锅与最终11单保守采购账见[全批报告](词值v02与互斥分支验算_2026-10-09.md)。','',
'全部为文档候选，星级、语义、正式剪词与未分流强属性兼容未冻结；未测试Order.ResolveRecipe、正式事实、Narrative或评分接入。难过前信主词仍缺；不从后续正文剪词。','']
(ROOT/'docs/验证/N02_v02互斥验算_2026-10-09.md').write_text('\n'.join(n02),encoding='utf-8')
print(json.dumps({'positions':len(words),'ordinaryBranches':50,'registeredWitnesses':len(actual),'logicalCells':sum(x['cells'] for x in logical.values()),'boundaries':sum(x['boundaries'] for x in logical.values()),'scanTotals':dict(totals),'chainHistories':sum(x['histories'] for x in states),'finalCurrency':min(x['ledger']['currency'] for x in states),'purchaseCost':max(x['spent'] for x in states)},ensure_ascii=False,indent=2))
