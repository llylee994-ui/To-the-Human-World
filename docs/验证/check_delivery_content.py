#!/usr/bin/env python3
"""Check T4-T6 manuscript contracts and actual Potion/Order arithmetic.

Requires Lupa Lua 5.4 (also accepts the project's existing .tmp/b1-python).
New letter sources are manuscript references, not received runtime inventory.
No WorldState/Narrative/Order.Rate, shop, UI or save transaction is simulated.
"""
from pathlib import Path
import itertools
import re
import subprocess
import sys
from urllib.parse import unquote

sys.dont_write_bytecode = True
from check_delivery_budget import Audit, ORDINARY, ROOT, RECIPES

sys.path.insert(0, str(ROOT / '.tmp/b1-python'))
from lupa.lua54 import LuaRuntime

model = Audit()
ordinary_file = ROOT / 'docs/文案/普通订单/普通订单正文包_N03-N22_v01.md'
ordinary_text = ordinary_file.read_text(encoding='utf-8')
packet_text = ordinary_text.split('## 记忆变化后的完整回信选择', 1)[0]
sections = re.split(r'(?m)^## N', packet_text)[1:]
assert len(sections) == 20
blocks = {int(block[:2]): block for block in sections}
conditions = {}
for number, block in blocks.items():
    body = block.split('### 完整来信', 1)[1].split('### 剪词', 1)[0]
    marks = re.findall(r'\{\{(.*?)\}\}', body)
    expected = tuple(model.words['word_' + word]['displayText'] for word in model.sources[f'N{number:02}'])
    assert tuple(marks) == expected and 3 <= len(marks) <= 4
    assert '人物、代笔、住址' in block and '地址：' in block
    rows = re.findall(r'\| `n\d+_result_(\d)` \| (.*?) \|', block)
    assert len(rows) == 3 and {int(star) for star, _ in rows} == {1, 2, 3}
    conditions[number] = {int(star): expression.split('（')[0].strip() for star, expression in rows}
    for star in (1, 2, 3):
        assert f'全文 variant `n{number:02}_r{star}_base`' in block

def matches(expression, effects):
    for term in expression.split(' AND '):
        chain = re.fullmatch(r'([\d.]+) ≤ (\w+) < ([\d.]+)', term)
        if chain:
            if not float(chain[1]) <= effects.get(chain[2], 0) < float(chain[3]):
                return False
            continue
        match = re.fullmatch(r'(\w+) ([≥<]) ([\d.]+)', term)
        assert match, term
        value, limit = effects.get(match[1], 0), float(match[3])
        if not (value >= limit if match[2] == '≥' else value < limit):
            return False
    return True

def stars(number, effects):
    found = [star for star, expression in conditions[number].items() if matches(expression, effects)]
    assert len(found) == 1, (number, effects, found)
    return found[0]

boundary_count = 0
for number, rows in conditions.items():
    tags = list(dict.fromkeys(re.findall(r'\b[a-z]+\b', rows[1])))
    for first, second in itertools.product((0, .59, .6, 2.19, 2.2, 2.21), (0, .59, .6, .61)):
        effects = {tags[0]: first}
        if len(tags) > 1:
            effects[tags[1]] = second
        stars(number, effects)
        boundary_count += 1
assert boundary_count == 480

selection = re.findall(r'\| `letter_n(\d+)` \| `n\d+_result_(\d)` \| `(n\d+_r\d_base)` \| `(n\d+_r\d_(?:base|memory))` \|', ordinary_text)
assert len(selection) == 60 and len({(n, s) for n, s, _, _ in selection}) == 60
definitions = re.findall(r'\*\*全文 variant `(n\d+_r\d_memory)`\*\*.*?\n\n(店主：[^\n]+)', ordinary_text)
full_variants = dict(definitions)
assert len(full_variants) == len(definitions) == 14
for number, star, base, faded in selection:
    assert f'全文 variant `{base}`' in blocks[int(number)]
    assert faded == base or faded in full_variants
    if int(number) in (20, 22):
        assert faded.endswith('_memory')
        assert ('说不全' in full_variants[faded] or '接不全' in full_variants[faded])
gates = re.findall(r'\| `(n\d+_extra_fun)` \| ([^|]+) \| ([^|]+) \| ([^|]+) \|', ordinary_text)
assert len(gates) == 20 and len({row[0] for row in gates}) == 20
assert all('_result_1' not in row[1] for row in gates)
assert 'n04_fun_memory' in next(row[3] for row in gates if row[0] == 'n04_extra_fun')
assert next(row[2] for row in gates if row[0] == 'n22_extra_fun').strip().startswith('recalled')

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('package.path = ' + repr(str(ROOT / 'scripts').replace('\\', '/') + '/?.lua;') + ' .. package.path')
lua.execute('''
D = require "data.content"
local ok, errors = D.Load(); assert(ok, table.concat(errors or {}, "\\n"))
ok, errors = D.ValidateStage1(); assert(ok, table.concat(errors or {}, "\\n"))
P = require "systems.Potion"
O = require("systems.Order").New(D)
function calculate(mainId, auxIds, ingredients, axis, sourceIds)
    local function ref(wordId, index)
        local origin = assert(sourceIds[wordId], "Missing manuscript source " .. wordId)
        return {tokenId="delivery:" .. index, definition=assert(D.GetWord(wordId)),
            source={wordId=wordId,sourceLetterInstanceId="draft:" .. origin,
                    sourceSpanId="body:" .. index,sourceNpcId="draft-npc"}}
    end
    local recipe={orderId="draft-order",baselineId="draft-baseline",contentVersion=D.contentVersion,
        equipment=D.GetEquipment("kit_old_cauldron"),main=ref(mainId,1),aux={},ingredients={},specialItems={}}
    for i,id in ipairs(auxIds) do recipe.aux[i]=ref(id,i+1) end
    for id,quantity in pairs(ingredients) do
        recipe.ingredients[#recipe.ingredients+1]={ingredientId=id,quantity=quantity,definition=D.GetIngredient(id)}
    end
    local calculated=P.Calculate(recipe,D)
    assert(calculated.ok, calculated.error and calculated.error.code)
    local potion=calculated.value
    local requirement={desc="Manuscript numerical contract",tags={[axis]=0.8},forbiddenEffects={},conditions={
        {id="onset",kind="onset",maxDelayHours=1},
        {id="duration",kind="duration",minHours=2,maxHours=4},
        {id="sleep",kind="forbiddenEffect",effectId="sleep",maxWeight=0.4}}}
    local evaluated=O.Evaluate(requirement,potion)
    assert(evaluated.ok, evaluated.error and evaluated.error.code)
    assert(evaluated.value.canShip, "Draft numerical requirement failed")
    return potion
end
''')

