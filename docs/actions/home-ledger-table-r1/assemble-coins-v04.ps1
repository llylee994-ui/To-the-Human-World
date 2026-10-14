$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$taskRoot = Split-Path -Parent $PSCommandPath
$sourcePath = 'D:\taptap\To-the-Human-World\scripts\素材\主页效果_双瓶桌面摆放_v03.png'
$generatedPath = Join-Path $taskRoot 'coin-bottom-edit-generated.png'
$outputPath = 'D:\taptap\To-the-Human-World\scripts\素材\主页效果_双瓶桌面摆放_v04.png'
if (Test-Path -LiteralPath $outputPath) { throw 'Output exists; refusing to overwrite.' }
$original = [System.Drawing.Bitmap]::new($sourcePath)
$generated = [System.Drawing.Bitmap]::new($generatedPath)
$resized = [System.Drawing.Bitmap]::new(110,210)
$canvas = [System.Drawing.Bitmap]::new($original)
$graphics = [System.Drawing.Graphics]::FromImage($resized)
try {
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.DrawImage($generated, [System.Drawing.Rectangle]::new(0,0,110,210))
} finally { $graphics.Dispose() }

function Get-FeatherWeight([double]$x,[double]$y,[double]$left,[double]$top,[double]$right,[double]$bottom,[double]$feather) {
    if ($x -le $left -or $x -ge $right -or $y -le $top -or $y -ge $bottom) { return 0.0 }
    $distance = [Math]::Min([Math]::Min($x-$left,$right-$x),[Math]::Min($y-$top,$bottom-$y))
    $t = [Math]::Min(1.0,$distance/$feather)
    return $t*$t*(3.0-2.0*$t)
}

try {
    # Two internal regions only: remove the floating coins; add the settled bottom coins.
    # Bottle silhouette, cork, position, DAY bottle, and entire remaining homepage remain source pixels.
    $changed = 0
    for ($y=0; $y -lt 210; $y++) {
        for ($x=0; $x -lt 110; $x++) {
            $topWeight = Get-FeatherWeight $x $y 24 65 77 111 4
            $bottomWeight = Get-FeatherWeight $x $y 23 149 79 194 3
            $weight = [Math]::Max($topWeight,$bottomWeight)
            if ($weight -le 0) { continue }
            $src = $original.GetPixel(1265+$x,365+$y)
            $edit = $resized.GetPixel($x,$y)
            $r = [int][Math]::Round($src.R*(1-$weight)+$edit.R*$weight)
            $g = [int][Math]::Round($src.G*(1-$weight)+$edit.G*$weight)
            $b = [int][Math]::Round($src.B*(1-$weight)+$edit.B*$weight)
            $color = [System.Drawing.Color]::FromArgb(255,$r,$g,$b)
            $canvas.SetPixel(1265+$x,365+$y,$color)
            if ($color.ToArgb() -ne $src.ToArgb()) { $changed++ }
        }
    }
    $canvas.Save($outputPath,[System.Drawing.Imaging.ImageFormat]::Png)
    $qaRegion = $canvas.Clone([System.Drawing.Rectangle]::new(1180,355,230,235),[System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $qaView = [System.Drawing.Bitmap]::new(690,705)
    $qaGraphics = [System.Drawing.Graphics]::FromImage($qaView)
    try {
        $qaGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $qaGraphics.DrawImage($qaRegion,[System.Drawing.Rectangle]::new(0,0,690,705))
        $qaView.Save((Join-Path $taskRoot 'coin-bottom-v04-check.png'),[System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $qaGraphics.Dispose(); $qaView.Dispose(); $qaRegion.Dispose() }
    $outsideChanges = 0
    for ($y=0; $y -lt $canvas.Height; $y++) {
        for ($x=0; $x -lt $canvas.Width; $x++) {
            $insideTop = $x -gt 1289 -and $x -lt 1342 -and $y -gt 430 -and $y -lt 476
            $insideBottom = $x -gt 1288 -and $x -lt 1344 -and $y -gt 514 -and $y -lt 559
            if (!$insideTop -and !$insideBottom -and $canvas.GetPixel($x,$y).ToArgb() -ne $original.GetPixel($x,$y).ToArgb()) { $outsideChanges++ }
        }
    }
    $report = [pscustomobject]@{
        output=$outputPath; width=$canvas.Width; height=$canvas.Height
        source=$sourcePath; generatedRegion=$generatedPath
        inputCrop=@(1265,365,110,210); changedPixels=$changed
        outsideTwoEditRegionsChangedPixels=$outsideChanges
        sha256=(Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash
    }
    $report | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $taskRoot 'coin-bottom-v04-check.json') -Encoding UTF8
    $report | ConvertTo-Json -Depth 3
} finally { $original.Dispose(); $generated.Dispose(); $resized.Dispose(); $canvas.Dispose() }
