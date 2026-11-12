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

header "📦 CLI tools"
brew bundle --file "${HOME}/dotfiles/Brewfile"
success "Homebrew packages installed"

header "⚙️ Languages & runtimes"
if command -v rustup &>/dev/null; then
  success "Rust already installed"
else
  rustup-init -y
  success "Rust toolchain installed"
fi
uv python install
success "Python installed"
"${BREW_PREFIX}/bin/mise" use --global node@lts
success "Node.js LTS installed"

header "🤖 Claude Code (CLI, plugins, language servers)"
bash "${HOME}/dotfiles/scripts/claude-bootstrap.sh" || warning "Claude bootstrap reported failures (re-run scripts/claude-bootstrap.sh)"

header "🗄️ Database tools"
uv tool install harlequin
success "harlequin installed"

header "🔗 Linking config files (stow)"
bash "${HOME}/dotfiles/scripts/link.sh"

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