def table(value):
    if isinstance(value, dict):
        return lua.table_from({key: table(item) for key, item in value.items()})
    if isinstance(value, (list, tuple)):
        return lua.table_from([table(item) for item in value])
    return value

sources = {}
for content_id, ids in model.sources.items():
    for word in ids:
        sources.setdefault('word_' + word, content_id)
effect_words = {'fear': 'afraid', 'confusion': 'confused', 'envy': 'jealous', 'anger': 'angry',
                'forget': 'forget', 'pain': 'aching', 'suspicion': 'doubt'}
calculations = 0
def calculate(order, aux=(), recipe=None):
    global calculations
    result = lua.globals().calculate('word_' + order.main, table(['word_' + word for word in aux]),
                                     table(recipe or RECIPES['standard']), order.axis, table(sources))
    calculations += 1
    return dict(result['effects'].items())

for order in ORDINARY[3:]:
    number = int(order.id[1:])
    for recipe in (RECIPES['standard'], {'ing_night_dew': 1, 'ing_ashen_herb': 1}, RECIPES['nonminimal']):
        assert stars(number, calculate(order, recipe=recipe)) == 3
    if number in (8, 16):
        assert stars(number, calculate(order, ('quiet',))) == 2
        assert stars(number, calculate(order, ('quiet', 'wait'), {'ing_night_dew': 1, 'ing_ashen_herb': 1})) == 1
    else:
        tags = list(dict.fromkeys(re.findall(r'\b[a-z]+\b', conditions[number][1])))
        aux = [effect_words[tag] for tag in tags]
        assert stars(number, calculate(order, aux[:1])) == 2
        assert stars(number, calculate(order, aux)) == 1
    # Extra memory effects are numerically valid; text selection remains an author contract.
    calculate(order, ('forget',))
    calculate(order, ('promise', 'forget'))
for order in model.main_order_defs + list(model.pair_order_defs.values()):
    for recipe in RECIPES.values():
        calculate(order, order.aux, recipe)
assert calculations == 160

# core.quotepath may escape Chinese names; use NUL output.
changed = set()
for args in (['git', 'diff', 'f76de64', '--name-only', '-z'], ['git', 'diff', '--cached', '--name-only', '-z'], ['git', 'ls-files', '--others', '--exclude-standard', '-z']):
    changed.update(subprocess.check_output(args, cwd=ROOT).decode('utf-8').strip('\0').split('\0'))
def is_local_artifact(path):
    # logs/ and other .gitignore'd evidence files are local-only by design;
    # records may link them without failing the link check.
    try:
        rel = path.resolve().relative_to(ROOT.resolve()).as_posix()
    except ValueError:
        return False
    return subprocess.run(['git', 'check-ignore', '-q', '--', rel], cwd=ROOT, capture_output=True).returncode == 0

links = 0
local_artifacts = 0
for path in changed:
    if not path.endswith('.md'):
        continue
    file = ROOT / path
    for target in re.findall(r'\[[^\]\n]+\]\(([^)]+)\)', file.read_text(encoding='utf-8-sig')):
        target = unquote(target.strip('<>')).split('#')[0]
        if not target or re.match(r'[a-z]+://', target):
            continue
        target = re.sub(r':\d+$', '', target)
        link_path = file.parent / target
        if not link_path.exists():
            if is_local_artifact(link_path):
                local_artifacts += 1
                continue
            raise AssertionError((path, target))
        links += 1
for file in (ROOT / 'docs/文案').rglob('*.md'):
    if file not in (ordinary_file,) and file.name not in {'主线正文与后续包_v02.md', '身份结局正文_v01.md'}:
        continue
    text = file.read_text(encoding='utf-8')
    for mark in re.findall(r'\{\{(.*?)\}\}', text):
        if mark == '词':  # author legend; bounded order bodies were checked above / by Audit
            continue
        assert mark in {word['displayText'] for word in model.words.values()}, (file, mark)
# 文风基准 R11：加粗不可剪——bold spans never contain cut marks
for file in (ROOT / 'docs/文案').rglob('*.md'):
    text = file.read_text(encoding='utf-8')
    for bold in re.finditer(r'\*\*(.+?)\*\*', text, re.S):
        assert '{{' not in bold.group(1), (file, bold.group(1)[:40])
print(f'PASS: 20 packets, 60 core choices, 14 complete memory variants, 20 fun gates; {boundary_count} author boundaries.')
print(f'PASS: {calculations} actual Lua Potion/Order.Evaluate inputs; manuscript sources only, NOT world/rating/inventory integration.')
print(f'PASS: {links} local links in changed Markdown files ({local_artifacts} gitignored local-evidence links skipped).')
