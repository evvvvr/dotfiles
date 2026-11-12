#!/usr/bin/env bash
# Idempotent bootstrap for the Claude Code CLI, plugins and the language servers
# the LSP plugins need. Safe to re-run. Contains no secrets.

set -uo pipefail

case "${1:-}" in
  -h|--help)
    echo "Usage: claude-bootstrap.sh"
    echo "Installs the Claude CLI, marketplaces and plugins from scripts/claude-plugins.json,"
    echo "merges that file into ~/.claude/settings.json (with backup), and installs"
    echo "the LSP binaries. Idempotent; safe to re-run."
    exit 0 ;;
esac

MERGED=""
trap '[ -n "$MERGED" ] && rm -f "$MERGED"' EXIT

DOTFILES="${DOTFILES:-${HOME}/dotfiles}"
FRAGMENT="${DOTFILES}/scripts/claude-plugins.json"
SETTINGS="${HOME}/.claude/settings.json"

GREEN="\033[0;32m"; BLUE="\033[0;34m"; YELLOW="\033[0;33m"; RED="\033[0;31m"; BOLD="\033[1m"; RESET="\033[0m"
info()    { echo -e "${BLUE}  →${RESET} $1"; }
success() { echo -e "${GREEN}  ✓${RESET} $1"; }
warning() { echo -e "${YELLOW}  !${RESET} $1"; }
header()  { echo -e "\n${BOLD}$1${RESET}"; }

PRESENT=(); INSTALLED=(); FAILED=()

# marketplace name|source passed to `claude plugin marketplace add`
MARKETPLACES=(
  "claude-plugins-official|anthropics/claude-plugins-official"
  "context-mode|mksglu/context-mode"
)

# name|check command (must succeed when usable)|install command
# rust-analyzer is a rustup proxy that exists on PATH even without the component,
# so it is checked by actually running it.
LSP_SERVERS=(
  "typescript-language-server|typescript-language-server --version|npm install -g typescript-language-server typescript"
  "pyright-langserver|command -v pyright-langserver|npm install -g pyright"
  "rust-analyzer|rust-analyzer --version|rustup component add rust-analyzer"
)

export PATH="${HOME}/.local/bin:${HOME}/.cargo/bin:${PATH}"

header "🤖 Claude Code CLI"
if command -v claude &>/dev/null; then
  PRESENT+=("cli: claude"); success "claude already installed ($(claude --version 2>/dev/null))"
else
  info "Installing via the official installer (https://claude.ai/install.sh)"
  if curl -fsSL https://claude.ai/install.sh | bash && command -v claude &>/dev/null; then
    INSTALLED+=("cli: claude"); success "claude installed"
  else
    FAILED+=("cli: claude"); warning "claude install failed"
  fi
fi

if ! command -v claude &>/dev/null || ! command -v jq &>/dev/null; then
  warning "claude or jq missing; cannot configure plugins"
  FAILED+=("plugins: skipped (claude/jq missing)")
else
  header "🏪 Marketplaces"
  KNOWN_MP="$(claude plugin marketplace list --json 2>/dev/null | jq -r '.[].name' 2>/dev/null)"
  for entry in "${MARKETPLACES[@]}"; do
    name="${entry%%|*}"; source="${entry#*|}"
    if grep -qx "$name" <<<"$KNOWN_MP"; then
      PRESENT+=("marketplace: $name"); success "$name already added"
    elif claude plugin marketplace add "$source" >/dev/null; then
      INSTALLED+=("marketplace: $name"); success "$name added"
    else
      FAILED+=("marketplace: $name"); warning "failed to add $name"
    fi
  done

  header "🔌 Plugins"
  INSTALLED_IDS="$(claude plugin list --json 2>/dev/null | jq -r '.[].id' 2>/dev/null)"
  while read -r id; do
    if grep -qx "$id" <<<"$INSTALLED_IDS"; then
      PRESENT+=("plugin: $id"); success "$id already installed"
    elif claude plugin install "$id" --scope user >/dev/null; then
      INSTALLED+=("plugin: $id"); success "$id installed"
    else
      FAILED+=("plugin: $id"); warning "failed to install $id"
    fi
  done < <(jq -r '.enabledPlugins | keys[]' "$FRAGMENT")

  header "⚙️  settings.json"
  mkdir -p "${HOME}/.claude"
  [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
  MERGED="$(mktemp)"
  if jq -s '.[0] * .[1]' "$SETTINGS" "$FRAGMENT" > "$MERGED"; then
    if jq -e -s '.[0] == .[1]' "$SETTINGS" "$MERGED" &>/dev/null; then
      PRESENT+=("settings.json: up to date"); success "already up to date"
    else
      BACKUP="${SETTINGS}.bak-$(date +%Y%m%d-%H%M%S)"
      cp "$SETTINGS" "$BACKUP" && cat "$MERGED" > "$SETTINGS"
      INSTALLED+=("settings.json: merged (backup: $BACKUP)"); success "merged; backup at $BACKUP"
    fi
  else
    FAILED+=("settings.json: merge"); warning "merge failed; settings untouched"
  fi
  rm -f "$MERGED"
fi

header "🧠 Language servers"
for entry in "${LSP_SERVERS[@]}"; do
  IFS='|' read -r bin check cmd <<<"$entry"
  if eval "$check" &>/dev/null; then
    PRESENT+=("lsp: $bin"); success "$bin already usable"
    continue
  fi
  info "$cmd"
  eval "$cmd" >/dev/null
  command -v mise &>/dev/null && mise reshim &>/dev/null
  hash -r
  if eval "$check" &>/dev/null; then
    INSTALLED+=("lsp: $bin"); success "$bin installed"
  else
    FAILED+=("lsp: $bin"); warning "$bin not usable after install"
  fi
done

header "📋 Summary"
echo "  already present: ${#PRESENT[@]}"
echo "  installed now:   ${#INSTALLED[@]}"
for i in "${INSTALLED[@]:-}"; do [ -n "$i" ] && echo "    + $i"; done
echo "  failed:          ${#FAILED[@]}"
for f in "${FAILED[@]:-}"; do [ -n "$f" ] && echo -e "    ${RED}✗${RESET} $f"; done
[ "${#INSTALLED[@]}" -gt 0 ] && warning "Restart Claude Code sessions to pick up new plugins/LSPs"
[ "${#FAILED[@]}" -eq 0 ]
