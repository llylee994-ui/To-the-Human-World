param([string]$DateImage,[string]$MoneyImage,[string]$Suffix='试稿一')
$ErrorActionPreference='Stop'
. "$PSScriptRoot\Bottle-Helpers.ps1"
$oldRoot='D:\taptap\To-the-Human-World\scripts\素材\双瓶标签_v01'
$newRoot='D:\taptap\To-the-Human-World\scripts\素材\双瓶标签_v02'
$date=[System.Drawing.Bitmap]::new($DateImage);$money=[System.Drawing.Bitmap]::new($MoneyImage)
$homeBitmap=[System.Drawing.Bitmap]::new("$oldRoot\过程稿\参考_最新主页_r2.png")
$collection=[System.Drawing.Text.PrivateFontCollection]::new();$collection.AddFontFile("$oldRoot\fonts\Mali-SemiBold.ttf")
$family=$collection.Families[0]
$NumberBrush=[System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255,232,216,180))
$ShadowBrush=[System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(135,68,53,36))
$NumberRim=[System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(150,252,239,211),0.55)
$g=[System.Drawing.Graphics]::FromImage($homeBitmap);Configure-Graphics $g
$g.DrawImage($date,[System.Drawing.RectangleF]::new(24,32,400,(400*$date.Height/$date.Width)))
$g.DrawImage($money,[System.Drawing.RectangleF]::new(24,200,400,(400*$money.Height/$money.Width)))
[void](Draw-Number $g '12' $family (24+1136*400/1776) (32+319*400/1776) 52)
[void](Draw-Number $g '1280' $family (24+977*400/1810) (200+414.5*400/1810) 52)
$g.Dispose()
$path="$newRoot\过程稿\预览_${Suffix}_主页.png"
if(Test-Path -LiteralPath $path){throw 'Output exists'}
$homeBitmap.Save($path,[System.Drawing.Imaging.ImageFormat]::Png)
foreach($b in @($date,$money)) {
  $top=[System.Drawing.Rectangle]::new([int]($b.Width*.3),[int]($b.Height*.03),[int]($b.Width*.4),[int]($b.Height*.10))
  $inner=[System.Drawing.Rectangle]::new([int]($b.Width*.5),[int]($b.Height*.3),[int]($b.Width*.25),[int]($b.Height*.3))
  [pscustomobject]@{width=$b.Width;height=$b.Height;topAlpha=[BottlePixels]::RegionAlpha($b,$top);innerAlpha=[BottlePixels]::RegionAlpha($b,$inner)} | ConvertTo-Json -Compress
}
foreach($b in @($date,$money,$homeBitmap,$collection,$NumberBrush,$ShadowBrush,$NumberRim)){$b.Dispose()}
