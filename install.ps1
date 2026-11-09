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
    [string] $Flavour = '',
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

# No default flavour. Ask, or fail where nobody can answer.
if (-not $Flavour) {
    if (-not [Environment]::UserInteractive -or [Console]::IsInputRedirected) {
        throw "no flavour given. pass -Flavour <name>: $($flavours -join ', ')"
    }
    for ($i = 0; $i -lt $flavours.Count; $i++) {
        Write-Host ("  {0}) {1}" -f ($i + 1), $flavours[$i])
    }
    while (-not $Flavour) {
        $answer = Read-Host "flavour (1-$($flavours.Count) or a name)"
        if (-not $answer) { continue }
        if ($answer -match '^\d+$' -and [int]$answer -ge 1 -and [int]$answer -le $flavours.Count) {
            $Flavour = $flavours[[int]$answer - 1]
        } elseif ($flavours -contains $answer) {
            $Flavour = $answer
        } else {
            Write-Warning "not a flavour: $answer"
        }
    }
}

if ($flavours -notcontains $Flavour) {
    throw "unknown flavour '$Flavour'. One of: $($flavours -join ', ')"
}
if ($Flavour) { $Flavour = $Flavour.ToLower() }

New-Item -ItemType Directory -Path $Destination -Force | Out-Null
$scriptPath = Join-Path $Destination 'yorumi.ps1'

$local = if ($PSScriptRoot) { Join-Path $PSScriptRoot 'yorumi.ps1' }
if ($local -and (Test-Path -LiteralPath $local)) {
    Copy-Item -LiteralPath $local -Destination $scriptPath -Force
} else {
    # download beside the target and move it in: a failed fetch leaves nothing
    $part = "$scriptPath.part.$PID"
    try {
        Invoke-WebRequest -UseBasicParsing -Uri "$rawBase/yorumi.ps1" -OutFile $part
    } catch {
        Remove-Item -LiteralPath $part -ErrorAction SilentlyContinue
        Write-Host "yorumi: could not download yorumi.ps1 from $rawBase" -ForegroundColor Red
        Write-Host "yorumi: if that repository is not public yet, clone it and run this script from the checkout." -ForegroundColor Red
        exit 3
    }
    Move-Item -LiteralPath $part -Destination $scriptPath -Force
}
# absolute, always: a relative path in the profile breaks the moment the shell
# starts somewhere else
$scriptPath = (Resolve-Path -LiteralPath $scriptPath).Path
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

# One block in, one block out. An existing block is replaced where it sits, a
# second copy of it is dropped, and a half-written block stops the write instead
# of eating everything after it.
$out = @()
$placed = $false
$inBlock = $false
$broken = $false
foreach ($line in $lines) {
    $trimmed = $line.Trim()
    if ($trimmed -eq $startMarker) {
        if ($inBlock) { $broken = $true }
        $inBlock = $true
        if (-not $placed) { $out += $block; $placed = $true }
        continue
    }
    if ($trimmed -eq $endMarker) {
        if (-not $inBlock) { $broken = $true }
        $inBlock = $false
        continue
    }
    if (-not $inBlock) { $out += $line }
}
if ($inBlock) { $broken = $true }

if ($broken) {
    throw "yorumi: $ProfilePath has an unpaired '$startMarker' or '$endMarker' marker. The profile was not touched; the theme itself is installed at $scriptPath. Fix or remove those lines, then run this again."
}

if (-not $placed -and ($lines -match [regex]::Escape($scriptPath))) {
    Write-Warning "yorumi is already dot-sourced in $ProfilePath outside the '$startMarker' block; leaving the profile alone."
    Write-Host "the script itself is updated, so nothing else is needed"
    return
}

if (-not $placed) {
    if ($out.Count -gt 0 -and $out[-1] -ne '') { $out += '' }
    $out += $block
}

$text = $out -join $newline
if ($raw.EndsWith("`n")) { $text += $newline }
$current = if (Test-Path -LiteralPath $ProfilePath) { [IO.File]::ReadAllText($ProfilePath) } else { $null }

if ($null -ne $current -and $current.TrimEnd() -eq $text.TrimEnd()) {
    Write-Host "profile entry already current in $ProfilePath"
} else {
    if ($null -ne $current) {
        $backup = "$ProfilePath.yorumi-backup"
        if (-not (Test-Path -LiteralPath $backup)) {
            Copy-Item -LiteralPath $ProfilePath -Destination $backup
        }
    }
    # no BOM: Windows PowerShell 5.1's -Encoding UTF8 writes one, PS 7's does not,
    # and a profile that differs per host is not worth owning
    # write beside the profile and move it in, so a crash cannot truncate it
    $tmp = "$ProfilePath.yorumi-tmp.$PID"
    [IO.File]::WriteAllText($tmp, $text, (New-Object System.Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $tmp -Destination $ProfilePath -Force
    Write-Host "profile entry written to $ProfilePath"
}

Write-Host ''
Write-Host 'Next:'
Write-Host "  restart your shell, or:  . `"$ProfilePath`""
Write-Host "  switch flavour:          Set-YorumiTheme <flavour>"
