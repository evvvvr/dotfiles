#!/usr/bin/env bash

function update {
  echo "Update Homebrew"
  brew update

  echo "Upgrade software"
  brew upgrade

  echo "Clean-up software"
  brew cleanup
}

function install {
  command -v "brew" >/dev/null 2>&1
  if [[ $? != 0 ]] ; then
    echo "Install Homebrew"
    /usr/bin/ruby -e "$(curl -fsSL https://raw.github.com/gist/323731)"
  else
    echo "Update Homebrew"
    brew update
  fi

  brew tap caskroom/cask

  echo "Install git"
  brew install git
  brew install git-flow
  ln -sf ${HOME}/dotfiles/git/git-clean-stale-local-branches /usr/local/bin

  echo "Install utils"
  brew untap homebrew/dupes
  brew tap homebrew/dupes

  brew install coreutils
  brew install binutils
  brew install diffutils
  brew install findutils
  brew install gnu-which
  brew install gnu-sed
  brew install grep
  brew install gnu-tar
  brew install gzip
  brew install unzip
  brew install watch
  brew install wget
  brew install curl
  brew install nmap
  brew install htop
  brew install rsync
  brew install bash-completion
  brew install tree
  brew install entr

  brew install --cask warp

  # Developer tools
  brew install --cask visual-studio-code
  brew install --cask ngrok
  brew install --cask dbeaver-community

  echo "Install MySQL"
  brew install mysql

  echo "Install PostgreSQL"
  brew install postgres

  echo "Install Python"
  brew install python
  brew install pyenv

  echo "Install Java"
  brew cask install java

  echo "Install docker"
  brew install --cask docker

  echo "Install Sublime Text"
  brew cask install sublime-text
  ln -s "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl" /usr/local/bin/subl

  # nvm
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
  nvm install node

  echo "Install fonts"
  brew tap homebrew/cask-fonts
  brew install font-fira-code

  echo "Install config files"
  ln -sf ${HOME}/dotfiles/git/.gitconfig ${HOME} 
  export SUBL_SETTINGS_DIR="${HOME}/Library/Application Support/Sublime Text 3"
  ln -sf ${HOME}/dotfiles/sublime-text/* "${SUBL_SETTINGS_DIR}/Packages/User/"
  ln -sf ${HOME}/dotfiles/sublime-text/Package\ Control.sublime-settings "${SUBL_SETTINGS_DIR}/Installed Packages/"

  ln -sf ${HOME}/dotfiles/bash/.bash_profile ${HOME}
  . ${HOME}/.bash_profile

  ln -sf ${HOME}/dotfiles/zsh/.zshrc ${HOME}
  . ${HOME}/.zshrc

  update
}

cmd=$1
if [ -z "$cmd" ]; then
  echo "Command required. Commands: 'install', 'update'"
  exit 1
fi

case "$cmd" in
  install)
    install
    ;;

  update)
    update
    ;;

  *)
    echo "Unknown command. Commands: 'install', 'update'"
    exit 1
    ;;  
esac
