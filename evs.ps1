<#
.SYNOPSIS
    EnvVarSwitcher (evs) - PowerShell Environment Variable Switcher

.DESCRIPTION
    A tool to quickly switch between different environment variable configurations.

.EXAMPLE
    evs list
    evs use dev
    evs show
#>

param(
    [Parameter(Position = 0)]
    [string]$Command,

    [Parameter(Position = 1)]
    [string]$Name,

    [Parameter(Position = 2, ValueFromRemainingArguments)]
    [string[]]$Args,

    [switch]$Help
)

# ============================================================================
# Configuration
# ============================================================================

$script:ProfilesDir = Join-Path $PSScriptRoot "profiles"
$script:TrackedVarsKey = "EVS_TRACKED_VARS"
$script:ActiveProfileKey = "EVS_ACTIVE_PROFILE"

# ============================================================================
# Helper Functions
# ============================================================================

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Type = "Info"  # Success, Error, Warning, Info, Muted
    )

    switch ($Type) {
        "Success" { Write-Host $Message -ForegroundColor Green }
        "Error" { Write-Host $Message -ForegroundColor Red }
        "Warning" { Write-Host $Message -ForegroundColor Yellow }
        "Info" { Write-Host $Message -ForegroundColor Cyan }
        "Muted" { Write-Host $Message -ForegroundColor DarkGray }
        default { Write-Host $Message }
    }
}

function Get-ProfilePath {
    param([string]$ProfileName)
    return Join-Path $script:ProfilesDir "$ProfileName.json"
}

function Test-CodexProfile {
    param([string]$ProfileName)
    $dirPath = Join-Path $script:ProfilesDir $ProfileName
    return (Test-Path $dirPath -PathType Container)
}

function Get-CodexProfilePath {
    param([string]$ProfileName)
    return Join-Path $script:ProfilesDir $ProfileName
}

function Apply-CodexConfig {
    param([string]$ProfileName)

    $profilePath = Get-CodexProfilePath $ProfileName
    $configPath = Join-Path $profilePath "config.toml"
    $authPath = Join-Path $profilePath "auth.json"

    # Validate files exist
    if (-not (Test-Path $configPath)) {
        Write-ColorOutput "Missing config.toml in profile '$ProfileName'" "Error"
        return $false
    }

    if (-not (Test-Path $authPath)) {
        Write-ColorOutput "Missing auth.json in profile '$ProfileName'" "Error"
        return $false
    }

    # Ensure ~/.codex directory exists
    $codexDir = Join-Path $env:USERPROFILE ".codex"
    if (-not (Test-Path $codexDir)) {
        New-Item -ItemType Directory -Path $codexDir -Force | Out-Null
    }

    # Copy files
    try {
        $targetConfig = Join-Path $codexDir "config.toml"
        $targetAuth = Join-Path $codexDir "auth.json"

        Copy-Item $configPath $targetConfig -Force
        Copy-Item $authPath $targetAuth -Force

        return $true
    }
    catch {
        Write-ColorOutput "Failed to copy config files: $_" "Error"
        Write-ColorOutput "Check permissions for $codexDir directory" "Warning"
        return $false
    }
}

function Get-AllProfiles {
    if (-not (Test-Path $script:ProfilesDir)) {
        return @()
    }

    $allProfiles = @()

    # Get JSON profiles (environment variables)
    $jsonProfiles = Get-ChildItem -Path $script:ProfilesDir -Filter "*.json" -ErrorAction SilentlyContinue
    foreach ($file in $jsonProfiles) {
        try {
            $content = Get-Content $file.FullName -Raw | ConvertFrom-Json
            $allProfiles += [PSCustomObject]@{
                FileName    = $file.BaseName
                Name        = if ($content.name) { $content.name } else { $file.BaseName }
                Description = if ($content.description) { $content.description } else { "" }
                Type        = "env"
                Variables   = $content.variables
                Path        = $file.FullName
            }
        }
        catch {
            Write-ColorOutput "Failed to parse profile '$($file.BaseName)': $_" "Warning"
        }
    }

    # Get directory profiles (codex configurations)
    $dirProfiles = Get-ChildItem -Path $script:ProfilesDir -Directory -ErrorAction SilentlyContinue
    foreach ($dir in $dirProfiles) {
        $configPath = Join-Path $dir.FullName "config.toml"
        $authPath = Join-Path $dir.FullName "auth.json"

        if ((Test-Path $configPath) -and (Test-Path $authPath)) {
            $allProfiles += [PSCustomObject]@{
                FileName    = $dir.Name
                Name        = $dir.Name
                Description = "Codex configuration"
                Type        = "codex"
                Variables   = $null
                Path        = $dir.FullName
            }
        }
    }

    return $allProfiles
}

