$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$drawingReferences = @([System.Drawing.Bitmap].Assembly.Location,[System.Drawing.Rectangle].Assembly.Location)
Add-Type -ReferencedAssemblies $drawingReferences -TypeDefinition (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'PixelMasks.cs') -Raw -Encoding UTF8)
$assetRoot = 'D:\taptap\To-the-Human-World\scripts\素材\桌面双瓶_原像素提取_v01'
$evidenceRoot = Join-Path $assetRoot '检查记录'
$sourcePath = Join-Path $assetRoot '源图_桌面双瓶主页_v01.png'
$basePath = 'D:\taptap\To-the-Human-World\scripts\素材\双瓶标签_选定版提取_v01\过程记录\底图_未加标签主页.png'
$sourceBitmap = [System.Drawing.Bitmap]::new($sourcePath)
$baseBitmap = [System.Drawing.Bitmap]::new($basePath)
$png = [System.Drawing.Imaging.ImageFormat]::Png
$font = [System.Drawing.Font]::new('Microsoft YaHei',13,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
$brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(230,232,226))

function New-Canvas([int]$width,[int]$height,[System.Drawing.Color]$color) {
    $bitmap=[System.Drawing.Bitmap]::new($width,$height,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics=[System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear($color)
    $graphics.Dispose()
    return ,$bitmap
}
function Caption($graphics,[string]$label,[int]$x,[int]$y) { $graphics.DrawString($label,$font,$brush,$x,$y) }
function Save-Canvas($bitmap,[string]$name) { $bitmap.Save((Join-Path $assetRoot $name),$png) }

# Coordinates below are a manual polygon selection relative to the untouched
# x1180/y345 native-size inspection crop. They define Alpha only.
$definitions = @(
    @{
        key='date';file='日期瓶_DAY_原像素_透明_v01.png';region=[System.Drawing.Rectangle]::new(1207,364,75,198)
        body='49.0,26.0 50.7,24.5 54,23.5 67,23.5 77.8,24.5 81.3,26.4 80.5,31.0 79.2,37.7 78.5,39.8 82.6,40.8 86,42.7 86.5,46.5 85.8,49.1 82.5,52.6 80,54.0 79,61.9 80.2,66.2 84.5,72.9 89,80.5 92.4,88.3 94.7,98 95.3,115 95.0,189 94.2,196.3 91,200.5 84.8,203.5 77,205.4 65,206.3 53,205.7 44.2,203.3 38.8,199.7 35.7,194.7 34.8,187 35.1,106 35.8,93.7 38,84.4 42.8,76 48.1,69.5 51.5,64 51.8,54 47.9,52.5 45.4,49 44.8,44.3 45.5,41.3 51,40.5 50.5,34.8'
        shadow='35,195 93,196 98,201 100,206 94,210 83,212 63,213 45,210 34,207 30,203'
    },
    @{
        key='money';file='金币瓶_原像素_透明_v01.png';region=[System.Drawing.Rectangle]::new(1280,370,74,206)
        body='122.0,31.8 126,30.7 139,30.5 149.8,32 153.1,34 152.5,39 150.7,46 154.8,46.7 157.6,49.1 158.1,52.4 155.8,55.3 153.4,57.5 152.2,64.8 153.5,70.6 158.2,79.1 162.1,87.2 164.8,96.7 165.5,109 165.2,201 164.1,208 160.1,213 153.5,215.9 145.8,218 134,218.5 122,217.5 114,214.8 108.7,210.6 106.2,205.3 105.6,198.3 106.4,105.4 107.6,94.1 110.5,85.4 115.6,78.2 120.1,72.9 122.2,67 122.4,58.3 118.2,55.5 117,52.7 116.4,49.5 117.6,47.3 123.3,45.8 122,39'
        shadow='107,209 163,210 170,217 170,222 157,226 137,227 116,224 105,221 102,217'
    }
)
$results=@()
$assetBitmaps=@()
foreach($definition in $definitions) {
    $body=[PixelMasks]::Points($definition.body,1180,345)
    $shadow=[PixelMasks]::Points($definition.shadow,1180,345)
    $selection=[PixelMasks]::Extract($sourceBitmap,$definition.region,$body,$shadow)
    $bounds=[PixelMasks]::Bounds($selection)
    $tight=[System.Drawing.Rectangle]::new($bounds[0]-2,$bounds[1]-2,$bounds[2]-$bounds[0]+4,$bounds[3]-$bounds[1]+4)
    $asset=$selection.Clone($tight,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $assetPath=Join-Path $assetRoot $definition.file
    $asset.Save($assetPath,$png)
    $asset.Dispose()
    $asset=[System.Drawing.Bitmap]::new($assetPath)
    $x=$definition.region.X+$tight.X
    $y=$definition.region.Y+$tight.Y
    $stats=[PixelMasks]::Check($asset,$sourceBitmap,$x,$y)
    $bbox=[PixelMasks]::Bounds($asset)
    $alpha=[PixelMasks]::AlphaImage($asset)
    $alpha.Save((Join-Path $evidenceRoot ($definition.key+'_蒙版.png')),$png)
    $alpha.Dispose()
    $results += [ordered]@{
        name=$definition.file; path=$assetPath;x=$x;y=$y;width=$asset.Width;height=$asset.Height
        alphaZero=$stats[0];alphaPartial=$stats[1];alphaOpaque=$stats[2]
        visibleRgbDifferencesFromSource=$stats[3];borderNonzeroAlpha=$stats[4]
        alphaBounds=$bbox;pixelFormat=$asset.PixelFormat.ToString();sha256=(Get-FileHash -LiteralPath $assetPath).Hash
        bodySelection=$definition.body;shadowSelection=$definition.shadow;selectionOffset=@(1180,345)
        interiorAlpha='255; original transmitted background preserved, NOT recovered transparent glass'
    }
    $assetBitmaps+=,$asset
    $selection.Dispose()
}

# Preview base only is size-mapped. The extracted layers always use DrawImageUnscaled.
$alignedBase=New-Canvas 1672 941 ([System.Drawing.Color]::Transparent)
$g=[System.Drawing.Graphics]::FromImage($alignedBase)
$g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::Half
$g.DrawImage($baseBitmap,[System.Drawing.Rectangle]::new(0,0,1672,941),0,0,1920,1080,[System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose()
$alignedBase.Save((Join-Path $evidenceRoot '无双瓶底图_仅预览映射1672x941.png'),$png)
$composite=$alignedBase.Clone([System.Drawing.Rectangle]::new(0,0,1672,941),[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g=[System.Drawing.Graphics]::FromImage($composite)
for($i=0;$i -lt $results.Count;$i++) { $g.DrawImageUnscaled($assetBitmaps[$i],$results[$i].x,$results[$i].y) }
$g.Dispose()
Save-Canvas $composite '预览_叠回无双瓶底图_1672x941_v01.png'

# A same-size paired full-scene comparison; each panel is exactly 1672x941.
$comparison=New-Canvas 3344 977 ([System.Drawing.Color]::FromArgb(36,38,37))
$g=[System.Drawing.Graphics]::FromImage($comparison)
Caption $g '原图｜唯一提取像素来源｜1672×941 原尺度' 12 9
Caption $g '原像素提取结果叠回无双瓶底图｜1672×941｜底图版本有差异，非无缝验收通过' 1684 9
$g.DrawImageUnscaled($sourceBitmap,0,36)
$g.DrawImageUnscaled($composite,1672,36)
$g.Dispose()
Save-Canvas $comparison '对照_原图与实底提取结果_同尺寸_v01.png'
$comparison.Dispose()

# Native-size transparent QA: each crop has the original 200x240 pixel scale.
$qa=New-Canvas 1056 306 ([System.Drawing.Color]::FromArgb(36,38,37))
$g=[System.Drawing.Graphics]::FromImage($qa)
$roi=[System.Drawing.Rectangle]::new(1180,345,200,240)
$labels=@('原图局部 1:1','未加双瓶底图 1:1','提取层：浅底 1:1','提取层：深底 1:1','实底叠回 1:1')
for($i=0;$i -lt 5;$i++) {
    $panelX=8+$i*210
    Caption $g $labels[$i] $panelX 8
    $panel=New-Canvas 200 240 ([System.Drawing.Color]::Transparent)
    $pg=[System.Drawing.Graphics]::FromImage($panel)
    if($i -eq 0) { $crop=$sourceBitmap.Clone($roi,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb);$pg.DrawImageUnscaled($crop,0,0);$crop.Dispose() }
    elseif($i -eq 1) { $crop=$alignedBase.Clone($roi,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb);$pg.DrawImageUnscaled($crop,0,0);$crop.Dispose() }
    elseif($i -eq 4) { $crop=$composite.Clone($roi,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb);$pg.DrawImageUnscaled($crop,0,0);$crop.Dispose() }
    else {
        if($i -eq 2) { $pg.Clear([System.Drawing.Color]::FromArgb(239,238,230)) }
        else { $pg.Clear([System.Drawing.Color]::FromArgb(29,34,37)) }
        for($j=0;$j -lt $results.Count;$j++) { $pg.DrawImageUnscaled($assetBitmaps[$j],($results[$j].x-1180),($results[$j].y-345)) }
    }
    $pg.Dispose()
    $g.DrawImageUnscaled($panel,$panelX,32)
    $panel.Dispose()
}
Caption $g '瓶内背景原样保留；外轮廓透明不等于玻璃内部可透新背景。可见 RGB 未改，不补绘接缝。' 8 280
$g.Dispose()
Save-Canvas $qa '对照_原图_透明边缘_无瓶底图_1比1_v01.png'
$qa.Dispose()

# Whole-frame transparent isolation is QA only, never delivered as the small object asset.
$isolation=New-Canvas 1672 941 ([System.Drawing.Color]::Transparent)
$g=[System.Drawing.Graphics]::FromImage($isolation)
for($i=0;$i -lt $results.Count;$i++) { $g.DrawImageUnscaled($assetBitmaps[$i],$results[$i].x,$results[$i].y) }
$g.Dispose()
$isolation.Save((Join-Path $evidenceRoot '原图尺寸选区复位_仅检查.png'),$png)
$isolation.Dispose()

$report=[ordered]@{
    method='Original-source RGB + manually traced Alpha masks and tight crop. No generation, painting, RGB editing, asset resampling or sharpening.'
    sourcePath=$sourcePath;sourceWidth=1672;sourceHeight=941;sourceSha256=(Get-FileHash -LiteralPath $sourcePath).Hash
    basePath=$basePath;baseWidth=1920;baseHeight=1080;baseSha256=(Get-FileHash -LiteralPath $basePath).Hash
    baseEvidence='Recorded unlabelled home source in docs/actions/2026-10-11-b-home-ledger-table-r1.md; NOT the runtime layout acceptance.'
    previewBaseResampleOnly=@(1672,941);assetScale=1;assets=$results
    knownLimitation='Visual inspection completed: date interior retains herb-jar imagery, money interior retains mortar/table imagery; brown tabletop remnants remain in contact-shadow selections. Base differs from source. Seam-free portable glass acceptance FAILED; no repainting attempted.'
    acceptance=[ordered]@{originalRgbPreservation='PASS';tightCropAndRgba='PASS';portableTransparentGlass='FAIL: source background is baked into interiors';seamFreeOnRecordedBase='NOT PASSED: remnants and local texture discontinuity';runtimeOrDevice='NOT RUN';userDecision='REJECTED: user does not accept original-background remnants. Do not adopt or hand off for integration. Preserve files as failed-trial evidence; further reconstruction requires separate authorization.'}
}
[System.IO.File]::WriteAllText((Join-Path $assetRoot '检查结果_v01.json'),($report | ConvertTo-Json -Depth 8),[System.Text.UTF8Encoding]::new($false))
$results | ConvertTo-Json -Depth 5
foreach($bitmap in $assetBitmaps) { $bitmap.Dispose() }
$sourceBitmap.Dispose();$baseBitmap.Dispose();$alignedBase.Dispose();$composite.Dispose();$font.Dispose();$brush.Dispose()
