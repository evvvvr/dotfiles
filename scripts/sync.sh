#!/usr/bin/env bash
# Sync this machine to the dotfiles: packages, links, Claude setup, macOS settings.
# Run via: mise run dotfiles:sync

set -e
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

header "📦 Syncing packages"
# --no-upgrade: sync only installs what is missing; upgrading is `mise run dotfiles:upgrade`
# (and the nightly launchd job).
brew bundle install --no-upgrade --file "$BREWFILE"
success "Packages synced (nothing upgraded, extras on machine kept)"

header "🔗 Linking config files (stow)"
bash "${DOTFILES}/scripts/link.sh"

header "🤖 Claude Code plugins"
bash "${DOTFILES}/scripts/claude-bootstrap.sh" || warning "Claude bootstrap reported failures"

header "🍎 Applying macOS settings"
bash "${DOTFILES}/macos.sh"

echo -e "\n${GREEN}${BOLD}✓ Sync complete!${RESET}\n"
