param(
    [string]$AssetDirectory='D:\taptap\To-the-Human-World\scripts\素材\双瓶标签_v01',
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
$OutputDirectory=if($Draft){Join-Path $AssetDirectory '过程稿'}else{$AssetDirectory}
$date=Crop-Asset 'C:\Users\YINGYI\.codex\generated_images\01a12584-8e9b-79e0-af65-6908469a0073\exec-f12ae240-cfd7-44b4-ba14-b7fdeab4f51e.png' '日期瓶_DAY_透明_v01.png'
$money=Crop-Asset 'C:\Users\YINGYI\.codex\generated_images\01a12584-8e9b-79e0-af65-6908469a0073\exec-1155387e-c2eb-4e5b-907e-5188bb78790d.png' '金钱瓶_金币_透明_v01.png'
# Regions are recorded in raw-image coordinates, converted into cropped asset coordinates.
$date.numberRegion=[System.Drawing.RectangleF]::new(925-$date.crop.X,290-$date.crop.Y,600,280)
$money.numberRegion=[System.Drawing.RectangleF]::new(660-$money.crop.X,400-$money.crop.Y,800,235)
$date.placement=[System.Drawing.Rectangle]::new(24,32,400,[int][Math]::Round(400*$date.bitmap.Height/$date.bitmap.Width))
$money.placement=[System.Drawing.Rectangle]::new(24,200,400,[int][Math]::Round(400*$money.bitmap.Height/$money.bitmap.Width))
$collection=[System.Drawing.Text.PrivateFontCollection]::new()
foreach($fontFile in @('Mali-SemiBold.ttf','Itim-Regular.ttf')) {$collection.AddFontFile((Join-Path "$AssetDirectory\fonts" $fontFile))}
$mali=$collection.Families | Where-Object Name -eq 'Mali SemiBold'
$itim=$collection.Families | Where-Object Name -eq 'Itim'
if(-not $mali -or -not $itim){throw 'Requested real fonts failed to load'}
$EmSize=52
$NumberBrush=[System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255,232,216,180))
$ShadowBrush=[System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(135,68,53,36))
$NumberRim=[System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(150,252,239,211),0.55)
$LabelBrush=[System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(65,56,46))
$labelFont=[System.Drawing.Font]::new('Microsoft YaHei',22,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
$smallFont=[System.Drawing.Font]::new('Microsoft YaHei',17,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
$homeBitmap=[System.Drawing.Bitmap]::new($HomeImage)
$previewList=@();$fontInfo=@();$fits=@()
$sourceHash=(Get-FileHash -LiteralPath $HomeImage -Algorithm SHA256).Hash
foreach($item in @(@('Mali',$mali,'Mali-SemiBold.ttf'),@('Itim',$itim,'Itim-Regular.ttf'))) {
    $fontName=$item[0];$family=$item[1]
    $fontPath=Join-Path "$AssetDirectory\fonts" $item[2]
    $fontInfo+=@{name=$family.Name;file=$item[2];weight=[BottlePixels]::FontWeight([IO.File]::ReadAllBytes($fontPath));sha256=(Get-FileHash -LiteralPath $fontPath -Algorithm SHA256).Hash}
    foreach($digits in @('1','7','12','108','1280','9999')) {
        $p=Glyph-Path $digits $family $EmSize;$bb=$p.GetBounds();$p.Dispose()
        foreach($entry in @($date,$money)) {
            $scale=400/$entry.bitmap.Width;$rw=$entry.numberRegion.Width*$scale;$rh=$entry.numberRegion.Height*$scale
            $ok=($bb.Width+3 -le $rw -and $bb.Height+4 -le $rh)
            $fits+=@{font=$fontName;asset=[IO.Path]::GetFileName($entry.path);digits=$digits;glyphWidth=$bb.Width;glyphHeight=$bb.Height;regionWidth=$rw;regionHeight=$rh;fit=$ok}
            if(-not $ok){throw "Overflow $fontName $digits in $($entry.path)"}
        }
    }
    $preview=New-Canvas 1920 1080;$g=[System.Drawing.Graphics]::FromImage($preview);Configure-Graphics $g
    $g.DrawImageUnscaled($homeBitmap,0,0)
    Draw-Bottle $g $date $date.placement.X $date.placement.Y 400 '12' $family
    Draw-Bottle $g $money $money.placement.X $money.placement.Y 400 '1280' $family
    $g.Dispose()
    Save-NewPng $preview "预览_双瓶标签_${fontName}_v01.png"
    $previewList+=,$preview
}
# Neutral backgrounds: actual alpha and highlight strength, no background painted into assets.
$matte=New-Canvas 1600 630;$g=[System.Drawing.Graphics]::FromImage($matte);Configure-Graphics $g
$g.Clear([System.Drawing.Color]::FromArgb(243,240,232))
$g.DrawString('浅底 / 深底 · 同一透明 PNG · 无示例数字',$labelFont,$LabelBrush,24,12)
$dark=[System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(47,43,39));$g.FillRectangle($dark,805,56,775,550)
Draw-Bottle $g $date 30 75 735 '' $mali;Draw-Bottle $g $money 30 350 735 '' $mali
Draw-Bottle $g $date 825 75 735 '' $mali;Draw-Bottle $g $money 825 350 735 '' $mali
$g.Dispose();Save-NewPng $matte '预览_双瓶标签_透明检查_v01.png'
# Six values x two fonts x two independent bottles at the actual 1920-preview scale.
$fitSheet=New-Canvas 1740 1020;$g=[System.Drawing.Graphics]::FromImage($fitSheet);Configure-Graphics $g
$g.Clear([System.Drawing.Color]::FromArgb(240,237,229))
$g.DrawString('A · Mali SemiBold',$labelFont,$LabelBrush,24,12);$g.DrawString('B · Itim Regular',$labelFont,$LabelBrush,895,12)
$warm=[System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(102,86,67))
$values=@('1','7','12','108','1280','9999')
for($row=0;$row -lt 6;$row++) {
    $y=53+$row*155
    $g.FillRectangle($warm,20,$y,837,146);$g.FillRectangle($warm,889,$y,837,146)
    Draw-Bottle $g $date 26 ($y+8) 400 $values[$row] $mali;Draw-Bottle $g $money 447 ($y+8) 400 $values[$row] $mali
    Draw-Bottle $g $date 895 ($y+8) 400 $values[$row] $itim;Draw-Bottle $g $money 1316 ($y+8) 400 $values[$row] $itim
}
$g.DrawString('相同字号 52 px；全部数字只用于检查，不代表游戏数值上限。',$smallFont,$LabelBrush,24,988)
$g.Dispose();Save-NewPng $fitSheet '预览_双瓶标签_数字适配检查_v01.png'
# Both font previews at two static phone viewport sizes; wide view uses contain, not unverified cropping.
$phone=New-Canvas 1720 1040;$g=[System.Drawing.Graphics]::FromImage($phone);Configure-Graphics $g
$g.Clear([System.Drawing.Color]::FromArgb(243,240,232))
for($i=0;$i -lt 2;$i++) {
    $x=20+$i*850;$fontName=@('Mali SemiBold','Itim Regular')[$i]
    $g.DrawString("$fontName · 800×450 静态缩略",$labelFont,$LabelBrush,$x,12)
    $g.DrawImage($previewList[$i],[System.Drawing.Rectangle]::new($x,50,800,450))
    $g.DrawString('844×390 · 等比完整显示（两侧留边）',$labelFont,$LabelBrush,$x,527)
    $g.FillRectangle($dark,$x,568,844,390)
    $g.DrawImage($previewList[$i],[System.Drawing.Rectangle]::new(($x+75),568,693,390))
}
$g.DrawString('仅静态可读性/避让检查；不是手机真机、安全区、点击或裁切适配验收。',$labelFont,$LabelBrush,20,990)
$g.Dispose();Save-NewPng $phone '预览_双瓶标签_手机检查_v01.png'
$allowed=[System.Drawing.Rectangle[]]@([System.Drawing.Rectangle]::new(22,30,404,$date.placement.Height+4),[System.Drawing.Rectangle]::new(22,198,404,$money.placement.Height+4))
$homeDiff=@();foreach($pr in $previewList){$homeDiff+=,@([BottlePixels]::Diff($homeBitmap,$pr,$allowed))}
$numAllowed=@()
foreach($entry in @($date,$money)) {
    $scale=400/$entry.bitmap.Width;$nr=$entry.numberRegion
    $numAllowed+=[System.Drawing.Rectangle]::new([int]($entry.placement.X+$nr.X*$scale-3),[int]($entry.placement.Y+$nr.Y*$scale-3),[int]($nr.Width*$scale+6),[int]($nr.Height*$scale+6))
}
$fontDiff=[BottlePixels]::Diff($previewList[0],$previewList[1],[System.Drawing.Rectangle[]]$numAllowed)
$output=[ordered]@{
    sourceSHA256=$sourceHash;sourceUnchanged=($sourceHash -eq (Get-FileHash -LiteralPath $HomeImage -Algorithm SHA256).Hash)
    date=@{stats=$date.stats;crop=@($date.crop.X,$date.crop.Y,$date.crop.Width,$date.crop.Height);placement=@($date.placement.X,$date.placement.Y,$date.placement.Width,$date.placement.Height);numberRegion=@($date.numberRegion.X,$date.numberRegion.Y,$date.numberRegion.Width,$date.numberRegion.Height);numberAreaAlpha=[BottlePixels]::RegionAlpha($date.bitmap,[System.Drawing.Rectangle]::Round($date.numberRegion))}
    money=@{stats=$money.stats;crop=@($money.crop.X,$money.crop.Y,$money.crop.Width,$money.crop.Height);placement=@($money.placement.X,$money.placement.Y,$money.placement.Width,$money.placement.Height);numberRegion=@($money.numberRegion.X,$money.numberRegion.Y,$money.numberRegion.Width,$money.numberRegion.Height);numberAreaAlpha=[BottlePixels]::RegionAlpha($money.bitmap,[System.Drawing.Rectangle]::Round($money.numberRegion))}
    fonts=$fontInfo;emSize=$EmSize;fits=$fits;homeDiff=$homeDiff;fontDiff=$fontDiff
    netTopApprox=385;moneyBottom=$money.placement.Bottom;gapToNetApprox=(385-$money.placement.Bottom)
    phone800Em=($EmSize*800/1920);phone844ContainEm=($EmSize*390/1080)
}
$output | ConvertTo-Json -Depth 9
foreach($b in @($date.bitmap,$money.bitmap,$homeBitmap,$matte,$fitSheet,$phone)+$previewList){$b.Dispose()}
foreach($o in @($collection,$NumberBrush,$ShadowBrush,$NumberRim,$LabelBrush,$labelFont,$smallFont,$dark,$warm)){$o.Dispose()}
