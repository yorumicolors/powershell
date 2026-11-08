#!/usr/bin/env bash
# Yorumi theme installer for PowerShell on macOS and Linux
#   ./install.sh [--flavour <name>] [--profile <path>] [--destination <dir>] [--no-profile]
#
# PowerShell 7.2+ is the real requirement; older hosts get PSReadLine colours
# only, because $PSStyle does not exist there.
set -euo pipefail

RAW_BASE="https://raw.githubusercontent.com/yorumicolors/powershell/main"
FLAVOURS="ether abyss bifrost kraken kabocha cosmic ryujin"
FLAVOUR=""
PROFILE=""
DESTINATION=""
NO_PROFILE=0

# No default flavour. Ask, or fail where nobody can answer.
ask_flavour() {
  # a real open, not a -r test: /dev/tty exists even when nothing is attached
  if ! { exec 3<>/dev/tty; } 2>/dev/null; then
    echo "no flavour given. pass --flavour <name>: $FLAVOURS" >&2
    exit 2
  fi
  i=0
  {
    echo "Yorumi flavours:"
    for f in $FLAVOURS; do i=$((i + 1)); echo "  $i) $f"; done
  } >&3
  while :; do
    printf 'flavour (1-%s or a name): ' "$i" >&3
    answer=""
    IFS= read -r answer <&3 || {
      exec 3>&-
      echo "no flavour given. pass --flavour <name>: $FLAVOURS" >&2
      exit 2
    }
    [ -z "$answer" ] && continue
    case "$answer" in
      *[!0-9]*) candidate="$answer" ;;
      *) candidate=""
         n=0
         for f in $FLAVOURS; do n=$((n + 1)); [ "$n" -eq "$answer" ] && candidate="$f"; done ;;
    esac
    case " $FLAVOURS " in
      *" $candidate "*) FLAVOUR="$candidate"; exec 3>&-; return 0 ;;
    esac
    printf 'not a flavour: %s\n' "$answer" >&3
  done
}

usage() {
  echo "usage: ./install.sh [--flavour <name>] [--profile <path>] [--destination <dir>] [--no-profile]"
  echo "flavours: $FLAVOURS"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --flavour|-f)  FLAVOUR="${2:-}"; shift 2 ;;
    --profile|-p)  PROFILE="${2:-}"; shift 2 ;;
    --destination|-d) DESTINATION="${2:-}"; shift 2 ;;
    --no-profile)  NO_PROFILE=1; shift ;;
    -h|--help)     usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -n "$FLAVOUR" ]; then
  case " $FLAVOURS " in
    *" $FLAVOUR "*) ;;
    *) echo "unknown flavour '$FLAVOUR'. One of: $FLAVOURS" >&2; exit 2 ;;
  esac
fi

[ -z "$FLAVOUR" ] && ask_flavour

PWSH="$(command -v pwsh || command -v powershellcli || true)"
if [ -z "$PWSH" ]; then
  cat >&2 <<'INFO'
PowerShell is not on PATH. Install PowerShell 7.2+ first:
  macOS   brew install --cask powershell
  Debian  https://learn.microsoft.com/powershell/scripting/install/install-debian
  Fedora  sudo dnf install powershell
INFO
  exit 1
fi

SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/install.ps1" ]; then
  INSTALLER="$SCRIPT_DIR/install.ps1"
else
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  curl -fsSL "$RAW_BASE/install.ps1" -o "$work/install.ps1" || {
    echo "could not download $RAW_BASE/install.ps1 — offline, or the repository is private and needs a token" >&2
    exit 1
  }
  INSTALLER="$work/install.ps1"
fi

version="$("$PWSH" -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>/dev/null || echo unknown)"
case "$version" in
  7.2*|7.[3-9]*|[89].*) ;;
  *) echo "note: PowerShell $version has no \$PSStyle — only the PSReadLine colours will apply." >&2 ;;
esac

args=(-NoLogo -NoProfile -File "$INSTALLER" -Flavour "$FLAVOUR")
[ -n "$PROFILE" ] && args+=(-ProfilePath "$PROFILE")
[ -n "$DESTINATION" ] && args+=(-Destination "$DESTINATION")
[ "$NO_PROFILE" -eq 1 ] && args+=(-NoProfile)

exec "$PWSH" "${args[@]}"
