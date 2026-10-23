# dotfiles

macOS setup scripts and configuration files.

## What's included

| Path | Contents |
|------|----------|
| `Brewfile` | Homebrew packages, casks, and VS Code extensions |
| `setup.sh` | Full machine setup script |
| `macos.sh` | macOS system preferences |
| `ghostty/` | Ghostty terminal config |
| `vscode/` | VS Code settings |
| `git/` | Git config and helpers |
| `zsh/` | Zsh config |
| `bash/` | Bash config |

## Fresh machine setup

1. Install Homebrew (also installs Xcode Command Line Tools if missing):
   ```sh
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/homebrew/install/HEAD/install.sh)"
   ```

2. Clone this repo:
   ```sh
   git clone https://github.com/evvvvr/dotfiles ~/dotfiles
   ```

3. Run setup:
   ```sh
   bash ~/dotfiles/setup.sh
   ```

`setup.sh` will:
- Check for Xcode Command Line Tools and prompt to install if missing
- Install all packages and apps via Homebrew
- Install Rust toolchain via `rustup`
- Install latest Python via `uv`
- Install Node.js LTS via `mise`
- Symlink all config files
- Apply macOS system preferences
- Generate an SSH key and copy the public key to clipboard (see below)

### SSH key

By default the script generates an ed25519 SSH key and copies the public key to your clipboard so you can paste it into [GitHub SSH settings](https://github.com/settings/ssh/new). To skip this (e.g. you're restoring an existing key):

```sh
bash ~/dotfiles/setup.sh --skip-ssh
```

## Keeping things updated

### Sync VS Code extensions

After installing new extensions, update the Brewfile:
```sh
code --list-extensions
# manually update the vscode entries in Brewfile
```

### Update macOS settings

Edit `macos.sh` and re-run it:
```sh
bash ~/dotfiles/macos.sh
```

### Update packages

```sh
brew bundle --file ~/dotfiles/Brewfile
```
