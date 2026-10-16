$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$refs=@([System.Drawing.Bitmap].Assembly.Location,[System.Drawing.Rectangle].Assembly.Location)
Add-Type -ReferencedAssemblies $refs -TypeDefinition (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'GlassRepair.cs') -Raw -Encoding UTF8)
$outRoot='D:\taptap\To-the-Human-World\scripts\素材\桌面双瓶_去背景修复_v02'
$reportPath=Join-Path $outRoot '检查结果_v02.json'
$report=Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json
$probes=@([System.Drawing.Rectangle]::new(22,100,26,38),[System.Drawing.Rectangle]::new(16,88,36,40))
for($i=0;$i -lt 2;$i++){
    $a=$report.assets[$i];$bitmap=[System.Drawing.Bitmap]::new($a.path)
    $alpha=[GlassRepair]::Alpha($bitmap,$probes[$i])
    $a | Add-Member -Force -NotePropertyName alphaBounds -NotePropertyValue @($alpha[3],$alpha[4],$alpha[5],$alpha[6])
    $a | Add-Member -Force -NotePropertyName clearGlassProbe -NotePropertyValue ([ordered]@{localX=$probes[$i].X;localY=$probes[$i].Y;width=$probes[$i].Width;height=$probes[$i].Height;alphaMin=$alpha[0];alphaMax=$alpha[1];alphaMean=$alpha[2];meanBackgroundTransmission=1-$alpha[2]/255})
    $bytes=[System.IO.File]::ReadAllBytes($a.path)
    $a | Add-Member -Force -NotePropertyName pngColorType -NotePropertyValue $bytes[25]
    if($a.protectedCoreRgbaDifferences -ne 0 -or $a.newPixelsOutsideOldAlpha -ne 0 -or $bytes[25] -ne 6){throw 'Asset invariant check failed'}
    $bitmap.Dispose()
}
$baseImage=[System.Drawing.Bitmap]::new('D:\taptap\To-the-Human-World\scripts\素材\桌面双瓶_原像素提取_v01\检查记录\无双瓶底图_仅预览映射1672x941.png')
$scene=[System.Drawing.Bitmap]::new((Join-Path $outRoot '预览_无双瓶底图_局部修复_v02.png'))
$sceneDiff=[GlassRepair]::SceneDiff($baseImage,$scene,[System.Drawing.Rectangle]::new(1208,366,74,194),[System.Drawing.Rectangle]::new(1280,373,72,201))
$scene.Dispose();$baseImage.Dispose()
$report | Add-Member -Force -NotePropertyName sceneCheck -NotePropertyValue ([ordered]@{changedPixels=$sceneDiff[0];changedOutsideAssetRectangles=$sceneDiff[1];baseWasAlreadyBottleFree=$true})
$report.visualStatus='Inspected native and magnified light/dark mattes, original-location bottle-free home and relocated sea background: no recognisable old herb-jar/mortar/table texture carried in clear interior; broad tabletop patch removed. Glass is more transparent; subtle original warm glass edging remains. Candidate awaits user visual approval. Exact physical refraction is not recovered.'
$report | Add-Member -Force -NotePropertyName userAcceptance -NotePropertyValue 'Pending; prior v01 remains rejected'
[System.IO.File]::WriteAllText($reportPath,($report|ConvertTo-Json -Depth 8),[System.Text.UTF8Encoding]::new($false))
$report | ConvertTo-Json -Depth 6
