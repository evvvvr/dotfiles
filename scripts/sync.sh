#!/usr/bin/env bash
# Sync this machine to the dotfiles: packages, links, Claude setup, macOS settings.
# Run via: mise run dotfiles:sync

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ui_banner "dotfiles · sync" "packages, links, Claude, macOS settings"
ui_total 4

# --no-upgrade: sync only installs what is missing; upgrading is `mise run dotfiles:upgrade`
# (and the nightly launchd job). Streamed because casks can ask for sudo.
ui_stream "Homebrew packages (nothing upgraded)" brew bundle install --no-upgrade --file "$BREWFILE"
ui_run "Linking config files (stow)" bash "${DOTFILES}/scripts/link.sh"
ui_run "Claude Code plugins" bash "${DOTFILES}/scripts/claude-bootstrap.sh"
ui_run "macOS settings" bash "${DOTFILES}/macos.sh"

ui_summary
