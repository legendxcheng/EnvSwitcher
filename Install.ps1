<#
.SYNOPSIS
    Install EnvVarSwitcher (evs) tool

.DESCRIPTION
    This script sets up the 'evs' command for use in PowerShell.
    It adds a function to your PowerShell profile.

.EXAMPLE
    .\Install.ps1
#>

$ErrorActionPreference = "Stop"

$scriptDir = $PSScriptRoot
$evsScript = Join-Path $scriptDir "evs.ps1"

# Verify evs.ps1 exists
if (-not (Test-Path $evsScript)) {
    Write-Host "Error: evs.ps1 not found in $scriptDir" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "EnvVarSwitcher (evs) Installer" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""

# Check if profile exists
$profilePath = $PROFILE.CurrentUserCurrentHost
$profileDir = Split-Path $profilePath -Parent

if (-not (Test-Path $profileDir)) {
    Write-Host "Creating PowerShell profile directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

# Function definition to add to profile
$functionDef = @"

# EnvVarSwitcher (evs) - Environment Variable Switcher
function evs {
    & "$evsScript" @args
}
"@

# Check if already installed
$profileContent = ""
if (Test-Path $profilePath) {
    $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
}

if ($profileContent -and $profileContent.Contains("EnvVarSwitcher")) {
    Write-Host "evs is already installed in your PowerShell profile." -ForegroundColor Yellow
    Write-Host ""

    $reinstall = Read-Host "Do you want to reinstall? (y/N)"
    if ($reinstall -ne "y" -and $reinstall -ne "Y") {
        Write-Host "Installation cancelled." -ForegroundColor Gray
        exit 0
    }

    # Remove existing installation
    $profileContent = $profileContent -replace "(?s)# EnvVarSwitcher.*?function evs \{[^}]+\}", ""
    Set-Content $profilePath $profileContent.Trim() -Encoding UTF8
}

# Add to profile
Add-Content $profilePath $functionDef -Encoding UTF8

Write-Host "Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "The 'evs' command has been added to your PowerShell profile."
Write-Host ""
Write-Host "To start using evs:" -ForegroundColor Cyan
Write-Host "  1. Restart PowerShell, or run: " -NoNewline
Write-Host ". `$PROFILE" -ForegroundColor Yellow
Write-Host "  2. Then try: " -NoNewline
Write-Host "evs list" -ForegroundColor Yellow
Write-Host ""
Write-Host "Profile location: $profilePath" -ForegroundColor Gray
Write-Host "Script location:  $evsScript" -ForegroundColor Gray
Write-Host ""
