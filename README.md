# dotfiles

macOS and Linux setup managed with [mise](https://mise.jdx.dev) — dotfiles,
system packages, language runtimes, git repos and macOS defaults, all declared
in `mise.toml` and `home/mise-global.toml`.

## Quick start

```sh
git clone https://github.com/dlapiduz/dotfiles ~/src/dotfiles
cd ~/src/dotfiles
mise trust

MISE_ENV=macos mise bootstrap     # macOS
MISE_ENV=linux mise bootstrap     # Linux

mise run macos                    # macOS only, needs sudo
```

`MISE_ENV` selects the platform package list (`mise.macos.toml` /
`mise.linux.toml`). You only pass it by hand on a fresh machine — once the
dotfiles are applied, `zshrc` exports it automatically from `uname`.

### Linux distros

`mise.linux.toml` carries Debian/Ubuntu (`apt`) and Fedora (`dnf`) entries in
the same file — mise skips any whose manager isn't installed, the same way it
skips `apk` everywhere else. `flatpak` covers GUI apps on both.

Verified on **Pop!_OS 24.04** (apt) and **Fedora 44** (dnf).

Fedora renames two things you'd otherwise get wrong: `wget` is now the
`wget2-wget` shim, and `zlib-devel` no longer exists — `zlib-ng-compat-devel`
provides `zlib.h` and declares `Provides: zlib-devel`. `git-secrets` has no
Fedora package at all and is install-by-hand there. Fedora already ships
flathub as a *system* remote, so the remote-add below is Debian-only.

### Linux: two extra steps

**Run the first bootstrap from a desktop terminal, not over SSH.** Two steps
need a session that can prompt you:

- `chsh` (the login-shell step) authenticates through PAM, *not* sudo. With no
  TTY it fails — and since it runs before the tools step, the whole bootstrap
  aborts and nothing gets installed.
- `flatpak install --system` needs polkit authorization.

If you're stuck on a headless box, do those two out of band and re-run:

```sh
sudo chsh -s /bin/zsh "$USER"
sudo flatpak install --system --noninteractive flathub <app-ids>
```

**Add Flathub as a system remote first.** mise installs flatpaks with
`--system`, and a user-scoped remote isn't visible there — you'd get
`No remote refs found`:

```sh
sudo flatpak remote-add --system --if-not-exists flathub \
  https://dl.flathub.org/repo/flathub.flatpakrepo
```

`mise bootstrap` runs, in order: install packages → clone repos → apply
dotfiles → set login shell → write macOS defaults → install tools → run the
`bootstrap` task. Every step converges, so re-running is safe and idempotent.

## Everyday commands

| Command | What it does |
| --- | --- |
| `mise bootstrap` | Re-converge everything |
| `mise bootstrap status` | Show what's out of sync |
| `mise bootstrap --dry-run` | Show what would change |
| `mise dotfiles status` / `apply` | Dotfile drift / symlink them |
| `mise bootstrap packages status` | Show missing or outdated brew packages |
| `mise ls` | Show global tool versions |
| `mise use -g node@24` | Change a global tool version |
| `mise upgrade` | Update mise-managed tools |
| `mise run macos` | macOS tweaks that need sudo |
| `mise run linux-desktop` | Key repeat + energy settings for COSMIC/GNOME |
| `mise run ghostty` | Install Ghostty on Linux (not packaged; see below) |
| `mise run fonts` | Install MesloLGS NF fonts for powerlevel10k |

Add a dotfile with `mise dotfiles add ~/.somerc --source home/somerc`.

## Layout

```
mise.toml                    # shared: dotfiles, repos, macOS defaults, hooks, tasks
mise.macos.toml              # Homebrew formulae + casks   (MISE_ENV=macos)
mise.linux.toml              # apt + dnf + flatpak         (MISE_ENV=linux)
home/                        # the dotfiles themselves (symlinked into ~)
  zshrc  p10k.zsh  vimrc  gitconfig  gitignore_global
  mise-global.toml           # -> ~/.config/mise/config.toml (global [tools])
scripts/
  macos-extras.sh            # macOS tweaks `defaults write` can't express (sudo)
  restart-affected-apps.sh   # post-defaults hook
  omz-sparse-checkout.sh     # post-repos hook
  install-fonts.sh           # MesloLGS NF
```

Dotfiles are **symlinked**, so editing `~/.zshrc` edits `home/zshrc` here and
shows up in `git status`. That includes edits made by installers that append to
`~/.zshrc` (LM Studio, gcloud, …) — intentional, so you can review them.

If mise refuses with `exists but is not a symlink`, the target is a real file:
back it up, then `mise dotfiles apply --force`.

### Machine-local shell config

`zshrc` sources `~/.zshrc.local` if it exists. That file is deliberately not
tracked — put host-specific `PATH` entries, private tool integrations and
anything else that shouldn't be public there, and this repo stays portable.

## Cross-platform

One repo, both machines. Most of it is platform-agnostic — dotfiles, the
oh-my-zsh/powerlevel10k clones, and all 16 tools in `home/mise-global.toml`
work unchanged on either OS.

mise skips whatever doesn't apply: `[bootstrap.macos.defaults]` reports
`57 entries skipped (only available on macos)` on Linux, and `brew-cask:`
entries skip the same way.

**`brew:` formulae are the exception — they do NOT self-skip on Linux.**
Homebrew can run there, so mise takes those entries seriously and will install
Linuxbrew into `/home/linuxbrew` to satisfy them. That's why packages are split
into `mise.macos.toml` / `mise.linux.toml` selected by `MISE_ENV`, rather than
living together in `mise.toml`. `[bootstrap.packages]` has no per-entry `os`
filter — nested tables, `platform =` and `platforms = []` are all rejected —
so the env-file split is the mechanism.

Platform-specific behaviour elsewhere:

| Thing | Handling |
| --- | --- |
| `install-fonts.sh` | `~/Library/Fonts` on macOS, `~/.local/share/fonts` + `fc-cache` on Linux |
| `macos-extras.sh`, `restart-affected-apps.sh` | exit early when `uname -s` isn't `Darwin` |
| `/opt/homebrew/opt/curl/bin` in `zshrc` | only added when the directory exists |
| key repeat + energy settings | `[bootstrap.macos.defaults]` on macOS, `mise run linux-desktop` on Linux |
| `login_shell = "/bin/zsh"` | works on both — Ubuntu merged `/usr`, so `/bin` is a symlink to `usr/bin`. zsh isn't preinstalled on Pop!_OS, but packages are installed before the login-shell step |

**Run the first Linux bootstrap from a real terminal, not over SSH-without-a-TTY.**
The login-shell step runs `chsh`, which authenticates through PAM and prompts
for your password — it does *not* go through sudo. With no TTY it fails with
`PAM: Authentication failure`, and because the login-shell step comes *before*
the tools step, the whole run aborts and no tools get installed. If you hit it,
set the shell out of band and re-run:

```sh
sudo chsh -s /bin/zsh "$USER"
MISE_ENV=linux mise bootstrap
```

## Homebrew vs mise

mise owns language runtimes and self-contained CLI binaries; Homebrew owns
system libraries and GUI apps. mise cannot install `.app` bundles, so casks
stay with brew permanently.

**Update mise-managed tools with `mise upgrade`, not `brew upgrade`.**

These stay on Homebrew for concrete reasons — re-checked, not assumed:

| Package | Why |
| --- | --- |
| `git`, `curl`, `wget`, `git-secrets` | no mise backend; `ubi:` fails too (source tarballs, no release binaries) |
| `coreutils` | brew ships **GNU**; mise only has `uutils`, a separate Rust reimplementation with different behaviour |
| `ansible` | `pipx:ansible` works but is a major version bump |
| `chromedriver` | the mise plugin tops out at Chrome **115**; must track the installed Chrome's major version |
| `claude`, `1password` | mise's entries are the **CLIs** (`claude-code`, `op`); the casks are the **desktop apps** |
| all other casks | GUI apps, no mise backend |

Five casks can't be resolved by mise at all, and **one unresolvable cask aborts
the entire packages step**, so they're deliberately undeclared and installed by
hand: `firefox` and `zoom` (unsupported artifact types `command_wrapper` /
`postflight_steps`), `microsoft-teams` (pkg installer choices), `authy` and
`wireshark` (no cask API metadata). Re-test after `mise self-update`.

## Gotchas

Things that will bite if forgotten. Verified against mise **2026.7.12** on
macOS 26.

**Rust is rustup's, not mise's.** `[tools] rust` is listed, but mise's
`core:rust` backend doesn't install Rust — it symlinks its install dir to
`~/.cargo/bin`, delegating to rustup. Keep rustup, `~/.cargo` and `~/.rustup`
installed; `rustup update` is what actually changes the version, and the pin
only records intent.

**Don't enable oh-my-zsh's `mise` plugin.** It works, but it activates mise at
plugin-load time — before the `PATH` prepends further down `zshrc`. Later
prepends then win, and a stray binary elsewhere on `PATH` silently shadows the
version you pinned. mise is activated at the *bottom* of `zshrc` instead, with
the plugin's completion setup copied alongside it.

**Don't `rm -rf` anything inside `~/.oh-my-zsh`.** Deleting tracked files
leaves the repo dirty, and mise then refuses to converge it (`has local
changes; commit, stash, or clean them`) — which breaks `mise bootstrap`
entirely. Exclude paths via `scripts/omz-sparse-checkout.sh` instead, which
keeps the working tree clean so `git pull --ff-only` still succeeds.

**`[bootstrap.macos.defaults]` only accepts bool / integer / float / string.**
Dict and array values are silently warned about and skipped — those live in
`scripts/macos-extras.sh`.

**mise expands neither `~` nor `{{env.HOME}}` in defaults values.** Anything
needing an absolute `$HOME` path (`com.apple.screencapture location`, Finder's
`NewWindowTargetPath`) lives in `scripts/macos-extras.sh`, so it stays portable
across usernames rather than hardcoding `/Users/diego`.

**Old Python builds fail attestation.** python-build-standalone releases from
before GitHub artifact attestations are rejected unless you set
`python.github_attestations = false`. Prefer a newer patch release over
disabling verification.

**`"latest"` means latest**, so a package reports `missing` when it's merely
outdated, and `mise bootstrap` will upgrade it. Pin a version if you don't want
that.

**`[bootstrap.repos]` reports `differs` when a clone is behind its branch.**
`mise bootstrap` fast-forwards oh-my-zsh and powerlevel10k. Pin `ref` to a tag
or SHA if you'd rather they stay put.

**`mise run macos` needs sudo** and changes power management, unhides
`/Volumes`, and enables Touch ID for sudo. Read it before running.

### Ghostty on Linux

Ghostty isn't in Fedora's or Debian's official repos and has **no Flathub
build**, so there's no `dnf:` / `apt:` / `flatpak:` entry that would work.
`mise run ghostty` handles it, preferring the least-third-party option
available:

1. **Snap** if snapd is present — the only Linux build Ghostty produces itself
2. **Fedora** — COPR `scottames/ghostty` (community-maintained)
3. **Debian/Ubuntu** — the `.deb` from `mkasberg/ghostty-ubuntu`
   (community-maintained), fetched from the GitHub release rather than piping
   upstream's install script into a shell, so you can see the artifact first

On macOS it's the `brew-cask:ghostty` entry and the script just says so.

## Desktop settings on Linux

`mise run linux-desktop` applies the COSMIC/GNOME equivalents of the macOS key
repeat and energy defaults. It writes whichever of the two is present, so a box
with both installed gets both.

The units differ three ways, which is the whole reason this needs a script:

| Setting | macOS | COSMIC | GNOME |
| --- | --- | --- | --- |
| repeat delay | `InitialKeyRepeat = 10` (x15 ms) | `repeat_delay: 150` (ms) | `delay 150` (ms) |
| repeat speed | `KeyRepeat = 1` (x15 ms) | `repeat_rate: 66` (**Hz**) | `repeat-interval 15` (ms) |
| screen off | `pmset displaysleep 30` (min) | `screen_off_time Some(1800000)` (**ms**) | `idle-delay 1800` (**s**) |
| suspend on AC | *never* | `suspend_on_ac_time None` | `sleep-inactive-ac-type 'nothing'` |
| suspend on battery | `pmset -b sleep 60` (min) | `suspend_on_battery_time Some(3600000)` | `sleep-inactive-battery-timeout 3600` |

macOS counts 15 ms ticks, COSMIC wants a *rate* in Hz, GNOME wants an
*interval* in ms — same intent, three encodings.

"Never suspend on AC" is spelled differently again: COSMIC uses `None` rather
than a number, and GNOME wants `sleep-inactive-ac-type 'nothing'` (the script
also zeroes the timeout, since either alone is enough but both is unambiguous).
Set `SUSPEND_AC_MIN` in the script to a non-zero number to re-enable it.

Note macOS is still on `pmset -c sleep 120`; the Linux boxes are the ones set
to never.

COSMIC config lives at `~/.config/cosmic/<component>/v1/<key>`, one RON value
per file. The script rewrites only `repeat_delay`/`repeat_rate` in `xkb_config`
so your keyboard layout is left alone. **Log out and back in** for COSMIC to
pick the changes up.

## macOS defaults

`[bootstrap.macos.defaults]` holds 57 keys. The following were deliberately
left out because they do nothing on current macOS — **don't add them back**:

| Keys | Why they're dead |
| --- | --- |
| `com.apple.Safari` (24 keys) | Safari's container is TCC-protected; every key reads back `unset` after being written |
| `com.apple.appstore` | App Store stopped being a WebKit app in Mojave |
| `com.apple.screensaver` `askForPassword*` | superseded by the Ventura+ lock-screen settings |
| `com.apple.commerce` `AutoUpdate*` | overlaps `com.apple.SoftwareUpdate`, which is set |
| `AppleFontSmoothing` | subpixel antialiasing was removed in Mojave; no-op on Retina |
| `NSWindowResizeTime` | legacy Cocoa knob, ignored by modern AppKit |
| `com.apple.terminal` / `.Terminal` | Terminal.app isn't used (Ghostty is). Note the two spellings are the same file only because APFS is case-insensitive — that would break on a case-sensitive volume |
| `com.google.Chrome.canary` | not installed |

`LSQuarantine = false` is set **deliberately**: it suppresses the "downloaded
from the internet, are you sure?" prompt. That's a security tradeoff, not an
oversight — remove it if you'd rather keep the prompt.

## Per-machine values

`home/gitconfig` is a plain symlink with the email baked in. For per-machine
values, mise can render templates instead:

```toml
"~/.gitconfig" = { source = "home/gitconfig.tmpl", mode = "template" }
```

Templates are Tera and get `env`, `vars` and `exec()`.
