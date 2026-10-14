"""Compile approved Markdown tables into static Lua content. No engine dependency.

Run from project root. --check checks reproducibility without writing files.
The compiler emits every disjoint comparison cell; runtime still evaluates all rules.
"""
from pathlib import Path
from itertools import product
from collections import Counter
import argparse, hashlib, json, re

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / 'docs/文案'
ORDER_IDS = ['E01'] + [f'N{i:02d}' for i in range(1, 11)]
NAMES = ['埃利亚斯·沃德', '卢卡', '诺拉', '艾莉', '奥托', '塞西莉亚', '莱昂', '贝娅', '马丁', '阿涅丝', '雅各布']
NPC_IDS = ['npc_passerby_a', 'npc_luca', 'npc_nora', 'npc_ellie', 'npc_otto', 'npc_cecilia', 'npc_leon', 'npc_bea', 'npc_martin', 'npc_agnes', 'npc_jacob']
COPY_ORDER = {
    'E01': ['rested', 'mother_dream', 'song_faded', 'mother_unclear', 'fish_choir', 'walking_crates', 'fragmented_dream', 'fragmented_song_faded'],
    'N01': ['departure_agreed', 'departure_conflict', 'stayed_for_promise', 'missed_place', 'started_learning'],
    'N02': ['good', 'swallowed', 'escaped', 'care', 'doubted'],
    'N03': ['good', 'hide', 'freeze', 'salt', 'protect'],
    'N04': ['good', 'envy', 'tear', 'play', 'past'],
    'N05': ['good', 'count', 'sad', 'talk', 'fork'],
    'N06': ['good', 'pain', 'stop', 'sleep', 'split'],
    'N07': ['good', 'soft', 'acid', 'discount', 'bucket'],
    'N08': ['good', 'slow', 'wait', 'child', 'military'],
    'N09': ['good', 'doubt', 'hedge', 'grace', 'grain'],
    'N10': ['3', '2a', '1a', '2b', '1b'],
}

def blocks(path):
    return [json.loads(x) for x in re.findall(r'```json\n(.*?)\n```', path.read_text(encoding='utf-8'), re.S)]

def section(text, heading):
    return text.split(heading, 1)[1].split('\n## ', 1)[0].strip()

def clean(text):
    return text.replace('**', '').strip()

def load_sources():
    paths = [DOCS / x for x in ['词条数值表_v02.md', '分支条件表_v02.md', '供给验算表_v02.md']]
    words, sources = {}, {}
    for line in paths[0].read_text(encoding='utf-8').splitlines():
        c = [x.strip() for x in line.split('|')[1:-1]]
        if len(c) != 9 or not re.fullmatch(r'(?:N\d\d|E01)-[A-Z]\d', c[0]):
            continue
        cid, link, paragraph, text, quote, wid, category, vector, profile = c
        path = DOCS / re.search(r'\]\((.*?)\)', link).group(1)
        raw = section(path.read_text(encoding='utf-8'), '## 首封来信正文' if cid.startswith('E01') else '## 完整来信')
        ps = re.split(r'\n\s*\n', raw)
        p = ps[int(paragraph)-1]
        assert p.count(quote) == 1 and quote.count(text) == 1, cid
        start = p.index(quote) + quote.index(text)
        assert not any(start < m.end() and start + len(text) > m.start() for m in re.finditer(r'\*\*.*?\*\*', p)), cid
        words[cid] = dict(id=wid.strip('`'), displayText=text, category=category, effects=json.loads(vector.strip('`')), reusable=False, attributeProfileId=profile)
        sources[cid] = dict(path=path, raw=raw, paragraph=int(paragraph)-1, start=start, end=start+len(text))
    assert len(words) == 61
    rules = {x.get('orderId', 'N10'): x for x in blocks(paths[1])}
    registry = next(x for x in blocks(paths[2]) if 'orders' in x)
    return words, sources, rules, registry, paths

def matches(row, e):
    def term(t):
        v = e.get(t['effectId'], 0)
        return v >= t['minWeight'] if 'minWeight' in t else v < t['maxWeightExclusive']
    return all(map(term, row['allOf'])) and all(not all(map(term, g)) for g in row['noneOf'])

def lua(value, level=0):
    pad = '    ' * level
    if isinstance(value, str):
        if '\n' in value:
            assert ']=]' not in value
            return '[=[' + value + ']=]'
        return json.dumps(value, ensure_ascii=False)
    if value is True: return 'true'
    if value is False: return 'false'
    if isinstance(value, (int, float)): return repr(value)
    if not value: return '{}'
    if isinstance(value, list):
        rows = [lua(v, level+1) for v in value]
    else:
        rows = [('[' + lua(k) + ']') + ' = ' + lua(value[k], level+1) for k in sorted(value)]
    return '{\n' + '\n'.join(pad + '    ' + s + ',' for s in rows) + '\n' + pad + '}'

