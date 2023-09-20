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

  brew install coreutils --with-default-names
  brew install binutils --with-default-names
  brew install diffutils --with-default-names
  brew install findutils --with-default-names
  brew install gnu-which --with-default-names
  brew install gnu-sed --with-default-names
  brew install grep --with-default-names
  brew install gnu-tar --with-default-names
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

  echo "Install Java"
  brew cask install java

  echo "Install docker"
  brew cask install docker

  echo "Install Sublime Text"
  brew cask install sublime-text
  ln -s "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl" /usr/local/bin/subl

  echo "Install meld"
  brew cask install meld

  # nvm (https://github.com/creationix/nvm#install-script) and node
  NVM_DIR="$HOME/.nvm"
  if [[ ! -d "$NVM_DIR" ]]; then
    echo "Install nvm and node"
    (
      git clone https://github.com/creationix/nvm.git "$NVM_DIR"
      cd "$NVM_DIR"
      git checkout `git describe --abbrev=0 --tags --match "v[0-9]*" origin`
    ) &&
    chmod +x "$NVM_DIR/nvm.sh" &&
    . "$NVM_DIR/nvm.sh" && nvm install node && nvm use node && npm install -g yarn
  fi

  if [[ ! -d "$HOME/.git-prompt" ]]; then
      echo "Install git-aware prompt"
      git clone https://github.com/jimeh/git-aware-prompt.git "$HOME/.git-prompt"  
  fi

  # grep -q "/usr/local/bin/bash" "/etc/shells";
  # if [[ $? != 0 ]] ; then
  #     echo "Install new bash"
  #     brew install bash
  #     sudo bash -c 'echo /usr/local/bin/bash >> /etc/shells'
  #     chsh -s /usr/local/bin/bash
  # fi

  echo "Install fonts"
  brew tap caskroom/fonts
  brew cask install font-fira-code

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
