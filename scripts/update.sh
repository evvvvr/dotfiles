#!/usr/bin/env bash
# Update the dotfiles to match this machine (VS Code extensions, untracked brew packages,
# Sublime package list). Run via: mise run dotfiles:update

set -e
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

header "🔄 Updating dotfiles to match this machine"

# VS Code extensions
header "  VS Code extensions"
if ! command -v code &>/dev/null; then
  warning "code CLI not found, skipping"
else
  CURRENT_EXTS=$(code --list-extensions | sort)
  TRACKED_EXTS=$(grep '^vscode ' "$BREWFILE" | sed 's/vscode "//;s/"//' | sort)

  NEW_EXTS=$(comm -23 <(echo "$CURRENT_EXTS") <(echo "$TRACKED_EXTS"))
  REMOVED_EXTS=$(comm -13 <(echo "$CURRENT_EXTS") <(echo "$TRACKED_EXTS"))

  if [ -z "$NEW_EXTS" ] && [ -z "$REMOVED_EXTS" ]; then
    success "Extensions already up to date"
  else
    # Rebuild vscode section in Brewfile
    NON_VSCODE=$(grep -v '^vscode ' "$BREWFILE")
    NEW_VSCODE_LINES=$(echo "$CURRENT_EXTS" | sed 's/.*/vscode "&"/')
    printf '%s\n%s\n' "$NON_VSCODE" "$NEW_VSCODE_LINES" > "$BREWFILE"

    [ -n "$NEW_EXTS" ]     && echo "$NEW_EXTS"     | while read -r e; do info "added:   $e"; done
    [ -n "$REMOVED_EXTS" ] && echo "$REMOVED_EXTS" | while read -r e; do info "removed: $e"; done
    success "Brewfile updated"
  fi
fi

# Brew packages not tracked
header "  Untracked brew packages"
TRACKED_FORMULAE=$(grep '^brew ' "$BREWFILE" | sed 's/brew "//;s/"//' | sort)
INSTALLED_FORMULAE=$(brew list --formula | sort)
UNTRACKED=$(comm -13 <(echo "$TRACKED_FORMULAE") <(echo "$INSTALLED_FORMULAE"))

if [ -z "$UNTRACKED" ]; then
  success "Nothing untracked"
else
  warning "Installed but not in Brewfile (add manually if needed):"
  echo "$UNTRACKED" | while read -r pkg; do dim "$pkg"; done
fi

# Sublime Text packages
header "  Sublime Text packages"
SUBL_PKG="${HOME}/Library/Application Support/Sublime Text/Packages/User/Package Control.sublime-settings"
if [ -f "$SUBL_PKG" ] && [ ! -L "$SUBL_PKG" ]; then
  cp "$SUBL_PKG" "${DOTFILES}/sublime-text/Library/Application Support/Sublime Text/Packages/User/Package Control.sublime-settings"
  success "Package Control.sublime-settings synced to dotfiles"
else
  warning "Sublime Text package list not found or is a symlink — skipping"
fi

# macOS reminder
header "  macOS settings"
warning "Cannot be captured automatically — edit macos.sh manually if needed"

echo -e "\n${GREEN}${BOLD}✓ Update complete!${RESET}\n"
