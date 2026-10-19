# Format existing screenshots only; no generation, UI retouching or scene compositing.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot='D:/To the Human World'
$shots=@(
    @('C:/Users/liliy/AppData/Local/Temp/codex-clipboard-e6f749c4-f301-4ce5-a2f6-dc0c1682e800.png','01-已通过-炼药配方-1920x1080.jpg'),
    @((Join-Path $projectRoot 'docs/验证/evidence/reading-panels-r1/reading_native_reader_top.png'),'02-阅读来信与剪词-1920x1080.jpg'),
    @((Join-Path $projectRoot 'docs/验证/evidence/story-reveal-r1/brew_native_result.png'),'03-药效结果与回信-1920x1080.jpg'),
    @((Join-Path $projectRoot 'docs/验证/evidence/second-batch-acceptance-2026-10-18/second_batch_10-frozen-collage.png'),'04-心愿拼贴信纸-1920x1080.jpg'),
    @('C:/Users/liliy/AppData/Local/Temp/codex-clipboard-c9db03d2-f27e-4c68-b3be-d520de2c08e8.png','05-已通过-标题背景-1920x1080.jpg')
)
$codec=[System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object {$_.MimeType -eq 'image/jpeg'}
foreach($shot in $shots){
    $destination=Join-Path $PSScriptRoot $shot[1]
    if(Test-Path -LiteralPath $destination){throw "Destination exists: $destination"}
    $source=[System.Drawing.Image]::FromFile($shot[0])
    $bitmap=[System.Drawing.Bitmap]::new(1920,1080)
    $graphics=[System.Drawing.Graphics]::FromImage($bitmap)
    $attributes=[System.Drawing.Imaging.ImageAttributes]::new()
    $parameters=[System.Drawing.Imaging.EncoderParameters]::new(1)
    try{
        $cropWidth=[double]$source.Width
        $cropHeight=[double]$source.Height
        if($cropWidth/$cropHeight -gt 16.0/9.0){$cropWidth=$cropHeight*16.0/9.0}
        else{$cropHeight=$cropWidth*9.0/16.0}
        $cropX=($source.Width-$cropWidth)/2.0
        $cropY=($source.Height-$cropHeight)/2.0
        $graphics.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $attributes.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
        $rectangle=[System.Drawing.Rectangle]::new(0,0,1920,1080)
        $graphics.DrawImage($source,$rectangle,[single]$cropX,[single]$cropY,[single]$cropWidth,[single]$cropHeight,[System.Drawing.GraphicsUnit]::Pixel,$attributes)
        $parameters.Param[0]=[System.Drawing.Imaging.EncoderParameter]::new([System.Drawing.Imaging.Encoder]::Quality,[long]94)
        $bitmap.Save($destination,$codec,$parameters)
        [PSCustomObject]@{File=$shot[1];SourceSize="$($source.Width)x$($source.Height)";Crop="$cropX,$cropY,$cropWidth,$cropHeight";Bytes=(Get-Item -LiteralPath $destination).Length}
    }finally{$parameters.Dispose();$attributes.Dispose();$graphics.Dispose();$bitmap.Dispose();$source.Dispose()}
}
