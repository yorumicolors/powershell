<h1 align="center" valign="middle">
  <img height="40px" src="https://github.com/yorumicolors/.github/blob/main/res/seal_sots.gif?raw=true">
  <sup>yorumi for PowerShell - deep code, quiet sea</sup>
</h1>

<p align="center">
  A calming deep sea colorscheme for the <strong>PowerShell</strong> prompt, in seven flavours.
</p>

---

Yorumi keeps visual noise low with mellow, low-contrast chrome while text and syntax stay
sharp: body text measures 9.6-19.5:1 against its background, and the lowest-contrast syntax
role is 4.6:1 — every role in this port clears WCAG AA on the ground it is drawn on.

## What it sets

`$PSStyle` and PSReadLine, from the flavour's own syntax roles, so PowerShell highlights the
way the yorumi editor ports do.

| role | hue | where it lands |
|---|---|---|
| functions | blue | `$PSStyle.FileInfo.Directory`, PSReadLine `Command` |
| keywords | purple | PSReadLine `Keyword`, `$PSStyle.Formatting.TableHeader` |
| strings | green | PSReadLine `String` |
| numbers | red | PSReadLine `Number`, `.zip/.tgz/.gz/.tar/.nupkg/.cab/.7z` |
| constants | orange | `$Yorumi.<flavour>.syn.constant` (yours to use) |
| types | cyan | PSReadLine `Type`, `Emphasis`, `$PSStyle.Formatting.Verbose` |
| parameters | magenta | PSReadLine `Parameter` |
| members, operators | yellow | PSReadLine `Member`, `Operator` |
| comments | dim neutral | PSReadLine `Comment`, `ContinuationPrompt`, `InlinePrediction` |
| errors, warnings | red, yellow | `$PSStyle.Formatting.Error/Warning`, PSReadLine `Error` |
| selection | flavour's selection pair | PSReadLine `Selection`, `ListPredictionSelected` |

### The directory fix

