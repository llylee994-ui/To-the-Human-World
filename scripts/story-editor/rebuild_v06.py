"""Build the approved v06 candidate; --apply uses revision-checked Store save.

This is a one-time migration, not the source of later editor edits. Never rerun
--apply after authors have continued editing the migrated graph.
"""
import argparse
import copy
import json
import re
from pathlib import Path
from store import Store, validate

ROOT = Path(__file__).resolve().parents[2]
GRAPH = ROOT / 'docs/文案/主线/主线故事图_v01.json'
DOC = ROOT / 'docs/文案/主线/主线唯一抓凶路线与提前结局重构_v06.md'
AUTHOR = '作者字段用于核对，不展示给玩家。玩家只读当时抵达的来信、附件和回信；不展示正确性、未来出口、星级配方或必胜序列。未选瓶永久丢弃，不寄来被丢弃愿望的回信。'


def rows(text):
    return [[c.strip() for c in line.strip().strip('|').split('|')]
            for line in text.splitlines() if line.startswith('|')]


def build(old, text):
    p = {k: copy.deepcopy(v) for k, v in old.items() if k not in ('nodes', 'edges')}
    p.update(title='寄往人间 · 唯一抓凶路线 v06', timelineMode='events', nodes=[], edges=[],
             notes='2026-10-11 同步用户复核修订v06。10场二选一、72条订单后续、4份固定结局草稿。事件层用于布局，非固定轮次或游戏日。普通队列、票期与身份运行代码尚未接入。')
    previous = {n['id']: n for n in old['nodes']}
    p['templates']=[t for t in p['templates'] if t['id']!='restitution']
    for t in p['templates']:
        if t['id']=='witness':t['summary']='已知原纸与实际亲见→本轮接待机会及人物顾虑→两份互斥愿望→三档生活后果，共用出口。未选作证与补问不另换来源补做。'
        if t['id']=='identity':t['summary']='案件结果一次保存→连续完成全部必需普通订单并确认→按既有资格判定唯一身份。旅行票有效窗口内主动离场为特殊出口。'
    by = {}

    def node(code, kind, title, rank, **fields):
        n = dict(id=code, parentId='root' if code != 'root' else None, kind=kind,
                 title=title, round=rank, step=0, templateId='', context='', summary='',
                 options='', conditions='', effects='', notes=AUTHOR, status='讨论草案',
                 dx=0, dy=0, collapsed=False, routeCode=code)
        n.update(fields)
        p['nodes'].append(n); by[code] = n
        return n

    def edge(source, target, label, condition='', wish=None):
        e = dict(id=f'v06_edge_{len(p["edges"])+1:03}', **{'from': source, 'to': target},
                 label=label, condition=condition, kind='next')
        if wish: e['wish'] = wish
        p['edges'].append(e)

    node('root', 'root', '海边的魔药铺', 0, templateId='opening',
         summary='前期八场依次认识人物，随后每场两瓶只实现一份，另一份丢回海里。选瓶决定调查方向，星级改变当次满意程度与生活后果。剧情结果到达即揭晓，随后连续完成剩余普通订单，再按资格揭晓身份。',
         options='主线有即时事件时与普通订单交替；等船可继续普通订单。',
         effects='案件结果只保存一份。低星后果保留，不因固定结局而抹除。',
         notes=AUTHOR+' 回溯恢复完整快照，不带回另一条路线的收入、星级或资料。')
    early = {r[0]: r for r in rows(text) if re.fullmatch(r'M0[1-8]', r[0])}
    assert len(early) == 8
    for i in range(1, 9):
        code=f'M{i:02}'; row=early[code]; ident=f'm{i:02}'
        title = row[1].split('：')[0]
        n=node(ident,'main',title,i,routeCode=code,
               templateId=previous[ident].get('templateId','opening'),
               summary=row[1]+'。\n'+row[3], context=row[3], effects=row[3],
               options=previous[ident].get('options',''),
               notes=AUTHOR+' 公事纸件先说明真实来源，不依赖本瓶星级生成。')
        following=f'm{i+1:02}' if i < 8 else 'C01'
        if i in (2,3,4,5):
            matches=re.findall(r'([321])星：(.*?)(?=；[321]星：|$)',row[2])
            assert len(matches)==3,code
            for star,local in matches:
                rid=f'{ident}_r{star}'
                node(rid,'result',f'{title} · {star}星',i,step=1,stars=int(star),
                     routeCode=code,summary=local.rstrip('。')+'。', effects=row[3],
                     conditions=f'{code} 单愿望 {star}星；具体词条与阈值另定。')
                edge(ident,rid,f'{star}星 · 当次结果',f'{star}星')
                edge(rid,following,'共同推进事实保留，进入下一场')
        else:
            edge(ident,following,'信息抵达，依次推进')
    edge('root','m01','第一场主线信息')

    adj={r[0]:r[1:] for r in rows(text) if re.fullmatch(r'[CF]0[1-6]',r[0]) and len(r)==3
         and all(re.fullmatch(r'[CF]0\d|E_[A-Z]+',c) for c in r[1:])}
    assert len(adj)==10
    sections={m[1]:(m[2],m[3].strip()) for m in re.finditer(
        r'^### ([CF]0\d)｜([^\n]+)\n(.*?)(?=^### |^## |\Z)',text,re.M|re.S)}
    opportunities={r[0]:r[1:] for r in rows(text) if re.fullmatch(r'C0[1-6]',r[0]) and len(r)==3 and r[1] not in adj}
    # Select the later §7.1 rows, whose cells contain prose rather than IDs.
    opportunities={k:v for k,v in opportunities.items() if not re.fullmatch(r'[CEF]_[A-Z]+|[CF]0\d',v[0])}
    ranks=dict(C01=9,C02=10,C03=11,C04=12,C05=13,C06=14,F01=13,F02=14,F03=12,F04=14)
    for code,(title,section) in sections.items():
        bottles=[r for r in rows(section) if len(r)==5 and re.match(r'[AB] ',r[0])]
        assert len(bottles)==2,code
        before=section.split('| 瓶子')[0].strip()
        after=section[section.rfind('|')+1:].strip()
        chance,missing=opportunities.get(code,('本场既有安排与办理范围见梗概。',''))
        unselected={}
        for j,r in enumerate(bottles):
            wish=r[0][0]; person=r[0][2:].split('：')[0]
            marker='未选'+person+'：'
            # §7.1 names the boy as 少年, unlike the bottle's 托马斯.
            if code=='C02' and wish=='A':marker='未选少年：'
            if marker in missing:
                gap=missing.split(marker,1)[1].split('未选',1)[0].strip()
            else:
                other=bottles[1-j]
                gap='本次愿望未实现，不由常规公事代为完成。选择另一瓶后的共用事实：'+other[4]
            unselected[wish]=gap
        n=node(code,'choice',title,ranks[code],summary=before,
               context=before+'\n选前机会：'+chance,
               options='\n'.join(r[0][0]+' · '+r[0][2:] for r in bottles),
               effects='所选瓶的三档共用出口；已收材料和隐私、关系损失分别保留。',
               unselected='\n'.join(f'{w} 未获帮助：{unselected[w]}' for w in ('A','B')),
               wishAId=code+'_wish_A',wishBId=code+'_wish_B',
               notes=AUTHOR+'\n'+after)
        if code.startswith('C') and code!='C01':
            prior=sections[f'C{int(code[1:])-1:02}'][1]
            bridge=re.search(r'进入'+code+r'的原因：(.*?)(?=\n\n|\Z)',prior,re.S)
            if bridge:n['context']='承接来源：'+bridge[1]+'\n'+n['context']
        if code=='C05':n['context']+='\n船期：已公告封存交接日末班航次及停止登船时刻，此刻未离港。'
        if code=='C06':n['context']+='\n发生在C05已公告的封存交接日，实际问询、值守或登船在本场办理。'
        if code=='F04':n['context']+='\n从F03进入用此前较早常规航次；从C05进入用此前封存日末班船。层位不代表统一日期。'
        for j,r in enumerate(bottles):
            wish=r[0][0]; other='B' if wish=='A' else 'A'
            for idx,star in enumerate((3,2,1),1):
                rid=f'{code}_{wish}_{star}'
                node(rid,'result',f'{code} · {r[0][2:].split("：")[0]} · {star}星',ranks[code],
                     step=1,stars=star,routeCode=code,summary=r[idx],
                     effects=r[4], context='已选愿望：'+r[0][2:],
                     conditions=f'实现{wish} / 丢弃{other}；{star}星。具体属性阈值后定；三档共用出口。',
                     unselected=f'丢弃{other}：'+unselected[other],
                     notes=AUTHOR+'\n'+after)
                edge(code,rid,f'{star}星 · '+r[0][2:],f'实现{wish} / 丢弃{other}；{star}星',wish)
                edge(rid,adj[code][j],'三档共用出口 → '+adj[code][j])

    for match in re.finditer(r'^### (E_[A-Z]+)｜([^\n]+)\n(.*?)(?=^### |^## |\Z)',text,re.M|re.S):
        code,title,body=match.groups()
        body=body.split('作者边界：')[0].strip()
        node(code,'ending',title,15,summary=body,status='固定正文草稿',
             conditions='仅在该路线的实际结果成立、通知抵达后播放；到达即揭晓，无固定末轮门槛。',
             effects='保存一次案件结果；停止主线投放，保留此前已发生事实。',
             notes=AUTHOR+' 四份共用文本待用户定稿，不按星级拼装。')
        edge(code,'ordinary_tail','案件结果保存 → 连续普通订单')
    node('ordinary_tail','merge','剩余普通订单',16,
         summary='保留唯一普通订单游标，从尚未完成的位置按既有顺序连续推进。每个经营日正常完成一份普通订单及配药、后续、评分和确认；无主线单双日等待，不重播、不漏单、不新增尾声订单。全部必需普通订单完成并确认后才判身份。',
         conditions='案件结果已经形成并播放；游标及当前未确认订单保持。',
         effects='案件结果冻结；普通星级、库存和家居仍照常记录。',
         notes='此节点表示队列流程，不把剩余订单一次挤到同一天。身份优先级：学徒 → 埃德蒙 → 无名者 → 未抵达者；旅行票主动离场保留为特殊提前出口。')
    for ident in ('apprentice','edmund','nameless','unreached','traveler'):
        n=copy.deepcopy(previous[ident]);n.update(round=18 if ident!='traveler' else 17,step=0,routeCode=ident);n.pop('day',None)
        if ident=='traveler':n['dx']=600
        p['nodes'].append(n);by[ident]=n
        if ident!='traveler':edge('ordinary_tail',ident,'唯一身份揭晓','全部必需普通订单完成并确认；'+n['conditions'])
    edge('root','traveler','经营期间有效票期内可主动离场','实际确认购买并启程；仅呈现已知事实，已有案件结果保留，未形成结果不提前播放未来通知。')
    p['stageLabels']={str(i):f'共同前段 · M{i:02}' for i in range(1,9)}
    p['stageLabels'].update({'0':'故事开端',**{str(i):'调查分路 · 按箭头到达（非固定日期）' for i in range(9,15)},
                            '15':'剧情结果 · 到达即揭晓','16':'剧情之后 · 连续普通订单','17':'特殊出口 · 主动启程','18':'普通订单完成后 · 身份揭晓'})
    validate(p)
    assert len(p['nodes'])==101 and sum(n['kind']=='result' for n in p['nodes'])==72
    return p


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply',action='store_true')
    args=parser.parse_args()
    store=Store(GRAPH);state=store.read()
    if state['project'].get('timelineMode')=='events':
        raise SystemExit('Current graph already migrated. Continue editing it; do not rebuild.')
    candidate=build(state['project'],DOC.read_text(encoding='utf-8'))
    path=ROOT/'.tmp/story-v06-candidate.json';path.parent.mkdir(exist_ok=True)
    path.write_text(json.dumps(candidate,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'Candidate: {len(candidate["nodes"])} nodes / {len(candidate["edges"])} edges')
    if args.apply:
        store.save(candidate,state['revision'])
        print('Saved through Store; previous graph automatically backed up.')


if __name__=='__main__':main()