def compile_pack():
    words, sources, rules, registry, paths = load_sources()
    # 读取实际 Lua 配置，不用正则复制另一个版本/订单顺序来源。
    import sys
    sys.path.insert(0, str(ROOT / '.tmp/b1-python'))
    from lupa.lua54 import LuaRuntime
    runtime = LuaRuntime(unpack_returned_tuples=True)
    runtime.execute('package.path = ... .. "/scripts/?.lua;" .. package.path', ROOT.as_posix())
    release = runtime.eval('require')("data.release")
    if isinstance(release, tuple):
        release = release[0]
    order_ids = [release.requiredOrderIds[i] for i in range(1, len(release.requiredOrderIds) + 1)]
    expected_ids = ['letter_pa_01'] + ['letter_' + oid.lower() for oid in ORDER_IDS[1:]]
    assert order_ids == expected_ids, '首发必需订单顺序与正文包不一致'
    title_path = DOCS / '故事标题表_v01.json'
    titles = json.loads(title_path.read_text(encoding='utf-8'))
    pack = {k: [] for k in ['words', 'letters', 'npcs', 'directRules', 'factExclusionGroups', 'fragments', 'followupTemplates', 'orderRatings', 'recipes']}
    pack['words'] = list(words.values())
    inputs = set(paths) | {title_path, ROOT / 'scripts/data/release.lua', ROOT / 'scripts/data/furniture.lua',
                          ROOT / 'scripts/data/ingredients.lua', ROOT / 'scripts/data/synthesis.lua', ROOT / 'scripts/data/stage1.lua'}
    cases = []
    for index, oid in enumerate(ORDER_IDS):
        rows = rules[oid]['exclusiveBranches']
        letter_id = 'letter_pa_01' if oid == 'E01' else 'letter_' + oid.lower()
        npc_id = NPC_IDS[index]
        tpl = 'tpl_pa_01' if oid == 'E01' else 'tpl_' + oid.lower()
        rule_set = 'rules_pa_01' if oid == 'E01' else 'rules_' + oid.lower()
        rating_set = 'rating_pa_01' if oid == 'E01' else 'rating_' + oid.lower()
        own = [(c, s) for c, s in sources.items() if c[:3] == oid]
        source_path = own[0][1]['path']; inputs.add(source_path)
        raw = own[0][1]['raw']
        paragraphs = re.split(r'\n\s*\n', raw)
        positions = sorted(own, key=lambda x: (x[1]['paragraph'], x[1]['start']))
        for cid, loc in reversed(positions):
            p = paragraphs[loc['paragraph']]
            paragraphs[loc['paragraph']] = p[:loc['start']] + '{{' + words[cid]['displayText'] + '}}' + p[loc['end']:]
        marked = clean('\n\n'.join(paragraphs))
        address = raw.splitlines()[-1]
        title = titles['ordinaryLetters'][oid]
        description = rules[oid]['requirement']['desc'].replace('（候选）', '').replace('（候选要求）', '').replace(oid + ' ', '')
        requirement = {**rules[oid]['requirement'], 'desc': description}
        assert requirement['conditions'] == [] and requirement['forbiddenEffects'] == []
        day = index + 1
        reward = registry['shop']['rewardByOrder'].get(oid, registry['shop']['laterRewardForConservativeCheck'])
        assert reward == release.orderReward, (oid, '报酬来源与首发配置不一致')
        pack['letters'].extend([
            dict(id=letter_id, senderId=npc_id, kind='order', cuttable=True, bottleType='normal', title=title,
                 selfIntro='来信人：'+NAMES[index], body=marked, address=address, attachments=[],
                 cutWordIds=[words[c]['id'] for c, _ in positions], requirement=requirement, reward={'currency': reward},
                 directRuleSetId=rule_set, followupTemplateId=tpl, ratingSetId=rating_set, appearCondition={'dayMin': day}),
            dict(id=letter_id+'_followup', senderId=npc_id, kind='direct_followup', cuttable=False, bottleType='normal',
                 title=NAMES[index]+'的回信', address=address, attachments=[], followupTemplateId=tpl)])
        branch_ids = [x['branch'] for x in rows]
        pack['npcs'].append(dict(id=npc_id, name=NAMES[index], occupation=clean(raw.split('\n\n')[0]),
                                 family='', background='', address=address, inCase=False, notes='词值v02试用接入',
                                 initialState={'lastResult': 'none'}, initialStateSchema={'lastResult': {'type': 'enum', 'values': ['none']+branch_ids}}))
        # One row per comparison cell: strict upper interval excludes >=cut. No first-match selector.
        cuts = {}
        for r in rows:
            for t in r['allOf'] + [t for g in r['noneOf'] for t in g]:
                cuts.setdefault(t['effectId'], set()).add(t.get('minWeight', t.get('maxWeightExclusive')))
        cuts = {k: sorted(v) for k, v in sorted(cuts.items())}
        keys = list(cuts)
        for serial, values in enumerate(product(*[[0]+cuts[k] for k in keys]), 1):
            e = dict(zip(keys, values))
            matched = [r for r in rows if matches(r, e)]
            assert len(matched) == 1, (oid, e, matched)
            branch = matched[0]['branch']
            when = [dict(source='potion.effects', path=k, op='gte', value=v) for k, v in requirement['tags'].items()]
            unless = []
            for k, lower in zip(keys, values):
                if lower > 0: when.append(dict(source='potion.effects', path=k, op='gte', value=lower))
                uppers = [x for x in cuts[k] if x > lower]
                if uppers: unless.append(dict(source='potion.effects', path=k, op='gte', value=uppers[0]))
            pack['directRules'].append(dict(id=f'rule_v02_{oid.lower()}_{serial:03}', ruleSetId=rule_set, priority=0,
                 desc='独立互斥区间 → '+branch, when=when, unless=unless,
                 facts=[dict(id=branch, subjectId=npc_id, value=True, important=True)],
                 changes=[dict(path='world.npcs.'+npc_id+'.lastResult', op='set', value=branch)]))
        pack['factExclusionGroups'].append(dict(id='exclusive_v02_'+oid.lower(), factIds=branch_ids))
        if oid == 'E01':
            follow_path = DOCS/'普通订单/首单_埃利亚斯_后续定稿_v01.md'
        else:
            separate = list((DOCS/'普通订单').glob(oid+'_*后续定稿_v01.md'))
            follow_path = separate[0] if separate else source_path
        inputs.add(follow_path)
        follow_text = follow_path.read_text(encoding='utf-8')
        if oid in ['N03','N04','N05','N06','N07']:
            follow_text = section(follow_text, '## 五支后续（原有三支＋新增两支）')
            sections = re.findall(r'^### (.*?)\n(.*?)(?=^### |\Z)', follow_text, re.M|re.S)
        else:
            follow_text = follow_text.split('\n## 作者区', 1)[0]
            sections = re.findall(r'^## (.*?)\n(.*?)(?=^## |\Z)', follow_text, re.M|re.S)
        assert len(sections) == len(rows), (oid, len(sections))
        fragments = []
        for suffix, (heading, text) in zip(COPY_ORDER[oid], sections):
            prefix = oid.lower() + ('_result_' if oid in ['E01','N01','N10'] else '_candidate_')
            branch = prefix + suffix
            row = next(x for x in rows if x['branch'] == branch)
            fid = 'frag_'+branch
            fragments.append(fid)
            pack['fragments'].append(dict(id=fid, templateId=tpl, kind='key', priority=0, requiresFacts=[branch],
                excludesFacts=[], coversFacts=[branch], overrides=[], text=clean(text)))
            # Story headings are editable titles; evaluation wording is independent.
            feedback = titles['ratingFeedback'].get('rating_'+branch, heading.split('｜',1)[-1])
            pack['orderRatings'].append(dict(id='rating_'+branch, ratingSetId=rating_set, priority=0, stars=row['stars'],
                requiresFacts=[branch], excludesFacts=[], feedback=feedback))
        pack['followupTemplates'].append(dict(id=tpl, letterId=letter_id+'_followup', opening='', closing='',
                 baseFragmentIds=[], fragmentIds=fragments, fallbackFragmentIds=[]))
        registration = next(x for x in registry['orders'] if x['orderId'] == oid)
        for serial, r in enumerate(registration['recipes'], 1):
            recipe = dict(equipmentId='kit_old_cauldron', mainWordId=words[r['main']]['id'], auxWordIds=[words[c]['id'] for c in r['aux']],
                          ingredients=[dict(ingredientId=k, quantity=v) for k,v in Counter(r['ingredients']).items()], specialItemIds=[])
            row = next(x for x in rows if x['branch'] == r['expectedBranch'])
            entry = dict(id=f'recipe_v02_{oid.lower()}_{serial}', letterId=letter_id, name=r['name'], recipe=recipe,
                         requiresFutureSources=False, expect={'canDeliver': True, 'facts': [r['expectedBranch']], 'stars': row['stars']})
            pack['recipes'].append(entry)
            cases.append(dict(**entry, sources=[{'positionId':c, 'wordId':words[c]['id'], 'letterId':'letter_pa_01' if c[:3]=='E01' else 'letter_'+c[:3].lower()} for c in [r['main']]+r['aux']]))
    # Git/Windows可切换CRLF；哈希使用统一LF的UTF-8正文，避免换行格式造成生成物过期。
    pack['sourceHashes'] = {str(p.relative_to(ROOT)).replace('\\','/'): hashlib.sha256(p.read_text(encoding='utf-8').encode('utf-8')).hexdigest() for p in sorted(inputs)}
    pack['sampleCases'] = make_samples(pack, rules, release.contentVersion)
    return pack, cases

