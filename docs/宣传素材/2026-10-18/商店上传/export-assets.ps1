# Only dimension normalization and file encoding; artwork is generated with image_gen.
param([string]$SourceRoot = 'C:/Users/liliy/.codex/generated_images/01a14548-ce7e-76c2-83af-d8879f5373a1',[switch]$European)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
function Export-Artwork {
    param([string]$SourceName,[string]$Name,[int]$Width,[int]$Height,[bool]$Alpha)
    $destination = Join-Path $PSScriptRoot $Name
    if (Test-Path -LiteralPath $destination) { throw "Destination exists: $destination" }
    $source = [System.Drawing.Image]::FromFile((Join-Path $SourceRoot $SourceName))
    $bitmap = [System.Drawing.Bitmap]::new($Width,$Height,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $attributes = [System.Drawing.Imaging.ImageAttributes]::new()
    try {
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $attributes.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
        $rectangle = [System.Drawing.Rectangle]::new(0,0,$Width,$Height)
        $graphics.DrawImage($source,$rectangle,0,0,$source.Width,$source.Height,[System.Drawing.GraphicsUnit]::Pixel,$attributes)
        if ($Alpha) {
            $bitmap.Save($destination,[System.Drawing.Imaging.ImageFormat]::Png)
        } else {
            $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
            $parameters = [System.Drawing.Imaging.EncoderParameters]::new(1)
            try {
                $parameters.Param[0] = [System.Drawing.Imaging.EncoderParameter]::new([System.Drawing.Imaging.Encoder]::Quality,[long]94)
                $bitmap.Save($destination,$codec,$parameters)
            } finally { $parameters.Dispose() }
        }
        Get-Item -LiteralPath $destination | Select-Object Name,Length
    } finally {
        $attributes.Dispose();$graphics.Dispose();$bitmap.Dispose();$source.Dispose()
    }
}
if ($European) {
    Export-Artwork 'exec-2f18f33c-5e28-48e6-8cc0-4b54fcf8e6d9.png' '04-游戏Logo-欧式花体-透明-v02-1600x900.png' 1600 900 $true
    Export-Artwork 'exec-ce697b79-c4fd-48cd-804d-0fa3eacb73d6.png' '05-宣传图-欧式花体-v02-1920x1080.jpg' 1920 1080 $false
} else {
    Export-Artwork 'exec-c8094ad0-5a56-4a35-bdd8-0c9ed5a4c28e.png' '01-游戏Logo-透明-1600x900.png' 1600 900 $true
    Export-Artwork 'exec-2f7a954c-2f32-4c98-87a2-3e182330d7bf.png' '02-宣传图-1920x1080.jpg' 1920 1080 $false
    Export-Artwork 'exec-05c89b28-87b9-4dc4-b059-4e95e08d7ff3.png' '03-游戏库背景-无字-3840x1240.jpg' 3840 1240 $false
}
