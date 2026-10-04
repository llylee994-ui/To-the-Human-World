"""Read-only snapshots of the lab's real native slot, never restore/copy into Runtime."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import re
from datetime import datetime

PROJECT = Path('D:/taptap/To-the-Human-World')
SLOT = 'b6_persist_20261004_a'
label = sys.argv[1]
assert label.replace('-', '').replace('_', '').isalnum()
files = list(Path('D:/taptap/.mpv/data').rglob('save_' + SLOT + '*'))
snapshots = []
for file in files:
    if file.suffix == '.json' and file.with_suffix('.commit').exists():
        raw = file.read_bytes().rstrip(b'\0')
        marker = file.with_suffix('.commit').read_bytes().rstrip(b'\0').decode()
        matched = re.fullmatch(r'B1\|(\d+)\|([ab])\|(\d+)\|(\d+)\|END', marker)
        assert matched and file.stem.endswith('_'+matched[2]), 'Invalid commit marker'
        digest = 0
        for byte in raw: digest = (digest * 31 + byte) % 4294967291
        assert len(raw) == int(matched[3]) and digest == int(matched[4]), 'Committed snapshot integrity failure'
        snapshots.append((int(matched[1]),json.loads(raw)['data']))
assert snapshots, 'No actual committed native files found'
generation, snapshot = max(snapshots, key=lambda item: item[0])
result = subprocess.run(['D:/node.js/node.exe','D:/taptap/.mpv/cli/dist/maker.js','preview','status','--target-dir',str(PROJECT),'--json'],capture_output=True,encoding='utf-8')
status = json.loads(result.stdout)
logs = subprocess.run(['D:/node.js/node.exe','D:/taptap/.mpv/cli/dist/maker.js','preview','logs','--target-dir',str(PROJECT),'--limit','500','--json'],capture_output=True,encoding='utf-8')
(PROJECT/'logs'/f'b6-persistent-{label}-logs.json').write_text(logs.stdout,encoding='utf-8')
record = {'slot':SLOT,'generation':generation,'session_id':status['session_id'],'runtime_pid':status.get('runtime_pid'),'process_alive':status['process_alive'],'state':status['state'],'files':{str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in files},'snapshot':snapshot}
# CLI sanitization truncates long game tokenId JSON. Inspect only this native round's
# Lua file and require the exact test slot; never publish this local evidence.
lua_dir = Path(status['executable']).parent/'logs/lua'
started = datetime.fromisoformat(status['started_at'].replace('Z','+00:00')).timestamp()
candidates = [f for f in lua_dir.glob('*.log') if f.stat().st_mtime >= started]
native = []
for f in candidates:
    raw_log = f.read_text(encoding='utf-8')
    for line in (json.loads(row)['m'] for row in raw_log.splitlines()):
        if '[B6Evidence] ' in line:
            value = json.loads(line.split('[B6Evidence] ',1)[1])
            if value['slot'] == SLOT: native.append((f,raw_log,value))
assert len(native)==1, 'Cannot uniquely identify the current native Lua log'
f,raw_log,boot = native[0]
(PROJECT/'logs'/f'b6-persistent-{label}-lua.log').write_text(raw_log,encoding='utf-8')
record['boot'] = boot
record['retry_probes'] = [json.loads(line.split('[B6PersistenceRetry] ',1)[1]) for line in (json.loads(row)['m'] for row in raw_log.splitlines()) if '[B6PersistenceRetry] ' in line]
(PROJECT/'logs'/f'b6-persistent-{label}.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'label':label,'generation':generation,'revision':snapshot['revision'],'phase':snapshot['currentOrder'] and snapshot['currentOrder']['phase'],'currency':snapshot['live']['economy']['currency'],'process_alive':status['process_alive'],'file_count':len(files)},ensure_ascii=False))
