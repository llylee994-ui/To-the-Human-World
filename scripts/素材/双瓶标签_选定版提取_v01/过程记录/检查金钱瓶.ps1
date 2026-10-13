param()
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
# Reuse only the already-verified C# measurement helper, without running date exports.
$dateScript=Get-Content -LiteralPath (Join-Path $PSScriptRoot '检查日期瓶.ps1') -Raw -Encoding UTF8
$match=[regex]::Match($dateScript,"(?s)Add-Type -TypeDefinition @'\r?\n(.*?)\r?\n'@")
if(-not $match.Success){throw 'Alpha helper was not found.'}
Add-Type -TypeDefinition $match.Groups[1].Value -ReferencedAssemblies System.Drawing.Common,System.Drawing.Primitives,System.Collections,System.Runtime

$taskRoot=Split-Path -Parent $PSScriptRoot
$rawPath=Join-Path $PSScriptRoot '金钱瓶_生成原稿_v01.png'
$raw=[System.Drawing.Bitmap]::new($rawPath)
$audit=[BottleAlphaAudit]::Inspect($raw)
$bounds=$audit['bounds_alpha_ge_8']
# Money coins extend below the generic central ROI; measure the actual empty
# number field below the coins and above the three bottom stones instead.
$audit['generic_center_roi_includes_coin_edge']=$audit['empty_center_roi']
$audit['generic_center_alpha_max']=$audit['empty_center_alpha_max']
$roi=[System.Drawing.Rectangle]::new(($bounds[0]+[int]($bounds[2]*.34)),($bounds[1]+[int]($bounds[3]*.57)),[int]($bounds[2]*.32),[int]($bounds[3]*.25))
$roiMin=255;$roiMax=0;[long]$roiSum=0;[long]$roiZero=0;[long]$roiCount=0
for($ry=$roi.Top;$ry -lt $roi.Bottom;$ry++){for($rx=$roi.Left;$rx -lt $roi.Right;$rx++){$a=$raw.GetPixel($rx,$ry).A;$roiCount++;$roiSum+=$a;if($a -lt $roiMin){$roiMin=$a};if($a -gt $roiMax){$roiMax=$a};if($a -eq 0){$roiZero++}}}
$audit['empty_center_roi']=@($roi.X,$roi.Y,$roi.Width,$roi.Height)
$audit['empty_center_alpha_min']=$roiMin
$audit['empty_center_alpha_max']=$roiMax
$audit['empty_center_alpha_mean']=[Math]::Round($roiSum/[double]$roiCount,4)
$audit['empty_center_zero_percent']=[Math]::Round(100*$roiZero/[double]$roiCount,4)
$padding=8
$cx=[Math]::Max(0,$bounds[0]-$padding);$cy=[Math]::Max(0,$bounds[1]-$padding)
$cr=[Math]::Min($raw.Width,$bounds[0]+$bounds[2]+$padding)
$cb=[Math]::Min($raw.Height,$bounds[1]+$bounds[3]+$padding)
$cut=$raw.Clone([System.Drawing.Rectangle]::new($cx,$cy,($cr-$cx),($cb-$cy)),[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$assetPath=Join-Path $taskRoot '金钱瓶_钱币_透明_v01.png'
$cut.Save($assetPath,[System.Drawing.Imaging.ImageFormat]::Png)
$cutAudit=[BottleAlphaAudit]::Inspect($cut)
$edgeMax=0;$edgeNonzero=0
for($x=0;$x -lt $cut.Width;$x++){foreach($y in @(0,($cut.Height-1))){$a=$cut.GetPixel($x,$y).A;if($a -gt $edgeMax){$edgeMax=$a};if($a -gt 0){$edgeNonzero++}}}
for($y=1;$y -lt $cut.Height-1;$y++){foreach($x in @(0,($cut.Width-1))){$a=$cut.GetPixel($x,$y).A;if($a -gt $edgeMax){$edgeMax=$a};if($a -gt 0){$edgeNonzero++}}}

$source=[System.Drawing.Bitmap]::new((Join-Path $PSScriptRoot '参考_金钱瓶_原像素.png'))
$board=[System.Drawing.Bitmap]::new(1000,730)
$g=[System.Drawing.Graphics]::FromImage($board)
$g.Clear([System.Drawing.ColorTranslator]::FromHtml('#F7F5EF'))
$g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$title=[System.Drawing.Font]::new('Microsoft YaHei',20)
$label=[System.Drawing.Font]::new('Microsoft YaHei',13)
$ink=[System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#282B2D'))
$light=[System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#EEE5D5'))
$dark=[System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#24292C'))
$g.DrawString('金钱瓶：源图与真实 Alpha 叠加检查（待审候选）',$title,$ink,20,16)
$g.DrawString('选定源图裁切 ×3',$label,$ink,22,70)
$g.DrawString('浅底 #EEE5D5',$label,$ink,335,70)
$g.DrawString('深底 #24292C',$label,$ink,665,70)
$g.FillRectangle($light,315,108,310,520)
$g.FillRectangle($dark,645,108,310,520)
$g.DrawImage($source,[System.Drawing.Rectangle]::new(22,108,234,510))
$drawH=[int][Math]::Round(156*3*$cut.Height/$bounds[3])
$drawW=[int][Math]::Round($cut.Width*$drawH/$cut.Height)
$g.DrawImage($cut,[System.Drawing.Rectangle]::new([int](470-$drawW/2),127,$drawW,$drawH))
$g.DrawImage($cut,[System.Drawing.Rectangle]::new([int](800-$drawW/2),127,$drawW,$drawH))
$g.DrawString('中央空白区 Alpha：'+$audit['empty_center_alpha_min']+'–'+$audit['empty_center_alpha_max']+'；均值 '+$audit['empty_center_alpha_mean'],$label,$ink,20,646)
$g.DrawString('固定钱币、三颗石子保留；无数字。透明重建不等于恢复原图细节。',$label,$ink,20,678)
$boardPath=Join-Path $taskRoot '检查_金钱瓶_浅深底_v01.png'
$board.Save($boardPath,[System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()

$basePath=Join-Path $PSScriptRoot '底图_未加标签主页.png'
$base=[System.Drawing.Bitmap]::new($basePath)
$preview=$base.Clone([System.Drawing.Rectangle]::new(0,0,$base.Width,$base.Height),[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$pg=[System.Drawing.Graphics]::FromImage($preview)
$pg.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$pg.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$scale=[Math]::Min($base.Width/1672.0,$base.Height/941.0)
$offsetX=($base.Width-1672*$scale)/2;$offsetY=($base.Height-941*$scale)/2
$objectScale=156*$scale/$bounds[3]
$px=[int][Math]::Round($offsetX+115*$scale-($bounds[0]-$cx)*$objectScale)
$py=[int][Math]::Round($offsetY+27*$scale-($bounds[1]-$cy)*$objectScale)
$pw=[int][Math]::Round($cut.Width*$objectScale);$ph=[int][Math]::Round($cut.Height*$objectScale)
$placement=[System.Drawing.Rectangle]::new($px,$py,$pw,$ph)
$pg.DrawImage($cut,$placement)
$pg.Dispose()
$previewPath=Join-Path $taskRoot '预览_金钱瓶_无标签主页_v01.png'
$preview.Save($previewPath,[System.Drawing.Imaging.ImageFormat]::Png)
$outside=[BottleAlphaAudit]::DifferencesOutside($base,$preview,$placement)

# Review-only paired composition; the earlier date problem draft remains unapproved.
$dateReport=Get-Content -LiteralPath (Join-Path $taskRoot '检查结果_v01.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$date=[System.Drawing.Bitmap]::new((Join-Path $PSScriptRoot '日期瓶_紧裁_问题稿.png'))
$pair=$preview.Clone([System.Drawing.Rectangle]::new(0,0,$preview.Width,$preview.Height),[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$pairGraphics=[System.Drawing.Graphics]::FromImage($pair)
$pairGraphics.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$pairGraphics.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$dp=$dateReport.date_preview_placement
$datePlacement=[System.Drawing.Rectangle]::new($dp[0],$dp[1],$dp[2],$dp[3])
$pairGraphics.DrawImage($date,$datePlacement)
$pairGraphics.Dispose()
$pairPath=Join-Path $taskRoot '预览_日期问题稿与金钱候选_无标签主页_v01.png'
$pair.Save($pairPath,[System.Drawing.Imaging.ImageFormat]::Png)
$pairOutside=[BottleAlphaAudit]::DifferencesOutside($base,$pair,[System.Drawing.Rectangle]::Union($placement,$datePlacement))

$ratio=$bounds[2]/[double]$bounds[3]
$report=[ordered]@{
 task='B-HOME-LEDGER-EXTRACT-20261011 r1, money continuation'
 authorization='User explicitly requested money extraction after the date problem preview.'
 status='money_rgba_candidate_delivered_pending_user_A_approval'
 source=[ordered]@{full_image=(Join-Path $PSScriptRoot '源图_选定双瓶主页.png');width=1672;height=941;crop=@(109,20,78,170);silhouette_approx=@(115,27,65,156);native_details_approx=@(65,156)}
 raw_money=$audit
 trimmed_money=$cutAudit
 asset=[ordered]@{path=$assetPath;width=$cut.Width;height=$cut.Height;crop_rect=@($cx,$cy,$cut.Width,$cut.Height);bounds_threshold=8;padding=8;retained_rgba_modified=$false;edge_max_alpha=$edgeMax;edge_nonzero_pixels=$edgeNonzero}
 source_visible_aspect_approx=(65/156.0)
 generated_visible_aspect=$ratio
 approximate_aspect_width_change_percent=[Math]::Round(100*($ratio/(65/156.0)-1),3)
 base=[ordered]@{path=$basePath;size=@($base.Width,$base.Height);contains_ui_bottles=$false;mapping='uniform center-fit';scale=$scale;offset=@($offsetX,$offsetY)}
 placement_on_base=@($px,$py,$pw,$ph)
 outside_money_placement_changes=$outside
 outside_pair_bounding_rectangle_changes=$pairOutside
 paired_preview=[ordered]@{path=$pairPath;date_status='previous_problem_draft_not_approved';date_pixels_unmodified=$true}
 files=@($assetPath,$boardPath,$previewPath,$pairPath)
 source_sha256=(Get-FileHash -LiteralPath (Join-Path $PSScriptRoot '源图_选定双瓶主页.png') -Algorithm SHA256).Hash
 base_sha256=(Get-FileHash -LiteralPath $basePath -Algorithm SHA256).Hash
 raw_sha256=(Get-FileHash -LiteralPath $rawPath -Algorithm SHA256).Hash
 asset_sha256=(Get-FileHash -LiteralPath $assetPath -Algorithm SHA256).Hash
 tool='built-in imagegen; prompt saved in 过程记录/金钱瓶_透明重建提示词.txt'
 reconstruction='Glass transparency, highlights, cork, coins and pebbles were generatively repainted; no exact original alpha or source detail recovery claim.'
 visual_review=[ordered]@{light_dark_opened=$true;unlabelled_home_opened=$true;obvious_baked_wood_or_plants=$false;number_placeholder_or_extra_currency_prefix=$false;coin_and_three_pebbles_present=$true;notes='A continuous semitransparent film is present. Shape is approximately 5 percent narrower, highlights stronger and coins more detailed than the low-resolution source. Pale glass haze remains visible on dark background. Extreme edge has alpha up to 2; exterior is not certified all-zero.'}
 runtime_or_device_tested=$false
}
$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $taskRoot '金钱瓶_检查结果_v01.json') -Encoding UTF8
[ordered]@{raw=@($raw.Width,$raw.Height);crop=@($cut.Width,$cut.Height);bounds=$bounds;center_min=$audit['empty_center_alpha_min'];center_max=$audit['empty_center_alpha_max'];center_mean=$audit['empty_center_alpha_mean'];center_zero_pct=$audit['empty_center_zero_percent'];edge_max_alpha=$edgeMax;edge_nonzero_pixels=$edgeNonzero;aspect_change_pct=$report.approximate_aspect_width_change_percent;placement=$report.placement_on_base;outside_money=$outside;outside_pair=$pairOutside}|ConvertTo-Json -Depth 5
$raw.Dispose();$cut.Dispose();$source.Dispose();$board.Dispose();$base.Dispose();$preview.Dispose();$date.Dispose();$pair.Dispose()
$title.Dispose();$label.Dispose();$ink.Dispose();$light.Dispose();$dark.Dispose()
