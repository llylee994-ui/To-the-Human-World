"""Exact-slot native fault lab. Read evidence or reversibly change one file's attributes."""
import ctypes
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

PROJECT = Path('D:/taptap/To-the-Human-World')
ROOT = Path('D:/taptap/.mpv/data').resolve()
SLOT = 'b6_fault_20261004_a'
LOGS = PROJECT / 'logs'
LOCK = LOGS / 'b6-fault-lock.json'


def safe_file(path):
    path = Path(path)
    resolved = path.resolve(strict=True)
    assert resolved.is_relative_to(ROOT) and resolved == path.absolute(), 'Outside lab or redirected file'
    assert resolved.parent.name == '0' and resolved.parent.parent.name == 'savedata'
    assert re.fullmatch('save_' + SLOT + r'_[ab]\.(json|commit)', resolved.name)
    return resolved


def attributes(path, value=None):
    kernel = ctypes.windll.kernel32
    kernel.GetFileAttributesW.argtypes = [ctypes.c_wchar_p]
    kernel.GetFileAttributesW.restype = ctypes.c_uint32
    kernel.SetFileAttributesW.argtypes = [ctypes.c_wchar_p, ctypes.c_uint32]
    if value is not None:
        assert kernel.SetFileAttributesW(str(path), value), 'Cannot set attributes'
    result = kernel.GetFileAttributesW(str(path))
    assert result != 0xFFFFFFFF, 'Cannot read attributes'
    return result


def current():
    files = [safe_file(p) for p in ROOT.rglob('save_' + SLOT + '_*')]
    assert files and len({p.parent for p in files}) == 1, 'Missing or ambiguous native slot'
    markers = []
    for file in files:
        if file.suffix != '.commit':
            continue
        match = re.fullmatch(r'B1\|(\d+)\|([ab])\|(\d+)\|(\d+)\|END', file.read_bytes().rstrip(b'\0').decode())
        assert match and file.stem.endswith('_' + match[2]), 'Invalid marker'
        markers.append((int(match[1]), match[2], int(match[3]), int(match[4]), file.with_suffix('.json')))
    generation, side, length, expected, file = max(markers)
    # Match SaveSystem: validate the highest committed generation, not an overwritten inactive bank.
    raw = file.read_bytes().rstrip(b'\0')
    digest = 0
    for byte in raw:
        digest = (digest * 31 + byte) % 4294967291
    assert len(raw) == length and digest == expected, 'Current committed snapshot corrupt'
    return files, generation, side, json.loads(raw)['data']


