param()
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
public static class BottleAlphaAudit {
  public static Dictionary<string,object> Inspect(Bitmap b) {
    long[] hist = new long[256];
    int minX=b.Width,minY=b.Height,maxX=-1,maxY=-1;
    int min8X=b.Width,min8Y=b.Height,max8X=-1,max8Y=-1;
    for(int y=0;y<b.Height;y++) for(int x=0;x<b.Width;x++) {
      int a=b.GetPixel(x,y).A; hist[a]++;
      if(a>0){minX=Math.Min(minX,x);minY=Math.Min(minY,y);maxX=Math.Max(maxX,x);maxY=Math.Max(maxY,y);}
      if(a>=8){min8X=Math.Min(min8X,x);min8Y=Math.Min(min8Y,y);max8X=Math.Max(max8X,x);max8Y=Math.Max(max8Y,y);}
    }
    long semi=0; int levels=0;
    for(int a=0;a<256;a++){if(hist[a]>0)levels++;if(a>0&&a<255)semi+=hist[a];}
    int bx=max8X-min8X+1,by=max8Y-min8Y+1;
    Rectangle roi=new Rectangle(min8X+(int)(bx*.35),min8Y+(int)(by*.50),(int)(bx*.30),(int)(by*.28));
    long rzero=0,rsum=0,rn=0;int rmin=255,rmax=0;
    for(int y=roi.Top;y<roi.Bottom;y++) for(int x=roi.Left;x<roi.Right;x++) {
      int a=b.GetPixel(x,y).A;rn++;rsum+=a;if(a==0)rzero++;rmin=Math.Min(rmin,a);rmax=Math.Max(rmax,a);
    }
    return new Dictionary<string,object>{
      {"width",b.Width},{"height",b.Height},{"pixel_format",b.PixelFormat.ToString()},
      {"alpha_histogram",hist},{"alpha_zero_pixels",hist[0]},{"alpha_partial_pixels",semi},
      {"alpha_255_pixels",hist[255]},{"alpha_levels_used",levels},
      {"bounds_alpha_gt_0",new int[]{minX,minY,maxX-minX+1,maxY-minY+1}},
      {"bounds_alpha_ge_8",new int[]{min8X,min8Y,bx,by}},
      {"empty_center_roi",new int[]{roi.X,roi.Y,roi.Width,roi.Height}},
      {"empty_center_alpha_min",rmin},{"empty_center_alpha_max",rmax},
      {"empty_center_alpha_mean",Math.Round((double)rsum/rn,4)},
      {"empty_center_zero_percent",Math.Round(100.0*rzero/rn,4)},
      {"corner_alpha",new int[]{b.GetPixel(0,0).A,b.GetPixel(b.Width-1,0).A,b.GetPixel(0,b.Height-1).A,b.GetPixel(b.Width-1,b.Height-1).A}}
    };
  }
  public static long DifferencesOutside(Bitmap a,Bitmap b,Rectangle allowed) {
    long n=0;
    for(int y=0;y<a.Height;y++)for(int x=0;x<a.Width;x++)
      if(!allowed.Contains(x,y)&&a.GetPixel(x,y).ToArgb()!=b.GetPixel(x,y).ToArgb())n++;
    return n;
  }
}
'@ -ReferencedAssemblies System.Drawing.Common,System.Drawing.Primitives,System.Collections,System.Runtime

