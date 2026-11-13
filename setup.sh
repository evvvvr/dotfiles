#!/usr/bin/env bash

source "${HOME}/dotfiles/scripts/lib.sh"

# Parse flags
SKIP_SSH=false
for arg in "$@"; do
  case $arg in
    --skip-ssh) SKIP_SSH=true ;;
  esac
done

ui_banner "dotfiles · setup" "new machine bootstrap"

# Xcode CLI tools (must come before Homebrew)
if ! xcode-select -p &>/dev/null; then
  xcode-select --install
  warning "Follow the installer prompt, then re-run this script"
  exit 1
fi

# Bootstrap Homebrew onto PATH (Apple Silicon)
if [ -f /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -f /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

BREW_PREFIX="$(brew --prefix)"

install_rust() { command -v rustup &>/dev/null || rustup-init -y; }
make_ssh_key() {
  local key="${HOME}/.ssh/id_ed25519"
  [ -f "$key" ] && { echo "SSH key already exists at ${key}"; return 0; }
  ssh-keygen -t ed25519 -C "$(git config user.email)" -f "$key" -N "" || return 1
  eval "$(ssh-agent -s)" &>/dev/null
  ssh-add "$key" && pbcopy <"${key}.pub"
}

total=8
$SKIP_SSH || total=$((total + 1))
ui_total "$total"

# Streamed: casks may ask for sudo, and the 1Password pause waits for you.
ui_stream "Homebrew packages" brew bundle --file "${HOME}/dotfiles/Brewfile"
ui_stream "1Password (for private config)" bash "${HOME}/dotfiles/scripts/wait-for-1password.sh" || true
ui_run "Linking config files (stow)" bash "${HOME}/dotfiles/scripts/link.sh"
ui_run "Rust toolchain" install_rust
ui_run "Python (uv)" uv python install
ui_run "mise tools (Node.js etc.)" "${BREW_PREFIX}/bin/mise" install
ui_run "Claude Code (CLI, plugins, language servers)" bash "${HOME}/dotfiles/scripts/claude-bootstrap.sh"
ui_run "macOS settings" "${HOME}/dotfiles/macos.sh"
if ! $SKIP_SSH; then
  ui_run "SSH key" make_ssh_key
fi

ui_summary
rc=$?
if ! $SKIP_SSH && [ -f "${HOME}/.ssh/id_ed25519.pub" ]; then
  info "A newly created public key is on the clipboard. Add it to GitHub → https://github.com/settings/ssh/new"
fi
exit $rc
