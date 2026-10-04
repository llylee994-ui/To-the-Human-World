"""Verify retained native evidence; this does not drive or simulate gameplay."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
LOGS = ROOT/'logs'


def read(label):
    return json.loads((LOGS/f'b6-persistent-{label}.json').read_text(encoding='utf-8'))


def compare_reopen(before, closed, reopened):
    a, b, c = read(before), read(closed), read(reopened)
    assert not b['process_alive'] and c['process_alive']
    assert a['slot'] == b['slot'] == c['slot'] == c['boot']['slot']
    assert a['session_id'] != c['session_id']
    assert a['files'] == b['files'] == c['files'], 'Native files or storage path changed'
    assert a['snapshot'] == b['snapshot'] == c['snapshot'] == c['boot']['snapshot']
    assert c['boot']['status']['status'] == 'loaded'
    return c['snapshot']


smoke = compare_reopen('smoke-closed','smoke-closed','smoke-reopened')
cut = compare_reopen('c-before','c-closed','c-reopened')
pending = compare_reopen('p-before','p-closed','p-reopened')
confirmed = compare_reopen('f-before','f-closed','f-reopened')
again = compare_reopen('f-reopened','retry-closed','retry-reopened')
assert confirmed == again
assert len(cut['live']['wordTokens']['byId']) == 1
assert pending['currentOrder']['phase'] == 'pending'
assert pending['live']['economy'] == cut['live']['economy']
assert pending['live']['wordTokens'] == cut['live']['wordTokens']
assert confirmed['currentOrder'] is False
assert confirmed['live']['economy']['currency'] == 110
assert confirmed['live']['economy']['ingredients']['ing_sea_salt'] == 2
assert confirmed['live']['gameFlow']['deliveredOrders'] == 1
assert all(not token['available'] and token['consumedByOrderId'] == 'order:1' for token in confirmed['live']['wordTokens']['byId'].values())
probes = read('f-reopened')['retry_probes'] + read('retry-reopened')['retry_probes']
assert len(probes) == 2
assert all(p['passed'] and p['unchanged'] and p['events'] == 0 and len(p['results']) == 2 for p in probes)
result = {'smoke':'PASS','C':'PASS','P':'PASS','F':'PASS','reopen_after_retry':'PASS','duplicate_confirm_calls':4,'duplicate_events':0,'committed_generation':read('retry-reopened')['generation'],'currency':110,'sea_salt':2,'delivered_orders':1,'same_slot':'b6_persist_20261004_a','scope':'Local patched Maker candidate, native windows and files; not official/mobile acceptance'}
(LOGS/'b6-persistent-verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(result,ensure_ascii=False))