PowerShell colours directory names with a **background** fill — `$PSStyle.FileInfo.Directory`
defaults to `` "`e[44;1m" ``, ANSI blue *behind* the text. In yorumi that measures 1.2-3.2:1
(near-black text on the flavour's blue in `bifrost`), and no colour scheme can repair it: a
scheme's `blue` has to be legible *as text* on the background as well, and the two demands
have no common value. This port keeps the hue and drops the fill — bold blue foreground,
4.6-12.1:1 — the way `ls`, `eza` and Terminal-Icons colour directories.

## Available Flavours

| flavour | mode | background | text |
|---|---|---|---|
| `ether` | dark | `#02040e` | `#ebedf1` |
| `abyss` | dark | `#060914` | `#bdbfcb` |
| `bifrost` | light | `#ebedf1` | `#191b25` |
| `kraken` | dark | `#0e0d17` | `#bfafdf` |
| `kabocha` | dark | `#150b03` | `#f5c5b0` |
| `cosmic` | dark | `#150718` | `#ffffff` |
| `ryujin` | dark | `#0b0b19` | `#afb9df` |

## Quick Installation

```powershell
irm https://raw.githubusercontent.com/yorumicolors/powershell/main/install.ps1 | iex
```

Windows PowerShell 5.1 needs TLS 1.2 first:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
irm https://raw.githubusercontent.com/yorumicolors/powershell/main/install.ps1 | iex
```

On macOS and Linux, `install.sh` finds `pwsh`, prompts for a flavour when none is given, and warns
below 7.2:

```sh
curl -fsSL https://raw.githubusercontent.com/yorumicolors/powershell/main/install.sh | bash
```

Flags travel as `-s --`:

```sh
curl -fsSL https://raw.githubusercontent.com/yorumicolors/powershell/main/install.sh | bash -s -- --flavour bifrost
curl -fsSL https://raw.githubusercontent.com/yorumicolors/powershell/main/install.sh | bash -s -- --no-profile --destination ~/.local/share/yorumi
```

## What the installer writes

Two things, and the theme itself is never written into your profile:

1. `yorumi.ps1` — the whole port, all seven flavours, one file.
   Windows: `%APPDATA%\yorumi\yorumi.ps1`; elsewhere `${XDG_CONFIG_HOME:-$HOME/.config}/yorumi/yorumi.ps1`
   (`XDG_CONFIG_HOME` counts only when absolute). `-Destination` moves it.
2. **one entry** in whatever `$PROFILE` resolves to in the PowerShell process that runs the
   installer — the current user's profile for the current host:

   ```powershell
   # >>> yorumi >>>
   . (Join-Path $env:APPDATA 'yorumi\yorumi.ps1') -Flavour $(if ($env:YORUMI_FLAVOUR) { $env:YORUMI_FLAVOUR } else { 'abyss' })
   # <<< yorumi <<<
   ```

   On macOS and Linux the first argument looks up `${XDG_CONFIG_HOME:-$HOME/.config}` at startup
   the same way — a relative `XDG_CONFIG_HOME` is ignored there too, exactly as in the install — and
   `-Destination` writes the absolute path you chose as a single-quoted literal instead. Nothing is
   expanded when the entry is written: a path containing `$`, backticks or spaces is just a string to
   the profile. A line that merely looks like a marker inside a string or here-string is left alone;
   only a real standalone comment counts.

`$PROFILE` is not one fixed path: the edition picks the directory (Windows PowerShell 5.1
`Documents\WindowsPowerShell`, PowerShell 7 `Documents\PowerShell`), the host picks the file name
(console `Microsoft.PowerShell_profile.ps1`, VS Code `Microsoft.VSCode_profile.ps1`), a redirected or
OneDrive `Documents` moves it, and on macOS and Linux it sits under `~/.config/powershell`.
`-ProfilePath <path>` writes the entry to a file you name instead — another host, another edition, or
a dotfiles repo; `install.sh --profile <path>` passes it through.

Re-running the installer removes every managed block and appends one at the end, keeps a single
`<profile>.yorumi-backup`, and never touches the rest of the file. A nested, reversed or unclosed
marker stops it before the profile is written; so does a literal dot-source of `yorumi.ps1` outside
the block, which would load the theme twice — the installer names that line and leaves the file
alone. `-Flavour`, `-Destination`, `-ProfilePath` and `-NoProfile` are there if you want a different
arrangement.

## Usage

```powershell
Set-YorumiTheme kraken          # switch flavour for this session
Get-YorumiTheme                 # all seven, as data
(Get-YorumiTheme abyss).syn     # the role table
```

Set `YORUMI_FLAVOUR` in the environment to override the entry's flavour at startup; `-Flavour`
chooses the fallback the entry uses when it is unset.

## Notes

- `$PSStyle` needs PowerShell 7.2+ — on every platform. Windows PowerShell 5.1 and PowerShell
  6.x get the PSReadLine colours only; nothing errors.
- Linux and macOS are first-class here: the same script, the same seven flavours, at
  `${XDG_CONFIG_HOME:-$HOME/.config}/yorumi/yorumi.ps1`, with the profile entry going into
  `$PROFILE` (`~/.config/powershell/Microsoft.PowerShell_profile.ps1` in a plain `pwsh` 7 session).
  `install.sh` is only a wrapper that locates `pwsh`.
- Colours are 24-bit escapes, so they look the same in Windows Terminal, VS Code, WezTerm and
  Terminal.app — pair the shell with the terminal scheme of the same flavour so the background
  matches.
- Hosts without ANSI support get a warning and no changes.
- The values are the flavour's syntax roles, not the 16 ANSI slots: a scheme swap will not
  move them, and `Set-YorumiTheme` re-applies them on demand.

## For AI Agents

1. **Install**: `irm https://raw.githubusercontent.com/yorumicolors/powershell/main/install.ps1 | iex`
   (add the TLS 1.2 line first on Windows PowerShell 5.1).
2. **Never paste theme code into a profile.** The port is one dot-sourced entry between
   `# >>> yorumi >>>` and `# <<< yorumi <<<`; re-running the installer keeps exactly one, at the end.
3. **Verify**: `$PSStyle.FileInfo.Directory` must be a foreground escape
   (`ESC[1m ESC[38;2;...m`) with no `44`/`48` background, and `$PSStyle.Formatting.Error`
   must be `ESC[38;2;...m`. `Get-YorumiTheme` lists the seven flavours.

---

## Accessibility

| layer | measured |
|---|---|
| body text on background | 9.57 – 19.53:1 |
| lowest syntax role | 4.61:1 (`sango-blue` on `kraken`) |
| selection ink on selection fill | 7.07 – 12.14:1 |

No blanket AAA claim is made for syntax colours — sRGB runs out before the saturated hues get
lighter. Roles come from the palette's own tier per mode (`kairo`/`sango`/`sumi`/`raito`), and
the generator refuses to write a flavour whose role falls under 4.5:1.

## License

MIT © [Yorumi Colors](https://github.com/yorumicolors)
