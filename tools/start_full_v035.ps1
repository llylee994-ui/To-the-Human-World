param([Parameter(Mandatory=$true)][ValidatePattern('^\d{2}$')][string]$Attempt,[switch]$Persistent)
$ErrorActionPreference='Stop'
$labRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ($labRoot -ne 'D:\taptap\To-the-Human-World-3D-Lab') {throw 'Wrong Lab'}
$env:TAPTAP_MAKER_HOME=Join-Path $labRoot '.preview-home'
$env:TEMP=Join-Path $labRoot 'tools\tmp';$env:TMP=$env:TEMP
$env:TAPTAP_MAKER_PYTHON_BIN='C:\Python313\python.exe'
$cli='C:\Users\YINGYI\AppData\Roaming\npm\node_modules\@taptap\maker\dist\maker.js'
$state=(& 'D:\node.js\node.exe' $cli preview status --target-dir $labRoot --json) | ConvertFrom-Json
if ($state.process_alive -or $state.project_realpath -ne $labRoot) {throw 'Live or unknown Lab session'}
$out=Join-Path $labRoot ('docs\evidence\v035-main-interface\native-full-20261013-'+$Attempt)
if (Test-Path -LiteralPath (Join-Path $out 'launch-intent.json')) {throw 'Attempt already used'}
New-Item -ItemType Directory -Path $out -Force | Out-Null
& 'D:\node.js\node.exe' $cli preview prepare --target-dir $labRoot --json 1> (Join-Path $out 'prepare-result.json') 2> (Join-Path $out 'prepare-stderr.log')
$LASTEXITCODE | Set-Content (Join-Path $out 'prepare-exit-code.txt')
if ($LASTEXITCODE -ne 0) {throw 'Official prepare failed; inspect evidence, no Runtime launched'}
$observerArgs=@('-X','utf8','tools\observe_full_v035.py','--attempt',$Attempt)
if ($Persistent) {$observerArgs+='--persistent'}
$p=Start-Process -FilePath 'C:\Python313\python.exe' -ArgumentList $observerArgs -WorkingDirectory $labRoot -WindowStyle Hidden -RedirectStandardOutput (Join-Path $out 'observer-stdout.log') -RedirectStandardError (Join-Path $out 'observer-stderr.log') -PassThru
@{observerPid=$p.Id;startedUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Tee-Object -FilePath (Join-Path $out 'observer-process.json')
