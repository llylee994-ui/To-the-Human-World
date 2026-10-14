"""Independently compare v02 Markdown expectations to real Lua rules and source cards.

Uses runtime StoryRules.Conditions, not the content compiler. Does not write game saves.
"""
from pathlib import Path
from itertools import product
import json, re, sys, copy

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.tmp/b1-python'))
from lupa.lua54 import LuaRuntime
runtime=LuaRuntime(unpack_returned_tuples=True)
runtime.execute('package.path="scripts/?.lua;"..package.path')
def require(name):
    x=runtime.eval('require')(name)
    return x[0] if isinstance(x,tuple) else x
def lt(v):
    if isinstance(v,dict):return runtime.table_from({k:lt(x) for k,x in v.items()})
    if isinstance(v,list):return runtime.table_from([lt(x) for x in v])
    return v
def py(v):
    if hasattr(v,'items'):
        keys=list(v.keys())
        if keys and set(keys)==set(range(1,len(keys)+1)):return [py(v[i]) for i in range(1,len(keys)+1)]
        return {k:py(x) for k,x in v.items()}
    return v
data=require('data.content')
assert data.Load()[0]
assert data.ValidateStage1()[0]
parser=require('systems.Letter').New(data)
docs=ROOT/'docs/文案'
rules=[json.loads(x) for x in re.findall(r'```json\n(.*?)\n```',(docs/'分支条件表_v02.md').read_text(encoding='utf-8'),re.S)]
registry=next(json.loads(x) for x in re.findall(r'```json\n(.*?)\n```',(docs/'供给验算表_v02.md').read_text(encoding='utf-8'),re.S) if '"orders"' in x)
compiled=py(data.directRules)
actual_matches=runtime.eval('''function(content, rules, effects)
    local R=require "systems.StoryRules"
    local source={potion={effects=effects},context={},world={npcs={}},facts={}}
    local matches={}
    for _,rule in ipairs(rules) do
        local all=R.Conditions(rule.when,source,content,"when")
        local _,any=R.Conditions(rule.unless,source,content,"unless",true)
        if all and not any then matches[#matches+1]=rule.facts[1].id end
    end
    return matches
end''')
def row_matches(row,e):
    def term(t):
        v=e.get(t['effectId'],0)
        return v>=t['minWeight'] if 'minWeight' in t else v<t['maxWeightExclusive']
    return all(term(t) for t in row['allOf']) and all(not all(term(t) for t in g) for g in row['noneOf'])
checks=0
counts={}
for spec in rules:
    oid=spec.get('orderId','N10')
    lid='letter_pa_01' if oid=='E01' else 'letter_'+oid.lower()
    letter=data.GetLetter(lid)
    selected=[r for r in compiled if r['ruleSetId']==letter.directRuleSetId]
    rows=spec['exclusiveBranches']
    cuts={}
    for row in rows:
        for t in row['allOf']+[t for g in row['noneOf'] for t in g]:
            cuts.setdefault(t['effectId'],set()).add(t.get('minWeight',t.get('maxWeightExclusive')))
    keys=sorted(cuts)
    perkey={k:sorted({spec['requirement']['tags'].get(k,0),1000000,*[t+d for t in cuts[k] for d in [-1e-9,0,1e-9] if t+d>=spec['requirement']['tags'].get(k,0)]}) for k in keys}
    branch_counts={}
    luaselected=lt(selected)
    for values in product(*[perkey[k] for k in keys]):
        e={**spec['requirement']['tags'],**dict(zip(keys,values))}
        expected=[r['branch'] for r in rows if row_matches(r,e)]
        actual=list(actual_matches(data,luaselected,lt(e)).values())
        assert len(expected)==1 and actual==expected,(oid,e,actual,expected)
        branch_counts[actual[0]]=branch_counts.get(actual[0],0)+1
        checks+=1
    # Reordering rules does not change factual result; intentionally duplicated cell is detectable.
    base=spec['requirement']['tags']
    assert list(actual_matches(data,lt(list(reversed(selected))),lt(base)).values())==list(actual_matches(data,luaselected,lt(base)).values())
    sample=next(r for r in selected if list(actual_matches(data,lt([r]),lt(base)).values()))
    overlap=selected+[dict(copy.deepcopy(sample),id='injected-overlap')]
    assert len(list(actual_matches(data,lt(overlap),lt(base)).values()))==2
    counts[oid]=dict(samples=sum(branch_counts.values()),branches=len(branch_counts))

# All61 rows verify actual letter positions/effects and unchanged prose, independent of compiler.
source_rows={}
for line in (docs/'词条数值表_v02.md').read_text(encoding='utf-8').splitlines():
    c=[s.strip() for s in line.split('|')[1:-1]]
    if len(c)!=9 or not re.fullmatch(r'(?:N\d\d|E01)-[A-Z]\d',c[0]):continue
    cid,link,para,text,quote,wid,category,vector,profile=c
    oid=cid[:3];lid='letter_pa_01' if oid=='E01' else 'letter_'+oid.lower()
    path=docs/re.search(r'\]\((.*?)\)',link).group(1)
    raw=path.read_text(encoding='utf-8').split('## 首封来信正文' if oid=='E01' else '## 完整来信',1)[1].split('\n## ',1)[0].strip()
    ps=re.split(r'\n\s*\n',raw)
    p=ps[int(para)-1]
    start=p.index(quote)+quote.index(text)
    source_rows.setdefault(lid,[]).append((int(para),start,wid.strip('`')))
    w=data.GetWord(wid.strip('`'))
    assert py(w.effects)==json.loads(vector.strip('`')) and w.attributeProfileId==profile and not w.reusable
    assert re.sub(r'\{\{(.*?)\}\}',r'\1',data.GetLetter(lid).body)==raw.replace('**',''),lid
for lid,rows in source_rows.items():
    parsed=parser.ParseDefinition(lid);assert parsed.ok,py(parsed.error)
    actual=[s.wordId for _,s in parsed.value.spans.items()]
    assert actual==[wid for _,_,wid in sorted(rows)],lid
# Branch/body association for sensitive copies (N06 corrections and N10 non-file-order cases).
n06=next(f for f in py(data.fragments) if f['id']=='frag_n06_candidate_sleep')['text']
assert '其实干活时我就有些犯困' in n06 and '腕子没有闹' not in n06
n10=next(f for f in py(data.fragments) if f['id']=='frag_n10_result_1a')['text']
assert '布' in n10
report={'status':'passed','ruleSamples':checks,'orders':counts,'realCutPositions':sum(map(len,source_rows.values())),
        'highestIntervals':'unbounded raw guard checks; runtime potion tiers retain existing maximum99',
        'scope':'numeric conditions and source mapping; not full mixed-effect prose/engine UI acceptance'}
out=ROOT/'docs/验证/词值v02_运行接入区间验算_2026-10-09.json'
out.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
