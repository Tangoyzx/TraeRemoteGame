$ErrorActionPreference = "Stop"

$GodotExe = "D:\GodotEngine\Godot_v4.6.1-stable_win64_console.exe"

Write-Host "Checking Git..."
git --version

Write-Host "Checking Godot executable..."
if (-not (Test-Path -LiteralPath $GodotExe)) {
    throw "Godot executable not found: $GodotExe"
}

& $GodotExe --version

Write-Host "Checking required project files..."
$requiredFiles = @(
    "project.godot",
    "scenes/main.tscn",
    "scripts/main.gd",
    "export_presets.cfg",
    ".github/workflows/deploy-pages.yml"
)

foreach ($file in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $file)) {
        throw "Missing required file: $file"
    }
    Write-Host "OK: $file"
}

Write-Host "Environment check completed."
