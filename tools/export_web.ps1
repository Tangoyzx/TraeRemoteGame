$ErrorActionPreference = "Stop"

$GodotExe = "D:\GodotEngine\Godot_v4.6.1-stable_win64_console.exe"
$DistDir = Join-Path (Get-Location) "dist"
$ExportPath = Join-Path $DistDir "index.html"

if (-not (Test-Path -LiteralPath $GodotExe)) {
    throw "Godot executable not found: $GodotExe"
}

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
& $GodotExe --headless --path "." --export-release "Web" $ExportPath

Write-Host "Export completed: $ExportPath"
