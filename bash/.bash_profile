#!/usr/bin/env bash

export GITAWAREPROMPT=~/.git-prompt
. "${GITAWAREPROMPT}/main.sh"

PS1='\u@\h \W $git_branch$git_dirty: '
PS2='|> '

alias ls='ls -a --color=auto'
alias cp='cp -iv'
alias mv='mv -iv'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

export EDITOR="subl"
export GOPATH="$HOME/projects/go-workspace"
export PATH=$(brew --prefix coreutils)/libexec/gnubin:/usr/local/bin:/usr/local/go/bin:$GOPATH/bin:$PATH
export MANPATH=$(brew --prefix coreutils)/opt/coreutils/libexec/gnuman:$MANPATH

if [ -f $(brew --prefix)/etc/bash_completion ]; then
    . $(brew --prefix)/etc/bash_completion
fi

[[ -s $(brew --prefix)/etc/profile.d/autojump.sh ]] && . $(brew --prefix)/etc/profile.d/autojump.sh

# export NVM_DIR="$HOME/.nvm"
# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

docker-machine start > /dev/null
eval $(docker-machine env default)
. "$HOME/.cargo/env"
export PATH="/usr/local/opt/mysql-client/bin:$PATH"
export PATH="/usr/local/opt/mysql-client/bin:$PATH"
