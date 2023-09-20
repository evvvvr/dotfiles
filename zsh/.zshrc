export ZSH=/Users/voga/.oh-my-zsh

ZSH_THEME="robbyrussell"

plugins=(git)

source $ZSH/oh-my-zsh.sh

export PROMPT='%n%f@%m%f %1~%f $(git_prompt_info)%# '

export LANG=en_US.UTF-8
export LC_ALL="en_US.UTF-8"
export EDITOR="subl"
export PATH=/usr/local/bin:$(/usr/local/bin/brew --prefix coreutils)/libexec/gnubin:$PATH
export MANPATH=$(brew --prefix coreutils)/opt/coreutils/libexec/gnuman:$MANPATH

alias ls='ls -a --color=auto'
alias cp='cp -iv'
alias mv='mv -iv'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

source /Users/voga/.zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

. /usr/local/etc/profile.d/z.sh

export NVM_DIR="$HOME/.nvm"

[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"


export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"