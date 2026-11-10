#Requires -Version 5.1
<#
.SYNOPSIS
    Install the yorumi theme for PowerShell.
.DESCRIPTION
    Copies yorumi.ps1 next to your PowerShell config and puts ONE entry in your
    profile that dot-sources it:

        . (Join-Path $env:APPDATA 'yorumi\yorumi.ps1') -Flavour <flavour>

    With -Destination the entry holds that absolute path as a single-quoted
    literal; with the default location it looks the path up at startup, so the
    entry does not name this account's home. The flavour is $env:YORUMI_FLAVOUR
    when the shell starts with it set, and the flavour chosen here otherwise.
    Nothing else is written to the profile: re-running strips every managed
    block and appends one at the end, and `Set-YorumiTheme <flavour>` in a
    session always wins until you restart.
.PARAMETER Flavour
    The flavour the profile entry falls back to. $env:YORUMI_FLAVOUR overrides
    it when the shell starts with it set. Asked for when it is not given.
.PARAMETER Destination
    Where yorumi.ps1 goes. Default: %APPDATA%\yorumi on Windows,
    $XDG_CONFIG_HOME/yorumi (or ~/.config/yorumi) elsewhere. Naming it writes
    that absolute path into the profile entry.
.PARAMETER ProfilePath
    Profile file to add the entry to. Default: $PROFILE (CurrentUserCurrentHost).
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

# a base to install under must be absolute; Windows PowerShell's IsPathRooted
# also says yes to C:foo and \foo, which resolve against the current directory,
# so the shape is tested instead
function Test-AbsolutePath([string] $path) {
    if ([string]::IsNullOrWhiteSpace($path)) { return $false }
    if ([IO.Path]::DirectorySeparatorChar -eq '\') {
        return ($path -match '^[A-Za-z]:[\\/]' -or $path -match '^[\\/]{2}[^\\/]')
    }
    return $path.StartsWith('/')
}

# --- a file that may be a link -----------------------------------------------
#
# The chain is followed to the file it names and only that file is rewritten, so
# a link survives. Resolution happens before anything is created or backed up,
# so a dangling or cyclic link stops the run with the filesystem untouched.
# 5.1 has no ResolveLinkTarget, so the provider's target property is walked.

function Test-PathEntry([string] $path) {
    # true for a dangling link too: the entry exists, its target does not
    try {
        [void][IO.File]::GetAttributes($path)
        return $true
    } catch [System.IO.IOException] {
        return $false
    } catch [System.UnauthorizedAccessException] {
        throw "'$path' cannot be read: access denied."
    }
}

function Get-LinkTarget([string] $path) {
    $item = Get-Item -LiteralPath $path -Force -ErrorAction Stop
    $target = $null
    # LinkTarget is the raw target on PowerShell 7; Target is what 5.1 has (and
    # what 7 exposes next to it), so both are asked for in that order
    if ($item.PSObject.Properties['LinkTarget']) { $target = $item.LinkTarget }
    if (-not $target -and $item.PSObject.Properties['Target']) { $target = $item.Target }
    if ($target -is [array]) {
        # 5.1 hands a symbolic link's target back as a one-element string[]
        if ($target.Count -ne 1) {
            throw "'$path' is a link with $($target.Count) targets; refusing to follow it."
        }
        $target = $target[0]
    }
    if ([string]::IsNullOrWhiteSpace([string] $target)) {
        throw "'$path' is a reparse point this PowerShell cannot follow; it was left alone."
    }
    return [string] $target
}

function Resolve-TargetPath([string] $path) {
    # ~ and PSDrives are the caller's business; links are not
    $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($path)
    for ($hops = 0; $hops -lt 40; $hops++) {
        if (-not (Test-PathEntry $full)) {
            # File.Exists is true for a dangling link on some hosts, so a hop
            # that ends at a missing entry is the evidence of a broken chain
            if ($hops -gt 0) {
                throw "'$path' is a symbolic link whose target does not exist. The link was left alone; repair or remove it and run this again."
            }
            return @{ Path = $full; Exists = $false; IsDirectory = $false }
        }
        $attrs = [IO.File]::GetAttributes($full)
        if ((([int] $attrs) -band [int] ([IO.FileAttributes]::ReparsePoint)) -eq 0) {
            return @{ Path = $full; Exists = $true; IsDirectory = [IO.Directory]::Exists($full) }
        }
        $target = Get-LinkTarget $full
        $next = if ([IO.Path]::IsPathRooted($target)) { $target } else { Join-Path (Split-Path -Path $full -Parent) $target }
        $full = [IO.Path]::GetFullPath($next)
    }
    throw "'$path' has more than 40 symbolic links in its chain; refusing to follow it."
}

