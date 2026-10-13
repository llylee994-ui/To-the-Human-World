"""One explicitly authorized official preview; observe only its exact Runtime PID.

No retries, input injection, foreign-process enumeration, focus or window moves.
The official CLI owns the bounded Runtime lifetime. This observer keeps the
native handle so a short-lived crash still has an exit code.
"""
from pathlib import Path
import argparse, ctypes, datetime, json, os, queue, subprocess, threading, time
from ctypes import wintypes as W

LAB=Path(__file__).resolve().parents[1]
assert str(LAB).lower()==r'd:\taptap\to-the-human-world-3d-lab'
parser=argparse.ArgumentParser()
parser.add_argument('--attempt',required=True)
parser.add_argument('--persistent',action='store_true',help='Official legacy external-runtime supervisor; runs until the user closes it')
args=parser.parse_args()
assert len(args.attempt)==2 and args.attempt.isdigit()
OUT=LAB/('docs/evidence/v035-main-interface/native-full-20261013-'+args.attempt)
RUNTIME=LAB/'.runtime/UrhoXRuntime.exe'
CLI=r'C:\Users\YINGYI\AppData\Roaming\npm\node_modules\@taptap\maker\dist\maker.js'
NODE=r'D:\node.js\node.exe'
K=ctypes.WinDLL('kernel32',use_last_error=True)
P=ctypes.WinDLL('psapi',use_last_error=True)
K.OpenProcess.argtypes=[W.DWORD,W.BOOL,W.DWORD];K.OpenProcess.restype=W.HANDLE
K.QueryFullProcessImageNameW.argtypes=[W.HANDLE,W.DWORD,W.LPWSTR,ctypes.POINTER(W.DWORD)]
K.GetExitCodeProcess.argtypes=[W.HANDLE,ctypes.POINTER(W.DWORD)]
K.CloseHandle.argtypes=[W.HANDLE]
K.WaitForSingleObject.argtypes=[W.HANDLE,W.DWORD];K.WaitForSingleObject.restype=W.DWORD
K.GetProcessTimes.argtypes=[W.HANDLE,ctypes.POINTER(W.FILETIME),ctypes.POINTER(W.FILETIME),ctypes.POINTER(W.FILETIME),ctypes.POINTER(W.FILETIME)]
class Memory(ctypes.Structure):
    _fields_=[('cb',W.DWORD),('PageFaultCount',W.DWORD)]+[(n,ctypes.c_size_t) for n in
        ('PeakWorkingSetSize','WorkingSetSize','QuotaPeakPagedPoolUsage','QuotaPagedPoolUsage','QuotaPeakNonPagedPoolUsage','QuotaNonPagedPoolUsage','PagefileUsage','PeakPagefileUsage','PrivateUsage')]
P.GetProcessMemoryInfo.argtypes=[W.HANDLE,ctypes.POINTER(Memory),W.DWORD]

