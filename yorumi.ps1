# yorumi for PowerShell — seven flavours of the palette, one script.
# Generated from primitives.json + ansi-themes.json; edit dev/generators/build-terminals.mjs.
#
# One entry in your profile is enough, and install.ps1 / install.sh write it:
#   Windows      . "$env:APPDATA\yorumi\yorumi.ps1" -Flavour abyss
#   macOS, Linux . "$HOME/.config/yorumi/yorumi.ps1" -Flavour abyss
# and `Set-YorumiTheme bifrost` switches flavour for the session.
# $PSStyle needs PowerShell 7.2+ on every platform; older hosts — Windows
# PowerShell 5.1, PowerShell 6.x — get the PSReadLine colours only.

[CmdletBinding()]
param(
    [string] $Flavour = $env:YORUMI_FLAVOUR
)

$Yorumi = @{
    ether = @{
        mode      = 'dark'
        bg        = '#02040e'
        fg        = '#ebedf1'
        selection = @{ bg = '#bdbfcb'; ink = '#02040e' }
        syn       = @{
            comment     = '#bdbfcb'
            string      = '#a1b38c'
            number      = '#de8280'
            constant    = '#f0a989'
            identifier  = '#cdb68c'
            operator    = '#cdb68c'
            parameter   = '#c9809f'
            fun         = '#7f8cbf'
            keyword     = '#9d8bb9'
            type        = '#96c3b8'
            error       = '#de8280'
            warning     = '#cdb68c'
            success     = '#a1b38c'
            accent      = '#7f8cbf'
        }
    }
    abyss = @{
        mode      = 'dark'
        bg        = '#060914'
        fg        = '#bdbfcb'
        selection = @{ bg = '#6ddbdd'; ink = '#060914' }
        syn       = @{
            comment     = '#9496a0'
            string      = '#80aa6e'
            number      = '#c65e53'
            constant    = '#de875f'
            identifier  = '#ba9a5e'
            operator    = '#ba9a5e'
            parameter   = '#b4647f'
            fun         = '#597bc0'
            keyword     = '#9e77d5'
            type        = '#5caeac'
            error       = '#c65e53'
            warning     = '#ba9a5e'
            success     = '#80aa6e'
            accent      = '#597bc0'
        }
    }
    bifrost = @{
        mode      = 'light'
        bg        = '#ebedf1'
        fg        = '#191b25'
        selection = @{ bg = '#afb9df'; ink = '#191b25' }
        syn       = @{
            comment     = '#4d4f58'
            string      = '#213828'
            number      = '#4e0e0e'
            constant    = '#5d3718'
            identifier  = '#4e3e0a'
            operator    = '#4e3e0a'
            parameter   = '#4c1036'
            fun         = '#0d2c4e'
            keyword     = '#2a1844'
            type        = '#054951'
            error       = '#4e0e0e'
            warning     = '#4e3e0a'
            success     = '#213828'
            accent      = '#0d2c4e'
        }
    }
    kraken = @{
        mode      = 'dark'
        bg        = '#0e0d17'
        fg        = '#bfafdf'
        selection = @{ bg = '#df8eff'; ink = '#0e0d17' }
        syn       = @{
            comment     = '#bdbfcb'
            string      = '#80aa6e'
            number      = '#c65e53'
            constant    = '#de875f'
            identifier  = '#ba9a5e'
            operator    = '#ba9a5e'
            parameter   = '#b4647f'
            fun         = '#597bc0'
            keyword     = '#9e77d5'
            type        = '#5caeac'
            error       = '#c65e53'
            warning     = '#ba9a5e'
            success     = '#80aa6e'
            accent      = '#597bc0'
        }
    }
    kabocha = @{
        mode      = 'dark'
        bg        = '#150b03'
        fg        = '#f5c5b0'
        selection = @{ bg = '#ffb86b'; ink = '#150b03' }
        syn       = @{
            comment     = '#bdbfcb'
            string      = '#80aa6e'
            number      = '#c65e53'
            constant    = '#de875f'
            identifier  = '#ba9a5e'
            operator    = '#ba9a5e'
            parameter   = '#b4647f'
            fun         = '#597bc0'
            keyword     = '#9e77d5'
            type        = '#5caeac'
            error       = '#c65e53'
            warning     = '#ba9a5e'
            success     = '#80aa6e'
            accent      = '#597bc0'
        }
    }
    cosmic = @{
        mode      = 'dark'
        bg        = '#150718'
        fg        = '#ffffff'
        selection = @{ bg = '#df7caa'; ink = '#150718' }
        syn       = @{
            comment     = '#bdbfcb'
            string      = '#a9d07c'
            number      = '#ea7262'
            constant    = '#f9ad6f'
            identifier  = '#e4d278'
            operator    = '#e4d278'
            parameter   = '#db8bae'
            fun         = '#798ddc'
            keyword     = '#a183ce'
            type        = '#85e0cb'
            error       = '#ea7262'
            warning     = '#e4d278'
            success     = '#a9d07c'
            accent      = '#798ddc'
        }
    }
    ryujin = @{
        mode      = 'dark'
        bg        = '#0b0b19'
        fg        = '#afb9df'
        selection = @{ bg = '#76b0ff'; ink = '#0b0b19' }
        syn       = @{
            comment     = '#bdbfcb'
            string      = '#a1b38c'
            number      = '#de8280'
            constant    = '#f0a989'
            identifier  = '#cdb68c'
            operator    = '#cdb68c'
            parameter   = '#c9809f'
            fun         = '#7f8cbf'
            keyword     = '#9d8bb9'
            type        = '#96c3b8'
            error       = '#de8280'
            warning     = '#cdb68c'
            success     = '#a1b38c'
            accent      = '#7f8cbf'
        }
    }
}

