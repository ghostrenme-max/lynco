param([Parameter(Mandatory=$true)][string]$Godot)
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$output = Join-Path $project ('test-results/editor-runtime-' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
& (Join-Path $PSScriptRoot 'build.ps1') -Output $output
$exe = Join-Path $output 'LYNCO_Card_Editor.exe'
function Run-Editor([string[]]$Arguments) {
    $quoted = @($Arguments | ForEach-Object { '"' + $_ + '"' })
    $process = Start-Process -FilePath $exe -ArgumentList $quoted -WindowStyle Hidden -PassThru -Wait
    if ($process.ExitCode -ne 0) { throw 'Editor test failed' }
}
Run-Editor @('--test', $output)
if (-not (Test-Path (Join-Path $output 'PASS.txt'))) { throw 'Missing editor test output' }
$fixture = Join-Path $output 'game'
New-Item -ItemType Directory -Force -Path (Join-Path $fixture 'scripts'),(Join-Path $fixture 'data'),(Join-Path $fixture 'assets/icons') | Out-Null
'config_version=5' | Set-Content -LiteralPath (Join-Path $fixture 'project.godot') -Encoding UTF8
foreach ($name in @('linked_rules.gd','linked_battle_model.gd','table_battle_model.gd','battle_model.gd','catalog.gd','collection_session.gd')) {
    Copy-Item -LiteralPath (Join-Path $project "scripts/$name") -Destination (Join-Path $fixture "scripts/$name")
}
Get-ChildItem -LiteralPath (Join-Path $project 'assets/icons') -Filter '*.png' | Copy-Item -Destination (Join-Path $fixture 'assets/icons')
Copy-Item -LiteralPath (Join-Path $project 'data/default_battle_cards.json') -Destination (Join-Path $fixture 'data/default_battle_cards.json')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'editor_bridge_test.gd') -Destination (Join-Path $fixture 'test.gd')
Run-Editor @('--apply',(Join-Path $output 'runtime_ui_saved.json'),$fixture)
& $Godot --headless --path $fixture --script res://test.gd
if ($LASTEXITCODE -ne 0) { throw 'Game bridge test failed' }
$export = (Get-ChildItem -LiteralPath $output -Directory -Filter 'LYNCO_Godot_*' | Select-Object -First 1).FullName
'config_version=5' | Set-Content -LiteralPath (Join-Path $export 'project.godot') -Encoding UTF8
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'export_test.gd') -Destination (Join-Path $export 'test.gd')
& $Godot --headless --path $export --editor --import
if ($LASTEXITCODE -ne 0) { throw 'Resource import failed' }
& $Godot --headless --path $export --script res://test.gd
if ($LASTEXITCODE -ne 0) { throw 'Resource export test failed' }
Write-Output "EDITOR_RUNTIME_PASS: $output"
