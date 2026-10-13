param([ValidateSet('status','run','refresh','logs')][string]$Action='status',[switch]$AllowNativeQa)
$ErrorActionPreference='Stop'
$labRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ($labRoot -ne 'D:\taptap\To-the-Human-World-3D-Lab') { throw 'This launcher is scoped to the original isolated lab' }
$cli='C:\Users\YINGYI\AppData\Roaming\npm\node_modules\@taptap\maker\dist\maker.js'
$node='D:\node.js\node.exe'
$runtime=Join-Path $labRoot '.runtime\UrhoXRuntime.exe'
foreach($file in @($cli,$node,$runtime,(Join-Path $labRoot '.maker-mcp\config.json'))) { if(-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing existing dependency: $file; nothing will be installed or rebound" } }
$config=Get-Content (Join-Path $labRoot 'scripts\lab\QAConfig.lua') -Raw
if($Action -in @('run','refresh') -and -not $AllowNativeQa -and $config -notmatch 'enabled\s*=\s*false') { throw 'QA is enabled. Restore QAConfig.enabled=false for normal use, or explicitly opt into the test.' }
$env:TAPTAP_MAKER_HOME=Join-Path $labRoot '.preview-home'
$env:TEMP=Join-Path $labRoot 'tools\tmp'; $env:TMP=$env:TEMP
$env:TAPTAP_MAKER_PYTHON_BIN='C:\Python313\python.exe'
if($Action -eq 'refresh') {
 $s=(& $node $cli preview status --target-dir $labRoot --json)|ConvertFrom-Json
 if(-not $s.process_alive -or $s.project_realpath -ne $labRoot) { throw 'No verified live lab preview; refresh will not restart a stopped preview' }
}
if($Action -eq 'run') {
 # Invoke only when the user explicitly wants a preview or during an authorized,
 # recorded bounded test. Never call to undo a user stop.
 & $node $cli preview run --target-dir $labRoot --runtime $runtime --duration-ms 600000 --json
} else { & $node $cli preview $Action --target-dir $labRoot --json }
exit $LASTEXITCODE