$taskRoot = Split-Path -Parent $PSScriptRoot
$rawPath = Join-Path $PSScriptRoot '日期瓶_生成原稿_待验.png'
$raw = [System.Drawing.Bitmap]::new($rawPath)
$audit = [BottleAlphaAudit]::Inspect($raw)
$visible = $audit['bounds_alpha_ge_8']
$pad = 8
$cx = [Math]::Max(0,$visible[0]-$pad)
$cy = [Math]::Max(0,$visible[1]-$pad)
$right = [Math]::Min($raw.Width,$visible[0]+$visible[2]+$pad)
$bottom = [Math]::Min($raw.Height,$visible[1]+$visible[3]+$pad)
$cropRect = [System.Drawing.Rectangle]::new($cx,$cy,($right-$cx),($bottom-$cy))
$cut = $raw.Clone($cropRect,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$cutPath = Join-Path $PSScriptRoot '日期瓶_紧裁_问题稿.png'
$cut.Save($cutPath,[System.Drawing.Imaging.ImageFormat]::Png)
$cutAudit = [BottleAlphaAudit]::Inspect($cut)

$sourceCrop = [System.Drawing.Bitmap]::new((Join-Path $PSScriptRoot '参考_日期瓶_原像素.png'))
$board = [System.Drawing.Bitmap]::new(1000,730)
$g = [System.Drawing.Graphics]::FromImage($board)
$g.Clear([System.Drawing.ColorTranslator]::FromHtml('#F7F5EF'))
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$titleFont = [System.Drawing.Font]::new('Microsoft YaHei',20)
$labelFont = [System.Drawing.Font]::new('Microsoft YaHei',13)
$ink = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(40,43,45))
$lightBrush = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#EEE5D5'))
$darkBrush = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#24292C'))
$g.DrawString('日期瓶：源图与真实 Alpha 叠加检查（待审问题稿）',$titleFont,$ink,20,16)
$g.DrawString('选定源图裁切 ×3',$labelFont,$ink,22,70)
$g.DrawString('浅底 #EEE5D5',$labelFont,$ink,335,70)
$g.DrawString('深底 #24292C',$labelFont,$ink,665,70)
$g.FillRectangle($lightBrush,315,108,310,520)
$g.FillRectangle($darkBrush,645,108,310,520)
$g.DrawImage($sourceCrop,[System.Drawing.Rectangle]::new(22,108,240,510))
$drawH=[int][Math]::Round(156*3*$cut.Height/$audit['bounds_alpha_ge_8'][3])
$drawW=[int][Math]::Round($cut.Width*$drawH/$cut.Height)
$g.DrawImage($cut,[System.Drawing.Rectangle]::new([int](470-$drawW/2),127,$drawW,$drawH))
$g.DrawImage($cut,[System.Drawing.Rectangle]::new([int](800-$drawW/2),127,$drawW,$drawH))
$g.DrawString('中央空白区 Alpha：'+$audit['empty_center_alpha_min']+'–'+$audit['empty_center_alpha_max']+'；完全透明占比 '+$audit['empty_center_zero_percent']+'%',$labelFont,$ink,20,646)
$g.DrawString('只作问题检查；扩大显示未增加源图信息。未开始金钱瓶处理。',$labelFont,$ink,20,678)
$boardPath = Join-Path $taskRoot '问题预览_日期瓶_浅深底_v01.png'
$board.Save($boardPath,[System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()

$basePath=Join-Path $PSScriptRoot '底图_未加标签主页.png'
$base=[System.Drawing.Bitmap]::new($basePath)
$preview=$base.Clone([System.Drawing.Rectangle]::new(0,0,$base.Width,$base.Height),[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$pg=[System.Drawing.Graphics]::FromImage($preview)
$pg.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$pg.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
# Approximate selected-source silhouette: left=33, top=27, width=67, height=156.
# Use uniform scaling; center-fit the 1672x941 source frame to the 1920x1080 base.
$scale=[Math]::Min($base.Width/1672.0,$base.Height/941.0)
$offsetX=($base.Width-1672*$scale)/2
$offsetY=($base.Height-941*$scale)/2
$rawSilhouette=$audit['bounds_alpha_ge_8']
$objectScale=156*$scale/$rawSilhouette[3]
$placeX=[int][Math]::Round($offsetX+33*$scale-($rawSilhouette[0]-$cx)*$objectScale)
$placeY=[int][Math]::Round($offsetY+27*$scale-($rawSilhouette[1]-$cy)*$objectScale)
$placeW=[int][Math]::Round($cut.Width*$objectScale)
$placeH=[int][Math]::Round($cut.Height*$objectScale)
$placement=[System.Drawing.Rectangle]::new($placeX,$placeY,$placeW,$placeH)
$pg.DrawImage($cut,$placement)
$pg.Dispose()
$previewPath=Join-Path $taskRoot '问题预览_日期瓶_无标签主页_v01.png'
$preview.Save($previewPath,[System.Drawing.Imaging.ImageFormat]::Png)
$outsideChanges=[BottleAlphaAudit]::DifferencesOutside($base,$preview,$placement)

$result=[ordered]@{
  task='B-HOME-LEDGER-EXTRACT-20261011 r1'
  status='date_gate_failed_problem_preview_only'
  source=[ordered]@{path=(Join-Path $PSScriptRoot '源图_选定双瓶主页.png');width=1672;height=941;format='RGB';date_crop=@(26,20,80,170);date_silhouette_approx=@(33,27,67,156);money_crop=@(109,20,78,170);money_silhouette_approx=@(115,27,65,156)}
  raw_date=$audit
  trimmed_date=$cutAudit
  trim=[ordered]@{from_raw=@($cx,$cy,$cut.Width,$cut.Height);bounds_threshold=8;padding=8;retained_alpha_values_modified=$false;discarded_external_noise_max_alpha=7;path=$cutPath;status='problem_draft_not_final'}
  source_date_aspect_approx=[Math]::Round(67/156.0,5)
  generated_visible_aspect=[Math]::Round($rawSilhouette[2]/[double]$rawSilhouette[3],5)
  base=[ordered]@{path=$basePath;width=$base.Width;height=$base.Height;contains_ui_bottles=$false;mapping='uniform center-fit';scale=$scale;offset=@($offsetX,$offsetY)}
  date_preview_placement=@($placeX,$placeY,$placeW,$placeH)
  pixels_changed_outside_date_placement=$outsideChanges
  preview_files=@($boardPath,$previewPath)
  source_hash=(Get-FileHash -LiteralPath (Join-Path $PSScriptRoot '源图_选定双瓶主页.png') -Algorithm SHA256).Hash
  base_hash=(Get-FileHash -LiteralPath $basePath -Algorithm SHA256).Hash
  raw_hash=(Get-FileHash -LiteralPath $rawPath -Algorithm SHA256).Hash
  money_processed=$false
  formal_assets_delivered=$false
  findings=@('Real RGBA, but center ROI alpha only 0-1 and 94.1119 percent exactly zero.','Visible width/height ratio is about 12.46 percent narrower than approximate selected-source silhouette.','Shoulder highlight and green-gold rim are stronger than source. No obvious baked wood/plants in inspected light/dark composites.','Alpha 1-7 scattered noise outside meaningful bounds prevented a strict all-nonzero tight crop.','User requested stop at date problem preview when date is visibly distorted; money processing was not started.')
}
$result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $taskRoot '检查结果_v01.json') -Encoding UTF8
$summary=[ordered]@{raw_dimensions=@($raw.Width,$raw.Height);trimmed_dimensions=@($cut.Width,$cut.Height);alpha_zero=$audit['alpha_zero_pixels'];alpha_partial=$audit['alpha_partial_pixels'];alpha_255=$audit['alpha_255_pixels'];alpha_levels=$audit['alpha_levels_used'];bounds=$audit['bounds_alpha_ge_8'];center_alpha_min=$audit['empty_center_alpha_min'];center_alpha_max=$audit['empty_center_alpha_max'];center_zero_pct=$audit['empty_center_zero_percent'];source_aspect=$result.source_date_aspect_approx;generated_aspect=$result.generated_visible_aspect;placement=$result.date_preview_placement;outside_changes=$outsideChanges}
$summary | ConvertTo-Json -Depth 4
$raw.Dispose();$cut.Dispose();$sourceCrop.Dispose();$board.Dispose();$base.Dispose();$preview.Dispose()
$titleFont.Dispose();$labelFont.Dispose();$ink.Dispose();$lightBrush.Dispose();$darkBrush.Dispose()
