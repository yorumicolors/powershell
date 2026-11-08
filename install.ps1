#Requires -Version 5.1
<#
.SYNOPSIS
    Install the yorumi theme for PowerShell.
.DESCRIPTION
    Copies yorumi.ps1 next to your PowerShell config and puts ONE entry in your
    profile that dot-sources it:

        . "<config>/yorumi/yorumi.ps1" -Flavour <flavour>

    Nothing else is written to the profile. Running this again replaces that
    entry instead of adding a second one, and `Set-YorumiTheme <flavour>` in a
    session always wins until you restart.
.PARAMETER Flavour
    Which flavour the profile entry starts with. Default: ether.
.PARAMETER Destination
    Where yorumi.ps1 goes. Default: %APPDATA%\yorumi on Windows,
    $XDG_CONFIG_HOME/yorumi (or ~/.config/yorumi) elsewhere.
.PARAMETER ProfilePath
    Profile file to add the entry to. Default: $PROFILE.CurrentUserAllHosts.
.PARAMETER NoProfile
    Install the script only; leave the profile alone.
.EXAMPLE
    irm https://raw.githubusercontent.com/yorumicolors/powershell/main/install.ps1 | iex
.EXAMPLE
    ./install.ps1 -Flavour abyss
#>
[CmdletBinding()]
param(
    [string] $Flavour = 'ether',
    [string] $Destination,
    [string] $ProfilePath,
    [switch] $NoProfile
)

$ErrorActionPreference = 'Stop'

# Windows PowerShell 5.1 predates TLS 1.2 defaults; the palette repo is HTTPS only.
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {
    # older .NET without the enum member: nothing to do
}

$rawBase = 'https://raw.githubusercontent.com/yorumicolors/powershell/main'
$isWindowsHost = ($env:OS -eq 'Windows_NT')

if (-not $Destination) {
    if ($isWindowsHost) {
        $base = $env:APPDATA
    } elseif ($env:XDG_CONFIG_HOME) {
        $base = $env:XDG_CONFIG_HOME
    } else {
        $base = Join-Path $HOME '.config'
    }
    $Destination = Join-Path $base 'yorumi'
}
if (-not $ProfilePath) { $ProfilePath = $PROFILE.CurrentUserAllHosts }

$flavours = 'ether', 'abyss', 'bifrost', 'kraken', 'kabocha', 'cosmic', 'ryujin'
if ($flavours -notcontains $Flavour) {
    throw "unknown flavour '$Flavour'. One of: $($flavours -join ', ')"
}

New-Item -ItemType Directory -Path $Destination -Force | Out-Null
$scriptPath = Join-Path $Destination 'yorumi.ps1'

$local = if ($PSScriptRoot) { Join-Path $PSScriptRoot 'yorumi.ps1' }
if ($local -and (Test-Path -LiteralPath $local)) {
    Copy-Item -LiteralPath $local -Destination $scriptPath -Force
} else {
    Invoke-WebRequest -UseBasicParsing -Uri "$rawBase/yorumi.ps1" -OutFile $scriptPath
}
Write-Host "installed $scriptPath"

if ($NoProfile) {
    Write-Host "profile untouched (-NoProfile); add this line yourself:"
    Write-Host "  . `"$scriptPath`" -Flavour $Flavour"
    return
}

$startMarker = '# >>> yorumi >>>'
$endMarker = '# <<< yorumi <<<'
$entry = ". `"$scriptPath`" -Flavour $Flavour"

$profileDir = Split-Path -Path $ProfilePath -Parent
if ($profileDir -and -not (Test-Path -LiteralPath $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

if (Test-Path -LiteralPath $ProfilePath) {
    $raw = Get-Content -LiteralPath $ProfilePath -Raw
    if ($null -eq $raw) { $raw = '' }
} else {
    $raw = ''
}

# keep whatever line ending the file already uses
$newline = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }
$lines = @()
if ($raw.Length -gt 0) { $lines = $raw -split "`r?`n" }
# a trailing newline shows up as an empty last element; drop it and re-add below
if ($lines.Count -gt 0 -and $lines[-1] -eq '') {
    if ($lines.Count -eq 1) { $lines = @() } else { $lines = $lines[0..($lines.Count - 2)] }
}

$block = @($startMarker, $entry, $endMarker)
$start = -1
$end = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i].Trim() -eq $startMarker) { $start = $i }
    elseif ($lines[$i].Trim() -eq $endMarker -and $start -ge 0) { $end = $i; break }
}

if ($start -ge 0 -and $end -ge 0) {
    $out = @()
    if ($start -gt 0) { $out += $lines[0..($start - 1)] }
    $out += $block
    if ($end + 1 -lt $lines.Count) { $out += $lines[($end + 1)..($lines.Count - 1)] }
} elseif ($lines -match [regex]::Escape($scriptPath)) {
    Write-Warning "yorumi is already dot-sourced in $ProfilePath outside the '$startMarker' block; leaving the profile alone."
    Write-Host "the script itself is updated, so nothing else is needed"
    return
} else {
    $out = @()
    if ($lines.Count -gt 0) { $out += $lines; $out += '' }
    $out += $block
}

if (Test-Path -LiteralPath $ProfilePath) {
    $backup = "$ProfilePath.yorumi-backup"
    if (-not (Test-Path -LiteralPath $backup)) {
        Copy-Item -LiteralPath $ProfilePath -Destination $backup
    }
}

Set-Content -LiteralPath $ProfilePath -Value ($out -join $newline) -Encoding UTF8
Write-Host "profile entry written to $ProfilePath"

Write-Host ''
Write-Host 'Next:'
Write-Host "  restart your shell, or:  . `"$ProfilePath`""
Write-Host "  switch flavour:          Set-YorumiTheme abyss"
