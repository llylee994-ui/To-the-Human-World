"""Check retained native fault experiments, not a simulated File adapter test."""
import json
from pathlib import Path

LOGS = Path(__file__).resolve().parents[3] / 'logs'
checks = []


def read(label):
    return json.loads((LOGS / ('b6-fault-' + label + '.json')).read_text(encoding='utf-8'))


def check(name, value):
    assert value, name
    checks.append(name)


brewing = read('brewing-before')
preview_fail = read('preview-failed')
pending = read('pending-before')
reopen = read('pending-reopen')
snapshot_fail = read('confirm-snapshot-failed')
commit_fail = read('confirm-commit-failed')
recovered = read('failed-reopen')
reset_fail = read('reset-failed')
confirmed = read('confirmed')
final = read('confirmed-reopen')
closed = read('final-closed')

for title, before, after in (
    ('preview snapshot write', brewing, preview_fail),
    ('confirm snapshot write', reopen, snapshot_fail),
    ('confirm marker write', snapshot_fail, commit_fail),
    ('reset snapshot write', recovered, reset_fail),
):
    check(title + ': full memory and committed state unchanged',
          before['snapshot'] == before['observation']['snapshot'] == after['snapshot'] == after['observation']['snapshot'])
    check(title + ': no events and generation unchanged', before['observation']['events'] == after['observation']['events']
          and before['generation'] == after['generation'])
    check(title + ': retry remains available', after['observation']['canMutate'] is True)
    if title != 'confirm marker write':
        check(title + ': no file content changed', before['files'] == after['files'])

check('preview retry persisted pending exactly once', pending['generation'] == brewing['generation'] + 1
      and pending['snapshot']['currentOrder']['phase'] == 'pending'
      and pending['snapshot']['live'] == brewing['snapshot']['live']
      and pending['observation']['events'] == {'DeliveryPreviewReady': 1})
check('pending restart retained original transaction and complete result',
      pending['snapshot'] == reopen['boot']['snapshot'] == reopen['snapshot']
      and pending['files'] == reopen['files'])
changed = [p for p in commit_fail['files'] if commit_fail['files'][p] != snapshot_fail['files'][p]]
check('marker failure wrote only inactive candidate, no commit marker',
      len(changed) == 1 and changed[0].endswith('_a.json') and commit_fail['side'] == 'b')
check('failed commit restart ignores uncommitted candidate', commit_fail['snapshot'] == recovered['boot']['snapshot']
      == recovered['snapshot'] == read('failed-closed')['snapshot']
      and commit_fail['files'] == read('failed-closed')['files'] == recovered['files'])
for label, item in (('confirm failed', snapshot_fail), ('commit failed', commit_fail), ('reset failed', reset_fail)):
    gates = item['observation']['actions']
    check(label + ': pending gates preserved', gates['Confirm']['enabled'] and gates['Reset']['enabled']
          and all(not gates[k]['enabled'] for k in ('NextDay', 'CutWord', 'Accept', 'Preview')))

check('successful retry installs complete candidate once',
      confirmed['snapshot']['live'] == pending['snapshot']['currentOrder']['pending']['candidateLive']
      and confirmed['snapshot']['currentOrder'] is False
      and confirmed['generation'] == pending['generation'] + 1)
live = confirmed['snapshot']['live']
check('reward, ingredient and card exactly once', live['economy']['currency'] == 110
      and live['economy']['ingredients']['ing_sea_salt'] == 2
      and live['gameFlow']['deliveredOrders'] == 1
      and len(live['wordTokens']['byId']) == 1
      and all(c['available'] is False and c['consumedByOrderId'] == 'order:1' for c in live['wordTokens']['byId'].values()))
check('successful confirm emits settlement only once', confirmed['observation']['events'] == {
    'PotionDelivered': 1, 'ItemRemoved': 1, 'OrderRatingRecorded': 1,
    'NpcStateChanged': 1, 'MoneyChanged': 1, 'LetterArchived': 1})
check('confirmed restart retains full result and file content',
      confirmed['snapshot'] == read('confirmed-closed')['snapshot'] == final['boot']['snapshot']
      == final['snapshot'] == closed['snapshot']
      and confirmed['files'] == read('confirmed-closed')['files'] == final['files'] == closed['files'])
probe, = final['retry_probes']
check('two repeated confirms after restart cause no changes', probe['passed'] and probe['unchanged']
      and probe['events'] == 0 and len(probe['results']) == 2
      and all(r['ok'] and r['alreadyConfirmed'] for r in probe['results']))
check('all other native slots unchanged', bool(brewing['other_slots']) and brewing['other_slots'] == closed['other_slots'])
for label in ('preview-snapshot', 'confirm-snapshot', 'confirm-commit', 'reset-snapshot'):
    lock = read('lock-' + label)
    unlock = read('unlock-' + label)
    check(label + ': exact original attributes restored', not unlock['active'] and lock['path'] == unlock['path']
          and closed['attributes'][lock['path']] == lock['original_attributes'] == unlock['original_attributes'])
check('no active fault and stopped native window', not read('lock')['active']
      and not closed['process_alive'] and all(not (v & 1) for v in closed['attributes'].values()))
for label, stage in (('confirm-snapshot-failed', 'snapshot_write'), ('confirm-commit-failed', 'commit'), ('reset-failed', 'snapshot_write')):
    messages = [json.loads(row)['m'] for row in (LOGS / ('b6-fault-' + label + '-lua.log')).read_text(encoding='utf-8').splitlines()]
    errors = [json.loads(m.split('[PlaySaveFailure] ', 1)[1]) for m in messages if '[PlaySaveFailure] ' in m]
    check(label + ': actual native failure stage', errors[-1]['code'] == 'SAVE_WRITE_FAILED' and errors[-1]['path'] == stage)
    check(label + ': no Lua exception', not any('ERROR' in m or 'stack traceback' in m for m in messages))

report = {'passed': True, 'checks': checks, 'slot': confirmed['slot'],
          'limits': ['Windows candidate only; readonly files, not full disk/power loss',
                     'known failed writes only; commit-uncertain recovery not native-tested',
                     'existing engine resource errors remain; mobile untested']}
(LOGS / 'b6-fault-verification.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({'passed': True, 'checks': len(checks), 'limits': report['limits']}, ensure_ascii=False))