# Swap $temp (already holding the new bytes) in for $path: one File.Replace for
# an existing file, which renames and hands the replacement the destination's
# ACLs and creation time without the ignore-metadata option, or one File.Move
# for a new one. A failure propagates - the original is left as it was and there
# is no second, non-atomic mutation route.
function Move-FileIntoPlace([string] $temp, [string] $path, [string] $backup) {
    if (-not [IO.File]::Exists($path)) {
        [IO.File]::Move($temp, $path)
        return
    }
    # the first backup is the pristine file; later runs must not overwrite it.
    # $backup is typed [string], so "no backup" arrives as '', and even a literal
    # $null would bind as '' too - NullString::Value is what hands .NET a real null
    if ([string]::IsNullOrEmpty($backup) -or (Test-PathEntry $backup)) {
        [IO.File]::Replace($temp, $path, [System.Management.Automation.Language.NullString]::Value)
    } else {
        [IO.File]::Replace($temp, $path, $backup)
    }
}

function Write-FileAtomic([string] $path, [byte[]] $bytes, [string] $backup) {
    # fail closed before a temp exists: a protected target (macOS uchg, read-only
    # attribute, ACL deny) cannot be replaced either, and copying its flags onto a
    # temp would leave a file that cannot even be removed
    if ([IO.File]::Exists($path)) {
        $probe = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite)
        $probe.Dispose()
    }
    $temp = "$path.yorumi-tmp.$([IO.Path]::GetRandomFileName())"
    try {
        if ([IO.File]::Exists($path)) {
            # overwrite=false makes Copy the exclusive create, and it carries the
            # original's owner, mode and attributes onto the temp first
            [IO.File]::Copy($path, $temp, $false)
            $mode = [IO.FileMode]::Truncate
        } else {
            $mode = [IO.FileMode]::CreateNew
        }
        $stream = [IO.File]::Open($temp, $mode, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try {
            $stream.Write($bytes, 0, $bytes.Length)
        } finally {
            $stream.Dispose()
        }
        Move-FileIntoPlace $temp $path $backup
        $temp = $null
    } finally {
        if ($temp -and (Test-PathEntry $temp)) {
            Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
        }
    }
}

# --- the profile's own encoding ----------------------------------------------
#
# The profile is read as bytes and written back with the same BOM and encoding,
# so an existing 5.1 ANSI or UTF-16 profile is not re-encoded. A BOM-less file is
# decoded exactly as the running host decodes it: Windows PowerShell 5.1 uses
# Encoding.Default (the ANSI code page), PowerShell 7 uses UTF-8. Text that
# encoding cannot hold is refused, never converted.

function Test-BytesEqual([byte[]] $left, [byte[]] $right) {
    if ($null -eq $left -or $null -eq $right) { return $false }
    return ([Convert]::ToBase64String($left) -ceq [Convert]::ToBase64String($right))
}

function Read-ProfileBody([byte[]] $bytes, [int] $bom, [Text.Encoding] $encoding, [string] $path) {
    $bomBytes = [byte[]] ($bytes[0..($bom - 1)])
    $body = if ($bytes.Length -gt $bom) { [byte[]] ($bytes[$bom..($bytes.Length - 1)]) } else { [byte[]] @() }
    $invalid = "'$path' is not valid $($encoding.WebName) text. It was not touched; save it again as UTF-8 and run this."
    try {
        $text = $encoding.GetString($body)
    } catch {
        throw $invalid
    }
    if (-not (Test-BytesEqual ($bomBytes + $encoding.GetBytes($text)) $bytes)) { throw $invalid }
    return @{ Text = $text; Encoding = $encoding; Bom = $bomBytes }
}

