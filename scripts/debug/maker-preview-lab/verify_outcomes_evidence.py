"""Compare saved native-window evidence with current content; does not operate the UI.

Uses the existing isolated lupa dependency only to read Lua configuration.
Tiny tolerance is for comparing calculated values to content's decimal expectations;
all save/reload, inventory, world and event comparisons remain exact.
"""
import json
import math
from pathlib import Path
import sys

PROJECT = Path(__file__).resolve().parents[3]
LOGS = PROJECT / 'logs'
sys.path.insert(0, str(PROJECT / '.tmp/b1-python'))
from lupa.lua54 import LuaRuntime, lua_type

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path = ... .. '/scripts/?.lua;' .. package.path", PROJECT.as_posix())


def convert(value):
    if lua_type(value) != 'table':
        return value
    keys = list(value.keys())
    if keys and set(keys) == set(range(1, len(keys) + 1)):
        return [convert(value[i]) for i in range(1, len(keys) + 1)]
    return {key: convert(child) for key, child in value.items()}


def config(name):
    return convert(lua.execute('return dofile(...)', (PROJECT / 'scripts/data' / name).as_posix()))


def read(label):
    return json.loads((LOGS / ('b6-outcomes-' + label + '.json')).read_text(encoding='utf-8'))


checks = []


def check(name, condition):
    assert condition, name
    checks.append(name)


cases = {case['id']: case for case in config('stage1.lua')['sampleCases']}
letter = next(item for item in config('letters.lua') if item['id'] == 'letter_pa_01')
accepted = read('accepted')
base = accepted['snapshot']['live']
tokens = base['wordTokens']['byId']
main_id = next(key for key, card in tokens.items() if card['wordId'] == 'word_sleep')
labels = {'A': 'a', 'G1': 'g1', 'G2': 'g2-fixed', 'B': 'b', 'C': 'c', 'D': 'd'}
formal_events = ('MoneyChanged', 'PotionDelivered', 'ItemRemoved', 'NpcStateChanged',
                 'OrderRatingRecorded', 'LetterArchived')
for case_id, label in labels.items():
    record = read(label)
    snapshot = record['snapshot']
    order = snapshot['currentOrder']
    pending = order['pending']
    expected = cases[case_id]['expect']
    recipe = cases[case_id]['recipe']
    check(case_id + ': native pending equals disk', order['phase'] == 'pending'
          and snapshot == record['observation']['snapshot'])
    check(case_id + ': same main token and baseline', order['recipe']['mainTokenId'] == main_id
          and order['baseline']['live'] == base and snapshot['live'] == base)
    check(case_id + ': configured recipe', order['recipe']['ingredients'] == recipe['ingredients']
          and [tokens[key]['wordId'] for key in order['recipe']['auxTokenIds']] == list(recipe['auxWordIds']))
    potion = pending['potion']
    check(case_id + ': effects match content', set(potion['effects']) == set(expected['effects'])
          and all(math.isclose(potion['effects'][key], value, rel_tol=1e-12, abs_tol=1e-12)
                  for key, value in expected['effects'].items()))
    check(case_id + ': timing and tiers', potion['onsetDelayHours'] == expected['onsetDelayHours']
          and potion['durationHours'] == expected['durationHours'] and potion['intensityByEffect'] == expected['tiers'])
    check(case_id + ': exact facts and fragments', {fact['id'] for fact in pending['facts']} == set(expected['facts'])
          and pending['followup']['fragmentIds'] == expected['followupFragments'])
    check(case_id + ': stars and fixed reward', pending['rating']['stars'] == expected['rating']['stars']
          and pending['rating']['ruleId'] == expected['rating']['ruleId'] and pending['reward'] == letter['reward'])
    check(case_id + ': no formal settlement events', all(record['observation']['events'].get(name, 0) == 0
                                                       for name in formal_events))
    check(case_id + ': trace keeps eight steps', [step['step'] for step in potion['trace']] == list(range(1, 9)))

