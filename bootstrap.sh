#!/usr/bin/env bash
# One-command fresh-machine bootstrap: installs Homebrew, downloads this repo
# (no git needed), and runs `dotfiles.sh setup`.
#
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/evvvvr/dotfiles/main/bootstrap.sh)" bootstrap [--skip-ssh]
#
# Use the `bash -c "$(curl ...)"` form, not `curl | bash`: the Homebrew installer
# is interactive and needs the terminal on stdin. Arguments are passed on to
# `dotfiles.sh setup`. Safe to re-run.
#
# Test hooks: DOTFILES_DIR overrides the download location (setup.sh itself
# always uses ~/dotfiles, so only combine it with DOTFILES_SKIP_SETUP=1).

set -euo pipefail

REPO="evvvvr/dotfiles"
BRANCH="main"
DEST="${DOTFILES_DIR:-${HOME}/dotfiles}"
TARBALL="https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz"
REMOTE="https://github.com/${REPO}.git"

BOLD="\033[1m"; GREEN="\033[0;32m"; BLUE="\033[0;34m"; YELLOW="\033[0;33m"; RED="\033[0;31m"; RESET="\033[0m"
info()    { echo -e "${BLUE}  →${RESET} $1"; }
success() { echo -e "${GREEN}  ✓${RESET} $1"; }
warning() { echo -e "${YELLOW}  !${RESET} $1"; }
error()   { echo -e "${RED}  ✗${RESET} $1" >&2; }
header()  { echo -e "\n${BOLD}$1${RESET}"; }

# 1. Homebrew (its installer also installs the Xcode Command Line Tools)
header "🍺 Homebrew"
if command -v brew &>/dev/null || [ -x /opt/homebrew/bin/brew ] || [ -x /usr/local/bin/brew ]; then
  success "Already installed"
else
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# 2. Download the repo
header "📥 Dotfiles"
if [ -f "${DEST}/dotfiles.sh" ]; then
  success "Already present at ${DEST}"
elif [ -d "${DEST}" ] && [ -n "$(ls -A "${DEST}")" ]; then
  error "${DEST} exists and is not a dotfiles checkout; move it away and re-run"
  exit 1
else
  mkdir -p "${DEST}"
  info "Downloading ${TARBALL}"
  curl -fsSL "${TARBALL}" | tar -xz --strip-components=1 -C "${DEST}"
  success "Downloaded to ${DEST}"
fi

# 3. Make it a normal git checkout so later edits can be committed and pushed.
if [ ! -d "${DEST}/.git" ] && command -v git &>/dev/null; then
  if git -C "${DEST}" init -q -b "${BRANCH}" \
     && git -C "${DEST}" remote add origin "${REMOTE}" \
     && git -C "${DEST}" fetch -q origin "${BRANCH}" \
     && git -C "${DEST}" reset -q "origin/${BRANCH}" \
     && git -C "${DEST}" branch -q --set-upstream-to="origin/${BRANCH}" "${BRANCH}"; then
    success "Initialised git repo tracking origin/${BRANCH}"
  else
    warning "Could not turn ${DEST} into a git repo (the files are still usable)"
  fi
fi

[ "${DOTFILES_SKIP_SETUP:-}" = "1" ] && { info "DOTFILES_SKIP_SETUP=1, stopping before setup"; exit 0; }

# 4. Run the main setup
header "🚀 Running dotfiles setup"
exec bash "${DEST}/dotfiles.sh" setup "$@"
