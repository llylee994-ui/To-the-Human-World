"""Capture/operate only this checkout's verified launch. Real OS mouse, no Lua injection.
Requires existing Pillow and psutil. Output stays in the launch's .windows-runs folder.
"""
from pathlib import Path
import argparse,ctypes as C,datetime,json,time
from ctypes import wintypes as W
import psutil
from PIL import ImageGrab
ROOT=Path(__file__).resolve().parents[1]
def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--run',required=True,type=Path);parser.add_argument('--capture',default='window')
 parser.add_argument('--click',type=int,nargs=2);parser.add_argument('--move',type=int,nargs=2)
 parser.add_argument('--wait',type=float,default=1);parser.add_argument('--sample',type=float,default=0);parser.add_argument('--close',action='store_true')
 args=parser.parse_args();out=args.run.resolve()
 assert out.is_relative_to((ROOT/'.windows-runs').resolve()) and out.is_relative_to(ROOT)
 assert args.capture and all(c.isalnum() or c in '-_' for c in args.capture)
 assert 0<=args.wait<=30 and 0<=args.sample<=30
 receipt=json.loads((out/'launch.json').read_text());pid=receipt['pid'];process=psutil.Process(pid)
 assert Path(process.exe()).resolve()==(ROOT/'.runtime-windows/UrhoXRuntime.exe').resolve()
 assert Path(receipt['cwd']).resolve()==ROOT
 assert abs(process.create_time()-datetime.datetime.fromisoformat(receipt['utc']).timestamp())<15,'Stale PID/receipt'
 user=C.WinDLL('user32',use_last_error=True)
 user.SetProcessDpiAwarenessContext.argtypes=[C.c_void_p];user.SetProcessDpiAwarenessContext(C.c_void_p(-4))
 user.GetForegroundWindow.restype=W.HWND
 user.GetClientRect.argtypes=[W.HWND,C.POINTER(W.RECT)];user.ClientToScreen.argtypes=[W.HWND,C.POINTER(W.POINT)]
 user.SetForegroundWindow.argtypes=[W.HWND];user.ShowWindow.argtypes=[W.HWND,C.c_int]
 user.PostMessageW.argtypes=[W.HWND,W.UINT,W.WPARAM,W.LPARAM]
 user.GetWindowThreadProcessId.argtypes=[W.HWND,C.POINTER(W.DWORD)];user.IsWindowVisible.argtypes=[W.HWND]
 windows=[]
 @C.WINFUNCTYPE(W.BOOL,W.HWND,W.LPARAM)
 def enum(hwnd,_):
  owner=W.DWORD();user.GetWindowThreadProcessId(hwnd,C.byref(owner))
  if owner.value==pid and user.IsWindowVisible(hwnd):
   rect=W.RECT();user.GetClientRect(hwnd,C.byref(rect))
   if rect.right>500 and rect.bottom>300:windows.append(hwnd)
  return True
 user.EnumWindows(enum,0);assert len(windows)==1,('Expected one game window',windows);hwnd=windows[0]
 user.ShowWindow(hwnd,9);user.SetForegroundWindow(hwnd);time.sleep(.3)
 assert user.GetForegroundWindow()==hwnd,'Game not foreground; no input'
 rect=W.RECT();origin=W.POINT(0,0);assert user.GetClientRect(hwnd,C.byref(rect));assert user.ClientToScreen(hwnd,C.byref(origin))
 record={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'pid':pid,'clientSize':[rect.right,rect.bottom],'capture':args.capture,'method':'visible game client pixels; real Windows mouse events'}
 point=args.click or args.move
 if point:
  assert 0<=point[0]<rect.right and 0<=point[1]<rect.bottom
  assert user.SetCursorPos(origin.x+point[0],origin.y+point[1]);time.sleep(.15)
  assert user.GetForegroundWindow()==hwnd,'Focus changed; no click'
  if args.click:
   user.mouse_event(0x0002,0,0,0,0);time.sleep(.12);user.mouse_event(0x0004,0,0,0,0)
  record['click' if args.click else 'move']=point
 time.sleep(args.wait);samples=[];end=time.monotonic()+args.sample
 while True:
  info=process.memory_info();samples.append({'unix':time.time(),'rssBytes':info.rss,'peakWorkingSetBytes':getattr(info,'peak_wset',None),'privateBytes':getattr(info,'private',None)})
  if time.monotonic()>=end:break
  time.sleep(.5)
 assert user.GetForegroundWindow()==hwnd,'Focus changed; screenshot skipped'
 target=out/(args.capture+'.png');assert not target.exists(),'Choose a new capture name'
 ImageGrab.grab(bbox=(origin.x,origin.y,origin.x+rect.right,origin.y+rect.bottom)).save(target)
 record.update(file=str(target.relative_to(ROOT)),samples=samples)
 with (out/'os-events.jsonl').open('a',encoding='utf-8') as f:f.write(json.dumps(record,ensure_ascii=False)+'\n')
 print(json.dumps(record,ensure_ascii=False))
 if args.close:user.PostMessageW(hwnd,0x0010,0,0)
if __name__=='__main__':main()
