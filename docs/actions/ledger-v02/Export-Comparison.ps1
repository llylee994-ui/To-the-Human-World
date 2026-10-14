$ErrorActionPreference='Stop'
. "$PSScriptRoot\Bottle-Helpers.ps1"
$oldRoot='D:\taptap\To-the-Human-World\scripts\素材\双瓶标签_v01'
$newRoot='D:\taptap\To-the-Human-World\scripts\素材\双瓶标签_v02'
$AssetDirectory=$newRoot;$OutputDirectory=$newRoot
$date=Crop-Asset "$newRoot\过程稿\原始_日期罐_轻量化_v02.png" '日期瓶_DAY_透明_v02.png'
$money=Crop-Asset "$newRoot\过程稿\原始_金币罐_轻量化_v02.png" '金钱瓶_金币_透明_v02.png'
$oldDate=[System.Drawing.Bitmap]::new("$oldRoot\日期瓶_DAY_透明_v01.png")
$oldMoney=[System.Drawing.Bitmap]::new("$oldRoot\金钱瓶_金币_透明_v01.png")
$homePath="$oldRoot\过程稿\参考_最新主页_r2.png"
$homeBitmap=[System.Drawing.Bitmap]::new($homePath)
$before=[System.Drawing.Bitmap]::new("$oldRoot\预览_双瓶标签_Mali_v01.png")
$collection=[System.Drawing.Text.PrivateFontCollection]::new()
$collection.AddFontFile("$oldRoot\fonts\Mali-SemiBold.ttf");$collection.AddFontFile("$oldRoot\fonts\Itim-Regular.ttf")
$mali=$collection.Families | Where-Object Name -eq 'Mali SemiBold'
$itim=$collection.Families | Where-Object Name -eq 'Itim'
$NumberBrush=[System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255,232,216,180))
$ShadowBrush=[System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(135,68,53,36))
$NumberRim=[System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(150,252,239,211),0.55)
$NumberCenters=@(@((24+1136*400/1776),(32+319*400/1776)),@((24+977*400/1810),(200+414.5*400/1810)))
$placement=@(@(24,32,400,(400*$date.bitmap.Height/$date.bitmap.Width)),@(24,200,400,(400*$money.bitmap.Height/$money.bitmap.Width)))
function Render-Home($dayBitmap,$coinBitmap,$family) {
  $result=New-Canvas 1920 1080;$g=[System.Drawing.Graphics]::FromImage($result);Configure-Graphics $g
  $g.DrawImageUnscaled($script:homeBitmap,0,0)
  $g.DrawImage($dayBitmap,[System.Drawing.RectangleF]::new(24,32,400,(400*$dayBitmap.Height/$dayBitmap.Width)))
  $g.DrawImage($coinBitmap,[System.Drawing.RectangleF]::new(24,200,400,(400*$coinBitmap.Height/$coinBitmap.Width)))
  [void](Draw-Number $g '12' $family $script:NumberCenters[0][0] $script:NumberCenters[0][1] 52)
  [void](Draw-Number $g '1280' $family $script:NumberCenters[1][0] $script:NumberCenters[1][1] 52)
  $g.Dispose();return ,$result
}
$beforeRemade=Render-Home $oldDate $oldMoney $mali
$baselineDiff=[BottlePixels]::Diff($before,$beforeRemade,@())
if($baselineDiff[0] -ne 0){throw 'Locked typography/old composition does not reproduce v01 exactly'}
$after=Render-Home $date.bitmap $money.bitmap $mali
$afterItim=Render-Home $date.bitmap $money.bitmap $itim
Save-NewPng $before '预览_修改前_Mali_v01.png'
Save-NewPng $after '预览_修改后_Mali_v02.png'
Save-NewPng $afterItim '预览_修改后_Itim_v02.png'
$labelFont=[System.Drawing.Font]::new('Microsoft YaHei',24,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
$smallFont=[System.Drawing.Font]::new('Microsoft YaHei',20,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
$ink=[System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(65,56,46))
$dark=[System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(48,46,42))

# Same home on both sides. Local crops below are also the same source rectangle and scale.
$sheet=New-Canvas 1960 1150;$g=[System.Drawing.Graphics]::FromImage($sheet);Configure-Graphics $g
$g.Clear([System.Drawing.Color]::FromArgb(243,240,232))
$g.DrawString('修改前 · v01',$labelFont,$ink,20,10);$g.DrawString('修改后 · v02',$labelFont,$ink,1000,10)
$g.DrawImage($before,[System.Drawing.Rectangle]::new(10,50,960,540));$g.DrawImage($after,[System.Drawing.Rectangle]::new(990,50,960,540))
$g.DrawString('同一区域细看 · 瓶宽400px，位置、数字、字体与字号均未改变',$smallFont,$ink,20,604)
$crop=[System.Drawing.Rectangle]::new(0,0,465,370)
$g.DrawImage($before,[System.Drawing.Rectangle]::new(190,646,581,463),$crop,[System.Drawing.GraphicsUnit]::Pixel)
$g.DrawImage($after,[System.Drawing.Rectangle]::new(1170,646,581,463),$crop,[System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose();Save-NewPng $sheet '预览_双瓶标签_前后对照_v02.png'

$matte=New-Canvas 1600 650;$g=[System.Drawing.Graphics]::FromImage($matte);Configure-Graphics $g
$g.Clear([System.Drawing.Color]::FromArgb(242,239,231));$g.FillRectangle($dark,805,50,780,580)
$g.DrawString('真实透明 · 同一PNG，浅底／深底（正式素材不含数字）',$labelFont,$ink,20,8)
foreach($i in 0,1){$b=@($date.bitmap,$money.bitmap)[$i];$y=65+$i*285;$h=735*$b.Height/$b.Width
  $g.DrawImage($b,[System.Drawing.RectangleF]::new(25,$y,735,$h));$g.DrawImage($b,[System.Drawing.RectangleF]::new(825,$y,735,$h))}
$g.Dispose();Save-NewPng $matte '预览_双瓶标签_透明检查_v02.png'

# An 800x450 phone-size comparison, plus longest-number test at exactly that scale.
$phone=New-Canvas 1660 830;$g=[System.Drawing.Graphics]::FromImage($phone);Configure-Graphics $g
$g.Clear([System.Drawing.Color]::FromArgb(243,240,232))
$g.DrawString('修改前 · 800×450 静态缩图',$labelFont,$ink,20,8);$g.DrawString('修改后 · 800×450 静态缩图',$labelFont,$ink,850,8)
$g.DrawImage($before,[System.Drawing.Rectangle]::new(20,48,800,450));$g.DrawImage($after,[System.Drawing.Rectangle]::new(850,48,800,450))
$g.DrawString('六组数字安全区复查 · 素材和字号按800/1920等比显示',$smallFont,$ink,20,518)
$values=@('1','7','12','108','1280','9999')
for($j=0;$j -lt 6;$j++){
  $x=20+$j*270;$g.FillRectangle($dark,$x,560,255,160)
  for($i=0;$i -lt 2;$i++){
    $b=@($date.bitmap,$money.bitmap)[$i];$sy=568+$i*75;$sw=400*800/1920;$h=$sw*$b.Height/$b.Width
    $g.DrawImage($b,[System.Drawing.RectangleF]::new(($x+40),$sy,$sw,$h))
    $numX=($NumberCenters[$i][0]-24)*800/1920+$x+40
    $numY=($NumberCenters[$i][1]-@(32,200)[$i])*800/1920+$sy
    [void](Draw-Number $g $values[$j] $mali $numX $numY (52*800/1920))
  }
}
$g.DrawString('只作静态美术/排版检查；不代表真机点击、安全区或更小屏幕验收。',$smallFont,$ink,20,755)
$g.Dispose();Save-NewPng $phone '预览_双瓶标签_手机前后检查_v02.png'

$allowed=[System.Drawing.Rectangle[]]@([System.Drawing.Rectangle]::new(22,30,404,142),[System.Drawing.Rectangle]::new(22,198,404,147))
$outside=[BottlePixels]::Diff($before,$after,$allowed)
$outsideHome=[BottlePixels]::Diff($homeBitmap,$after,$allowed)
$fontAllowed=[System.Drawing.Rectangle[]]@([System.Drawing.Rectangle]::new(209,69,143,70),[System.Drawing.Rectangle]::new(148,261,184,61))
$fontDiff=[BottlePixels]::Diff($after,$afterItim,$fontAllowed)
$glass=@();$stats=@();$fits=@()
foreach($i in 0,1){
  $pair=@(@($oldDate,$date.bitmap),@($oldMoney,$money.bitmap))[$i]
  foreach($v in 0,1){
    $b=$pair[$v]
    $top=[System.Drawing.Rectangle]::new([int]($b.Width*.3),[int]($b.Height*.03),[int]($b.Width*.4),[int]($b.Height*.10))
    $inner=[System.Drawing.Rectangle]::new([int]($b.Width*.5),[int]($b.Height*.3),[int]($b.Width*.25),[int]($b.Height*.3))
    $glass+=@{asset=@('date','money')[$i];version=@('v01','v02')[$v];topStrip=@([BottlePixels]::RegionAlpha($b,$top));inner=@([BottlePixels]::RegionAlpha($b,$inner))}
  }
  $entry=@($date,$money)[$i];$b=$entry.bitmap;$edgeMax=0
  for($x=0;$x -lt $b.Width;$x++){$edgeMax=[Math]::Max($edgeMax,[Math]::Max($b.GetPixel($x,0).A,$b.GetPixel($x,$b.Height-1).A))}
  for($y=0;$y -lt $b.Height;$y++){$edgeMax=[Math]::Max($edgeMax,[Math]::Max($b.GetPixel(0,$y).A,$b.GetPixel($b.Width-1,$y).A))}
  $stats+=@{file=[IO.Path]::GetFileName($entry.path);format=$b.PixelFormat.ToString();alpha=$entry.stats;crop=@($entry.crop.X,$entry.crop.Y,$entry.crop.Width,$entry.crop.Height);raw=$entry.raw;edgeAlphaMax=$edgeMax;placement=$placement[$i]}
  foreach($family in @($mali,$itim)){foreach($number in $values){
    $p=Glyph-Path $number $family 52;$bounds=$p.GetBounds();$p.Dispose()
    # Locked v01 safe zones remain valid visually in the cleared v02 body.
    $rw=@((600*400/1776),(800*400/1810))[$i];$rh=@((280*400/1776),(235*400/1810))[$i]
    $fits+=@{font=$family.Name;asset=@('date','money')[$i];number=$number;width=$bounds.Width;height=$bounds.Height;fit=($bounds.Width+3 -le $rw -and $bounds.Height+4 -le $rh)}
  }}
}
$result=[ordered]@{homeSHA256=(Get-FileHash -LiteralPath $homePath -Algorithm SHA256).Hash;assets=$stats;glassComparison=$glass;beforeReproductionDifference=$baselineDiff;beforeAfterDifference=$outside;homeDifference=$outsideHome;fontOnlyDifference=$fontDiff;digitCenters=$NumberCenters;emSize=52;fits=$fits}
$result | ConvertTo-Json -Depth 12
foreach($o in @($oldDate,$oldMoney,$date.bitmap,$money.bitmap,$homeBitmap,$before,$beforeRemade,$after,$afterItim,$sheet,$matte,$phone,$collection,$NumberBrush,$ShadowBrush,$NumberRim,$labelFont,$smallFont,$ink,$dark)){$o.Dispose()}
