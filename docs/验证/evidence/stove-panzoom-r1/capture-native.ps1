param([int]$RuntimePid,[string]$Output,[int]$Seconds=34,[int]$Fps=10)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force -Path $Output | Out-Null
# Background capture only. No activation, sizing, pointer or keyboard injection.
Add-Type -ReferencedAssemblies System.Drawing @'
using System;using System.IO;using System.Diagnostics;using System.Drawing;using System.Drawing.Imaging;using System.Runtime.InteropServices;
public class PanZoomCapture {
 public delegate bool E(IntPtr h,IntPtr p);
 [StructLayout(LayoutKind.Sequential)] public struct R {public int l,t,r,b;}
 [DllImport("user32.dll")] static extern bool EnumWindows(E e,IntPtr p);
 [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h,out uint p);
 [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr h,out R r);
 [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h,IntPtr dc,uint flags);
 [DllImport("user32.dll")] static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
 public static void Run(uint pid,string dir,int seconds,int fps){
  SetThreadDpiAwarenessContext(new IntPtr(-4));IntPtr handle=IntPtr.Zero;
  EnumWindows((h,p)=>{uint id;GetWindowThreadProcessId(h,out id);if(id==pid&&IsWindowVisible(h))handle=h;return true;},IntPtr.Zero);
  if(handle==IntPtr.Zero)throw new Exception("No visible window for "+pid);
  var watch=Stopwatch.StartNew();int i=0;
  using(var log=new StreamWriter(Path.Combine(dir,"capture.csv"))){log.WriteLine("frame,utc,elapsed_ms,width,height");
   while(watch.Elapsed.TotalSeconds<seconds){R r;GetClientRect(handle,out r);
    var stamp=DateTime.UtcNow.ToString("o");var elapsed=watch.Elapsed.TotalMilliseconds;
    using(var b=new Bitmap(r.r,r.b)){using(var g=Graphics.FromImage(b)){var dc=g.GetHdc();bool ok=PrintWindow(handle,dc,3);g.ReleaseHdc(dc);if(!ok)throw new Exception("PrintWindow failed");}b.Save(Path.Combine(dir,String.Format("frame-{0:D4}.jpg",i)),ImageFormat.Jpeg);}
    log.WriteLine(String.Format(System.Globalization.CultureInfo.InvariantCulture,"{0},{1},{2:F3},{3},{4}",i,stamp,elapsed,r.r,r.b));log.Flush();i++;
    int delay=(int)(i*1000.0/fps-watch.Elapsed.TotalMilliseconds);if(delay>0)System.Threading.Thread.Sleep(delay);
   }
  }
  Console.WriteLine("Captured "+i+" native window frames; actual timestamps in capture.csv; PID="+pid);
 }
}
'@
[PanZoomCapture]::Run($RuntimePid,$Output,$Seconds,$Fps)
