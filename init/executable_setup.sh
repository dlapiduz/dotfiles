#!/usr/bin/env bash


# Setup src directory
if [ -d "$HOME/src" ]; then
  echo "There is already a ~/src directory"
else
  mkdir "$HOME/src"
fi

###############################################################################
# Homebrew                                                                    #
###############################################################################

# install homebrew if not yet existing
if ! command -v brew >/dev/null; then
  echo "Homebrew is not yet installed"
  # install homebrew
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
else
    echo "Homebrew is already installed."
fi

# Turn Homebrew Analytics off
brew analytics off

# Install some basic apps
brew cask install caffeine spectacle

###############################################################################
# Install oh-my-zsh                                                           #
###############################################################################

if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
