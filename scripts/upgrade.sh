#!/usr/bin/env bash
# Upgrade everything now: the daily auto-upgrade job in the foreground, plus VS Code
# extensions and the Command Line Tools update (sudo, confirmed).
# Run via: mise run dotfiles:upgrade

set -e
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

header "⬆️  Upgrading all software"
FAILED_STEPS=()
step() {  # step "<label>" <command...>
  local label="$1"; shift
  header "  ${label}"
  if "$@"; then success "${label} done"; else warning "${label} failed"; FAILED_STEPS+=("$label"); fi
}

step "Auto-upgrade (brew, mise, rustup, uv, npm, Claude plugins)" bash "${DOTFILES}/scripts/auto-upgrade.sh" --foreground

if command -v code &>/dev/null; then
  step "VS Code extensions" bash -c 'code --list-extensions | while read -r ext; do [ -n "$ext" ] && code --install-extension "$ext" --force </dev/null; done'
fi

header "  Xcode Command Line Tools / macOS"
CLT_LABEL="$(softwareupdate -l 2>&1 | sed -n 's/^\* Label: \(Command Line Tools.*\)$/\1/p' | tail -1)"
if [ -n "$CLT_LABEL" ]; then
  warning "Update available: ${CLT_LABEL}"
  if [ -t 0 ]; then
    read -r -p "  Install it now (needs sudo)? [y/N] " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      step "Command Line Tools" sudo softwareupdate -i "$CLT_LABEL"
    fi
  else
    dim "Run: sudo softwareupdate -i \"${CLT_LABEL}\""
  fi
else
  success "Command Line Tools up to date"
fi
dim "Other macOS updates: softwareupdate -l (install with sudo softwareupdate -ia)"
dim "Sublime Text packages: update via Package Control inside Sublime"

if [ "${#FAILED_STEPS[@]}" -gt 0 ]; then
  echo -e "\n${YELLOW}${BOLD}Finished with failures:${RESET} ${FAILED_STEPS[*]}\n"
  exit 1
fi
echo -e "\n${GREEN}${BOLD}✓ Upgrade complete!${RESET}\n"
