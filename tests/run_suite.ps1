param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [string]$Label = 'regression',
    [string[]]$Tests = @(),
    [int]$TimeoutSeconds = 120
)
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
if ($Label -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Label must be a filename-safe identifier.' }
$output = Join-Path $project "test-results/$Label"
New-Item -ItemType Directory -Force -Path $output | Out-Null
$scenarios = @('verify','verify-motion','verify-table','verify-look','verify-inspector')
if ($Tests.Count -eq 0) { $Tests = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*_test.gd' | Sort-Object Name | ForEach-Object { $_.BaseName }) + $scenarios }
$results = @()
foreach ($name in $Tests) {
    $scenario = $name -in $scenarios
    if (-not $scenario -and ($name -notmatch '^[a-zA-Z0-9_]+$' -or -not (Test-Path (Join-Path $PSScriptRoot "$name.gd")))) { throw "Unknown test: $name" }
    $stdout = Join-Path $output "$name.stdout.log"
    $stderr = Join-Path $output "$name.stderr.log"
    $arguments = @('--path', "`"$project`"", '--script', "res://tests/$name.gd")
    if ($scenario) { $arguments = @('--path', "`"$project`"", '--', "--$name") }
    if ($name -in @('model_test', 'shift_model_test', 'table_rules_test', 'optimization_model_parity_test', 'linked_model_parity_test', 'structure_refactor_test', 'linked_rules_test', 'script_parse_test')) { $arguments = @('--headless') + $arguments }
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $process = Start-Process -FilePath $Godot -ArgumentList $arguments -WorkingDirectory $project -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) { $process.Kill(); $process.WaitForExit() }
    $process.Refresh()
    $log = (Get-Content -LiteralPath $stdout,$stderr -Raw) -join "`n"
    $passed = -not $timedOut -and $process.ExitCode -eq 0 -and $log -match 'PASS' -and $log -notmatch '(?m)(SCRIPT ERROR:|ERROR:)'
    $row = [pscustomobject]@{ Test=$name; Passed=$passed; TimedOut=$timedOut; ExitCode=$process.ExitCode; Seconds=[math]::Round($watch.Elapsed.TotalSeconds,2) }
    $results += $row
    Write-Output ("{0}: {1} ({2}s)" -f $name, $(if ($passed) {'PASS'} else {'FAIL'}), $row.Seconds)
    if (-not $passed) { Write-Output $log }
}
$results | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $output 'summary.json') -Encoding UTF8
if (@($results | Where-Object { -not $_.Passed }).Count -gt 0) { exit 1 }
