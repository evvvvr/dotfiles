#!/usr/bin/env bash

set -e

DOTFILES="${HOME}/dotfiles"
BREWFILE="${DOTFILES}/Brewfile"

BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[0;33m"
DIM="\033[2m"
RESET="\033[0m"

info()    { echo -e "${BLUE}  →${RESET} $1"; }
success() { echo -e "${GREEN}  ✓${RESET} $1"; }
warning() { echo -e "${YELLOW}  !${RESET} $1"; }
header()  { echo -e "\n${BOLD}$1${RESET}"; }
dim()     { echo -e "${DIM}  $1${RESET}"; }

symlink_configs() {
  header "🔗 Linking config files (stow)"
  bash "${DOTFILES}/scripts/link.sh"
}

cmd_setup() {
  bash "${DOTFILES}/setup.sh" "$@"
}

cmd_sync() {
  header "📦 Syncing packages"
  brew bundle --file "$BREWFILE"
  success "Packages synced (extras on machine kept)"

  symlink_configs

  header "🤖 Claude Code plugins"
  bash "${DOTFILES}/scripts/claude-bootstrap.sh" || warning "Claude bootstrap reported failures"

  header "🍎 Applying macOS settings"
  bash "${DOTFILES}/macos.sh"

  echo -e "\n${GREEN}${BOLD}✓ Sync complete!${RESET}\n"
}

cmd_update() {
  header "🔄 Updating dotfiles to match this machine"

  # VS Code extensions
  header "  VS Code extensions"
  if ! command -v code &>/dev/null; then
    warning "code CLI not found, skipping"
  else
    CURRENT_EXTS=$(code --list-extensions | sort)
    TRACKED_EXTS=$(grep '^vscode ' "$BREWFILE" | sed 's/vscode "//;s/"//' | sort)

    NEW_EXTS=$(comm -23 <(echo "$CURRENT_EXTS") <(echo "$TRACKED_EXTS"))
    REMOVED_EXTS=$(comm -13 <(echo "$CURRENT_EXTS") <(echo "$TRACKED_EXTS"))

    if [ -z "$NEW_EXTS" ] && [ -z "$REMOVED_EXTS" ]; then
      success "Extensions already up to date"
    else
      # Rebuild vscode section in Brewfile
      NON_VSCODE=$(grep -v '^vscode ' "$BREWFILE")
      NEW_VSCODE_LINES=$(echo "$CURRENT_EXTS" | sed 's/.*/vscode "&"/')
      printf '%s\n%s\n' "$NON_VSCODE" "$NEW_VSCODE_LINES" > "$BREWFILE"

      [ -n "$NEW_EXTS" ]     && echo "$NEW_EXTS"     | while read -r e; do info "added:   $e"; done
      [ -n "$REMOVED_EXTS" ] && echo "$REMOVED_EXTS" | while read -r e; do info "removed: $e"; done
      success "Brewfile updated"
    fi
  fi

  # Brew packages not tracked
  header "  Untracked brew packages"
  TRACKED_FORMULAE=$(grep '^brew ' "$BREWFILE" | sed 's/brew "//;s/"//' | sort)
  INSTALLED_FORMULAE=$(brew list --formula | sort)
  UNTRACKED=$(comm -13 <(echo "$TRACKED_FORMULAE") <(echo "$INSTALLED_FORMULAE"))

  if [ -z "$UNTRACKED" ]; then
    success "Nothing untracked"
  else
    warning "Installed but not in Brewfile (add manually if needed):"
    echo "$UNTRACKED" | while read -r pkg; do dim "$pkg"; done
  fi

  # Sublime Text packages
  header "  Sublime Text packages"
  SUBL_PKG="${HOME}/Library/Application Support/Sublime Text/Packages/User/Package Control.sublime-settings"
  if [ -f "$SUBL_PKG" ] && [ ! -L "$SUBL_PKG" ]; then
    cp "$SUBL_PKG" "${DOTFILES}/sublime-text/Library/Application Support/Sublime Text/Packages/User/Package Control.sublime-settings"
    success "Package Control.sublime-settings synced to dotfiles"
  else
    warning "Sublime Text package list not found or is a symlink — skipping"
  fi

  # macOS reminder
  header "  macOS settings"
  warning "Cannot be captured automatically — edit macos.sh manually if needed"

  echo -e "\n${GREEN}${BOLD}✓ Update complete!${RESET}\n"
}

cmd_upgrade() {
  header "⬆️  Upgrading all software"
  FAILED_STEPS=()
  step() {  # step "<label>" <command...>
    local label="$1"; shift
    header "  ${label}"
    if "$@"; then success "${label} done"; else warning "${label} failed"; FAILED_STEPS+=("$label"); fi
  }

  if command -v brew &>/dev/null; then
    step "Homebrew formulae" bash -c 'brew update && brew upgrade'
    step "Homebrew casks"    brew upgrade --cask --greedy
    step "Homebrew cleanup"  brew cleanup
  fi
  command -v mise   &>/dev/null && step "mise runtimes"   mise upgrade
  command -v rustup &>/dev/null && step "Rust toolchain"  rustup update
  command -v uv     &>/dev/null && step "uv tools"        uv tool upgrade --all
  command -v npm    &>/dev/null && step "npm globals"     npm update -g
  if command -v claude &>/dev/null; then
    step "Claude Code CLI" claude update
    if command -v jq &>/dev/null; then
      step "Claude Code plugins" bash -c 'for p in $(claude plugin list --json | jq -r ".[].id"); do claude plugin update "$p" || exit 1; done'
    fi
  fi
  if command -v code &>/dev/null; then
    step "VS Code extensions" bash -c 'code --list-extensions | xargs -n1 code --install-extension --force'
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
    return 1
  fi
  echo -e "\n${GREEN}${BOLD}✓ Upgrade complete!${RESET}\n"
}

usage() {
  echo -e "${BOLD}Usage:${RESET} dotfiles.sh <command> [options]"
  echo ""
  echo -e "${BOLD}Commands:${RESET}"
  echo -e "  ${GREEN}setup${RESET}    Fresh machine setup (installs everything, generates SSH key)"
  echo -e "           Options: --skip-ssh"
  echo -e "  ${GREEN}sync${RESET}     Sync machine to dotfiles (packages, symlinks, macOS settings)"
  echo -e "  ${GREEN}update${RESET}   Update dotfiles to match machine (VS Code extensions, brew diff)"
  echo -e "  ${GREEN}upgrade${RESET}  Upgrade installed software (brew, mise, rustup, uv, npm, Claude, VS Code, CLT)"
  echo ""
}

case "${1:-}" in
  setup)  shift; cmd_setup "$@" ;;
  sync)   cmd_sync ;;
  update) cmd_update ;;
  upgrade) cmd_upgrade ;;
  *)      usage ;;
esac
