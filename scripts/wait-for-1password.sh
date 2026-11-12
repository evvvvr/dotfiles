#!/usr/bin/env bash
# Pause setup until the 1Password CLI can talk to the desktop app, so private
# config (AWS config, Sublime license) is restored on the first run instead of
# being skipped. Only prompts in an interactive terminal and only when `op` is
# installed but not yet usable. Never fails: typing "s" (or no terminal) skips.
#
# The CLI integration needs the 1Password app installed, signed in and unlocked,
# with Settings > Developer > "Integrate with 1Password CLI" turned on.

set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

command -v op &>/dev/null || { warning "1Password CLI (op) not installed; skipping"; exit 0; }

# On a fresh Mac with no 1Password account yet, `op` asks "add an account
# manually?" by reading the terminal device directly (not stdin). Run the probe
# in a new session with no controlling terminal so it can only succeed or fail.
usable() {
  perl -MPOSIX -e 'POSIX::setsid(); exec @ARGV' op vault list --format json </dev/null &>/dev/null
}

if usable; then
  success "1Password CLI is ready"
  exit 0
fi

if [ ! -t 0 ]; then
  warning "1Password CLI not ready and no terminal to prompt; sign in later and run: mise run dotfiles:private"
  exit 0
fi

pgrep -x 1Password &>/dev/null || open -a 1Password 2>/dev/null || true

echo
echo -e "${BOLD}  1Password needs a one-time setup so private config can be restored:${RESET}"
echo "    1. In the 1Password app, sign in to your account and unlock it"
echo "    2. Settings > Developer > turn on \"Integrate with 1Password CLI\""
echo

while true; do
  read -r -p "  Press Enter when done (or type s to skip for now): " ans
  case "$ans" in
    s|S) warning "Skipped; later run: mise run dotfiles:private"; exit 0 ;;
  esac
  if usable; then
    success "1Password CLI is ready"
    exit 0
  fi
  warning "Still can't reach 1Password; check steps 1 and 2"
done
