# dotfiles

macOS setup scripts and configuration files.

## What's included

| Path | Contents |
|------|----------|
| `dotfiles.sh` | Main CLI — setup, sync, update, upgrade |
| `Brewfile` | Homebrew packages, casks, and VS Code extensions |
| `setup.sh` | Fresh machine setup (called by `dotfiles.sh setup`) |
| `macos.sh` | macOS system preferences (called by `dotfiles.sh sync`) |
| `claude/` | Claude Code global `CLAUDE.md` (stow package) |
| `scripts/` | `link.sh` (stow), `auto-upgrade.sh` (daily unattended upgrades), `claude-bootstrap.sh` + `claude-plugins.json` (Claude CLI, plugins, language servers) |
| `launchd/` | LaunchAgent that runs `auto-upgrade.sh` daily (stow package) |
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
- Install the Claude CLI, plugins and language servers (`scripts/claude-bootstrap.sh`, see [Claude Code](#claude-code))
- Install `harlequin` via `uv tool`
- Symlink all config files with GNU Stow (`scripts/link.sh`) and load the daily auto-upgrade launchd agent
- Apply macOS system preferences
- Generate an SSH key and copy the public key to clipboard

To skip SSH key generation (e.g. you're restoring an existing key):
```sh
bash ~/dotfiles/dotfiles.sh setup --skip-ssh
```

## Day-to-day usage

### Sync machine to dotfiles

Installs any missing Homebrew packages, re-stows configs, re-runs the Claude bootstrap (installs only what's missing), and applies macOS settings. Does not upgrade or uninstall anything on the machine.

```sh
~/dotfiles/dotfiles.sh sync
```

### Upgrade all software

**Automatic:** a launchd agent (`launchd/` package, loaded by `scripts/link.sh`) runs `scripts/auto-upgrade.sh` daily at 03:30 (or on wake if the Mac was asleep). It upgrades Homebrew formulae and non-self-updating casks, mise runtimes, Rust, uv tools, npm globals and Claude plugins. Output goes to `~/.cache/dotfiles/upgrade.log`; a failure triggers a notification and a one-line warning in new zsh sessions (a cheap file read, no network). Self-updating apps (VS Code, Warp, ...) update themselves, and sudo items (macOS, Xcode Command Line Tools) are never run unattended.

**Manual:** runs the same upgrade in the foreground, plus VS Code extensions and an optional Xcode Command Line Tools update (prompts for sudo). Sublime packages update inside Sublime.

```sh
~/dotfiles/dotfiles.sh upgrade
```

To pause the automatic job: `launchctl bootout gui/$(id -u)/dev.dotfiles.auto-upgrade` (re-enable by running `scripts/link.sh`).

### Update dotfiles to match machine

Auto-syncs VS Code extensions in the Brewfile, shows any brew packages installed but not tracked, and copies Sublime's `Package Control.sublime-settings` back into the repo.

```sh
~/dotfiles/dotfiles.sh update
```

> macOS settings cannot be captured automatically — edit `macos.sh` manually when preferences change.

## Claude Code

`scripts/claude-bootstrap.sh` (idempotent, safe to re-run) installs the Claude CLI with the official installer if missing, adds the marketplaces, installs only the missing plugins from `scripts/claude-plugins.json`, installs the language servers the LSP plugins need (`typescript-language-server`, `pyright`, `rust-analyzer`), and merges `claude-plugins.json` into `~/.claude/settings.json` (a timestamped backup is written first; existing settings are preserved). The global `~/.claude/CLAUDE.md` is stowed from `claude/.claude/CLAUDE.md`.

To add a plugin, add it to `enabledPlugins` (and its marketplace to `extraKnownMarketplaces` if new) in `scripts/claude-plugins.json`, then run the script. Plugin updates are handled by the daily auto-upgrade job. After installs or updates, restart Claude Code to apply them.

## Layout (GNU Stow)

Each top-level config folder (`bash`, `zsh`, `git`, `starship`, `ghostty`, `vscode`, `sublime-text`, `claude`, `launchd`) is a stow package whose contents mirror `$HOME`, e.g. `starship/.config/starship.toml` -> `~/.config/starship.toml`. `scripts/link.sh` runs `stow --no-folding` so only individual files are linked (never whole directories like `~/.claude`). Files that must not be linked (the git helper script, Sublime's `Package Control.sublime-settings`) are listed in each package's `.stow-local-ignore` and handled by `link.sh` directly.
