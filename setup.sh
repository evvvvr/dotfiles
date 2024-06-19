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
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    echo "Update Homebrew"
    brew update
  fi
 
  brew bundle --file Brewfile

  ln -sf ${HOME}/dotfiles/git/git-clean-stale-local-branches /usr/local/bin

  ln -s "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl" /usr/local/bin/subl

  echo "Install config files"
  ln -sf ${HOME}/dotfiles/git/.gitconfig ${HOME} 
  export SUBL_SETTINGS_DIR="${HOME}/Library/Application Support/Sublime Text 3"
  ln -sf ${HOME}/dotfiles/sublime-text/* "${SUBL_SETTINGS_DIR}/Packages/User/"
  ln -sf ${HOME}/dotfiles/sublime-text/Package\ Control.sublime-settings "${SUBL_SETTINGS_DIR}/Installed Packages/"

  ln -sf ${HOME}/dotfiles/bash/.bash_profile ${HOME}
  . ${HOME}/.bash_profile

  ln -sf ${HOME}/dotfiles/zsh/.zshrc ${HOME}
  . ${HOME}/.zshrc
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