function Read-ProfileConfig {
    param([string]$ProfileName)

    $path = Get-ProfilePath $ProfileName
    if (-not (Test-Path $path)) {
        return $null
    }

    try {
        $content = Get-Content $path -Raw | ConvertFrom-Json
        return $content
    }
    catch {
        Write-ColorOutput "Failed to parse profile '$ProfileName': $_" "Error"
        return $null
    }
}

function Get-MaskedValue {
    param([string]$Value)

    if ([string]::IsNullOrEmpty($Value)) {
        return $Value
    }

    $len = $Value.Length
    if ($len -le 4) {
        # Too short, mask entirely
        return "*" * $len
    }
    elseif ($len -le 8) {
        # Short value: show first 1 and last 1
        return $Value[0] + ("*" * ($len - 2)) + $Value[-1]
    }
    else {
        # Normal value: show first 2 and last 3
        $first = $Value.Substring(0, 2)
        $last = $Value.Substring($len - 3)
        $masked = "*" * ($len - 5)
        return "$first$masked$last"
    }
}

function Get-TrackedVars {
    $tracked = [Environment]::GetEnvironmentVariable($script:TrackedVarsKey)
    if ([string]::IsNullOrEmpty($tracked)) {
        return @()
    }
    return $tracked -split ","
}

function Set-TrackedVars {
    param([string[]]$VarNames)
    $value = $VarNames -join ","
    [Environment]::SetEnvironmentVariable($script:TrackedVarsKey, $value)
}

function Add-TrackedVar {
    param([string]$VarName)
    $current = Get-TrackedVars
    if ($VarName -notin $current) {
        $current += $VarName
        Set-TrackedVars $current
    }
}

# ============================================================================
# Command: Help
# ============================================================================

function Show-Help {
    $helpText = @"

  EnvVarSwitcher (evs) - Environment Variable Switcher

  USAGE:
    evs <command> [arguments]

  COMMANDS:
    list, ls              List all available profiles
    use, switch <name>    Switch to specified profile
    show [name]           Show current state or preview a profile
    clear                 Clear all variables set by current profile
    add <name>            Create a new profile interactively
    edit <name>           Open profile in default editor
    remove, rm <name>     Delete a profile

  EXAMPLES:
    evs list              # List all profiles
    evs use dev           # Switch to 'dev' profile
    evs show              # Show current active variables
    evs show prod         # Preview 'prod' profile
    evs clear             # Clear current session variables
    evs add staging       # Create new 'staging' profile
    evs edit dev          # Edit 'dev' profile

  PROFILE LOCATION:
    $script:ProfilesDir

"@
    Write-Host $helpText
}

# ============================================================================
# Command: List
# ============================================================================

function Invoke-List {
    $profiles = @(Get-AllProfiles)

    if ($profiles.Count -eq 0) {
        Write-ColorOutput "No profiles found." "Warning"
        Write-Host "Create one with: evs add <name>"
        return
    }

    $activeProfile = [Environment]::GetEnvironmentVariable($script:ActiveProfileKey)

    Write-Host ""
    Write-Host "Available profiles:"
    Write-Host ""

    foreach ($p in $profiles) {
        $marker = if ($p.FileName -eq $activeProfile) { "*" } else { " " }
        $color = if ($p.FileName -eq $activeProfile) { "Green" } else { "White" }

        # Add type indicator
        $typeIndicator = if ($p.Type -eq "codex") { "[codex]" } else { "[env]  " }

        $line = "  $marker $($p.FileName.PadRight(15)) $typeIndicator"
        Write-Host $line -NoNewline -ForegroundColor $color

        if ($p.Description) {
            Write-Host " - $($p.Description)" -ForegroundColor DarkGray
        }
        else {
            Write-Host ""
        }
    }

    Write-Host ""
    Write-ColorOutput "  * = active profile" "Muted"
    Write-Host ""
}

# ============================================================================
# Command: Use
# ============================================================================

