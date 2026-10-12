"""Offline Lua 5.4 checks. cjson adapter only; no native rendering claim."""
from pathlib import Path
import sys,json,datetime,hashlib,traceback
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/vendor'))
from lupa.lua54 import LuaRuntime,lua_type
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("package.path = ... .. '/scripts/?.lua;' .. ... .. '/scripts/?/init.lua;' .. package.path",ROOT.as_posix(),ROOT.as_posix())
def plain(v):
    if lua_type(v)!='table': return v
    keys=list(v.keys())
    if keys and set(keys)==set(range(1,len(keys)+1)): return [plain(v[i]) for i in range(1,len(keys)+1)]
    return {str(k):plain(x) for k,x in v.items()}
def table(v):
    if isinstance(v,dict): return lua.table_from({k:table(x) for k,x in v.items()})
    if isinstance(v,list): return lua.table_from([table(x) for x in v])
    return v
logs=[]
def log(*args):
    s=' '.join(map(str,args)); logs.append(s); print(s,flush=True)
lua.globals().print=log
lua.globals().cjson=lua.table_from({'encode':lambda v:json.dumps(plain(v),ensure_ascii=False,allow_nan=False),'decode':lambda s:table(json.loads(s))})
lua.execute('''
    File=function() error("DISK STORAGE FORBIDDEN") end
    fileSystem=setmetatable({}, {__index=function() error("FILESYSTEM ACCESS FORBIDDEN") end})
''')
syntax=0
for p in sorted((ROOT/'scripts').rglob('*.lua')):
    lua.execute('assert(load(...))',p.read_text(encoding='utf-8'))
    syntax+=1
log('[syntax]',syntax,'Lua files compiled under',lua.eval('_VERSION'))
failure=None
try:
    result=plain(lua.eval('require("lab.tests.Checks").Run')())
except Exception:
    failure=traceback.format_exc(); log(failure); result=[]
report={'timestamp':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'FAIL' if failure else 'PASS','failure':failure,'runtime':'Lupa Lua 5.4; copied existing dependency; no engine','syntax_files':syntax,'results':result,'log':logs,
        'tested_sources':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((ROOT/'scripts').rglob('*.lua'))}}
e=ROOT/'docs/evidence/3d-lab-r3'
(e/'offline-checks.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
(e/'offline-checks.log').write_text('\n'.join(logs)+'\n',encoding='utf-8')
print('Evidence:',e/'offline-checks.json')
if failure: raise SystemExit(1)
