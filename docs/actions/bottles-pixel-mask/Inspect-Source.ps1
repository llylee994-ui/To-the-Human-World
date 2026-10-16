$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$assetRoot = 'D:\taptap\To-the-Human-World\scripts\素材\桌面双瓶_原像素提取_v01'
$evidenceRoot = Join-Path $assetRoot '检查记录'
New-Item -ItemType Directory -Path $evidenceRoot -Force | Out-Null
$sourcePath = 'C:\WINDOWS\TEMP\codex-clipboard-834dd8a5-1ce2-443b-92f9-d13ff6a21aee.png'
$copyPath = Join-Path $assetRoot '源图_桌面双瓶主页_v01.png'
if (-not (Test-Path -LiteralPath $copyPath)) { Copy-Item -LiteralPath $sourcePath -Destination $copyPath }
$sourceBitmap = [System.Drawing.Bitmap]::new($copyPath)
try {
    $rect = [System.Drawing.Rectangle]::new(1180,345,200,240)
    $crop = $sourceBitmap.Clone($rect,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $crop.Save((Join-Path $evidenceRoot '原像素局部_x1180_y345_200x240.png'),[System.Drawing.Imaging.ImageFormat]::Png)
    # QA-only nearest-neighbour viewing aid; never used as an extraction source.
    $zoom = [System.Drawing.Bitmap]::new(800,960)
    $zoomGraphics = [System.Drawing.Graphics]::FromImage($zoom)
    $zoomGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $zoomGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $zoomGraphics.DrawImage($crop,[System.Drawing.Rectangle]::new(0,0,800,960),0,0,200,240,[System.Drawing.GraphicsUnit]::Pixel)
    $zoom.Save((Join-Path $evidenceRoot '选区观察_4倍最近邻_非素材.png'),[System.Drawing.Imaging.ImageFormat]::Png)
    $zoomGraphics.Dispose()
    $zoom.Dispose()
    $crop.Dispose()
    [pscustomobject]@{Width=$sourceBitmap.Width;Height=$sourceBitmap.Height;SourceHash=(Get-FileHash -LiteralPath $sourcePath).Hash;CopyHash=(Get-FileHash -LiteralPath $copyPath).Hash} | ConvertTo-Json
} finally { $sourceBitmap.Dispose() }