def utc():return datetime.datetime.now(datetime.timezone.utc).isoformat()
def ticks(ft):return (ft.dwHighDateTime<<32)|ft.dwLowDateTime

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    marker=OUT/'launch-intent.json'
    assert not marker.exists(),'One-run marker exists. Do not restart this observation.'
    env=os.environ.copy();env.update(TAPTAP_MAKER_HOME=str(LAB/'.preview-home'),TEMP=str(LAB/'tools/tmp'),TMP=str(LAB/'tools/tmp'),TAPTAP_MAKER_PYTHON_BIN=r'C:\Python313\python.exe')
    base=[NODE,CLI,'preview']
    checked=subprocess.run(base+['status','--target-dir',str(LAB),'--json'],cwd=LAB,env=env,capture_output=True,timeout=30,creationflags=subprocess.CREATE_NO_WINDOW)
    (OUT/'immediate-prelaunch-status.json').write_bytes(checked.stdout)
    status=json.loads(checked.stdout)
    assert status['project_realpath'].lower()==str(LAB).lower() and not status.get('process_alive') and status.get('state') in ('stopped','failed','missing'),'Live or unknown session; refuse launch'
    prepare=json.loads((OUT/'prepare-result.json').read_text(encoding='utf-8-sig'))
    assert prepare.get('ok'),'Official full prepare did not pass'
    command=base+(['start','--legacy-wmi'] if args.persistent else ['run','--duration-ms','600000'])+['--target-dir',str(LAB),'--runtime',str(RUNTIME),'--json']
    marker.write_text(json.dumps({'utc':utc(),'authorization':'One controlled full-scene validation explicitly authorized by parent/user','command':command},indent=2),encoding='utf-8')
    launch=time.time();messages=queue.Queue();handle=None;identity=None;native_exited=False
    peak_working=peak_private=0;last_metric=0
    with (OUT/'observer.jsonl').open('a',encoding='utf-8') as events:
        def emit(event,**details):
            row={'utc':utc(),'event':event,**details}
            events.write(json.dumps(row,ensure_ascii=False)+'\n');events.flush()
            if event!='sample':print(json.dumps(row,ensure_ascii=False),flush=True)
        process=subprocess.Popen(command,cwd=LAB,env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,creationflags=subprocess.CREATE_NO_WINDOW)
        emit('cli_started',pid=process.pid)
        def drain(stream,name):
            with (OUT/name).open('wb') as raw:
                for line in iter(stream.readline,b''):
                    raw.write(line);raw.flush();messages.put(line)
            messages.put(None)
        threads=[threading.Thread(target=drain,args=(process.stdout,'cli-stdout.log'),daemon=True),threading.Thread(target=drain,args=(process.stderr,'cli-stderr.log'),daemon=True)]
        for thread in threads:thread.start()
        ended_streams=0;cli_finished_at=None
        while True:
            try:
                line=messages.get(timeout=.2)
                if line is None:ended_streams+=1
                else:
                    try:row=json.loads(line)
                    except (ValueError,UnicodeDecodeError):row={}
                    if (row.get('event')=='preview.started' or (args.persistent and row.get('state')=='running' and row.get('runtime_pid'))) and identity is None:
                        assert row['project_realpath'].lower()==str(LAB).lower()
                        assert Path(row['executable'])==RUNTIME
                        identity={k:row.get(k) for k in ('session_id','reload_id','runtime_pid','supervisor_pid','started_at','executable','project_realpath')}
                        (OUT/'owned-session.json').write_text(json.dumps(row,ensure_ascii=False,indent=2),encoding='utf-8')
                        handle=K.OpenProcess(0x100410,False,row['runtime_pid'])
                        if not handle:handle=K.OpenProcess(0x101000,False,row['runtime_pid'])
                        if handle:
                            buf=ctypes.create_unicode_buffer(32768);size=W.DWORD(len(buf))
                            assert K.QueryFullProcessImageNameW(handle,0,buf,ctypes.byref(size)) and buf.value.lower()==str(RUNTIME).lower(),'Runtime image identity mismatch'
                            created,exit_time,kernel,user=W.FILETIME(),W.FILETIME(),W.FILETIME(),W.FILETIME()
                            assert K.GetProcessTimes(handle,ctypes.byref(created),ctypes.byref(exit_time),ctypes.byref(kernel),ctypes.byref(user))
                            created_unix=ticks(created)/1e7-11644473600
                            assert created_unix>=launch-2,'PID predates this launch'
                            emit('native_handle_verified',**identity,creationUnix=created_unix)
                        else:emit('native_handle_unavailable',**identity,winerror=ctypes.get_last_error())
            except queue.Empty:pass
            if handle and not native_exited:
                if K.WaitForSingleObject(handle,0)==0:
                    code=W.DWORD();ok=K.GetExitCodeProcess(handle,ctypes.byref(code))
                    native_exited=True
                    result={'utc':utc(),'identity':identity,'exitCode':code.value if ok else None,'exitHex':f'0x{code.value:08X}' if ok else None,
                        'peakWorkingSetBytes':peak_working,'peakPrivateBytesSampled':peak_private,'secondsSinceCliLaunch':time.time()-launch}
                    (OUT/'native-exit.json').write_text(json.dumps(result,indent=2),encoding='utf-8');emit('native_exit',**result)
                elif time.monotonic()-last_metric>=1:
                    last_metric=time.monotonic();mem=Memory();mem.cb=ctypes.sizeof(mem)
                    ok=P.GetProcessMemoryInfo(handle,ctypes.byref(mem),mem.cb)
                    if ok:
                        peak_working=max(peak_working,mem.PeakWorkingSetSize);peak_private=max(peak_private,mem.PrivateUsage)
                        emit('sample',pid=identity['runtime_pid'],workingSetBytes=mem.WorkingSetSize,peakWorkingSetBytes=mem.PeakWorkingSetSize,
                            privateBytes=mem.PrivateUsage,peakPrivateBytesSampled=peak_private,secondsSinceCliLaunch=time.time()-launch)
                    else:emit('memory_query_unavailable',pid=identity['runtime_pid'],winerror=ctypes.get_last_error())
            if process.poll() is not None:
                if args.persistent and handle and not native_exited:
                    continue
                if cli_finished_at is None:cli_finished_at=time.monotonic()
                if ended_streams==2 and (not handle or native_exited):break
                if time.monotonic()-cli_finished_at>30:
                    emit('cleanup_unverified',nativeStillAlive=bool(handle and not native_exited));break
        for thread in threads:thread.join(timeout=1)
        if handle:K.CloseHandle(handle)
        final={'utc':utc(),'cliExitCode':process.poll(),'identity':identity,'nativeExitCaptured':native_exited,
            'peakWorkingSetBytes':peak_working,'peakPrivateBytesSampled':peak_private,'nativeRestarted':False}
        (OUT/'observer-final.json').write_text(json.dumps(final,indent=2),encoding='utf-8');emit('finished',**final)

if __name__=='__main__':main()