function Read-ProfileText([byte[]] $bytes, [string] $path) {
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        return (Read-ProfileBody $bytes 3 (New-Object System.Text.UTF8Encoding($false, $true)) $path)
    }
    if ($bytes.Length -ge 4 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE -and $bytes[2] -eq 0x00 -and $bytes[3] -eq 0x00) {
        return (Read-ProfileBody $bytes 4 (New-Object System.Text.UTF32Encoding($false, $false, $true)) $path)
    }
    if ($bytes.Length -ge 4 -and $bytes[0] -eq 0x00 -and $bytes[1] -eq 0x00 -and $bytes[2] -eq 0xFE -and $bytes[3] -eq 0xFF) {
        return (Read-ProfileBody $bytes 4 (New-Object System.Text.UTF32Encoding($true, $false, $true)) $path)
    }
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        return (Read-ProfileBody $bytes 2 (New-Object System.Text.UnicodeEncoding($false, $false, $true)) $path)
    }
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        return (Read-ProfileBody $bytes 2 (New-Object System.Text.UnicodeEncoding($true, $false, $true)) $path)
    }
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        $ansi = [Text.Encoding]::Default
        $text = $ansi.GetString($bytes)
        if (-not (Test-BytesEqual ($ansi.GetBytes($text)) $bytes)) {
            throw "'$path' is not text Windows PowerShell 5.1 can read without losing characters (ANSI code page $($ansi.CodePage)). It was not touched; save it as UTF-8 and run this again."
        }
        return @{ Text = $text; Encoding = $ansi; Bom = [byte[]] @() }
    }
    try {
        $text = (New-Object System.Text.UTF8Encoding($false, $true)).GetString($bytes)
    } catch {
        throw "'$path' is not valid UTF-8. It was not touched; save it as UTF-8 and run this again."
    }
    return @{ Text = $text; Encoding = (New-Object System.Text.UTF8Encoding($false)); Bom = [byte[]] @() }
}

function New-ProfileText {
    # a new profile is UTF-8; 5.1 gets a BOM so a non-ASCII path is not misread
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        return @{ Text = ''; Encoding = (New-Object System.Text.UTF8Encoding($true)); Bom = [byte[]] (0xEF, 0xBB, 0xBF) }
    }
    return @{ Text = ''; Encoding = (New-Object System.Text.UTF8Encoding($false)); Bom = [byte[]] @() }
}

function Get-ProfileBytes([hashtable] $decoded, [string] $text, [string] $path) {
    $lossy = "'$path' cannot hold the new lines in its current encoding ($($decoded.Encoding.WebName)); it was not touched. Save it as UTF-8 and run this again."
    try {
        $encoded = [byte[]] $decoded.Encoding.GetBytes($text)
    } catch {
        throw $lossy
    }
    if ($decoded.Encoding.GetString($encoded) -cne $text) { throw $lossy }
    return [byte[]] ($decoded.Bom + $encoded)
}

# did the caller pick the location? It uses the same truthiness as the default
# selection below - a nonempty string, whitespace included - so the entry and the
# install can never disagree about what was chosen
$destinationGiven = [bool] $Destination

if (-not $Destination) {
    if ($isWindowsHost) {
        $base = $env:APPDATA
    } elseif (Test-AbsolutePath $env:XDG_CONFIG_HOME) {
        $base = $env:XDG_CONFIG_HOME
    } else {
        $base = Join-Path $HOME '.config'
    }
    $Destination = Join-Path $base 'yorumi'
}
if (-not $ProfilePath) { $ProfilePath = $PROFILE }

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

# resolved against the PowerShell location, then created by .NET: New-Item -Path
# expands wildcards ([) and silently creates nothing for a whitespace-only name
$Destination = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Destination)
[void][IO.Directory]::CreateDirectory($Destination)
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
        # a terminating error, not exit: an Invoke-Expression caller keeps its
        # session and sees the failure, and the message names the file and source
        throw "yorumi: could not download $rawBase/yorumi.ps1 to '$scriptPath': $($_.Exception.Message). If that repository is not public yet, clone it and run this script from the checkout. Nothing was installed."
    }
    Move-Item -LiteralPath $part -Destination $scriptPath -Force
}
Write-Host "installed $scriptPath"