function Invoke-Use {
    param([string]$ProfileName)

    if ([string]::IsNullOrEmpty($ProfileName)) {
        Write-ColorOutput "Usage: evs use <profile-name>" "Error"
        return
    }

    $config = Read-ProfileConfig $ProfileName
    if ($null -eq $config) {
        Write-ColorOutput "Profile '$ProfileName' not found." "Error"
        Write-Host "Run 'evs list' to see available profiles."
        return
    }

    # Clear previous variables first
    Invoke-Clear -Silent

    # Set new variables
    $varCount = 0
    $varNames = @()

    if ($config.variables) {
        $config.variables.PSObject.Properties | ForEach-Object {
            $varName = $_.Name
            $varValue = $_.Value

            [Environment]::SetEnvironmentVariable($varName, $varValue)
            $varNames += $varName
            $varCount++
        }
    }

    # Track which variables we set
    Set-TrackedVars $varNames
    [Environment]::SetEnvironmentVariable($script:ActiveProfileKey, $ProfileName)

    # Output
    Write-Host ""
    Write-ColorOutput "Switched to '$ProfileName'" "Success"
    Write-Host ""

    if ($varCount -gt 0) {
        Write-Host "  Set $varCount variable(s):"
        foreach ($varName in $varNames) {
            $value = [Environment]::GetEnvironmentVariable($varName)
            $maskedValue = Get-MaskedValue $value
            Write-Host "    " -NoNewline
            Write-Host $varName -NoNewline -ForegroundColor Cyan
            Write-Host " = " -NoNewline
            Write-Host $maskedValue -ForegroundColor White
        }
    }

    Write-Host ""
}

# ============================================================================
# Command: Show
# ============================================================================

function Invoke-Show {
    param([string]$ProfileName)

    Write-Host ""

    # If profile name given, preview that profile
    if (-not [string]::IsNullOrEmpty($ProfileName)) {
        $config = Read-ProfileConfig $ProfileName
        if ($null -eq $config) {
            Write-ColorOutput "Profile '$ProfileName' not found." "Error"
            return
        }

        Write-Host "Profile: " -NoNewline
        Write-Host $ProfileName -ForegroundColor Cyan

        if ($config.description) {
            Write-ColorOutput "  $($config.description)" "Muted"
        }

        Write-Host ""
        Write-Host "Variables:"

        if ($config.variables) {
            $config.variables.PSObject.Properties | ForEach-Object {
                $maskedValue = Get-MaskedValue $_.Value
                Write-Host "    " -NoNewline
                Write-Host $_.Name -NoNewline -ForegroundColor Cyan
                Write-Host " = " -NoNewline
                Write-Host $maskedValue -ForegroundColor White
            }
        }
        else {
            Write-ColorOutput "  (no variables defined)" "Muted"
        }

        Write-Host ""
        return
    }

    # Show current session state
    $activeProfile = [Environment]::GetEnvironmentVariable($script:ActiveProfileKey)
    $trackedVars = @(Get-TrackedVars)

    if ([string]::IsNullOrEmpty($activeProfile)) {
        Write-ColorOutput "No active profile." "Muted"
        Write-Host "Use 'evs use <name>' to switch to a profile."
        Write-Host ""
        return
    }

    Write-Host "Active profile: " -NoNewline
    Write-Host $activeProfile -ForegroundColor Green
    Write-Host ""

    if ($trackedVars.Count -gt 0) {
        Write-Host "Variables:"
        foreach ($varName in $trackedVars) {
            $value = [Environment]::GetEnvironmentVariable($varName)
            $maskedValue = Get-MaskedValue $value
            Write-Host "    " -NoNewline
            Write-Host $varName -NoNewline -ForegroundColor Cyan
            Write-Host " = " -NoNewline
            Write-Host $maskedValue -ForegroundColor White
        }
    }
    else {
        Write-ColorOutput "  (no variables set)" "Muted"
    }

    Write-Host ""
}

# ============================================================================
# Command: Clear
# ============================================================================

function Invoke-Clear {
    param([switch]$Silent)

    $trackedVars = @(Get-TrackedVars)
    $activeProfile = [Environment]::GetEnvironmentVariable($script:ActiveProfileKey)

    if ($trackedVars.Count -eq 0 -and [string]::IsNullOrEmpty($activeProfile)) {
        if (-not $Silent) {
            Write-Host ""
            Write-ColorOutput "No variables to clear." "Muted"
            Write-Host ""
        }
        return
    }

    # Clear each tracked variable
    foreach ($varName in $trackedVars) {
        [Environment]::SetEnvironmentVariable($varName, $null)
    }

    # Clear tracking variables
    [Environment]::SetEnvironmentVariable($script:TrackedVarsKey, $null)
    [Environment]::SetEnvironmentVariable($script:ActiveProfileKey, $null)

    if (-not $Silent) {
        Write-Host ""
        Write-ColorOutput "Cleared $($trackedVars.Count) variable(s) from session." "Success"
        Write-Host ""
    }
}

# ============================================================================
# Command: Add
# ============================================================================

