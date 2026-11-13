#!/usr/bin/env bash
# Shared helpers for scripts/*.sh (source this file).

DOTFILES="${DOTFILES:-${HOME}/dotfiles}"
# shellcheck disable=SC2034  # used by sync.sh
BREWFILE="${DOTFILES}/Brewfile"

BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[0;33m"
DIM="\033[2m"
RESET="\033[0m"

info()    { echo -e "${BLUE}  →${RESET} $1"; }
success() { echo -e "${GREEN}  ✓${RESET} $1"; }
warning() { echo -e "${YELLOW}  !${RESET} $1"; }
header()  { echo -e "\n${BOLD}$1${RESET}"; }
dim()     { echo -e "${DIM}  $1${RESET}"; }

# Terminal effects (banner, numbered steps, spinner, summary).
source "$(dirname "${BASH_SOURCE[0]}")/ui.sh"
