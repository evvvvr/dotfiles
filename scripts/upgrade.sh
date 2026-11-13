#!/usr/bin/env bash
# Upgrade everything now: the daily auto-upgrade job in the foreground, plus VS Code
# extensions and the Command Line Tools update (sudo, confirmed).
# Run via: mise run dotfiles:upgrade

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CLT_LABEL="$(softwareupdate -l 2>&1 | sed -n 's/^\* Label: \(Command Line Tools.*\)$/\1/p' | tail -1)"

total=2
command -v code &>/dev/null && total=$((total + 1))
ui_banner "dotfiles · upgrade" "brew, mise, rustup, uv, npm, Claude plugins, VS Code"
ui_total "$total"

ui_stream "Auto-upgrade (brew, mise, rustup, uv, npm, Claude plugins)" bash "${DOTFILES}/scripts/auto-upgrade.sh" --foreground

if command -v code &>/dev/null; then
  ui_run "VS Code extensions" bash -c 'code --list-extensions | while read -r ext; do [ -n "$ext" ] && code --install-extension "$ext" --force </dev/null; done'
fi

if [ -z "$CLT_LABEL" ]; then
  ui_skip "Command Line Tools" "up to date"
elif [ -t 0 ]; then
  warning "Update available: ${CLT_LABEL}"
  read -r -p "  Install it now (needs sudo)? [y/N] " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    ui_stream "Command Line Tools" sudo softwareupdate -i "$CLT_LABEL"
  else
    ui_skip "Command Line Tools" "update declined"
  fi
else
  ui_skip "Command Line Tools" "update available, run: sudo softwareupdate -i \"${CLT_LABEL}\""
fi

dim "Other macOS updates: softwareupdate -l (install with sudo softwareupdate -ia)"
dim "Sublime Text packages: update via Package Control inside Sublime"

ui_summary
