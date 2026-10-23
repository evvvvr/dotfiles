# ~/.zshrc  (managed via stow: dotfiles/zsh/.zshrc)

export EDITOR="zed --wait"
export LANG=en_US.UTF-8
export TERM=xterm-256color

# --- Homebrew (Apple Silicon) ---
[ -d /opt/homebrew/bin ] && eval "$(/opt/homebrew/bin/brew shellenv)"
autoload -Uz compinit && compinit

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
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE

# --- Aliases ---
alias ls="eza --icons --group-directories-first"
alias ll="eza -la --icons --group-directories-first"
alias lt="eza --tree --level=2 --icons"
alias cat="bat"
alias g="git"
alias gs="git status"
alias gl="git log --oneline --graph --decorate -20"
alias lg="lazygit"
alias ld="lazydocker"
alias pn="pnpm"

# --- pnpm ---
export PNPM_HOME="$HOME/Library/pnpm"
export PATH="$PNPM_HOME:$PATH"

# --- uv (python) ---
export PATH="$HOME/.local/bin:$PATH"

alias awsume="source awsume"