function Get-YorumiTheme {
    <#
    .SYNOPSIS
        All yorumi flavours, or one of them by name.
    .EXAMPLE
        (Get-YorumiTheme abyss).syn.keyword
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string] $Flavour
    )
    if (-not $Flavour) { return $Yorumi }
    if (-not $Yorumi.ContainsKey($Flavour)) {
        throw "yorumi: unknown flavour '$Flavour'. One of: $($Yorumi.Keys -join ', ')"
    }
    return $Yorumi[$Flavour]
}

function Set-YorumiTheme {
    <#
    .SYNOPSIS
        Paint $PSStyle and PSReadLine with a yorumi flavour.
    .DESCRIPTION
        Colours are the flavour's own syntax roles, so PowerShell highlights the
        way the yorumi editor ports do. Directories get a foreground colour, not
        PowerShell's default blue background fill.
    .EXAMPLE
        Set-YorumiTheme kraken
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $Flavour
    )

    $theme = Get-YorumiTheme -Flavour $Flavour

    if (-not (Get-Variable PSStyle -ErrorAction SilentlyContinue) -and -not $Host.UI.SupportsVirtualTerminal) {
        Write-Warning 'yorumi: this host cannot render ANSI colours; nothing was changed.'
        return
    }

    $e = [char]27
    $paint = {
        param([string] $Hex, [string] $Layer)
        $r = [Convert]::ToInt32($Hex.Substring(1, 2), 16)
        $g = [Convert]::ToInt32($Hex.Substring(3, 2), 16)
        $b = [Convert]::ToInt32($Hex.Substring(5, 2), 16)
        $code = 38
        if ($Layer -eq 'bg') { $code = 48 }
        '{0}[{1};2;{2};{3};{4}m' -f $e, $code, $r, $g, $b
    }
    $fg = { param([string] $Hex) & $paint $Hex 'fg' }
    $bg = { param([string] $Hex) & $paint $Hex 'bg' }

    if (Get-Variable PSStyle -ErrorAction SilentlyContinue) {
        $PSStyle.Formatting.Error        = & $fg $theme.syn.error
        $PSStyle.Formatting.ErrorAccent  = & $fg $theme.syn.type
        $PSStyle.Formatting.Warning      = & $fg $theme.syn.warning
        $PSStyle.Formatting.Verbose      = & $fg $theme.syn.type
        $PSStyle.Formatting.Debug        = & $fg $theme.syn.comment
        $PSStyle.Formatting.FormatAccent = & $fg $theme.syn.accent
        $PSStyle.Formatting.TableHeader  = & $fg $theme.syn.keyword
        $PSStyle.Progress.Style          = & $fg $theme.syn.accent

        # PowerShell's default wraps directory names in a blue *background*
        # (`e[44;1m): ordinary text on the palette's blue, which measures
        # 1.2-3.2:1 in these flavours. Keep the hue, drop the fill.
        $PSStyle.FileInfo.Directory    = '{0}[1m{1}' -f $e, (& $fg $theme.syn.fun)
        $PSStyle.FileInfo.SymbolicLink = & $fg $theme.syn.type
        $PSStyle.FileInfo.Executable   = & $fg $theme.syn.success
        foreach ($ext in '.zip', '.tgz', '.gz', '.tar', '.nupkg', '.cab', '.7z') {
            $PSStyle.FileInfo.Extension[$ext] = & $fg $theme.syn.error
        }
        foreach ($ext in '.ps1', '.psd1', '.psm1', '.ps1xml') {
            $PSStyle.FileInfo.Extension[$ext] = & $fg $theme.syn.fun
        }
    }

    if (Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue) {
        $ink = (& $bg $theme.selection.bg) + (& $fg $theme.selection.ink)
        Set-PSReadLineOption -Colors @{
            Command                = & $fg $theme.syn.fun
            Comment                = & $fg $theme.syn.comment
            ContinuationPrompt     = & $fg $theme.syn.comment
            Default                = & $fg $theme.fg
            Emphasis               = & $fg $theme.syn.type
            Error                  = & $fg $theme.syn.error
            InlinePrediction       = & $fg $theme.syn.comment
            Keyword                = & $fg $theme.syn.keyword
            ListPrediction         = & $fg $theme.syn.comment
            ListPredictionSelected = $ink
            Member                 = & $fg $theme.syn.identifier
            Number                 = & $fg $theme.syn.number
            Operator               = & $fg $theme.syn.operator
            Parameter              = & $fg $theme.syn.parameter
            Selection              = $ink
            String                 = & $fg $theme.syn.string
            Type                   = & $fg $theme.syn.type
            Variable               = & $fg $theme.fg
        }
    }
}

if (-not $Flavour) { $Flavour = 'ether' }
Set-YorumiTheme -Flavour $Flavour
