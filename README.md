# dotfiles

macOS setup scripts and configuration files.

## What's included

| Path | Contents |
|------|----------|
| `bootstrap.sh` | One-command fresh-machine entry point (Homebrew, download repo, run setup) |
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
| `git/` | Git config and global gitignore |
| `starship/` | Starship prompt config |
| `zsh/` | Zsh config |
| `bash/` | Bash config |

## Fresh machine setup

Run one command:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/evvvvr/dotfiles/main/bootstrap.sh)"
```

`bootstrap.sh` installs Homebrew (which also installs the Xcode Command Line Tools if missing), downloads this repo to `~/dotfiles` as a tarball (no git needed), turns it into a git checkout tracking `origin/main`, and runs `dotfiles.sh setup`. Use the `bash -c "$(curl ...)"` form rather than `curl | bash`, because the Homebrew installer needs the terminal for its prompts. It is safe to re-run.

Setup then:
- Checks for Xcode Command Line Tools and prompts to install if missing
- Installs all packages and apps via Homebrew
- Symlinks all config files with GNU Stow (`scripts/link.sh`), loads the daily auto-upgrade launchd agent and restores `~/.aws/config` from 1Password if available
- Installs the Rust toolchain via `rustup`, Python via `uv`, and the tools in the stowed mise config (Node.js, tflint, typescript, typescript-language-server, pyright) via `mise install`
- Installs the Claude CLI, plugins, skills and language servers (`scripts/claude-bootstrap.sh`, see [Claude Code](#claude-code))
- Installs `harlequin` via `uv tool`
- Applies macOS system preferences
- Generates an SSH key and copies the public key to the clipboard

To skip SSH key generation (e.g. you're restoring an existing key), pass the flag through:
```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/evvvvr/dotfiles/main/bootstrap.sh)" bootstrap --skip-ssh
```

Already have the repo? Run setup directly: `bash ~/dotfiles/dotfiles.sh setup [--skip-ssh]`.

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

To add a plugin, add it to `enabledPlugins` (and its marketplace to `extraKnownMarketplaces` if new) in `scripts/claude-plugins.json`, then run the script. Third-party skills listed in `SKILLS` in the script (currently `ex-ussr-kinship-research`) are cloned into `~/.claude/skills`. Plugins and those skills are updated by the daily auto-upgrade job. After installs or updates, restart Claude Code to apply them.

## Private config (1Password)

Some files are kept out of this public repo and restored from 1Password secure notes by `scripts/restore-private-config.sh` (called from `scripts/link.sh`, using the 1Password CLI `op`):

| File | 1Password note | Why it is not in the repo |
|---|---|---|
| `~/.aws/config` | `op://Personal/aws-config/notesPlain` | names profiles, accounts and SSO URLs |
| Sublime Text license (`.../Sublime Text/Local/License.sublime_license`) | `op://Personal/SublimeText/reg_code` (a 1Password Software License item) | the license is a secret |

The script skips quietly when `op` is missing or locked, backs up a differing existing file instead of overwriting it, refuses to write a license that does not contain `BEGIN LICENSE`, only creates the Sublime license when none exists (it never replaces an installed one), and never touches credentials. Item titles must not contain `/`. On a new machine, enable Settings > Developer > "Integrate with 1Password CLI" in the app, then re-run `scripts/link.sh`.

## Linting

The Brewfile installs `shellcheck`, `shfmt`, `hadolint`, `actionlint`, `kubeconform`, `kube-linter` and `ruff`; `tflint` comes from the mise config. `shellcheck` does not support zsh, so check zsh files with `zsh -n <file>` (syntax only). Project-level linters (eslint, prettier, ...) belong in each project, not here.

## Layout (GNU Stow)

Each top-level config folder (`bash`, `zsh`, `git`, `starship`, `ghostty`, `vscode`, `sublime-text`, `claude`, `launchd`, `mise`, `btop`, `television`) is a stow package whose contents mirror `$HOME`, e.g. `starship/.config/starship.toml` -> `~/.config/starship.toml`. `scripts/link.sh` runs `stow --no-folding` so only individual files are linked (never whole directories like `~/.claude`). Files that must not be linked (Sublime's `Package Control.sublime-settings`) are listed in each package's `.stow-local-ignore` and handled by `link.sh` directly.