for label in ('reset-a', 'reset-g1', 'reset-g2', 'reset-b', 'reset-c'):
    record = read(label)
    order = record['snapshot']['currentOrder']
    check(label + ': restores all live state and keeps cut cards', record['snapshot']['live'] == base
          and record['snapshot'] == record['observation']['snapshot'] and order['phase'] == 'brewing'
          and order['pending'] is False and order['baseline']['live'] == base)

for label, before in (('g2', 'reset-g1'), ('e-failure', 'reset-g2'), ('f-failure', 'e-failure')):
    record, previous = read(label), read(before)
    check(label + ': failure does not save or settle', record['snapshot'] == previous['snapshot']
          and record['files'] == previous['files'] and record['generation'] == previous['generation']
          and record['observation']['events'] == previous['observation']['events'])

fixed, reopened = read('g2-fixed'), read('g2-reopened')
check('G2: exact native close/reopen after precision fix', fixed['snapshot'] == reopened['snapshot']
      == reopened['boot']['snapshot'] and fixed['files'] == reopened['files'])
check('G2: native problematic residual preserved exactly',
      fixed['snapshot']['currentOrder']['pending']['potion']['residuals'][2]['weight'] == 0.15000000000000002)

trial, confirmed, final = read('d'), read('d-confirmed'), read('final-reopened')
check('D: commit installs exact candidate', confirmed['snapshot']['live'] == trial['snapshot']['currentOrder']['pending']['candidateLive']
      and confirmed['snapshot']['currentOrder'] is False and confirmed['generation'] == trial['generation'] + 1)
live = confirmed['snapshot']['live']
check('D: fixed reward once', live['economy']['currency'] == base['economy']['currency'] + letter['reward']['currency']
      and live['gameFlow']['deliveredOrders'] == 1)
expected_inventory = dict(base['economy']['ingredients'])
expected_inventory['ing_sea_salt'] -= 1
check('D: one ingredient only', live['economy']['ingredients'] == expected_inventory)
used = {trial['snapshot']['currentOrder']['recipe']['mainTokenId'],
        *trial['snapshot']['currentOrder']['recipe']['auxTokenIds']}
check('D: exactly three source cards consumed once', len(used) == 3
      and all(card['available'] == (key not in used)
              and card['consumedByOrderId'] == ('order:1' if key in used else False)
              for key, card in live['wordTokens']['byId'].items()))
check('D: one set of settlement events', all(confirmed['observation']['events'].get(name) == 1 for name in formal_events))
check('D: complete committed state survives restart', final['snapshot'] == final['boot']['snapshot']
      == confirmed['snapshot'] and final['files'] == confirmed['files'] and final['generation'] == confirmed['generation'])
retry, = final['retry_probes']
check('D: two confirm retries emit nothing and change nothing', retry['passed'] and retry['unchanged']
      and retry['events'] == 0 and len(retry['results']) == 2
      and all(result['ok'] and result['alreadyConfirmed'] for result in retry['results']))
check('all previous native slots unchanged', bool(accepted['other_slots']) and accepted['other_slots'] == final['other_slots'])
check('final native precision boundary regression passed', '[SaveJsonTest] PASS' in
      (LOGS / 'b6-outcomes-final-reopened-lua.log').read_text(encoding='utf-8'))
for label in ('g2-fixed', 'g2-reopened', 'b', 'c', 'd', 'd-confirmed', 'final-reopened'):
    messages = [json.loads(line)['m'] for line in (LOGS / ('b6-outcomes-' + label + '-lua.log')).read_text(encoding='utf-8').splitlines()]
    check(label + ': no Lua exception', not any('ERROR' in text or 'stack traceback' in text for text in messages))

report = {'passed': True, 'checks': checks, 'count': len(checks), 'slot': accepted['slot'],
          'limits': ['Compares existing native-window evidence; does not rerun UI operations',
                     'Screenshots inspected separately; E/F causes proven by UI screenshots',
                     'Isolated desktop persistence candidate, not official native/mobile acceptance']}
(LOGS / 'b6-outcomes-verification.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(f'PASS {len(checks)} native outcome evidence checks')
