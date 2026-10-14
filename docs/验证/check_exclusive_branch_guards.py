"""Regression checks for detecting overlapping/incomplete candidate conditions.

Loads only pure matching functions, not the full synthesis/report run.
Run: python -X utf8 docs/验证/check_exclusive_branch_guards.py
"""
from pathlib import Path
import ast,copy,json,re

ROOT=Path(__file__).resolve().parents[2]
text=(ROOT/'docs/文案/分支条件表_v02.md').read_text(encoding='utf-8')
rules={r['orderId']:r for r in [json.loads(x) for x in re.findall(r'```json\s*(.*?)\s*```',text,re.S)]}
known=set()
for line in (ROOT/'docs/文案/词条数值表_v02.md').read_text(encoding='utf-8').splitlines():
    c=[s.strip() for s in line.split('|')[1:-1]]
    if len(c)==9 and re.fullmatch(r'(?:N\d\d|E01)-[A-Z]\d',c[0]):known.update(json.loads(c[7].strip('`')))
tree=ast.parse((ROOT/'docs/验证/check_numeric_candidates_v02.py').read_text(encoding='utf-8'))
names={'term_matches','row_matches','predicates','matching_rows','select'}
module=ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in names],type_ignores=[])
ns={'rules':rules,'known':known}
exec(compile(ast.fix_missing_locations(module),'<pure-exclusive-functions>','exec'),ns)

e={'recall':1,'fear':.6,'anger':.6}
base=copy.deepcopy(rules['N10'])
assert ns['select']('N10',e)=='n10_result_2b'
assert ns['select']('N10',{**e,'fear':.6-1e-9})=='n10_result_2a'
assert ns['select']('N10',{**e,'fear':.6+1e-9})=='n10_result_2b'
results=['valid_mixed_one_match','threshold_below_exact_above']

# Removing the anger branch's exclusions must create TWO matches and fail.
row=next(x for x in rules['N10']['exclusiveBranches'] if x['branch']=='n10_result_2a')
row['noneOf']=[]
assert len(ns['matching_rows']('N10',e))==2
try:ns['select']('N10',e)
except AssertionError as ex:assert ex.args[0][0]=='coverage_or_overlap'
else:raise AssertionError('overlap was silently accepted')
results.append('intentional_overlap_rejected')

# An impossible fear branch leaves this mixed point uncovered. Fail, do not fall back.
rules['N10']=copy.deepcopy(base)
row=next(x for x in rules['N10']['exclusiveBranches'] if x['branch']=='n10_result_2b')
row['allOf'].append({'effectId':'fear','maxWeightExclusive':.6})
assert ns['matching_rows']('N10',e)==[]
try:ns['select']('N10',e)
except AssertionError as ex:assert ex.args[0][0]=='coverage_or_overlap'
else:raise AssertionError('uncovered point was silently accepted')
results.append('intentional_gap_rejected')

rules['N10']=copy.deepcopy(base)
rules['N10']['exclusiveBranches'].reverse()
assert ns['select']('N10',e)=='n10_result_2b'
results.append('reversed_branch_order_same_result')
print(json.dumps({'checks':len(results),'passed':results,'runtimeEdited':False},ensure_ascii=False))
