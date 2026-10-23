#!/usr/bin/env bash

set -e

BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[0;33m"
RESET="\033[0m"

info()    { echo -e "${BLUE}  →${RESET} $1"; }
success() { echo -e "${GREEN}  ✓${RESET} $1"; }
warning() { echo -e "${YELLOW}  !${RESET} $1"; }
header()  { echo -e "\n${BOLD}$1${RESET}"; }

# Parse flags
SKIP_SSH=false
for arg in "$@"; do
  case $arg in
    --skip-ssh) SKIP_SSH=true ;;
  esac
done

# Xcode CLI tools (must come before Homebrew)
header "🔧 Xcode Command Line Tools"
if xcode-select -p &>/dev/null; then
  success "Already installed"
else
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

header "📦 Installing packages"
brew bundle --file "${HOME}/dotfiles/Brewfile"
success "Homebrew packages installed"

header "🦀 Rust"
if command -v rustup &>/dev/null; then
  success "Rust already installed"
else
  rustup-init -y
  success "Rust toolchain installed"
fi

header "🐍 Python"
uv python install
success "Python installed"

header "🟢 Node.js"
"${BREW_PREFIX}/bin/mise" use --global node@lts
success "Node.js LTS installed"

header "🔗 Symlinking config files"

ln -sf "${HOME}/dotfiles/git/git-clean-stale-local-branches" "${BREW_PREFIX}/bin"
info "git helpers"

ln -sf "${HOME}/dotfiles/git/.gitconfig" "${HOME}"
info ".gitconfig"

mkdir -p "${HOME}/Library/Application Support/com.mitchellh.ghostty"
ln -sf "${HOME}/dotfiles/ghostty/config" "${HOME}/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
info "Ghostty config"

ln -sf "${HOME}/dotfiles/vscode/settings.json" "${HOME}/Library/Application Support/Code/User/settings.json"
info "VS Code settings"

ln -sf "${HOME}/dotfiles/bash/.bash_profile" "${HOME}"
info ".bash_profile"

ln -sf "${HOME}/dotfiles/zsh/.zshrc" "${HOME}"
info ".zshrc"

mkdir -p "${HOME}/.config"
ln -sf "${HOME}/dotfiles/starship/starship.toml" "${HOME}/.config/starship.toml"
info "starship config"

SUBL_DIR="${HOME}/Library/Application Support/Sublime Text/Packages/User"
mkdir -p "${SUBL_DIR}"
ln -sf "${HOME}/dotfiles/sublime-text/Preferences.sublime-settings" "${SUBL_DIR}/"
ln -sf "${HOME}/dotfiles/sublime-text/Terminus.sublime-settings" "${SUBL_DIR}/"
ln -sf "${HOME}/dotfiles/sublime-text/Debugger.sublime-settings" "${SUBL_DIR}/"
ln -sf "${HOME}/dotfiles/sublime-text/Adaptive.sublime-theme" "${SUBL_DIR}/"
ln -sf "${HOME}/dotfiles/sublime-text/Side Bar.sublime-menu" "${SUBL_DIR}/"
rm -f "${SUBL_DIR}/Package Control.sublime-settings"
cp "${HOME}/dotfiles/sublime-text/Package Control.sublime-settings" "${SUBL_DIR}/"
mkdir -p "${SUBL_DIR}/Terminus"
ln -sf "${HOME}/dotfiles/sublime-text/Terminus/Night Owl.json" "${SUBL_DIR}/Terminus/"
info "Sublime Text config"

header "🍎 macOS settings"
"${HOME}/dotfiles/macos.sh"

# SSH key
if [ "$SKIP_SSH" = false ]; then
  header "🔑 SSH key"
  SSH_KEY="${HOME}/.ssh/id_ed25519"
  if [ -f "$SSH_KEY" ]; then
    warning "SSH key already exists at ${SSH_KEY}, skipping"
  else
    ssh-keygen -t ed25519 -C "$(git config user.email)" -f "$SSH_KEY" -N ""
    eval "$(ssh-agent -s)" &>/dev/null
    ssh-add "$SSH_KEY"
    pbcopy < "${SSH_KEY}.pub"
    success "SSH key generated and public key copied to clipboard"
    info "Add it to GitHub → https://github.com/settings/ssh/new"
  fi
else
  warning "Skipping SSH key generation (--skip-ssh)"
fi

echo -e "\n${GREEN}${BOLD}✓ Setup complete!${RESET}\n"
