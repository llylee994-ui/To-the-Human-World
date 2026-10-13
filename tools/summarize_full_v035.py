"""Summarize existing evidence for one exact official Lab session; no process control."""
from pathlib import Path
import argparse,json,re,datetime
p=argparse.ArgumentParser();p.add_argument('--attempt',required=True);args=p.parse_args()
assert re.fullmatch(r'\d{2}',args.attempt)
lab=Path(__file__).resolve().parents[1]
out=lab/('docs/evidence/v035-main-interface/native-full-20261013-'+args.attempt)
owned=json.loads((out/'owned-session.json').read_text(encoding='utf-8'))
source=Path(owned['preparation']['source_directory'])
runtime_log=source.parent/'runtime.log'
events=[]
for line in runtime_log.read_text(encoding='utf-8').splitlines():
    row=json.loads(line);message=row.get('text','')
    if message.startswith('[lua]'):continue
    match=re.search(r'\[V035 FULL ([A-Z_]+)\] (\{.*\})',message)
    if match:
        try:events.append({'kind':match[1],'value':json.loads(match[2])})
        except ValueError:pass
metrics=[json.loads(s) for s in (out/'observer.jsonl').read_text(encoding='utf-8').splitlines()]
samples=[r for r in metrics if r['event']=='sample']
def latest(kind):return next((x['value'] for x in reversed(events) if x['kind']==kind),None)
report={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'sessionId':owned['session_id'],'runtimePid':owned['runtime_pid'],'runtimeLog':str(runtime_log),
    'ready':latest('READY'),'camera':latest('CAMERA'),'latestFrame':latest('FRAME'),
    'failures':[x['value'] for x in events if x['kind']=='FAIL'],
    'programmaticEntries':[x['value'] for x in events if x['kind']=='ENTRY_CHECK'],
    'programmaticDone':latest('ENTRY_CHECK_DONE'),
    'latestMemory':samples[-1] if samples else None,
    'peakWorkingSetBytes':max((x['peakWorkingSetBytes'] for x in samples),default=0),
    'peakPrivateBytesSampled':max((x['privateBytes'] for x in samples),default=0),
    'exit':json.loads((out/'native-exit.json').read_text()) if (out/'native-exit.json').exists() else None,
    'limitations':['programmaticEntries are direct UI callbacks, not OS clicks','Update timings are not GPU frame measurements','exit null means no captured exit yet']}
expected={'home.drawer':('home','letters'),'home.journal':('home','journal'),
    'home.tray':('home','words'),'home.caseFile':('home','case'),
    'home.merchantShip':('home','shop'),'home.letterPaper':('home','letters'),
    'home.net':('seaside',False),'home.stove':('brew',False)}
report['entryVerdicts']={r['id']:r.get('picked')==r['id'] and (r['scene'],r['panel'])==expected[r['id']] and not r['busy'] for r in report['programmaticEntries']}
report['allEightProgrammaticPassed']=len(report['entryVerdicts'])==8 and all(report['entryVerdicts'].values())
(out/'runtime-summary.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
compact={k:report[k] for k in ['runtimePid','ready','failures','entryVerdicts','allEightProgrammaticPassed','programmaticDone','peakWorkingSetBytes','peakPrivateBytesSampled','exit']}
if report['camera']:compact['camera']={k:report['camera'][k] for k in ['ok','pointError','rayError','handedness','lookSign']}
print(json.dumps(compact,ensure_ascii=False,indent=2))
