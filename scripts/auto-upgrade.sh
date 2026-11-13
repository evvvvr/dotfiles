#!/usr/bin/env bash
# Unattended upgrade of everything that can be upgraded without sudo or prompts.
# Run daily by launchd (launchd/Library/LaunchAgents/dev.dotfiles.auto-upgrade.plist);
# `mise run dotfiles:upgrade` (scripts/upgrade.sh) runs it in the foreground with --foreground.
#
# Output: ~/.cache/dotfiles/upgrade.log, status: ~/.cache/dotfiles/upgrade-status
# Never run from shell startup. Casks that update themselves (VS Code, Warp, ...)
# are left to their own updaters (no --greedy).

set -uo pipefail

FOREGROUND=false
[ "${1:-}" = "--foreground" ] && FOREGROUND=true

CACHE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/dotfiles"
LOG="${CACHE_DIR}/upgrade.log"
STATUS="${CACHE_DIR}/upgrade-status"
mkdir -p "$CACHE_DIR"

# launchd starts with a minimal PATH
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:${HOME}/.local/share/mise/shims:${HOME}/.cargo/bin:${HOME}/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export HOMEBREW_NO_ENV_HINTS=1

if ! $FOREGROUND; then
  [ -f "$LOG" ] && [ "$(stat -f%z "$LOG")" -gt 1000000 ] && mv "$LOG" "${LOG}.1"
  exec >>"$LOG" 2>&1
fi

echo "=== $(date '+%Y-%m-%d %H:%M:%S') auto-upgrade start"
FAILED=()
run() {  # run "<label>" <command...>
  local label="$1"; shift
  echo "--- ${label}"
  "$@" || { echo "!!! ${label} failed"; FAILED+=("${label// /_}"); }
}

if command -v brew &>/dev/null; then
  run "brew update"   brew update
  run "brew upgrade"  brew upgrade
  run "brew casks"    brew upgrade --cask
  run "brew cleanup"  brew cleanup
fi
command -v mise   &>/dev/null && run "mise"       mise upgrade
command -v rustup &>/dev/null && run "rustup"     rustup update
command -v uv     &>/dev/null && run "uv tools"   uv tool upgrade --all
command -v npm    &>/dev/null && run "npm globals" npm update -g
if command -v claude &>/dev/null && command -v jq &>/dev/null; then
  run "claude plugins" bash -c 'for p in $(claude plugin list --json | jq -r ".[].id"); do claude plugin update "$p" || exit 1; done'
fi

for d in "${HOME}"/.claude/skills/*/.git; do
  [ -d "$d" ] && run "claude skills ($(basename "$(dirname "$d")"))" git -C "$(dirname "$d")" pull --ff-only --quiet
done

# Self-updating casks (VS Code, Warp, ...) are skipped above (no --greedy). Report the
# ones that are still outdated, but never upgrade them here. The log lists them
# every run; a macOS notification is shown at most once a week.
if command -v brew &>/dev/null; then
  echo "--- self-updating apps still outdated"
  APPS_OUTDATED="$(brew outdated --cask --greedy --verbose 2>/dev/null)"
  if [ -z "$APPS_OUTDATED" ]; then
    echo "none"
  else
    echo "$APPS_OUTDATED"
    STAMP="${CACHE_DIR}/app-updates-notified"
    if ! $FOREGROUND && { [ ! -f "$STAMP" ] || [ -n "$(find "$STAMP" -mtime +6 2>/dev/null)" ]; }; then
      NAMES="$(brew outdated --cask --greedy --quiet 2>/dev/null | paste -sd, - | sed 's/,/, /g')"
      osascript -e "display notification \"${NAMES}\" with title \"App updates available\" subtitle \"Update them in the apps, or: brew upgrade --cask --greedy\"" 2>/dev/null && touch "$STAMP"
    fi
  fi
fi

{
  echo "time=$(date +%s)"
  echo "failed=${FAILED[*]:-}"
} > "$STATUS"

echo "=== done; failed: ${FAILED[*]:-none}"
if [ "${#FAILED[@]}" -gt 0 ] && ! $FOREGROUND; then
  osascript -e "display notification \"Failed: ${FAILED[*]}\" with title \"Dotfiles auto-upgrade\"" 2>/dev/null || true
fi
[ "${#FAILED[@]}" -eq 0 ]
