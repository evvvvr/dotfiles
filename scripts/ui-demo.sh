#!/usr/bin/env bash
# Preview of the proposed terminal effects (scripts/ui.sh). Installs and changes
# nothing; every "step" is a short sleep, and one step fails on purpose.
#
#   bash ~/dotfiles/scripts/ui-demo.sh            # fancy (needs a real terminal)
#   bash ~/dotfiles/scripts/ui-demo.sh | cat      # see the plain fallback used for logs
#   NO_COLOR=1 bash ~/dotfiles/scripts/ui-demo.sh # colourless

source "$(dirname "${BASH_SOURCE[0]}")/ui.sh"

ui_banner "dotfiles · setup" "demo - nothing is installed"
ui_total 7

ui_run "Homebrew packages"    sleep 2
ui_run "Linking config files" sleep 1
ui_skip "1Password CLI" "not signed in yet"
ui_run "Claude plugins"       sleep 1.5

# a "download" with a progress bar
echo "Fetching language servers"
for i in $(seq 1 20); do ui_bar "$i" 20 "typescript-language-server"; sleep 0.06; done

ui_run "Language servers"     bash -c 'echo "npm ERR! simulated failure" >&2; echo "see the log for details" >&2; exit 1'
ui_run "macOS settings"       sleep 1
ui_run "Upgrading everything" sleep 2

ui_summary
