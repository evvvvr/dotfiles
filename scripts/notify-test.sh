#!/usr/bin/env bash
# Send a test macOS notification, the same way auto-upgrade.sh does, to check that
# notifications from osascript are allowed. Run via: mise run dotfiles:notify-test
osascript -e 'display notification "test: fake-app, other-app" with title "App updates available" subtitle "Update them in the apps, or: brew upgrade --cask --greedy"' \
  && echo "Sent. Did a banner appear (top right) or show in Notification Centre?"
