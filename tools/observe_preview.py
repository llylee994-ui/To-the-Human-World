"""Run the authorized official Lab preview and retain its native exit status.

Read-only process observation: no input, focus, window moves or foreign process
termination. Only handles whose executable is the isolated Lab Runtime are kept.
"""
import argparse
import ctypes
from ctypes import wintypes
import datetime
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
assert str(ROOT).lower() == r"d:\taptap\to-the-human-world-3d-lab"
K = ctypes.WinDLL("kernel32", use_last_error=True)
P = ctypes.WinDLL("psapi", use_last_error=True)
K.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
K.OpenProcess.restype = wintypes.HANDLE
K.CloseHandle.argtypes = [wintypes.HANDLE]
K.QueryFullProcessImageNameW.argtypes = [wintypes.HANDLE,wintypes.DWORD,wintypes.LPWSTR,ctypes.POINTER(wintypes.DWORD)]
K.GetExitCodeProcess.argtypes = [wintypes.HANDLE,ctypes.POINTER(wintypes.DWORD)]
P.EnumProcesses.argtypes = [ctypes.POINTER(wintypes.DWORD),wintypes.DWORD,ctypes.POINTER(wintypes.DWORD)]

def stamp():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--label",required=True)
    parser.add_argument("--capture",action="store_true")
    args=parser.parse_args()
    assert args.label.replace("-", "").isalnum()
    output=ROOT/"docs/evidence/3d-lab-r3"/args.label
    output.mkdir(exist_ok=False)
    env=os.environ.copy()
    env.update(TAPTAP_MAKER_HOME=str(ROOT/".preview-home"),TEMP=str(ROOT/"tools/tmp"),TMP=str(ROOT/"tools/tmp"),TAPTAP_MAKER_PYTHON_BIN=r"C:\Python313\python.exe")
    runtime=ROOT/".runtime/UrhoXRuntime.exe"
    cmd=[r"D:\node.js\node.exe",r"C:\Users\YINGYI\AppData\Roaming\npm\node_modules\@taptap\maker\dist\maker.js","preview","run","--target-dir",str(ROOT),"--runtime",str(runtime),"--duration-ms","600000","--json"]
    tracked={}; seen=set(); capture=[]
    with (output/"observer.jsonl").open("a",encoding="utf-8") as events, (output/"cli-complete.log").open("wb") as raw:
        def emit(kind,**fields):
            entry={"utc":stamp(),"event":kind,**fields}
            events.write(json.dumps(entry,ensure_ascii=False)+"\n");events.flush()
            print(json.dumps(entry,ensure_ascii=False),flush=True)
        emit("authorized_launch",runtime=str(runtime),duration_ms=600000)
        process=subprocess.Popen(cmd,cwd=ROOT,env=env,stdout=raw,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        while process.poll() is None or tracked:
            ids=(wintypes.DWORD*8192)(); count=wintypes.DWORD()
            if P.EnumProcesses(ids,ctypes.sizeof(ids),ctypes.byref(count)):
                for pid in ids[:count.value//ctypes.sizeof(wintypes.DWORD)]:
                    if not pid or pid in seen or pid in tracked:continue
                    handle=K.OpenProcess(0x1000,False,pid)
                    if not handle:continue
                    text=ctypes.create_unicode_buffer(32768);size=wintypes.DWORD(len(text))
                    if K.QueryFullProcessImageNameW(handle,0,text,ctypes.byref(size)) and text.value.lower()==str(runtime).lower():
                        tracked[pid]=handle;seen.add(pid);emit("native_observed",pid=pid)
                        if args.capture:
                            # Existing helper verifies HWND ownership and title before capture.
                            log=(output/("capture-"+str(pid)+".log")).open("wb")
                            shell=r"C:\Users\YINGYI\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe"
                            c=subprocess.Popen([shell,"-NoProfile","-File",str(ROOT/"tools/capture_lab_window.ps1"),"-RuntimeId",str(pid),"-Frames","12","-IntervalMs","600","-Series",args.label+"-"+str(pid)],cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
                            capture.append((c,log))
                    else:K.CloseHandle(handle)
            for pid,handle in list(tracked.items()):
                code=wintypes.DWORD()
                if K.GetExitCodeProcess(handle,ctypes.byref(code)) and code.value!=259:
                    emit("native_exit",pid=pid,exit_code=code.value,exit_hex=f"0x{code.value:08X}")
                    K.CloseHandle(handle);del tracked[pid]
            time.sleep(0.10)
        emit("cli_exit",exit_code=process.wait())
        for proc,log in capture:
            try:proc.wait(timeout=60)
            except subprocess.TimeoutExpired:emit("capture_still_running",pid=proc.pid)
            log.close()

if __name__=="__main__":main()
