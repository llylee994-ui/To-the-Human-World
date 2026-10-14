"""Verify retained desktop reset evidence; never writes game state or starts Runtime."""
import json
from pathlib import Path

LOGS = Path(__file__).resolve().parents[3] / 'logs'
checks = []


def read(label):
    return json.loads((LOGS / f'b6-persistent-reset-{label}.json').read_text(encoding='utf-8'))


def check(name, condition):
    assert condition, name
    checks.append(name)


baseline = read('baseline')['snapshot']
before = read('p-before')
reopen = read('p-reopen')
reset = read('after')['snapshot']
retry = read('p-retry')['snapshot']
first = read('initial')['snapshot']
second = read('n01-confirmed')['snapshot']
third_pending = read('n02-pending')['snapshot']
final = read('three-confirmed')['snapshot']
check('pending close and reopen: complete state and files',
      before['snapshot'] == read('p-closed')['snapshot'] == reopen['snapshot'] == reopen['boot']['snapshot']
      and before['files'] == read('p-closed')['files'] == reopen['files'])
order = before['snapshot']['currentOrder']
check('pending has not changed formal state', before['snapshot']['live'] == baseline['live'])
check('reset returns exact pre-input live, including letters/cards/prior orders',
      reset['live'] == baseline['live'] == order['baseline']['live'])
check('reset retains baseline and accepted order, clears trial and pending',
      reset['currentOrder']['baseline'] == order['baseline']
      and reset['currentOrder']['orderId'] == order['orderId']
      and reset['currentOrder']['phase'] == 'brewing'
      and reset['currentOrder']['pending'] is False
      and reset['currentOrder']['recipe'] is False)
pending = order['pending']
recomputed = retry['currentOrder']['pending']
check('rebrew has a new transaction', pending['transactionId'] != recomputed['transactionId'])
for field in ('potion', 'facts', 'worldChanges', 'followup', 'rating', 'consumption', 'reward'):
    check(f'rebrew deterministic {field}', pending[field] == recomputed[field])
check('second confirm installs complete candidate once', second['live'] == recomputed['candidateLive'])
check('third confirm installs complete candidate once', final['live'] == third_pending['currentOrder']['pending']['candidateLive'])
check('first confirmed order survives both later orders',
      first['live']['orders']['confirmedById']['order:1'] == final['live']['orders']['confirmedById']['order:1'])
check('three orders ledger', final['live']['gameFlow']['deliveredOrders'] == 3
      and final['live']['economy']['currency'] == 270
      and final['live']['economy']['ingredients'] == {
          'ing_sea_salt': 0, 'ing_night_dew': 1, 'ing_ashen_herb': 3, 'ing_dried_petal': 3})
cards = [c for c in final['live']['wordTokens']['byId'].values() if c['wordId'] == 'word_smile']
by_letter = {final['live']['letters']['byId'][c['sourceLetterInstanceId']]['letterId']: c for c in cards}
check('only selected same-name card consumed', len(cards) == 2
      and by_letter['letter_n02']['available'] is False
      and by_letter['letter_n02']['consumedByOrderId'] == 'order:3'
      and by_letter['letter_pa_01']['available'] is True)
closed = read('three-closed')
last = read('three-reopen')
check('three-order close/reopen exact state and files',
      final == closed['snapshot'] == last['snapshot'] == last['boot']['snapshot']
      and closed['files'] == last['files'] == read('final-closed')['files'])
probe, = last['retry_probes']
check('six repeated confirms no state/event changes', probe['passed'] and probe['unchanged']
      and probe['events'] == 0 and len(probe['results']) == 6
      and all(r['ok'] and r['alreadyConfirmed'] for r in probe['results']))
duration = (LOGS / 'b6-desktop-30.png').stat().st_mtime - (LOGS / 'b6-desktop-14.png').stat().st_mtime
check('observed interactive window interval exceeds five minutes', duration >= 300)
sessions = {}
for label in ('p-before', 'three-confirmed', 'three-reopen'):
    item = read(label)
    sessions[item['session_id']] = item['runtime_pid']
    messages = [json.loads(row)['m'] for row in (LOGS / f'b6-persistent-reset-{label}-lua.log').read_text(encoding='utf-8').splitlines()]
    check(f'native Lua log clean: {label}', not any('ERROR' in m or 'stack traceback' in m for m in messages))
check('final native process stopped', read('final-closed')['process_alive'] is False)
report = {'passed': True, 'checks': checks, 'interactive_seconds': duration, 'sessions': sessions,
          'limits': ['Windows isolated candidate only', 'existing engine resource errors remain',
                     'no mobile, forced kill, power loss or UI storage fault injection']}
(LOGS / 'b6-desktop-verification.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(report, ensure_ascii=False))
