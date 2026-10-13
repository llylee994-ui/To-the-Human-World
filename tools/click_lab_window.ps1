param([Parameter(Mandatory=$true)][int]$RuntimeId,[Parameter(Mandatory=$true)][ValidateRange(0,1)][double]$X,[Parameter(Mandatory=$true)][ValidateRange(0,1)][double]$Y,[Parameter(Mandatory=$true)][ValidatePattern('^[a-zA-Z0-9-]+$')][string]$Label,[switch]$HoldCursor)
$ErrorActionPreference='Stop'
$labRoot='D:\taptap\To-the-Human-World-3D-Lab'
$runtime=Get-Process -Id $RuntimeId
if ($runtime.ProcessName -ne 'UrhoXRuntime' -or $runtime.Path -ne (Join-Path $labRoot '.runtime\UrhoXRuntime.exe')) {throw 'Wrong process'}
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class LabClick {
 [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
 [StructLayout(LayoutKind.Sequential)] public struct Rect {public int Left,Top,Right,Bottom;}
 [StructLayout(LayoutKind.Sequential)] public struct Point {public int X,Y;}
 [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h,out Rect r);
 [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h,ref Point p);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h,out uint p);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
 [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr h,int command);
 [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h,IntPtr after,int x,int y,int cx,int cy,uint flags);
 [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(Point p);
 [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h,uint flags);
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] public static extern bool GetCursorPos(out Point p);
 [DllImport("user32.dll")] public static extern void mouse_event(uint flags,uint dx,uint dy,uint data,UIntPtr extra);
}
'@
[void][LabClick]::SetThreadDpiAwarenessContext([IntPtr](-4))
$h=$runtime.MainWindowHandle
[uint32]$owner=0
[void][LabClick]::GetWindowThreadProcessId($h,[ref]$owner)
if ($owner -ne $RuntimeId) {throw 'Window owner mismatch'}
if ([LabClick]::IsIconic($h)) {
    [void][LabClick]::ShowWindowAsync($h,9)
    Start-Sleep -Milliseconds 400
}
if ([LabClick]::IsIconic($h)) {throw 'Lab window is minimized; no input sent'}
$rect=New-Object LabClick+Rect
if (-not [LabClick]::GetClientRect($h,[ref]$rect)) {throw 'No client rectangle'}
$point=New-Object LabClick+Point
$point.X=[int]($X*($rect.Right-$rect.Left));$point.Y=[int]($Y*($rect.Bottom-$rect.Top))
[void][LabClick]::ClientToScreen($h,[ref]$point)
$old=New-Object LabClick+Point
[void][LabClick]::GetCursorPos([ref]$old)
[void][LabClick]::SetForegroundWindow($h)
Start-Sleep -Milliseconds 200
if ([LabClick]::GetForegroundWindow() -ne $h) {
    $activate=New-Object -ComObject WScript.Shell
    [void]$activate.AppActivate($RuntimeId)
    Start-Sleep -Milliseconds 200
}
if ([LabClick]::GetForegroundWindow() -ne $h) {throw 'Foreground was not acquired; no input sent'}
[void][LabClick]::SetWindowPos($h,[IntPtr](-1),0,0,0,0,0x43)
try {
[void][LabClick]::SetCursorPos($point.X,$point.Y)
Start-Sleep -Milliseconds 100
$actual=New-Object LabClick+Point
[void][LabClick]::GetCursorPos([ref]$actual)
if ($actual.X -ne $point.X -or $actual.Y -ne $point.Y) {throw ('Cursor target changed from '+$point.X+','+$point.Y+' to '+$actual.X+','+$actual.Y+'; no click sent')}
Write-Output ('screen point '+$point.X+','+$point.Y)
if ([LabClick]::GetForegroundWindow() -ne $h) {throw 'Foreground changed; no click sent'}
if ([LabClick]::GetAncestor([LabClick]::WindowFromPoint($actual),2) -ne $h) {throw 'Target point is covered by another window; no click sent'}
[LabClick]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
Start-Sleep -Milliseconds 90
[LabClick]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
Start-Sleep -Milliseconds 200
if (-not $HoldCursor) {[void][LabClick]::SetCursorPos($old.X,$old.Y)}
@{utc=[DateTime]::UtcNow.ToString('o');pid=$RuntimeId;label=$Label;x=$X;y=$Y;clientWidth=$rect.Right;clientHeight=$rect.Bottom;method='OS left mouse down/up; exact owned foreground HWND'} | ConvertTo-Json -Compress | Add-Content -LiteralPath (Join-Path $labRoot 'docs\evidence\v035-main-interface\os-clicks.jsonl') -Encoding UTF8
Start-Sleep -Milliseconds 700
& (Join-Path $labRoot 'tools\capture_lab_window.ps1') -RuntimeId $RuntimeId -Frames 1 -Series $Label -ScreenPixels
} finally {
 [void][LabClick]::SetWindowPos($h,[IntPtr](-2),0,0,0,0,0x43)
}
