#!/usr/bin/env bash
# Restore ~/.aws/config from the 1Password secure note "aws-config" (vault
# "Personal"). The config is kept out of this public repo because it names
# profiles, accounts and SSO URLs. Credentials are never stored here.
#
# Skips quietly (exit 0) when `op` is missing or not signed in, so it is safe
# in setup/sync. Re-run after enabling Settings > Developer > "Integrate with
# 1Password CLI". An existing different file is backed up, never overwritten
# silently. Override the reference with AWS_CONFIG_OP_REF.

set -uo pipefail

REF="${AWS_CONFIG_OP_REF:-op://Personal/aws-config/notesPlain}"
DEST="${HOME}/.aws/config"

BLUE="\033[0;34m"; GREEN="\033[0;32m"; YELLOW="\033[0;33m"; RESET="\033[0m"
info()    { echo -e "${BLUE}  →${RESET} $1"; }
success() { echo -e "${GREEN}  ✓${RESET} $1"; }
warning() { echo -e "${YELLOW}  !${RESET} $1"; }

if ! command -v op &>/dev/null; then
  warning "1Password CLI (op) not installed; skipping AWS config"; exit 0
fi

if ! content="$(op read "$REF" 2>/dev/null)" || [ -z "$content" ]; then
  warning "could not read ${REF} (enable 1Password CLI integration / unlock the app); skipping AWS config"
  exit 0
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
printf '%s\n' "$content" > "$TMP"

mkdir -p "${HOME}/.aws" && chmod 700 "${HOME}/.aws"
if [ -f "$DEST" ] && cmp -s "$TMP" "$DEST"; then
  success "~/.aws/config already up to date"
else
  if [ -f "$DEST" ]; then
    BACKUP="${DEST}.bak-$(date +%Y%m%d-%H%M%S)"
    cp -p "$DEST" "$BACKUP" && info "existing config backed up to ${BACKUP}"
  fi
  install -m 600 "$TMP" "$DEST" && success "~/.aws/config restored from 1Password"
fi
