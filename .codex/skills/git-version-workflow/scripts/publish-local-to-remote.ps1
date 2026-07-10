[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Message,

    [string]$Remote = "origin",
    [switch]$AllowEmpty,
    [switch]$NoPush
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
    throw "Current HEAD is detached; publish-local-to-remote requires a named branch."
}

Write-Host "Repository: $repoRoot"
Write-Host "Current branch: $branch"
Write-Host "Remote target: $Remote/$branch"
Write-Host ""
Write-Host "Initial status:"
Invoke-Git -Arguments @("status", "--short", "--branch")

Invoke-Git -Arguments @("add", "-A")

$hasStagedChanges = $false
& git diff --cached --quiet
if ($LASTEXITCODE -eq 1) {
    $hasStagedChanges = $true
} elseif ($LASTEXITCODE -ne 0) {
    throw "git diff --cached --quiet failed with exit code $LASTEXITCODE"
}

if ($hasStagedChanges) {
    Invoke-Git -Arguments @("commit", "-m", $Message)
} elseif ($AllowEmpty) {
    Invoke-Git -Arguments @("commit", "--allow-empty", "-m", $Message)
} else {
    Write-Host "No staged changes after git add -A; skipping commit."
}

if ($NoPush) {
    Write-Host "NoPush is set; skipping git push."
} else {
    Invoke-Git -Arguments @("push", $Remote, $branch)
}

Write-Host ""
Write-Host "Publish workflow complete. Final status:"
Invoke-Git -Arguments @("status", "--short", "--branch")
