[CmdletBinding()]
param(
    [string]$Remote = "origin",
    [switch]$Force,
    [switch]$IncludeIgnored
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Git {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    Write-Host "> git $($Arguments -join ' ')"
    & git @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
}

function Get-GitOutput {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $output = & git @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
    return ($output | Out-String).Trim()
}

$repoRoot = Get-GitOutput -Arguments @("rev-parse", "--show-toplevel")
Set-Location $repoRoot

$branch = Get-GitOutput -Arguments @("branch", "--show-current")
if ([string]::IsNullOrWhiteSpace($branch)) {
    throw "Current HEAD is detached; reset-to-remote-latest requires a named branch."
}

$target = "$Remote/$branch"
$cleanArgs = if ($IncludeIgnored) { @("clean", "-fdx") } else { @("clean", "-fd") }

Write-Host "Repository: $repoRoot"
Write-Host "Current branch: $branch"
Write-Host "Remote target: $target"
Write-Host ""
Write-Host "Current status:"
Invoke-Git -Arguments @("status", "--short", "--branch")
Write-Host ""

if (-not $Force) {
    Write-Host "Preview only. No files were changed."
    Write-Host "To execute the destructive reset, rerun with -Force."
    Write-Host "Commands that will run:"
    Write-Host "  git fetch --prune $Remote"
    Write-Host "  git reset --hard $target"
    Write-Host "  git $($cleanArgs -join ' ')"
    exit 0
}

Write-Host "WARNING: This will discard tracked local changes and remove untracked files."
if ($IncludeIgnored) {
    Write-Host "WARNING: -IncludeIgnored is set; ignored files will also be removed."
}

Invoke-Git -Arguments @("fetch", "--prune", $Remote)
Invoke-Git -Arguments @("rev-parse", "--verify", "$target^{commit}")
Invoke-Git -Arguments @("reset", "--hard", $target)
Invoke-Git -Arguments $cleanArgs

Write-Host ""
Write-Host "Workspace reset complete. Final status:"
Invoke-Git -Arguments @("status", "--short", "--branch")
