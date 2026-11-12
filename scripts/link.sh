#!/usr/bin/env bash
# Link configs into $HOME with GNU Stow. Idempotent; safe to re-run.
#
# Each package directory mirrors $HOME (e.g. zsh/.zshrc -> ~/.zshrc).
# --no-folding makes stow link individual files, never whole directories,
# so ~/.claude and ~/Library/... keep their machine-generated contents.

set -euo pipefail

DOTFILES="${DOTFILES:-${HOME}/dotfiles}"
PACKAGES=(bash zsh git starship ghostty vscode sublime-text claude launchd mise btop television)

BLUE="\033[0;34m"; GREEN="\033[0;32m"; YELLOW="\033[0;33m"; RESET="\033[0m"
info()    { echo -e "${BLUE}  →${RESET} $1"; }
success() { echo -e "${GREEN}  ✓${RESET} $1"; }
warning() { echo -e "${YELLOW}  !${RESET} $1"; }

if ! command -v stow &>/dev/null; then
  warning "stow not found (brew install stow)"; exit 1
fi

# One-time migration: remove the absolute symlinks the old ln -sf scripts
# created. Stow's own links are relative, so -lname "${DOTFILES}/*" only
# matches the old ones.
SUBL_USER="${HOME}/Library/Application Support/Sublime Text/Packages/User"
for entry in \
  "${HOME}|1" \
  "${HOME}/.config|1" \
  "${HOME}/.claude|1" \
  "${HOME}/Library/Application Support/com.mitchellh.ghostty|1" \
  "${HOME}/Library/Application Support/Code/User|1" \
  "${SUBL_USER}|2"; do
  dir="${entry%|*}"; depth="${entry#*|}"
  [ -d "$dir" ] && find "$dir" -maxdepth "$depth" -type l -lname "${DOTFILES}/*" -delete
done

stow --no-folding --restow --dir "$DOTFILES" --target "$HOME" "${PACKAGES[@]}"
success "Stowed: ${PACKAGES[*]}"

# Not expressible as stow links:
if [ -d "${HOME}/projects/RustTestExplorer" ]; then
  ln -sfn "${HOME}/projects/RustTestExplorer" "${HOME}/Library/Application Support/Sublime Text/Packages/RustTestExplorer"
  info "Sublime Text RustTestExplorer plugin"
fi

# Package Control rewrites its settings file, so it is copied, not linked.
rm -f "${SUBL_USER}/Package Control.sublime-settings"
cp "${DOTFILES}/sublime-text/Library/Application Support/Sublime Text/Packages/User/Package Control.sublime-settings" "${SUBL_USER}/"
info "Sublime Text Package Control settings (copied)"

# Daily background upgrade job (see scripts/auto-upgrade.sh). Reload so edits apply.
AGENT="dev.dotfiles.auto-upgrade"
PLIST="${HOME}/Library/LaunchAgents/${AGENT}.plist"
if [ -e "$PLIST" ] && command -v launchctl &>/dev/null; then
  launchctl bootout "gui/$(id -u)/${AGENT}" 2>/dev/null || true
  if launchctl bootstrap "gui/$(id -u)" "$PLIST"; then
    info "launchd agent ${AGENT} loaded (daily 03:30)"
  else
    warning "could not load launchd agent ${AGENT}"
  fi
fi

# Private config kept in 1Password (skips quietly if op is unavailable).
bash "${DOTFILES}/scripts/restore-aws-config.sh" || true