function Invoke-Add {
    param([string]$ProfileName)

    if ([string]::IsNullOrEmpty($ProfileName)) {
        Write-ColorOutput "Usage: evs add <profile-name>" "Error"
        return
    }

    # Validate name
    if ($ProfileName -notmatch '^[a-zA-Z0-9_-]+$') {
        Write-ColorOutput "Invalid profile name. Use only letters, numbers, underscore, and hyphen." "Error"
        return
    }

    $path = Get-ProfilePath $ProfileName
    if (Test-Path $path) {
        Write-ColorOutput "Profile '$ProfileName' already exists." "Error"
        Write-Host "Use 'evs edit $ProfileName' to modify it."
        return
    }

    # Ensure profiles directory exists
    if (-not (Test-Path $script:ProfilesDir)) {
        New-Item -ItemType Directory -Path $script:ProfilesDir -Force | Out-Null
    }

    Write-Host ""
    Write-Host "Creating new profile: " -NoNewline
    Write-Host $ProfileName -ForegroundColor Cyan
    Write-Host ""

    # Get description
    $description = Read-Host "Description (optional)"

    # Get variables
    Write-Host ""
    Write-Host "Enter variables (empty name to finish):"
    Write-Host ""

    $variables = @{}
    while ($true) {
        $varName = Read-Host "  Variable name"
        if ([string]::IsNullOrEmpty($varName)) {
            break
        }

        $varValue = Read-Host "  Value for '$varName'"
        $variables[$varName] = $varValue
        Write-Host ""
    }

    # Create config object
    $config = @{
        name        = $ProfileName
        description = $description
        variables   = $variables
    }

    # Write to file
    $config | ConvertTo-Json -Depth 10 | Set-Content -Path $path -Encoding UTF8

    Write-Host ""
    Write-ColorOutput "Profile '$ProfileName' created successfully." "Success"
    Write-Host "  Location: $path"
    Write-Host ""
    Write-Host "Use 'evs use $ProfileName' to activate it."
    Write-Host ""
}

# ============================================================================
# Command: Edit
# ============================================================================

function Invoke-Edit {
    param([string]$ProfileName)

    if ([string]::IsNullOrEmpty($ProfileName)) {
        Write-ColorOutput "Usage: evs edit <profile-name>" "Error"
        return
    }

    $path = Get-ProfilePath $ProfileName
    if (-not (Test-Path $path)) {
        Write-ColorOutput "Profile '$ProfileName' not found." "Error"
        Write-Host "Run 'evs list' to see available profiles."
        return
    }

    # Try to open with default editor
    Write-Host ""
    Write-Host "Opening '$ProfileName' in editor..."

    try {
        # Try VS Code first
        $vscode = Get-Command "code" -ErrorAction SilentlyContinue
        if ($vscode) {
            & code $path
            return
        }

        # Try notepad++
        $npp = Get-Command "notepad++" -ErrorAction SilentlyContinue
        if ($npp) {
            & notepad++ $path
            return
        }

        # Fall back to notepad
        & notepad $path
    }
    catch {
        Write-ColorOutput "Failed to open editor: $_" "Error"
        Write-Host "File location: $path"
    }
}

# ============================================================================
# Command: Remove
# ============================================================================

function Invoke-Remove {
    param([string]$ProfileName)

    if ([string]::IsNullOrEmpty($ProfileName)) {
        Write-ColorOutput "Usage: evs remove <profile-name>" "Error"
        return
    }

    $path = Get-ProfilePath $ProfileName
    if (-not (Test-Path $path)) {
        Write-ColorOutput "Profile '$ProfileName' not found." "Error"
        return
    }

    Write-Host ""
    $confirm = Read-Host "Are you sure you want to delete '$ProfileName'? (y/N)"

    if ($confirm -eq "y" -or $confirm -eq "Y") {
        Remove-Item $path -Force

        # Clear if this was the active profile
        $activeProfile = [Environment]::GetEnvironmentVariable($script:ActiveProfileKey)
        if ($activeProfile -eq $ProfileName) {
            Invoke-Clear -Silent
        }

        Write-ColorOutput "Profile '$ProfileName' deleted." "Success"
    }
    else {
        Write-ColorOutput "Cancelled." "Muted"
    }

    Write-Host ""
}

# ============================================================================
# Main Entry Point
# ============================================================================

# Show help if requested or no command given
if ($Help -or [string]::IsNullOrEmpty($Command)) {
    Show-Help
    return
}

# Route to appropriate command
switch ($Command.ToLower()) {
    { $_ -in "list", "ls" } {
        Invoke-List
    }
    { $_ -in "use", "switch" } {
        Invoke-Use -ProfileName $Name
    }
    "show" {
        Invoke-Show -ProfileName $Name
    }
    "clear" {
        Invoke-Clear
    }
    "add" {
        Invoke-Add -ProfileName $Name
    }
    "edit" {
        Invoke-Edit -ProfileName $Name
    }
    { $_ -in "remove", "rm" } {
        Invoke-Remove -ProfileName $Name
    }
    "help" {
        Show-Help
    }
    default {
        Write-ColorOutput "Unknown command: $Command" "Error"
        Write-Host "Run 'evs help' for usage information."
    }
}
