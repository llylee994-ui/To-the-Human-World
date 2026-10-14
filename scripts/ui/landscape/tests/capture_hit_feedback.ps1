param([string]$SessionReceipt,[string]$EvidenceDirectory)
$ErrorActionPreference='Stop'
$maker='C:\Users\YINGYI\.taptap-maker\mcp-runtime\0.0.36\dist\maker.js'
$node='D:\node.js\node.exe'
$project=Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot)))
$receipt=Get-Content -LiteralPath $SessionReceipt -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $receipt.process_alive) { throw 'No live receipt; capture cannot start a preview.' }
$cursor=0
$captured=@{}
$records=@()
$allLines=@()
$until=(Get-Date).AddSeconds(240)
while ((Get-Date) -lt $until) {
    $raw=& $node $maker preview logs --target-dir $project --session-id $receipt.session_id --reload-id $receipt.reload_id --cursor $cursor --limit 500 --json
    $logs=$raw | ConvertFrom-Json
    if (-not $logs.process_alive -or $logs.session_id -ne $receipt.session_id -or $logs.reload_id -ne $receipt.reload_id) { throw 'Preview changed or stopped; capture abandoned.' }
    $cursor=$logs.next_cursor
    $allLines+=@($logs.logs)
    foreach ($line in $logs.logs) {
        if ($line.text -match '\[HitFeedback\]') { Write-Output $line.text }
        if ($line.text -match '\[HitFeedback\] CAPTURE ([a-zA-Z0-9_.-]+)' -and -not $captured.ContainsKey($Matches[1])) {
            $name=$Matches[1]
            $path=Join-Path $EvidenceDirectory ($name+'.png')
            $start=(Get-Date).ToUniversalTime().ToString('o')
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'window_evidence.ps1') -RuntimePid $receipt.runtime_pid -Output $path
            if ($LASTEXITCODE -ne 0) { throw 'Window capture failed' }
            $captured[$name]=$true
            $records+=@{name=$name;file=$path;marker=$line.text;startUtc=$start;endUtc=(Get-Date).ToUniversalTime().ToString('o');session=$receipt.session_id;reload=$receipt.reload_id;runtimePid=$receipt.runtime_pid}
        }
    }
    $records | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $EvidenceDirectory 'capture-index.json') -Encoding UTF8
    $allLines | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $EvidenceDirectory 'normal-native-logs.json') -Encoding UTF8
    if (@($logs.logs | Where-Object {$_.text -match '\[HitFeedback\] FAIL'}).Count) { throw 'Native probe failed; logs preserved' }
    if (@($logs.logs | Where-Object {$_.text -match '\[HitFeedback\] PASS normal held frames'}).Count) {
        if ($captured.Count -ne 9) { throw "Expected nine held captures, got $($captured.Count)" }
        Write-Output 'CAPTURE PASS: nine held frames; session retained.'
        exit 0
    }
    Start-Sleep -Milliseconds 300
}
throw 'Capture timed out; preview was not stopped or restarted.'
