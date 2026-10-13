$ErrorActionPreference='Stop'
$labRoot=$PSScriptRoot
if ([IO.Path]::GetFullPath($labRoot) -ne 'D:\taptap\To-the-Human-World-3D-Lab') {throw 'This launcher belongs to the isolated 3D Lab'}
$env:TAPTAP_MAKER_HOME=Join-Path $labRoot '.preview-home'
$env:TEMP=Join-Path $labRoot 'tools\tmp';$env:TMP=$env:TEMP
$cli='C:\Users\YINGYI\AppData\Roaming\npm\node_modules\@taptap\maker\dist\maker.js'
$state=(& 'D:\node.js\node.exe' $cli preview status --target-dir $labRoot --json) | ConvertFrom-Json
if ($state.project_realpath -ne $labRoot) {throw 'Unexpected preview project'}
if ($state.process_alive) {Write-Output ('3D Lab is already running. PID: '+$state.runtime_pid);exit 0}
if ($state.state -notin @('stopped','failed','missing')) {throw 'Preview is starting or its state is unknown; inspect it before another launch'}
for ($i=7;$i -lt 100;$i++) {
    $attempt=$i.ToString('D2')
    $out=Join-Path $labRoot ('docs\evidence\v035-main-interface\native-full-20261013-'+$attempt)
    if (-not (Test-Path -LiteralPath $out)) {
        & (Join-Path $labRoot 'tools\start_full_v035.ps1') -Attempt $attempt -Persistent
        Write-Output 'Full 3D Lab launch requested. First load takes several minutes. The game stays open until you close it.'
        exit 0
    }
}
throw 'Evidence attempt numbers are full; preserve the records and allocate a new series.'