def make_samples(pack, rules, content_version):
    # 生成首单结构验收数据，正式回归另读三表独立预期，不复用此计算。
    import sys
    sys.path.insert(0, str(ROOT/'.tmp/b1-python'))
    from lupa.lua54 import LuaRuntime
    runtime=LuaRuntime(unpack_returned_tuples=True)
    runtime.execute('package.path="scripts/?.lua;"..package.path')
    def require(n):
        x=runtime.eval('require')(n)
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
    stage=require('data.stage1')
    c=lt(dict(words=pack['words'],effects=py(require('data.effects')),synthesis=py(require('data.synthesis')),
              equipment=py(require('data.equipment')),ingredients=py(require('data.ingredients')),attributeProfiles=py(stage.attributeProfiles),stage1=py(stage),contentVersion=content_version))
    pmod=require('systems.Potion')
    byword={w['id']:w for w in pack['words']}
    equipment=py(c.equipment[1]);ingredients={v.id:py(v) for _,v in c.ingredients.items()}
    recipes=[x['recipe'] for x in pack['recipes'] if x['letterId']=='letter_pa_01']
    recipes += [dict(recipes[0],ingredients=[{'ingredientId':'ing_night_dew','quantity':1},{'ingredientId':'ing_sea_salt','quantity':1}]),
                dict(recipes[0],ingredients=[{'ingredientId':'ing_night_dew','quantity':2}])]
    result=[]
    for sid,recipe in zip(['A','B','C','D','E','F','G1','G2','G3','G4'],recipes):
        def ref(wid):return dict(tokenId='sample-'+wid,definition=byword[wid],source=dict(wordId=wid,sourceLetterInstanceId='sample-e01',sourceSpanId=wid,sourceNpcId='npc_passerby_a'))
        resolved=dict(orderId='sample',baselineId='sample',contentVersion=c.contentVersion,equipment=equipment,
                      main=ref(recipe['mainWordId']),aux=[ref(w) for w in recipe['auxWordIds']],
                      ingredients=[dict(x,definition=ingredients[x['ingredientId']]) for x in recipe['ingredients']],specialItems=[])
        calculated=pmod.Calculate(lt(resolved),c)
        assert calculated.ok,py(calculated.error)
        potion=calculated.value
        rows=[r for r in rules['E01']['exclusiveBranches'] if matches(r,py(potion.effects))]
        assert len(rows)==1
        row=rows[0];branch=row['branch']
        result.append(dict(id=sid,purpose='v02首单登记配方及不同原料验收',baselineId='S0',recipe=recipe,
            expect=dict(effects=py(potion.effects),tiers=py(potion.intensityByEffect),durationHours=potion.durationHours,onsetDelayHours=potion.onsetDelayHours,
                        stability=potion.stability,unstable=potion.unstable,sideEffects=py(potion.sideEffects),canShip=True,failures=[],
                        facts=[branch],followupFragments=['frag_'+branch],rating={'stars':row['stars'],'ruleId':'rating_'+branch})))
    return result

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    pack,cases=compile_pack()
    outputs={ROOT/'scripts/data/numeric_v02.lua': '-- 自动生成：scripts/debug/generate_numeric_v02.py；来源为已确认v02与定稿。\nreturn '+lua(pack)+'\n',
             ROOT/'scripts/debug/fixtures/NumericV02Cases.lua': '-- 登记配方与真实来源见证（测试数据，不给玩家赠卡）。\nreturn '+lua(cases)+'\n'}
    for p,text in outputs.items():
        if args.check:
            assert p.read_text(encoding='utf-8')==text, str(p)+' 已过期'
        else: p.write_text(text,encoding='utf-8',newline='\n')
    print(json.dumps({'words':len(pack['words']),'orders':len(pack['letters'])//2,'branches':len(pack['fragments']),'cells':len(pack['directRules']),'recipes':len(cases),'check':args.check},ensure_ascii=False))

if __name__ == '__main__': main()
