param([int]$RuntimePid,[string]$Output,[int]$ClickX=-1,[int]$ClickY=-1,[int]$ClientWidth=0,[int]$ClientHeight=0)
$ErrorActionPreference='Stop'
# Invoke with Windows PowerShell (powershell.exe), whose System.Drawing is inbox.
# Target one verified Maker process. Never move the global cursor or send keys.
Add-Type -ReferencedAssemblies System.Drawing @'
using System;using System.Text;using System.Drawing;using System.Drawing.Imaging;using System.Runtime.InteropServices;
public class HomeEvidence {
 public delegate bool E(IntPtr h,IntPtr p);
 [StructLayout(LayoutKind.Sequential)] public struct R {public int l,t,r,b;}
 [DllImport("user32.dll")] static extern bool EnumWindows(E e,IntPtr p);
 [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h,out uint p);
 [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr h,out R r);
 [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h,out R r);
 [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h,IntPtr dc,uint f);
 [DllImport("user32.dll")] static extern bool PostMessage(IntPtr h,uint m,IntPtr w,IntPtr l);
 [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h,IntPtr a,int x,int y,int w,int z,uint flags);
 [DllImport("user32.dll")] static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
 public static IntPtr Find(uint pid){IntPtr found=IntPtr.Zero;EnumWindows((h,p)=>{uint id;GetWindowThreadProcessId(h,out id);if(id==pid&&IsWindowVisible(h))found=h;return true;},IntPtr.Zero);if(found==IntPtr.Zero)throw new Exception("No visible Maker window for PID "+pid);return found;}
 public static void Run(uint pid,string path,int x,int y,int w,int h){SetThreadDpiAwarenessContext(new IntPtr(-4));var handle=Find(pid);R r;GetClientRect(handle,out r);
  if(w>0&&h>0){R outer;GetWindowRect(handle,out outer);SetWindowPos(handle,IntPtr.Zero,0,0,w+outer.r-outer.l-r.r,h+outer.b-outer.t-r.b,22);System.Threading.Thread.Sleep(800);GetClientRect(handle,out r);}
  if(x>=0&&y>=0){if(x>=r.r||y>=r.b)throw new Exception("Click outside target client");var point=new IntPtr((y<<16)|x);PostMessage(handle,0x200,IntPtr.Zero,point);PostMessage(handle,0x201,new IntPtr(1),point);System.Threading.Thread.Sleep(80);PostMessage(handle,0x202,IntPtr.Zero,point);System.Threading.Thread.Sleep(600);}
  if(!String.IsNullOrEmpty(path)){using(var b=new Bitmap(r.r,r.b)){using(var g=Graphics.FromImage(b)){var dc=g.GetHdc();bool ok=PrintWindow(handle,dc,3);g.ReleaseHdc(dc);if(!ok)throw new Exception("PrintWindow failed");}b.Save(path,ImageFormat.Png);}}
  Console.WriteLine("Maker PID="+pid+" HWND="+handle+" client="+r.r+"x"+r.b+" screenshot="+path);
 }
}
'@
[HomeEvidence]::Run($RuntimePid,$Output,$ClickX,$ClickY,$ClientWidth,$ClientHeight)
