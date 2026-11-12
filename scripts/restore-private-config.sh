#!/usr/bin/env bash
# Restore private files from 1Password secure notes. These are kept out of this
# public repo: ~/.aws/config names profiles/accounts/SSO URLs, and the Sublime
# Text license is a secret. Credentials themselves are never handled here.
#
# Skips quietly (exit 0) when `op` is missing or locked, so it is safe in
# setup/sync. Re-run after enabling Settings > Developer > "Integrate with
# 1Password CLI". A differing existing file is backed up, never overwritten
# silently, and a note that fails its content check is never written.
#
# Table format: name|op secret reference|destination|required text (optional)|mode (optional)
# mode "create-only" never touches an existing destination (used for the Sublime
# license, whose installed file may legitimately differ from the stored text).
# NOTE: item titles must not contain "/" (it is the op:// path separator).

set -uo pipefail

ITEMS=(
  "AWS config|op://Personal/aws-config/notesPlain|${HOME}/.aws/config||"
  "Sublime Text license|op://Personal/SublimeText/reg_code|${HOME}/Library/Application Support/Sublime Text/Local/License.sublime_license|BEGIN LICENSE|create-only"
)

BLUE="\033[0;34m"; GREEN="\033[0;32m"; YELLOW="\033[0;33m"; RESET="\033[0m"
info()    { echo -e "${BLUE}  →${RESET} $1"; }
success() { echo -e "${GREEN}  ✓${RESET} $1"; }
warning() { echo -e "${YELLOW}  !${RESET} $1"; }

if ! command -v op &>/dev/null; then
  warning "1Password CLI (op) not installed; skipping private config"; exit 0
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

for entry in "${ITEMS[@]}"; do
  IFS='|' read -r name ref dest check mode <<<"$entry"

  if [ "$mode" = "create-only" ] && [ -e "$dest" ]; then
    success "${name}: already present; leaving it alone"
    continue
  fi

  if ! content="$(op read "$ref" 2>/dev/null)" || [ -z "$content" ]; then
    warning "${name}: could not read ${ref} (enable 1Password CLI integration / unlock the app); skipping"
    continue
  fi
  if [ -n "$check" ] && ! grep -q -- "$check" <<<"$content"; then
    warning "${name}: note does not contain \"${check}\"; not writing it"
    continue
  fi

  printf '%s\n' "$content" > "$TMP"
  mkdir -p "$(dirname "$dest")"
  case "$dest" in "${HOME}/.aws/"*) chmod 700 "${HOME}/.aws" ;; esac

  if [ -f "$dest" ] && cmp -s "$TMP" "$dest"; then
    success "${name}: already up to date"
    continue
  fi
  if [ -f "$dest" ]; then
    backup="${dest}.bak-$(date +%Y%m%d-%H%M%S)"
    cp -p "$dest" "$backup" && info "${name}: existing file backed up to ${backup}"
  fi
  install -m 600 "$TMP" "$dest" && success "${name}: restored from 1Password"
done
