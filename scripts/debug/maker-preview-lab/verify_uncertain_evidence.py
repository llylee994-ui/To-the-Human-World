"""Verify native-window evidence with explicitly injected commit readback failures."""
import json
from pathlib import Path

LOGS = Path(__file__).resolve().parents[3] / 'logs'
checks = []


def read(label):
    return json.loads((LOGS / ('b6-uncertain-' + label + '.json')).read_text(encoding='utf-8'))


def check(name, condition):
    assert condition, name
    checks.append(name)


before, locked, guard, failed, released, recovered, reopened, final = map(read, (
    'pending-before', 'locked', 'guard', 'reload-blocked', 'released', 'recovered', 'reopened', 'final-closed'))
check('fault initially disarmed; real pending matches memory', not before['observation']['injection']['armed']
      and not before['observation']['injection']['blocked'] and before['snapshot'] == before['observation']['snapshot'])
check('commit persisted complete candidate in native files', locked['generation'] == before['generation'] + 1
      and locked['snapshot']['live'] == before['snapshot']['currentOrder']['pending']['candidateLive']
      and locked['snapshot']['currentOrder'] is False)
check('injected read failure happens after exactly one native commit write',
      locked['observation']['injection']['committedWrites'] == 1
      and locked['observation']['injection']['blockedReads'] == 2
      and locked['observation']['injection']['blocked'])
check('uncertain status locks old in-memory state', locked['observation']['status']['status'] == 'recovery_required'
      and locked['observation']['status']['error']['code'] == 'SAVE_COMMIT_UNCERTAIN'
      and locked['observation']['snapshot'] == before['snapshot'] and not locked['observation']['canMutate'])
check('uncertain commit emits no settlement events', locked['observation']['events'] == before['observation']['events'])
for label, value in (('uncertain', locked), ('read still failing', failed), ('released before reload', released)):
    check(label + ': all mutation gates remain closed',
          not value['observation']['canMutate'] and all(not a['enabled'] for a in value['observation']['actions'].values()))
probe, = guard['guard_probes']
check('direct commands cannot bypass lock', probe['unchanged'] and probe['eventsUnchanged']
      and all(not r['ok'] and r['error']['code'] == 'STATE_LOCKED' for r in probe['results'].values()))
check('wrong-slot recovery rejected', probe['wrongSlot']['error']['code'] == 'RECOVERY_SLOT_MISMATCH')
check('reload while blocked preserves old memory and native committed result',
      failed['observation']['status']['error']['code'] == 'SAVE_READ_FAILED'
      and failed['observation']['injection']['blockedReads'] == 3
      and failed['observation']['snapshot'] == before['snapshot']
      and failed['snapshot'] == locked['snapshot'] and failed['files'] == locked['files'])
check('release alone does not install or unlock', not released['observation']['injection']['blocked']
      and released['observation']['snapshot'] == before['snapshot'] and not released['observation']['canMutate'])
check('real reload button installs complete same-slot committed result',
      recovered['observation']['snapshot'] == recovered['snapshot'] == locked['snapshot']
      and recovered['observation']['status']['status'] == 'loaded' and recovered['observation']['canMutate'])
expected_events = dict(before['observation']['events'])
expected_events['SaveLoaded'] = expected_events.get('SaveLoaded', 0) + 1
check('recovery only adds SaveLoaded; no settlement replay', recovered['observation']['events'] == expected_events)
check('recovery performs no writes', recovered['files'] == locked['files']
      and recovered['generation'] == locked['generation'])
live = recovered['snapshot']['live']
check('one delivery reward and consumption', live['gameFlow']['deliveredOrders'] == 1
      and live['economy']['currency'] == 110 and live['economy']['ingredients']['ing_sea_salt'] == 2
      and len(live['wordTokens']['byId']) == 1
      and all(not c['available'] and c['consumedByOrderId'] == 'order:1' for c in live['wordTokens']['byId'].values()))
check('normal close/reopen exact full state and files', recovered['snapshot'] == read('closed')['snapshot']
      == reopened['boot']['snapshot'] == reopened['snapshot'] == final['snapshot']
      and recovered['files'] == read('closed')['files'] == reopened['files'] == final['files'])
retry, = reopened['retry_probes']
check('two repeated confirms after restart are no-ops', retry['passed'] and retry['unchanged'] and retry['events'] == 0
      and len(retry['results']) == 2 and all(r['ok'] and r['alreadyConfirmed'] for r in retry['results']))
check('old slots not changed', bool(before['other_slots']) and before['other_slots'] == final['other_slots'])
check('fault absent after restart and window stopped', not final['process_alive']
      and not final['observation']['injection']['armed'] and not final['observation']['injection']['blocked']
      and final['observation']['injection']['committedWrites'] == 0)
for label in ('recovered', 'reopened'):
    rows = [json.loads(line)['m'] for line in (LOGS / ('b6-uncertain-' + label + '-lua.log')).read_text(encoding='utf-8').splitlines()]
    check(label + ': no uncaught Lua exception', not any('ERROR' in row or 'stack traceback' in row for row in rows))
report = {'passed': True, 'checks': checks, 'slot': before['slot'],
          'limits': ['Native File writes; commit reads deliberately refused by debug wrapper',
                     'Not a physical disk, OS read-lock or power-loss test',
                     'Existing engine resource errors remain; mobile not tested']}
(LOGS / 'b6-uncertain-verification.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({'passed': True, 'checks': len(checks), 'limits': report['limits']}, ensure_ascii=False))
