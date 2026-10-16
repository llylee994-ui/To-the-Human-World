$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$drawingReferences=@([System.Drawing.Bitmap].Assembly.Location,[System.Drawing.Rectangle].Assembly.Location)
Add-Type -ReferencedAssemblies $drawingReferences -TypeDefinition (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'GlassRepair.cs') -Raw -Encoding UTF8)
$root='D:\taptap\To-the-Human-World\scripts\素材'
$oldRoot=Join-Path $root '桌面双瓶_原像素提取_v01'
$outRoot=Join-Path $root '桌面双瓶_去背景修复_v02'
$qaRoot=Join-Path $outRoot '检查记录'
New-Item -ItemType Directory -Path $qaRoot -Force | Out-Null
$oldReport=Get-Content -LiteralPath (Join-Path $oldRoot '检查结果_v01.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$source=[System.Drawing.Bitmap]::new($oldReport.sourcePath)
$baseImage=[System.Drawing.Bitmap]::new((Join-Path $oldRoot '检查记录\无双瓶底图_仅预览映射1672x941.png'))
$oldPreview=[System.Drawing.Bitmap]::new((Join-Path $oldRoot '预览_叠回无双瓶底图_1672x941_v01.png'))
$png=[System.Drawing.Imaging.ImageFormat]::Png
$font=[System.Drawing.Font]::new('Microsoft YaHei',13,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
$brush=[System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(230,232,226))
function Canvas([int]$w,[int]$h,[System.Drawing.Color]$color) {
    $b=[System.Drawing.Bitmap]::new($w,$h,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g=[System.Drawing.Graphics]::FromImage($b);$g.Clear($color);$g.Dispose();return ,$b
}
function SaveImage($b,[string]$name){$b.Save((Join-Path $outRoot $name),$png)}
function Label($g,[string]$t,[int]$x,[int]$y){$g.DrawString($t,$font,$brush,$x,$y)}
$newNames=@('日期瓶_DAY_局部修复_透明_v02.png','金币瓶_局部修复_透明_v02.png')
$newImages=@();$oldImages=@();$results=@()
for($i=0;$i -lt 2;$i++) {
    $a=$oldReport.assets[$i];$isDate=$i -eq 0
    $old=[System.Drawing.Bitmap]::new($a.path)
    $new=[GlassRepair]::Repair($old,$source,$a.x,$a.y,$a.bodySelection,$a.shadowSelection,$isDate)
    $newPath=Join-Path $outRoot $newNames[$i]
    $new.Save($newPath,$png);$new.Dispose()
    $new=[System.Drawing.Bitmap]::new($newPath)
    $stats=[GlassRepair]::Inspect($old,$new,$a.x,$a.y,$isDate)
    $mask=[GlassRepair]::ProtectedMask($old,$a.x,$a.y,$isDate)
    $mask.Save((Join-Path $qaRoot ('保护区_'+$i+'.png')),$png);$mask.Dispose()
    $results += [ordered]@{name=$newNames[$i];path=$newPath;x=$a.x;y=$a.y;width=$new.Width;height=$new.Height;protectedCorePixels=$stats[0];protectedCoreRgbaDifferences=$stats[1];repairedPixels=$stats[2];newPixelsOutsideOldAlpha=$stats[3];alphaZero=$stats[4];alphaPartial=$stats[5];alphaOpaque=$stats[6];borderNonzeroAlpha=$stats[7];sha256=(Get-FileHash -LiteralPath $newPath).Hash;previousAssetUnchanged=((Get-FileHash -LiteralPath $a.path).Hash -eq $a.sha256)}
    $newImages+=,$new;$oldImages+=,$old
}
$composite=$baseImage.Clone([System.Drawing.Rectangle]::new(0,0,1672,941),[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g=[System.Drawing.Graphics]::FromImage($composite)
for($i=0;$i -lt 2;$i++){$g.DrawImageUnscaled($newImages[$i],$results[$i].x,$results[$i].y)}
$g.Dispose();SaveImage $composite '预览_无双瓶底图_局部修复_v02.png'

$comparison=Canvas 3344 977 ([System.Drawing.Color]::FromArgb(36,38,37))
$g=[System.Drawing.Graphics]::FromImage($comparison)
Label $g '修复前 v01（用户否决）｜同一无双瓶底图｜瓶子1:1' 12 9
Label $g '局部去背景修复 v02（待确认）｜同一位置和尺寸｜瓶子1:1' 1684 9
$g.DrawImageUnscaled($oldPreview,0,36);$g.DrawImageUnscaled($composite,1672,36)
$g.Dispose();SaveImage $comparison '对照_同主页修复前后_同尺寸_v02.png';$comparison.Dispose()

$roi=[System.Drawing.Rectangle]::new(1180,345,200,240)
$qa=Canvas 1056 306 ([System.Drawing.Color]::FromArgb(36,38,37))
$g=[System.Drawing.Graphics]::FromImage($qa)
$labels=@('源图局部 1:1','v01 浅底（否决）','v02 浅底 1:1','v02 深底 1:1','v02 实底叠回 1:1')
$panels=@()
for($k=0;$k -lt 5;$k++) {
    $panel=Canvas 200 240 ([System.Drawing.Color]::FromArgb(239,238,230))
    $pg=[System.Drawing.Graphics]::FromImage($panel)
    if($k -eq 0 -or $k -eq 4) {
        $chosen=$source;if($k -eq 4){$chosen=$composite}
        $crop=$chosen.Clone($roi,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb);$pg.DrawImageUnscaled($crop,0,0);$crop.Dispose()
    } else {
        if($k -eq 3){$pg.Clear([System.Drawing.Color]::FromArgb(29,34,37))}
        $images=$newImages;if($k -eq 1){$images=$oldImages}
        for($j=0;$j -lt 2;$j++){$pg.DrawImageUnscaled($images[$j],($results[$j].x-1180),($results[$j].y-345))}
    }
    $pg.Dispose();$g.DrawImageUnscaled($panel,(8+$k*210),32);Label $g $labels[$k] (8+$k*210) 8
    $panels+=,$panel
}
Label $g '局部修复透明度为估算；瓶形/尺寸不变。固定物件保护区逐像素核对；非生图，待外观确认。' 8 280
$g.Dispose();SaveImage $qa '对照_原尺度_浅深底与实底_v02.png';$qa.Dispose()

# Inspection only, nearest-neighbour zoom never used as the asset source.
$zoom=Canvas 1287 752 ([System.Drawing.Color]::FromArgb(36,38,37))
$g=[System.Drawing.Graphics]::FromImage($zoom)
$g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::Half
for($i=0;$i -lt 3;$i++){
    Label $g @('v02 浅底｜3倍检查','v02 深底｜3倍检查','v02 实底｜3倍检查')[$i] ($i*429+8) 8
    # Crop to both bottle shapes for a compact inspection sheet.
    $g.DrawImage($panels[$i+2],[System.Drawing.Rectangle]::new($i*429,32,429,720),28,0,143,240,[System.Drawing.GraphicsUnit]::Pixel)
}
$g.Dispose();SaveImage $zoom '检查记录\局部修复_约3倍观察_非素材.png';$zoom.Dispose()

# Demonstrate portability on a second actual-home region, no rescaling.
$moved=$baseImage.Clone([System.Drawing.Rectangle]::new(0,0,1672,941),[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g=[System.Drawing.Graphics]::FromImage($moved)
$g.DrawImageUnscaled($newImages[0],360,180);$g.DrawImageUnscaled($newImages[1],440,185)
$g.Dispose();SaveImage $moved '检查记录\移至海面_仅透底检查非布局.png';$moved.Dispose()

$report=[ordered]@{version='v02 local background decontamination';source=$oldReport.sourcePath;sourceSha256=(Get-FileHash -LiteralPath $oldReport.sourcePath).Hash;method='Manual protected masks; non-generative local RGB/Alpha reconstruction of contaminated glass; original-position contact-shadow neutralization. No asset resize. Physical glass alpha is estimated, not recovered.';basePath=$oldReport.basePath;previewBaseSize=@(1672,941);assets=$results;visualStatus='Pending inspection';runtimeAndDevice='Not run'}
[System.IO.File]::WriteAllText((Join-Path $outRoot '检查结果_v02.json'),($report|ConvertTo-Json -Depth 6),[System.Text.UTF8Encoding]::new($false))
$results|ConvertTo-Json -Depth 4
foreach($bmp in $panels+$newImages+$oldImages){$bmp.Dispose()}
$source.Dispose();$baseImage.Dispose();$oldPreview.Dispose();$composite.Dispose();$font.Dispose();$brush.Dispose()
