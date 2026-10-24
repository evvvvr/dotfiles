# ~/.zshrc  (managed via stow: dotfiles/zsh/.zshrc)

export EDITOR="zed --wait"
export LANG=en_US.UTF-8

# --- Homebrew (Apple Silicon) ---
[ -d /opt/homebrew/bin ] && eval "$(/opt/homebrew/bin/brew shellenv)"

# --- Unique path / fpath entries ---
typeset -U path fpath

# --- PATH exports ---
export PNPM_HOME="$HOME/Library/pnpm"
export PATH="$PNPM_HOME:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# --- Completions ---
_zsh_comp_dir="${HOME}/.zsh/completions"
[[ -d $_zsh_comp_dir ]] || mkdir -p "$_zsh_comp_dir"
fpath=("$_zsh_comp_dir" $fpath)

_regen_comp() {
  local out="$1"; shift
  if [[ ! -f $out || $(( $(date +%s) - $(stat -f %m "$out") )) -gt 86400 ]]; then
    local tmp="${out}.tmp.$$"
    if "$@" > "$tmp" 2>/dev/null && [[ -s $tmp ]]; then
      mv "$tmp" "$out"
      rm -f "${ZDOTDIR:-$HOME}/.zcompdump"
    else
      rm -f "$tmp"
    fi
  fi
}
_regen_comp "$_zsh_comp_dir/_uv"   uv generate-shell-completion zsh
_regen_comp "$_zsh_comp_dir/_mise" mise completion zsh
_regen_comp "$_zsh_comp_dir/_pnpm" pnpm completion zsh

autoload -Uz compinit
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}' 'r:|=*' 'l:|=* r:|=*'

# --- mise: node + python version management (auto-switches per dir) ---
eval "$(mise activate zsh)"

# --- Prompt + navigation tools ---
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
eval "$(direnv hook zsh)"

# --- television (tv): fuzzy finder TUI, replaces fzf ---
# Provides Ctrl-T (smart find) and Ctrl-R (history) shell widgets.
eval "$(tv init zsh)"

# --- History ---
HISTSIZE=50000
SAVEHIST=50000
HISTFILE=~/.zsh_history
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE \
       EXTENDED_HISTORY HIST_FIND_NO_DUPS HIST_REDUCE_BLANKS

# --- Options ---
setopt AUTO_CD INTERACTIVE_COMMENTS

# --- Key bindings ---
bindkey '^[[A' history-search-backward
bindkey '^[OA' history-search-backward
bindkey '^[[B' history-search-forward
bindkey '^[OB' history-search-forward

# --- Aliases ---
alias ls="eza --icons --group-directories-first"
alias ll="eza -la --icons --group-directories-first"
alias lt="eza --tree --level=2 --icons"
alias cat="bat"
alias g="git"
alias gs="git status"
alias gl="git log --oneline --graph --decorate -20"
alias lg="lazygit"
alias top="btop"
alias ld="lazydocker"
alias pn="pnpm"

alias awsume="source awsume"

# --- Plugins (zsh-syntax-highlighting must be last) ---
_brew="${HOMEBREW_PREFIX:-/opt/homebrew}"
[[ -f ${_brew}/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] &&
  source "${_brew}/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
[[ -f ${_brew}/share/zsh-you-should-use/you-should-use.plugin.zsh ]] &&
  source "${_brew}/share/zsh-you-should-use/you-should-use.plugin.zsh"
[[ -f ${_brew}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] &&
  source "${_brew}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