def write_record(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf-8')


mode = sys.argv[1]
PREFIX = 'b6-fault-'
if mode == 'collect' and len(sys.argv) == 4:
    prefixes = {'b6_uncertain_20261004_a': 'b6-uncertain-',
                'b6_outcomes_20261004_a': 'b6-outcomes-'}
    assert sys.argv[3] in prefixes, 'Unknown additional evidence slot'
    SLOT = sys.argv[3]
    PREFIX = prefixes[SLOT]
if mode == 'restore':
    record = json.loads(LOCK.read_text(encoding='utf-8'))
    assert record['active'], 'No active fault'
    target = safe_file(record['path'])
    assert attributes(target, record['original_attributes']) == record['original_attributes']
    record['active'] = False
    record['restored_at'] = datetime.now().astimezone().isoformat()
    write_record(LOCK, record)
    write_record(LOGS / ('b6-fault-unlock-' + record['label'] + '.json'), record)
    print('Restored original attributes: ' + target.name)
    sys.exit(0)

files, generation, side, snapshot = current()
if mode == 'readonly':
    kind, label = sys.argv[2:4]
    assert kind in ('snapshot', 'commit') and re.fullmatch(r'[a-z0-9-]+', label)
    assert not LOCK.exists() or not json.loads(LOCK.read_text(encoding='utf-8'))['active'], 'Fault already active'
    target = safe_file(files[0].parent / ('save_' + SLOT + '_' + ('b' if side == 'a' else 'a')
                                        + ('.json' if kind == 'snapshot' else '.commit')))
    original = attributes(target)
    assert not original & 1, 'Already readonly; cannot claim ownership'
    record = {'active': True, 'label': label, 'kind': kind, 'path': str(target),
              'original_attributes': original, 'generation': generation,
              'armed_at': datetime.now().astimezone().isoformat()}
    write_record(LOCK, record)  # Record recovery before touching the test file.
    assert attributes(target, original | 1) & 1
    write_record(LOGS / ('b6-fault-lock-' + label + '.json'), record)
    print('Readonly fault armed on inactive ' + target.name)
    sys.exit(0)

assert mode == 'collect'
label = sys.argv[2]
assert re.fullmatch(r'[a-z0-9-]+', label)
output = LOGS / (PREFIX + label + '.json')
assert not output.exists(), 'Do not overwrite evidence'
result = subprocess.run(['D:/node.js/node.exe', 'D:/taptap/.mpv/cli/dist/maker.js', 'preview', 'status',
                         '--target-dir', str(PROJECT), '--json'], capture_output=True, encoding='utf-8', check=True)
status = json.loads(result.stdout)
started = datetime.fromisoformat(status['started_at'].replace('Z', '+00:00')).timestamp()
anchor = LOGS / (PREFIX + 'session-' + status['session_id'] + '-' + str(status['reload_id']) + '.json')
if status['process_alive']:
    pid = int(status['runtime_pid'])
    command = f"(Get-Process -Id {pid}).StartTime.ToUniversalTime().ToString('o')"
    process_start = subprocess.run(['powershell', '-NoProfile', '-Command', command],
                                   capture_output=True, encoding='utf-8', check=True).stdout.strip()
    started = datetime.fromisoformat(process_start).timestamp()
    write_record(anchor, {'runtime_pid': pid, 'started': started})
else:
    started = json.loads(anchor.read_text(encoding='utf-8'))['started']
native = []
for file in (Path(status['executable']).parent / 'logs/lua').glob('*.log'):
    if file.stat().st_mtime < started:
        continue
    raw = file.read_text(encoding='utf-8')
    messages = [json.loads(row)['m'] for row in raw.splitlines()]
    boots = [json.loads(m.split('[B6Evidence] ', 1)[1]) for m in messages if '[B6Evidence] ' in m]
    if len(boots) == 1 and boots[0]['slot'] == SLOT:
        native.append((raw, messages, boots[0]))
assert len(native) == 1, 'Cannot uniquely identify current native log'
raw, messages, boot = native[0]
observations = [json.loads(m.split('[B6FaultEvidence] ', 1)[1]) for m in messages if '[B6FaultEvidence] ' in m]
assert observations, 'Click the readonly evidence button in this window before collecting'
record = {'slot': SLOT, 'collected_at': datetime.now().astimezone().isoformat(),
          'session_id': status['session_id'], 'runtime_pid': status.get('runtime_pid'),
          'reload_id': status['reload_id'], 'native_started': started,
          'process_alive': status['process_alive'], 'generation': generation, 'side': side,
          'snapshot': snapshot, 'boot': boot, 'observation': observations[-1],
          'observations_count': len(observations),
          'retry_probes': [json.loads(m.split('[B6PersistenceRetry] ', 1)[1]) for m in messages if '[B6PersistenceRetry] ' in m],
          'guard_probes': [json.loads(m.split('[B6UncertainGuard] ', 1)[1]) for m in messages if '[B6UncertainGuard] ' in m],
          'files': {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in files},
          'attributes': {str(p): attributes(p) for p in files},
          'other_slots': {str(p): hashlib.sha256(p.read_bytes()).hexdigest()
                          for p in files[0].parent.glob('save_*') if p.is_file() and p not in files}}
write_record(output, record)
(LOGS / (PREFIX + label + '-lua.log')).write_text(raw, encoding='utf-8')
print(json.dumps({'label': label, 'generation': generation, 'phase': snapshot['currentOrder'] and snapshot['currentOrder']['phase'],
                  'currency': snapshot['live']['economy']['currency'], 'events': record['observation']['events']}, ensure_ascii=False))
