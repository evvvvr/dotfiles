# dotfiles

macOS setup scripts and configuration files.

## What's included

| Path | Contents |
|------|----------|
| `dotfiles.sh` | Main CLI — setup, sync, update |
| `Brewfile` | Homebrew packages, casks, and VS Code extensions |
| `setup.sh` | Fresh machine setup (called by `dotfiles.sh setup`) |
| `macos.sh` | macOS system preferences (called by `dotfiles.sh sync`) |
| `claude/` | Claude Code global `CLAUDE.md` (stow package) |
| `scripts/` | `link.sh` (stow), `claude-bootstrap.sh` + `claude-plugins.json` (Claude CLI, plugins, language servers) |
| `ghostty/` | Ghostty terminal config |
| `sublime-text/` | Sublime Text preferences and package list |
| `vscode/` | VS Code settings |
| `git/` | Git config and helpers |
| `starship/` | Starship prompt config |
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
   bash ~/dotfiles/dotfiles.sh setup
   ```

This will:
- Check for Xcode Command Line Tools and prompt to install if missing
- Install all packages and apps via Homebrew
- Install Rust toolchain via `rustup`
- Install latest Python via `uv`
- Install Node.js LTS via `mise`
- Symlink all config files with GNU Stow (`scripts/link.sh`)
- Apply macOS system preferences
- Generate an SSH key and copy the public key to clipboard

To skip SSH key generation (e.g. you're restoring an existing key):
```sh
bash ~/dotfiles/dotfiles.sh setup --skip-ssh
```

## Day-to-day usage

### Sync machine to dotfiles

Installs any missing packages, re-stows configs, applies macOS settings. Does not uninstall anything extra on the machine.

```sh
~/dotfiles/dotfiles.sh sync
```

### Update dotfiles to match machine

Auto-syncs VS Code extensions in the Brewfile and shows any brew packages installed but not tracked.

```sh
~/dotfiles/dotfiles.sh update
```

> macOS settings cannot be captured automatically — edit `macos.sh` manually when preferences change.

## Layout (GNU Stow)

Each top-level config folder (`bash`, `zsh`, `git`, `starship`, `ghostty`, `vscode`, `sublime-text`, `claude`) is a stow package whose contents mirror `$HOME`, e.g. `starship/.config/starship.toml` -> `~/.config/starship.toml`. `scripts/link.sh` runs `stow --no-folding` so only individual files are linked (never whole directories like `~/.claude`). Files that must not be linked (the git helper script, Sublime's `Package Control.sublime-settings`) are listed in each package's `.stow-local-ignore` and handled by `link.sh` directly.
