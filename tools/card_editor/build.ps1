param([string]$Output = "$PSScriptRoot\build")
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $Output | Out-Null
$compiler = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$arguments = @('/nologo','/target:winexe','/r:System.Windows.Forms.dll','/r:System.Drawing.dll','/r:System.Web.Extensions.dll',"/out:$Output\LYNCO_Card_Editor.exe", "/win32manifest:$PSScriptRoot\editor.manifest")
foreach ($name in @('default_cards.json','decks.json','catalog.html','lynco_card_data.gd','lynco_card_loader.gd','README.txt')) { $arguments += "/resource:$PSScriptRoot\$name,$name" }
foreach ($file in Get-ChildItem "$PSScriptRoot\..\..\assets\icons\*.png") { $arguments += "/resource:$($file.FullName),icon.$($file.Name)" }
$arguments += "$PSScriptRoot\Program.cs"
& $compiler @arguments
if ($LASTEXITCODE -ne 0) { throw 'Compile failed' }
