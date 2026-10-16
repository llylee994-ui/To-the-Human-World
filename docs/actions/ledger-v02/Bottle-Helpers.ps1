param(
    [string]$AssetDirectory='D:\taptap\To-the-Human-World\scripts\素材\双瓶标签_v02',
    [string]$HomeImage='C:\WINDOWS\TEMP\codex-clipboard-18ab0545-37c4-4733-908d-e3c6e76f9237.png',
    [switch]$Draft
)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$drawingReferences=@([System.Drawing.Bitmap].Assembly.Location,[System.Drawing.Rectangle].Assembly.Location)
Add-Type -ReferencedAssemblies $drawingReferences -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class BottlePixels {
  public static long[] Inspect(Bitmap b,int threshold) {
    var d=b.LockBits(new Rectangle(0,0,b.Width,b.Height),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
    try {
      byte[] buf=new byte[Math.Abs(d.Stride)*b.Height]; Marshal.Copy(d.Scan0,buf,0,buf.Length);
      long zero=0,partial=0,opaque=0,border=0; int x0=b.Width,y0=b.Height,x1=-1,y1=-1;
      for(int y=0;y<b.Height;y++) for(int x=0;x<b.Width;x++) {
        int a=buf[y*d.Stride+x*4+3];
        if(a==0)zero++; else if(a==255)opaque++; else partial++;
        if(a>threshold){x0=Math.Min(x0,x);y0=Math.Min(y0,y);x1=Math.Max(x1,x);y1=Math.Max(y1,y);}
        if(a>0&&(x==0||y==0||x==b.Width-1||y==b.Height-1))border++;
      }
      return new long[]{b.Width,b.Height,zero,partial,opaque,x0,y0,x1+1,y1+1,border};
    } finally {b.UnlockBits(d);}
  }
  public static double[] RegionAlpha(Bitmap b,Rectangle r) {
    int lo=255,hi=0; long sum=0,count=0;
    for(int y=r.Top;y<r.Bottom;y++) for(int x=r.Left;x<r.Right;x++) {
      int a=b.GetPixel(x,y).A;lo=Math.Min(lo,a);hi=Math.Max(hi,a);sum+=a;count++;
    }
    return new double[]{lo,hi,(double)sum/count};
  }
  public static long[] Diff(Bitmap a,Bitmap b,Rectangle[] allowed) {
    long count=0,outside=0;int x0=a.Width,y0=a.Height,x1=-1,y1=-1;
    for(int y=0;y<a.Height;y++)for(int x=0;x<a.Width;x++){
      if(a.GetPixel(x,y).ToArgb()==b.GetPixel(x,y).ToArgb())continue;
      count++;bool ok=false;foreach(var r in allowed)if(r.Contains(x,y)){ok=true;break;}
      if(!ok)outside++;x0=Math.Min(x0,x);y0=Math.Min(y0,y);x1=Math.Max(x1,x);y1=Math.Max(y1,y);
    }
    return new long[]{count,outside,x0,y0,x1+1,y1+1};
  }
  public static int FontWeight(byte[] b) {
    int n=(b[4]<<8)|b[5];
    for(int i=0;i<n;i++) {int p=12+i*16;
      if(b[p]==79&&b[p+1]==83&&b[p+2]==47&&b[p+3]==50){
        int off=(b[p+8]<<24)|(b[p+9]<<16)|(b[p+10]<<8)|b[p+11];
        return (b[off+4]<<8)|b[off+5];
      }
    } return -1;
  }
}
'@
function Configure-Graphics($g) {
    $g.CompositingMode=[System.Drawing.Drawing2D.CompositingMode]::SourceOver
    $g.CompositingQuality=[System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
}
function New-Canvas([int]$w,[int]$h) {return [System.Drawing.Bitmap]::new($w,$h,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)}
function Save-NewPng($b,[string]$name) {
    $path=Join-Path $script:OutputDirectory $name
    if(Test-Path -LiteralPath $path){throw "Refusing to overwrite $path"}
    $b.Save($path,[System.Drawing.Imaging.ImageFormat]::Png)
}
function Get-Alpha($b) {
    $s=[BottlePixels]::Inspect($b,0);$s8=[BottlePixels]::Inspect($b,7)
    return [ordered]@{width=$s[0];height=$s[1];alphaZero=$s[2];alphaPartial=$s[3];alphaOpaque=$s[4];bboxPositive=@($s[5],$s[6],$s[7],$s[8]);bboxAtLeast8=@($s8[5],$s8[6],$s8[7],$s8[8]);outerNonzero=$s[9]}
}
function Crop-Asset([string]$rawPath,[string]$name) {
    $raw=[System.Drawing.Bitmap]::new($rawPath);$s=Get-Alpha $raw;$v=$s.bboxAtLeast8
    # Generated files contain remote alpha=1..7 dust reaching the original canvas edges.
    # Crop the actual outline (alpha>=8) plus 12px feather margin; never change kept alpha.
    $x=[Math]::Max(0,$v[0]-12);$y=[Math]::Max(0,$v[1]-12)
    $r=[Math]::Min($raw.Width,$v[2]+12);$bottom=[Math]::Min($raw.Height,$v[3]+12)
    $crop=[System.Drawing.Rectangle]::new($x,$y,$r-$x,$bottom-$y)
    # Only copy/crop existing RGBA pixels. No alpha replacement, color key or artwork edits.
    $b=$raw.Clone($crop,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $path=Join-Path $AssetDirectory $name
    if(Test-Path -LiteralPath $path) {
        $old=[System.Drawing.Bitmap]::new($path)
        if($old.Width -ne $b.Width -or $old.Height -ne $b.Height){throw 'Existing asset size changed'}
        $diff=[BottlePixels]::Diff($old,$b,@())
        $old.Dispose();if($diff[0] -ne 0){throw 'Existing asset pixels changed'}
    } else {$b.Save($path,[System.Drawing.Imaging.ImageFormat]::Png)}
    $stats=Get-Alpha $b
    $raw.Dispose()
    return @{bitmap=$b;crop=$crop;stats=$stats;raw=$s;path=$path}
}
function Glyph-Path([string]$digits,$family,[single]$size) {
    $p=[System.Drawing.Drawing2D.GraphicsPath]::new()
    $p.AddString($digits,$family,0,$size,[System.Drawing.PointF]::new(0,0),[System.Drawing.StringFormat]::GenericTypographic)
    return ,$p
}
function Draw-Number($g,[string]$digits,$family,[single]$cx,[single]$cy,[single]$size) {
    $p=Glyph-Path $digits $family $size;$bounds=$p.GetBounds()
    $m=[System.Drawing.Drawing2D.Matrix]::new();$m.Translate($cx-$bounds.X-$bounds.Width/2,$cy-$bounds.Y-$bounds.Height/2);$p.Transform($m);$m.Dispose()
    $shade=$p.Clone();$m=[System.Drawing.Drawing2D.Matrix]::new();$m.Translate(1.1,1.4);$shade.Transform($m)
    $g.FillPath($script:ShadowBrush,$shade)
    $g.FillPath($script:NumberBrush,$p)
    # A subtle sub-pixel warm rim and shallow shade coordinate with the stone prefix.
    $g.DrawPath($script:NumberRim,$p)
    $drawBounds=$p.GetBounds()
    $shade.Dispose();$p.Dispose();$m.Dispose()
    return $drawBounds
}
function Draw-Bottle($g,$entry,[single]$x,[single]$y,[single]$w,[string]$digits,$family) {
    $scale=$w/$entry.bitmap.Width;$h=$entry.bitmap.Height*$scale
    $g.DrawImage($entry.bitmap,[System.Drawing.RectangleF]::new($x,$y,$w,$h))
    $region=$entry.numberRegion
    $cx=$x+($region.X+$region.Width/2)*$scale;$cy=$y+($region.Y+$region.Height/2)*$scale
    if($digits){[void](Draw-Number $g $digits $family $cx $cy ($script:EmSize*$w/400))}
}

