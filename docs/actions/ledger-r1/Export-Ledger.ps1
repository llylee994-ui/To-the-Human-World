param(
    [string]$Generated = 'C:\Users\YINGYI\.codex\generated_images\01a12584-8e9b-79e0-af65-6908469a0073\exec-8f3f0c5a-b025-41f1-a76b-6153e19413c0.png',
    [string]$HomeImage = 'C:\WINDOWS\TEMP\codex-clipboard-82d96881-3cfe-43ed-b167-c8f53df3f41b.png',
    [string]$AssetDirectory = 'D:\taptap\To-the-Human-World\scripts\素材'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$drawingReferences=@([System.Drawing.Bitmap].Assembly.Location,[System.Drawing.Rectangle].Assembly.Location)
Add-Type -ReferencedAssemblies $drawingReferences -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class LedgerPixels {
    public static long[] Inspect(Bitmap b, int threshold) {
        var area = new Rectangle(0, 0, b.Width, b.Height);
        var data = b.LockBits(area, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        try {
            var bytes = new byte[Math.Abs(data.Stride) * b.Height];
            Marshal.Copy(data.Scan0, bytes, 0, bytes.Length);
            long zero=0, partial=0, opaque=0, nearOpaque=0, border=0;
            int x0=b.Width, y0=b.Height, x1=-1, y1=-1, lo=255, hi=0;
            for (int y=0; y<b.Height; y++) for (int x=0; x<b.Width; x++) {
                int a=bytes[y*data.Stride+x*4+3];
                lo=Math.Min(lo,a); hi=Math.Max(hi,a);
                if(a==0) zero++; else if(a==255) opaque++; else partial++;
                if(a>=250) nearOpaque++;
                if(a>threshold) { x0=Math.Min(x0,x); y0=Math.Min(y0,y); x1=Math.Max(x1,x); y1=Math.Max(y1,y); }
                if(a>0 && (x==0 || y==0 || x==b.Width-1 || y==b.Height-1)) border++;
            }
            return new long[]{b.Width,b.Height,lo,hi,zero,partial,opaque,nearOpaque,x0,y0,x1+1,y1+1,border};
        } finally { b.UnlockBits(data); }
    }
    public static long[] Difference(Bitmap a, Bitmap b, Rectangle allowed) {
        long outside=0, total=0; int x0=a.Width,y0=a.Height,x1=-1,y1=-1;
        for(int y=0;y<a.Height;y++) for(int x=0;x<a.Width;x++) {
            if(a.GetPixel(x,y).ToArgb()!=b.GetPixel(x,y).ToArgb()) {
                total++; if(!allowed.Contains(x,y)) outside++;
                x0=Math.Min(x0,x); y0=Math.Min(y0,y); x1=Math.Max(x1,x); y1=Math.Max(y1,y);
            }
        }
        return new long[]{total,outside,x0,y0,x1+1,y1+1};
    }
}
'@
function New-Canvas([int]$Width,[int]$Height) {
    return [System.Drawing.Bitmap]::new($Width,$Height,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
}
function Configure-Graphics($Graphics) {
    $Graphics.CompositingMode=[System.Drawing.Drawing2D.CompositingMode]::SourceOver
    $Graphics.CompositingQuality=[System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $Graphics.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $Graphics.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $Graphics.TextRenderingHint=[System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
}
function Save-NewPng($Bitmap,[string]$Path) {
    if(Test-Path -LiteralPath $Path) { throw "Refusing to overwrite: $Path" }
    $Bitmap.Save($Path,[System.Drawing.Imaging.ImageFormat]::Png)
}
function Measure-Alpha($Bitmap) {
    $s=[LedgerPixels]::Inspect($Bitmap,0)
    $s8=[LedgerPixels]::Inspect($Bitmap,7)
    return [ordered]@{width=$s[0];height=$s[1];alphaMin=$s[2];alphaMax=$s[3];transparent=$s[4];partial=$s[5];opaque=$s[6];alphaAtLeast250=$s[7];boundsAlphaPositive=@($s[8],$s[9],$s[10],$s[11]);boundsAlphaAtLeast8=@($s8[8],$s8[9],$s8[10],$s8[11]);nonzeroOuterEdgePixels=$s[12]}
}
$assetPath=Join-Path $AssetDirectory '账签_空白_透明_v01.png'
$previewPath=Join-Path $AssetDirectory '预览_账签_主页左上角_v01.png'
$checkPath=Join-Path $AssetDirectory '预览_账签_手机横屏与透明检查_v01.png'
foreach($path in @($previewPath,$checkPath)) { if(Test-Path -LiteralPath $path) { throw "Output exists: $path" } }
$sourceHash=(Get-FileHash -LiteralPath $HomeImage -Algorithm SHA256).Hash
$raw=[System.Drawing.Bitmap]::new($Generated)
$rawStats=Measure-Alpha $raw
$b=$rawStats.boundsAlphaPositive
$pad=8
$cropX=[Math]::Max(0,$b[0]-$pad); $cropY=[Math]::Max(0,$b[1]-$pad)
$cropRight=[Math]::Min($raw.Width,$b[2]+$pad); $cropBottom=[Math]::Min($raw.Height,$b[3]+$pad)
$crop=[System.Drawing.Rectangle]::new($cropX,$cropY,$cropRight-$cropX,$cropBottom-$cropY)
# Mechanical export only: copy source RGBA pixels, no color edit or alpha thresholding.
$asset=$raw.Clone($crop,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
if(Test-Path -LiteralPath $assetPath) {
    $existingAsset=[System.Drawing.Bitmap]::new($assetPath)
    if($existingAsset.Width -ne $asset.Width -or $existingAsset.Height -ne $asset.Height) { throw 'Existing asset differs in size' }
    $assetDifference=[LedgerPixels]::Difference($existingAsset,$asset,[System.Drawing.Rectangle]::Empty)
    $existingAsset.Dispose()
    if($assetDifference[0] -ne 0) { throw 'Existing asset differs in pixels' }
} else { Save-NewPng $asset $assetPath }
$assetStats=Measure-Alpha $asset
$homeBitmap=[System.Drawing.Bitmap]::new($HomeImage)
$preview=New-Canvas $homeBitmap.Width $homeBitmap.Height
$g=[System.Drawing.Graphics]::FromImage($preview)
Configure-Graphics $g
$g.DrawImageUnscaled($homeBitmap,0,0)
$drawX=36; $drawY=32; $drawW=520; $drawH=[int][Math]::Round($drawW*$asset.Height/$asset.Width)
$placement=[System.Drawing.Rectangle]::new($drawX,$drawY,$drawW,$drawH)
$g.DrawImage($asset,$placement)
# Runtime-text placeholders exist ONLY in the composite preview.
$ink=[System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255,67,54,40))
$hintInk=[System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255,95,79,60))
$mainFont=[System.Drawing.Font]::new('Microsoft YaHei',42,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
$hintFont=[System.Drawing.Font]::new('Microsoft YaHei',30,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
$format=[System.Drawing.StringFormat]::GenericTypographic.Clone()
$dateText='第 18 天'; $coinText='金币 1,280'; $hintText='点击收工'
$g.DrawString($dateText,$mainFont,$ink,[System.Drawing.PointF]::new(80,92),$format)
$g.DrawString($hintText,$hintFont,$hintInk,[System.Drawing.PointF]::new(86,145),$format)
$g.DrawString($coinText,$mainFont,$ink,[System.Drawing.PointF]::new(306,108),$format)
$dateMeasure=$g.MeasureString($dateText,$mainFont,1000,$format)
$coinMeasure=$g.MeasureString($coinText,$mainFont,1000,$format)
$g.Dispose()
Save-NewPng $preview $previewPath
$diff=[LedgerPixels]::Difference($homeBitmap,$preview,[System.Drawing.Rectangle]::new(34,30,524,$drawH+4))

# Evidence sheet: the two full phone-size views and two matte tests use the same PNG.
$sheet=New-Canvas 1720 1020
$g=[System.Drawing.Graphics]::FromImage($sheet); Configure-Graphics $g
$g.Clear([System.Drawing.Color]::FromArgb(244,243,239))
$labelFont=[System.Drawing.Font]::new('Microsoft YaHei',21,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
$g.DrawString('16:9 静态缩略 · 800 × 450',$labelFont,$ink,20,14)
$g.DrawString('19.5:9 静态等比适配 · 844 × 390',$labelFont,$ink,850,14)
$g.DrawImage($preview,[System.Drawing.Rectangle]::new(20,55,800,450))
$dark=[System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(40,43,38))
$g.FillRectangle($dark,850,55,844,390)
$g.DrawImage($preview,[System.Drawing.Rectangle]::new(925,55,693,390))
$g.DrawString('浅色底 · 相同透明素材，无文字',$labelFont,$ink,20,542)
$g.DrawString('深色底 · 检查半透明投影与轮廓',$labelFont,$ink,850,542)
$g.FillRectangle([System.Drawing.Brushes]::White,20,583,800,290)
$g.FillRectangle($dark,850,583,844,290)
$testW=760; $testH=[int][Math]::Round($testW*$asset.Height/$asset.Width)
$g.DrawImage($asset,[System.Drawing.Rectangle]::new(40,600,$testW,$testH))
$g.DrawImage($asset,[System.Drawing.Rectangle]::new(890,600,$testW,$testH))
$g.DrawString('仅静态排版检查：独立 PNG 无文字；真机安全区与日期点击由 C 接入验收。',$labelFont,$ink,20,930)
$g.Dispose(); Save-NewPng $sheet $checkPath
$result=[ordered]@{
    sourceSHA256=$sourceHash;sourceUnchanged=($sourceHash -eq (Get-FileHash -LiteralPath $HomeImage -Algorithm SHA256).Hash)
    raw=$rawStats;crop=@($crop.X,$crop.Y,$crop.Width,$crop.Height);export=$assetStats
    placement=@($drawX,$drawY,$drawW,$drawH);dateTextWidth=$dateMeasure.Width;coinTextWidth=$coinMeasure.Width
    changedPixels=$diff[0];changedOutsideLedgerRectangle=$diff[1];differenceBounds=@($diff[2],$diff[3],$diff[4],$diff[5])
    netTopApprox=385;ledgerBottom=($drawY+$drawH);gapToNetApprox=(385-$drawY-$drawH)
    fontPreviewSourcePx=42;hintPreviewSourcePx=30;phone800MainPx=(42*800/1920);phone800HintPx=(30*800/1920)
    paths=@($assetPath,$previewPath,$checkPath)
}
$result | ConvertTo-Json -Depth 6
foreach($object in @($format,$mainFont,$hintFont,$labelFont,$ink,$hintInk,$dark,$raw,$asset,$homeBitmap,$preview,$sheet)) { $object.Dispose() }
