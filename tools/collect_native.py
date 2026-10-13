"""Read official logs of an explicitly identified lab session; never start/refresh."""
from pathlib import Path
import subprocess,json,os,argparse,datetime,hashlib
p=argparse.ArgumentParser(); p.add_argument('--session',required=True);p.add_argument('--reload',required=True,type=int);p.add_argument('--label',required=True);p.add_argument('--saved',action='store_true'); a=p.parse_args()
root=Path(__file__).resolve().parents[1]; out=root/'docs/evidence/3d-lab-r3'/a.label
assert out.resolve().is_relative_to(root.resolve())
out.mkdir(parents=True,exist_ok=True)
env=dict(os.environ,TAPTAP_MAKER_HOME=str(root/'.preview-home'),TEMP=str(root/'tools/tmp'),TMP=str(root/'tools/tmp'))
base=[r'D:\node.js\node.exe',r'C:\Users\YINGYI\AppData\Roaming\npm\node_modules\@taptap\maker\dist\maker.js','preview','logs','--target-dir',str(root),'--session-id',a.session,'--reload-id',str(a.reload),'--limit','500','--json']
cursor=0; all_logs=[]; state={}
for page in range(0 if a.saved else 30):
    r=subprocess.run(base+['--cursor',str(cursor)],env=env,capture_output=True,encoding='utf-8',timeout=30)
    assert r.returncode==0,r.stderr
    state=json.loads(r.stdout)
    assert state.get('session_id')==a.session and state.get('reload_id')==a.reload
    (out/f'page-{page:02d}.json').write_text(json.dumps(state,ensure_ascii=False,indent=2),encoding='utf-8')
    all_logs.extend(state.get('logs',[])); next_cursor=state.get('next_cursor',cursor)
    if not state.get('truncated') or next_cursor<=cursor: break
    cursor=next_cursor
if a.saved:
    for f in sorted(out.glob('page-*.json')):
        state=json.loads(f.read_text(encoding='utf-8')); assert state['session_id']==a.session and state['reload_id']==a.reload
        all_logs.extend(state.get('logs',[]))
    state['state']='historical_saved_logs; current process state not queried'
qa=[]; seen=set(); frames=[]; errors=[]; unparsed=[]; redacted_headers=[]
for row in all_logs:
    text=row['text']
    if '[D3-LAB QA] ' in text:
        payload=text.split('[D3-LAB QA] ',1)[1]
        try: entry=json.loads(payload,strict=False)
        except json.JSONDecodeError:
            unparsed.append(text)
            # Maker's log sanitizer treats a business tokenId as a token and
            # truncates the rest. Preserve its intact assertion header only;
            # never invent or attempt to recover the redacted result payload.
            if '<redacted>' not in payload or ',"detail":' not in payload: continue
            try: entry=json.loads(payload.split(',"detail":',1)[0]+'}',strict=False)
            except json.JSONDecodeError: continue
            if not all(k in entry for k in ('name','status','utc')): continue
            entry['detail']={'unavailable':'Official Maker log redaction truncated result payload. Assertion header is intact.'}
            redacted_headers.append(entry)
        key=json.dumps(entry,sort_keys=True)
        if key not in seen: seen.add(key); qa.append(entry)
    if '[D3-LAB frame]' in text and '[lua]' in text: frames.append(text.strip())
    if 'ERROR:' in text: errors.append(text.strip())
report={'collected_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'session_id':a.session,'reload_id':a.reload,'state':state.get('state'),'native_qa':qa,'pass_count':sum(x['status']=='PASS' for x in qa),'failures':[x for x in qa if x['status']=='FAIL'],'complete':any(x['status']=='COMPLETE' for x in qa),'frame_logs':frames,'errors':errors,'unparsed_qa':unparsed,'redacted_qa_headers':redacted_headers,'limitations':'Program-driven adapter and actual UI callbacks, not human input or full native UI event dispatch. Continuous still frames do not prove smooth playback.'}
(out/'summary.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:report[k] for k in ('collected_utc','state','pass_count','failures','complete')},ensure_ascii=False))
print(json.dumps(qa[-5:],ensure_ascii=False))