# --- the profile entry -------------------------------------------------------
#
# One line, generated once and used both in the profile and in the -NoProfile
# advice. A -Destination path becomes a single-quoted literal with apostrophes
# doubled, so $, backticks and spaces are never interpolated; the default
# location is a small startup lookup instead, so the entry does not bake this
# account's home into a profile someone else may use. The flavour is
# $env:YORUMI_FLAVOUR when the shell starts with it set, else the one chosen here.

function ConvertTo-SingleQuoted([string] $value) { return "'" + $value.Replace("'", "''") + "'" }

function Test-SameScript([string] $literal, [string] $scriptPath) {
    # a relative or ~-rooted literal is resolved against the PowerShell location,
    # never the process directory
    try { $candidate = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($literal) } catch { return $false }
    $comparison = if ([IO.Path]::DirectorySeparatorChar -eq '\') { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    try { return [string]::Equals([IO.Path]::GetFullPath($candidate), [IO.Path]::GetFullPath($scriptPath), $comparison) } catch { return $false }
}

if ($destinationGiven) {
    $scriptRef = ConvertTo-SingleQuoted $scriptPath
} elseif ($isWindowsHost) {
    $scriptRef = '(Join-Path $env:APPDATA ''yorumi\yorumi.ps1'')'
} else {
    $scriptRef = '(Join-Path $(if ($env:XDG_CONFIG_HOME -and [IO.Path]::IsPathRooted($env:XDG_CONFIG_HOME)) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME ''.config'' }) ''yorumi/yorumi.ps1'')'
}
$flavourRef = '$(if ($env:YORUMI_FLAVOUR) { $env:YORUMI_FLAVOUR } else { ' + (ConvertTo-SingleQuoted $Flavour) + ' })'
$entry = ". $scriptRef -Flavour $flavourRef"

$startMarker = '# >>> yorumi >>>'
$endMarker = '# <<< yorumi <<<'

if ($NoProfile) {
    Write-Host "profile untouched (-NoProfile); add this line yourself:"
    Write-Host "  $entry"
    return
}

# a linked profile is rewritten through the link, never over it, and a dangling
# or cyclic one is refused before its directory or a backup is touched
try { $profileTarget = Resolve-TargetPath $ProfilePath } catch {
    throw "yorumi: $($_.Exception.Message) The theme itself is installed at $scriptPath; the profile was not touched."
}
if ($profileTarget.IsDirectory) {
    throw "yorumi: '$ProfilePath' is a directory, not a profile file. The theme itself is installed at $scriptPath."
}
$profileReal = $profileTarget.Path

$profileDir = Split-Path -Path $profileReal -Parent
if ($profileDir -and -not (Test-Path -LiteralPath $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

$original = if ($profileTarget.Exists) { [IO.File]::ReadAllBytes($profileReal) } else { $null }
$decoded = if ($null -ne $original) { Read-ProfileText $original $ProfilePath } else { New-ProfileText }
$raw = $decoded.Text

# keep whatever line ending the file already uses
$newline = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }
$lines = @()
if ($raw.Length -gt 0) { $lines = $raw -split "`r?`n" }
# a trailing newline shows up as an empty last element; drop it and re-add below
if ($lines.Count -gt 0 -and $lines[-1] -eq '') {
    if ($lines.Count -eq 1) { $lines = @() } else { $lines = $lines[0..($lines.Count - 2)] }
}

$block = @($startMarker, $entry, $endMarker)

# The lexer decides what a marker line is: a comment token alone on its line, so
# a line that merely looks like one inside a string, here-string or block comment
# is user content and is kept byte for byte. Marker lines are collected by number.
$tokens = $null
$parseErrors = $null
$parsed = [System.Management.Automation.Language.Parser]::ParseInput($raw, [ref] $tokens, [ref] $parseErrors)
$markerStarts = @{}
$markerEnds = @{}
foreach ($token in $tokens) {
    if ($token.Kind -ne [System.Management.Automation.Language.TokenKind]::Comment) { continue }
    $text = $token.Text.Trim()
    if (($text -cne $startMarker) -and ($text -cne $endMarker)) { continue }
    $lineNumber = $token.Extent.StartLineNumber
    if ($lineNumber -lt 1 -or $lineNumber -gt $lines.Count) { continue }
    if ($token.Extent.StartColumnNumber -gt 1) {
        $line = $lines[$lineNumber - 1]
        $cut = [Math]::Min($token.Extent.StartColumnNumber - 1, $line.Length)
        if (-not [string]::IsNullOrWhiteSpace($line.Substring(0, $cut))) { continue }
    }
    if ($text -ceq $startMarker) { $markerStarts[$lineNumber] = $true } else { $markerEnds[$lineNumber] = $true }
}

# Every correctly paired block is removed - wherever it sits and however many
# there are - and exactly one is appended at the end. A nested, reversed or
# unclosed marker stops the write before the profile is touched instead of
# guessing what was meant.
$kept = @()
$blockLines = @{}
$inBlock = $false
$broken = $false
for ($i = 0; $i -lt $lines.Count; $i++) {
    $lineNumber = $i + 1
    if ($markerStarts.ContainsKey($lineNumber)) {
        if ($inBlock) { $broken = $true }
        $inBlock = $true
        $blockLines[$lineNumber] = $true
        continue
    }
    if ($markerEnds.ContainsKey($lineNumber)) {
        if (-not $inBlock) { $broken = $true }
        $inBlock = $false
        $blockLines[$lineNumber] = $true
        continue
    }
    if ($inBlock) {
        $blockLines[$lineNumber] = $true
    } else {
        $kept += $lines[$i]
    }
}
if ($inBlock) { $broken = $true }

if ($broken) {
    throw "yorumi: $ProfilePath has an unpaired '$startMarker' or '$endMarker' marker (nested, reversed or never closed). The profile was not touched; the theme itself is installed at $scriptPath. Fix or remove those lines, then run this again."
}

# A literal dot-source of this script outside a managed block would be a second
# load. The profile is parsed, never evaluated, and only string-literal targets
# are compared. Lines that belong to a block are ours, so an old block does not
# hide a stray call elsewhere; the reported line is the one in the file.
$dots = @($parsed.FindAll({
    param($node)
    ($node -is [System.Management.Automation.Language.CommandAst]) -and
    ($node.InvocationOperator -eq [System.Management.Automation.Language.TokenKind]::Dot)
}, $true))
foreach ($dot in $dots) {
    if ($dot.CommandElements.Count -lt 1) { continue }
    if ($blockLines.ContainsKey($dot.Extent.StartLineNumber)) { continue }
    $target = $dot.CommandElements[0]
    if (($target -is [System.Management.Automation.Language.StringConstantExpressionAst]) -and (Test-SameScript $target.Value $scriptPath)) {
        throw "yorumi: $ProfilePath line $($target.Extent.StartLineNumber) already dot-sources $($target.Value) outside the '$startMarker' block. The profile was not touched; the theme itself is installed at $scriptPath. Remove that line (or let this installer own it) and run this again."
    }
}

# one block, at the end: a separating blank line is added only when one is needed,
# so a user's own trailing blank lines are left alone and a rerun is identical
$out = @($kept)
if ($out.Count -gt 0 -and $out[-1].Trim() -ne '') { $out += '' }
$out += $block

$text = $out -join $newline
if ($raw.EndsWith("`n")) { $text += $newline }

# encoded with the profile's own BOM and encoding, or refused above before
# anything is written; the encoding is never changed to fit the new lines
$bytes = Get-ProfileBytes $decoded $text $ProfilePath

if (($null -ne $original) -and (Test-BytesEqual $original $bytes)) {
    Write-Host "profile entry already current in $ProfilePath"
} else {
    Write-FileAtomic $profileReal $bytes "$profileReal.yorumi-backup"
    Write-Host "profile entry written to $ProfilePath"
}

Write-Host ''
Write-Host 'Next:'
Write-Host "  restart your shell, or:  . $(ConvertTo-SingleQuoted $profileReal)"
Write-Host "  switch flavour:          Set-YorumiTheme <flavour>"
