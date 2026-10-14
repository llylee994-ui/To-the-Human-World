$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$outRoot='D:\taptap\To-the-Human-World\scripts\素材\桌面双瓶_去背景修复_v02\检查记录'
New-Item -ItemType Directory -Path $outRoot -Force | Out-Null
$source=[System.Drawing.Bitmap]::new('D:\taptap\To-the-Human-World\scripts\素材\桌面双瓶_原像素提取_v01\源图_桌面双瓶主页_v01.png')
$definitions=@(@('DAY观察_8倍_非素材',1218,431,51,36),@('金币石子观察_6倍_非素材',1211,505,139,61))
foreach($definition in $definitions) {
    $scale=8
    if($definition[0] -like '金币*'){$scale=6}
    $bmp=[System.Drawing.Bitmap]::new($definition[3]*$scale,$definition[4]*$scale)
    $g=[System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $g.DrawImage($source,[System.Drawing.Rectangle]::new(0,0,$bmp.Width,$bmp.Height),$definition[1],$definition[2],$definition[3],$definition[4],[System.Drawing.GraphicsUnit]::Pixel)
    $bmp.Save((Join-Path $outRoot ($definition[0]+'.png')),[System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose();$bmp.Dispose()
}
$source.Dispose()
