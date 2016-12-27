#!/usr/bin/env bash

command -v brew >/dev/null 2>&1
if [[ $? != 0 ]] ; then
  echo "Install Homebrew"
  /usr/bin/ruby -e "$(curl -fsSL https://raw.github.com/gist/323731)"
else
  echo "Update Homebrew"
  brew update
fi

echo "Install git"
brew install git

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

echo "Install Python"
brew install python

echo "Install meld"
brew install meld

echo "Install Sublime Text"
brew cask install sublime-text

# nvm (https://github.com/creationix/nvm#install-script) and node
command -v nvm >/dev/null 2>&1
if [[ $? != 0 ]] ; then
    echo "Install nvm and node"
    export NVM_DIR="$HOME/.nvm" && (
    git clone https://github.com/creationix/nvm.git "$NVM_DIR"
    cd "$NVM_DIR"
    git checkout `git describe --abbrev=0 --tags --match "v[0-9]*" origin`
    ) &&
    export NVM_DIR="$HOME/.nvm" && chmod +x "$NVM_DIR/nvm.sh" &&
    . "$NVM_DIR/nvm.sh" && nvm install node && nvm use node && npm install -g yarn
fi

echo "Install autojump"
brew install autojump

if [[ ! -d "$HOME/.git-prompt" ]]; then
    echo "Install git-aware prompt"
    git clone https://github.com/jimeh/git-aware-prompt.git "$HOME/.git-prompt"  
fi

grep -q "/usr/local/bin/bash" "/etc/shells";
if [[ $? != 0 ]] ; then
    echo "Install new bash"
    brew install bash
    sudo bash -c 'echo /usr/local/bin/bash >> /etc/shells'
    chsh -s /usr/local/bin/bash
fi

echo "Install docker"
brew cask install docker

echo "Install iTerm2"
brew cask install iterm2

echo "Upgrade software"
brew upgrade

echo "Clean-up software"
brew cleanup

echo "Install config files"
ln -sf ${HOME}/dotfiles/git/.gitconfig ${HOME} 
export SUBL_SETTINGS_DIR="${HOME}/Library/Application Support/Sublime Text 3"
ln -sf ${HOME}/dotfiles/sublime-text/* "${SUBL_SETTINGS_DIR}/Packages/User/"
ln -sf ${HOME}/dotfiles/sublime-text/Package\ Control.sublime-settings "${SUBL_SETTINGS_DIR}/Installed Packages/"

ln -sf ${HOME}/dotfiles/bash/.bash_profile ${HOME}
. ${HOME}/.bash_profile