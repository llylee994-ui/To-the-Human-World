"""Bounded stdio diagnostic client for the already installed EmmyLua server.
No package install, no preview, no writes outside this lab. Raw diagnostic evidence retained.
"""
from pathlib import Path
import os,sys,subprocess,threading,queue,json,time,datetime,hashlib
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/evidence/3d-lab-r3/lsp'; OUT.mkdir(parents=True,exist_ok=True)
EXE=Path(r'C:\Users\YINGYI\.taptap-maker\lua-lsp-venv\Lib\site-packages\maker_lua_lsp\bin\emmylua_ls.exe')
CONFIG={'runtime':{'version':'Lua5.4','requireLikeFunction':['tolua'],'special':{'tolua':'require'}},'workspace':{'library':[str(ROOT/'.emmylua')],'packages':[str(ROOT/'urhox-libs')]},'diagnostics':{'enable':True,'globals':['tolua']}}
RESOURCES=OUT/'server-resources'; RESOURCES.mkdir(exist_ok=True)
ARGS=[str(EXE),'--communication','stdio','--log-level','warn','--log-path',str(OUT/'server.log'),'--resources-path',str(RESOURCES)]
env=os.environ.copy();env.update(TEMP=str(ROOT/'tools/tmp'),TMP=str(ROOT/'tools/tmp'))
p=subprocess.Popen(ARGS,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,cwd=ROOT,env=env,creationflags=subprocess.CREATE_NO_WINDOW)
q=queue.Queue(); messages=[]; diagnostics={}; stderr=[]; responses={}
def read():
    while True:
        headers={}
        while True:
            line=p.stdout.readline()
            if not line: return
            if line in (b'\r\n',b'\n'): break
            k,v=line.decode().split(':',1); headers[k.lower()]=v.strip()
        q.put(json.loads(p.stdout.read(int(headers['content-length']))))
def read_err():
    for line in iter(p.stderr.readline,b''): stderr.append(line.decode('utf-8',errors='replace').rstrip())
threading.Thread(target=read,daemon=True).start(); threading.Thread(target=read_err,daemon=True).start()
def send(method=None,params=None,identity=None,result=None):
    msg={'jsonrpc':'2.0'}
    if method: msg.update(method=method,params=params or {})
    if identity is not None: msg['id']=identity
    if not method: msg['result']=result
    data=json.dumps(msg,ensure_ascii=False).encode('utf-8')
    p.stdin.write(f'Content-Length: {len(data)}\r\n\r\n'.encode()+data); p.stdin.flush()
def pump(seconds):
    deadline=time.monotonic()+seconds
    while time.monotonic()<deadline:
        try: msg=q.get(timeout=min(.1,max(.001,deadline-time.monotonic())))
        except queue.Empty: continue
        messages.append(msg)
        method=msg.get('method')
        if method=='workspace/configuration': send(identity=msg['id'],result=[CONFIG for _ in msg.get('params',{}).get('items',[])])
        elif method and 'id' in msg: send(identity=msg['id'],result=None)
        elif method=='textDocument/publishDiagnostics': diagnostics[msg['params']['uri']]=msg['params']['diagnostics']
        elif 'id' in msg: responses[msg['id']]=msg
send('initialize',{'processId':os.getpid(),'rootUri':(ROOT/'scripts').as_uri(),'workspaceFolders':[{'uri':(ROOT/'scripts').as_uri(),'name':'D3-LAB'}],'capabilities':{'workspace':{'configuration':True},'textDocument':{'publishDiagnostics':{}}}},1)
pump(3)
assert 1 in responses and 'result' in responses[1],responses
send('initialized')
# Open every app source so the response count is inspectable; no editor or window control.
files=sorted((ROOT/'scripts').rglob('*.lua'))
for f in files: send('textDocument/didOpen',{'textDocument':{'uri':f.as_uri(),'languageId':'lua','version':1,'text':f.read_text(encoding='utf-8')}})
pump(12)
send('shutdown',identity=2); pump(1); send('exit')
try: p.wait(timeout=5)
except subprocess.TimeoutExpired: p.terminate(); p.wait(timeout=5)
local={uri:items for uri,items in diagnostics.items() if '/scripts/' in uri}
errors=sum(d.get('severity')==1 for ds in local.values() for d in ds)
warnings=sum(d.get('severity')==2 for ds in local.values() for d in ds)
report={'time':datetime.datetime.now(datetime.timezone.utc).isoformat(),'command':ARGS,'config':CONFIG,'exit_code':p.returncode,'opened_files':len(files),'diagnostic_publications':len(diagnostics),'app_errors':errors,'app_warnings':warnings,'diagnostics':local,'stderr':stderr,'protocol_messages':messages,'sources':{str(f.relative_to(ROOT)):hashlib.sha256(f.read_bytes()).hexdigest() for f in files}}
(OUT/'diagnostics.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k in ('opened_files','diagnostic_publications','app_errors','app_warnings','exit_code')}))
for uri,ds in local.items():
    for d in ds:
        if d.get('severity',4)<=2: print(uri.split('/scripts/')[-1],d['range']['start']['line']+1,d.get('code'),d['message'])
if not diagnostics: raise SystemExit('No diagnostics received; validation inconclusive')
if errors: raise SystemExit(1)
