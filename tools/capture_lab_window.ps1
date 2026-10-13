param([Parameter(Mandatory=$true)][int]$RuntimeId,[int]$Frames=240,[int]$IntervalMs=1000,[string]$Series='native-qa',[switch]$ScreenPixels)
$ErrorActionPreference='Stop'
$labRoot='D:\taptap\To-the-Human-World-3D-Lab'
$env:TEMP=Join-Path $labRoot 'tools\tmp'
$env:TMP=$env:TEMP
$out=Join-Path $labRoot ('docs\evidence\3d-lab-r3\native\'+$Series)
$resolved=[IO.Path]::GetFullPath($out)
if (-not $resolved.StartsWith($labRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Output outside lab' }
New-Item -ItemType Directory -Path $out -Force | Out-Null
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class LabWindowRead {
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
 [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
 [StructLayout(LayoutKind.Sequential)] public struct Rect {public int Left,Top,Right,Bottom;}
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h,out Rect r);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h,out uint id);
 [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h,IntPtr dc,uint flags);
}
'@
[void][LabWindowRead]::SetThreadDpiAwarenessContext([IntPtr](-4))
$windowDeadline=[DateTime]::UtcNow.AddSeconds(60)
for ($i=0;$i -lt $Frames;$i++) {
 $runtime=Get-Process -Id $RuntimeId -ErrorAction SilentlyContinue
 if (-not $runtime) { Write-Output 'Known Runtime ended; capture stopped, no restart'; break }
 if ($runtime.ProcessName -ne 'UrhoXRuntime' -or $runtime.Path -ne (Join-Path $labRoot '.runtime\UrhoXRuntime.exe')) { throw 'Unexpected process identity' }
 if (-not $runtime.MainWindowHandle) {
  if ([DateTime]::UtcNow -gt $windowDeadline) { Write-Output 'Known lab title unavailable; no other window captured'; break }
  Start-Sleep -Milliseconds 500; $i--; continue
 }
 $h=$runtime.MainWindowHandle
 if ([LabWindowRead]::IsIconic($h)) {Write-Output 'Owned window minimized; cached PrintWindow pixels are not live acceptance'; break}
 [uint32]$windowProcess=0
 [void][LabWindowRead]::GetWindowThreadProcessId($h,[ref]$windowProcess)
 if ($windowProcess -ne $RuntimeId) { throw 'Window ownership changed' }
 $rect=New-Object LabWindowRead+Rect
 if (-not [LabWindowRead]::GetWindowRect($h,[ref]$rect)) { throw 'Window bounds unavailable' }
 $width=$rect.Right-$rect.Left; $height=$rect.Bottom-$rect.Top
 if ($width -lt 1 -or $height -lt 1) { break }
 $stamp=[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
 $file=Join-Path $out ('{0:D4}-{1}.png' -f $i,$stamp)
 $bmp=New-Object Drawing.Bitmap($width,$height)
 $g=[Drawing.Graphics]::FromImage($bmp)
 if ($ScreenPixels) {
  if ([LabWindowRead]::GetForegroundWindow() -ne $h) { $g.Dispose();$bmp.Dispose();throw 'Screen capture requires exact owned foreground window' }
  try { $g.CopyFromScreen($rect.Left,$rect.Top,0,0,$bmp.Size);$ok=$true } finally { $g.Dispose() }
 } else {
  $dc=$g.GetHdc()
  try { $ok=[LabWindowRead]::PrintWindow($h,$dc,2) } finally { $g.ReleaseHdc($dc);$g.Dispose() }
 }
 try { if ($ok) { $bmp.Save($file,[Drawing.Imaging.ImageFormat]::Png) } } finally { $bmp.Dispose() }
 @{utc=$stamp;runtime_pid=$RuntimeId;success=$ok;width=$width;height=$height;file=[IO.Path]::GetFileName($file);method=$(if($ScreenPixels){'CopyFromScreen exact owned foreground window rectangle'}else{'PrintWindow own lab HWND'})} | ConvertTo-Json -Compress | Add-Content (Join-Path $out 'frames.jsonl') -Encoding UTF8
 if ($i % 20 -eq 0) { Write-Output "$Series frame=$i utc=$stamp size=${width}x${height} captured=$ok" }
 Start-Sleep -Milliseconds $IntervalMs
}
