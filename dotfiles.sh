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
  header "🔗 Symlinking config files"
  BREW_PREFIX="$(brew --prefix)"

  ln -sf "${DOTFILES}/git/git-clean-stale-local-branches" "${BREW_PREFIX}/bin"
  info "git helpers"

  ln -sf "${DOTFILES}/git/.gitconfig" "${HOME}"
  info ".gitconfig"

  mkdir -p "${HOME}/Library/Application Support/com.mitchellh.ghostty"
  ln -sf "${DOTFILES}/ghostty/config" "${HOME}/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
  info "Ghostty config"

  ln -sf "${DOTFILES}/vscode/settings.json" "${HOME}/Library/Application Support/Code/User/settings.json"
  info "VS Code settings"

  ln -sf "${DOTFILES}/bash/.bash_profile" "${HOME}"
  info ".bash_profile"

  ln -sf "${DOTFILES}/zsh/.zshrc" "${HOME}"
  info ".zshrc"

  mkdir -p "${HOME}/.config"
  ln -sf "${DOTFILES}/starship/starship.toml" "${HOME}/.config/starship.toml"
  info "starship config"

  SUBL_DIR="${HOME}/Library/Application Support/Sublime Text/Packages/User"
  mkdir -p "${SUBL_DIR}"
  ln -sf "${DOTFILES}/sublime-text/Preferences.sublime-settings" "${SUBL_DIR}/"
  ln -sf "${DOTFILES}/sublime-text/Terminus.sublime-settings" "${SUBL_DIR}/"
  ln -sf "${DOTFILES}/sublime-text/Debugger.sublime-settings" "${SUBL_DIR}/"
  ln -sf "${DOTFILES}/sublime-text/Adaptive.sublime-theme" "${SUBL_DIR}/"
  rm -f "${SUBL_DIR}/Package Control.sublime-settings"
  cp "${DOTFILES}/sublime-text/Package Control.sublime-settings" "${SUBL_DIR}/"
  mkdir -p "${SUBL_DIR}/Terminus"
  ln -sf "${DOTFILES}/sublime-text/Terminus/Night Owl.json" "${SUBL_DIR}/Terminus/"
  info "Sublime Text config"

  success "Config files symlinked"
}

cmd_setup() {
  bash "${DOTFILES}/setup.sh" "$@"
}

cmd_sync() {
  header "📦 Syncing packages"
  brew bundle --file "$BREWFILE"
  success "Packages synced (extras on machine kept)"

  symlink_configs

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
    cp "$SUBL_PKG" "${DOTFILES}/sublime-text/Package Control.sublime-settings"
    success "Package Control.sublime-settings synced to dotfiles"
  else
    warning "Sublime Text package list not found or is a symlink — skipping"
  fi

  # macOS reminder
  header "  macOS settings"
  warning "Cannot be captured automatically — edit macos.sh manually if needed"

  echo -e "\n${GREEN}${BOLD}✓ Update complete!${RESET}\n"
}

usage() {
  echo -e "${BOLD}Usage:${RESET} dotfiles.sh <command> [options]"
  echo ""
  echo -e "${BOLD}Commands:${RESET}"
  echo -e "  ${GREEN}setup${RESET}    Fresh machine setup (installs everything, generates SSH key)"
  echo -e "           Options: --skip-ssh"
  echo -e "  ${GREEN}sync${RESET}     Sync machine to dotfiles (packages, symlinks, macOS settings)"
  echo -e "  ${GREEN}update${RESET}   Update dotfiles to match machine (VS Code extensions, brew diff)"
  echo ""
}

case "${1:-}" in
  setup)  shift; cmd_setup "$@" ;;
  sync)   cmd_sync ;;
  update) cmd_update ;;
  *)      usage ;;
esac
