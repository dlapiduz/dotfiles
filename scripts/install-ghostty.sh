#!/usr/bin/env bash
#
# Install Ghostty on Linux.
#
# Run with: mise run ghostty
#
# Ghostty can't go in [bootstrap.packages] on Linux: it isn't in Fedora's or
# Debian's official repos and has no Flathub build, so there's no `dnf:` /
# `apt:` / `flatpak:` entry that would work. Upstream ships:
#
#   Fedora         COPR scottames/ghostty     (community-maintained)
#   Debian/Ubuntu  .deb from mkasberg/ghostty-ubuntu  (community-maintained)
#   Snap           snap install ghostty --classic     (built in Ghostty's CI)
#   macOS          the brew cask, already in mise.macos.toml
#
# Both Linux options are third-party. The Snap is the only one upstream builds
# itself, so it's preferred when snapd is present.
#
set -uo pipefail

# Platform check first: on macOS `ghostty` can resolve to a copy bundled inside
# another app, so don't let that masquerade as an install.
case "$(uname -s)" in
  Darwin)
    echo "==> macOS: ghostty comes from the brew cask in mise.macos.toml."
    echo "    MISE_ENV=macos mise bootstrap"
    exit 0
    ;;
esac

if command -v ghostty >/dev/null 2>&1; then
  echo "==> ghostty already installed: $(command -v ghostty)"
  exit 0
fi

# --- Snap: the only build upstream produces itself -------------------------
if command -v snap >/dev/null 2>&1; then
  echo "==> Installing ghostty via snap (upstream-built)"
  sudo snap install ghostty --classic && exit 0
  echo "    snap install failed; falling through to distro packages"
fi

# --- Fedora / RHEL: COPR ---------------------------------------------------
if command -v dnf >/dev/null 2>&1; then
  # `dnf copr` lives in a plugin package: dnf5-plugins on Fedora 41+ (where dnf
  # is dnf5), dnf-plugins-core on dnf4. Without it you get "Unknown argument".
  if ! dnf copr --help >/dev/null 2>&1; then
    echo "==> Installing the dnf copr plugin"
    if dnf --version 2>/dev/null | grep -q "^dnf5"; then
      sudo dnf -y install dnf5-plugins || { echo "    failed" >&2; exit 1; }
    else
      sudo dnf -y install dnf-plugins-core || { echo "    failed" >&2; exit 1; }
    fi
  fi

  echo "==> Fedora: enabling COPR scottames/ghostty (third-party)"
  sudo dnf -y copr enable scottames/ghostty || {
    echo "    failed to enable the COPR" >&2; exit 1; }
  sudo dnf -y install ghostty || { echo "    dnf install failed" >&2; exit 1; }
  echo "==> Installed: $(command -v ghostty)"
  exit 0
fi

# --- Debian / Ubuntu: community .deb ---------------------------------------
# Fetched from the GitHub release rather than piping upstream's install script
# into a shell, so the artifact is visible before it runs.
if command -v apt-get >/dev/null 2>&1; then
  echo "==> Debian/Ubuntu: fetching the latest ghostty .deb (third-party)"
  arch=$(dpkg --print-architecture)
  # Assets are named per release: Ubuntu by version (24.04, 26.04) and Debian
  # by codename (trixie, forky) — so try both identifiers.
  ver=$(. /etc/os-release && echo "${VERSION_ID:-}")
  code=$(. /etc/os-release && echo "${VERSION_CODENAME:-}")
  api="https://api.github.com/repos/mkasberg/ghostty-ubuntu/releases/latest"

  urls=$(curl -fsSL "$api" | grep -oE 'https://[^"]+\.deb') || {
    echo "    could not reach the GitHub release API" >&2; exit 1; }

  # Prefer an exact arch + release match, else any build for this arch.
  url=""
  for id in "$ver" "$code"; do
    [ -n "$id" ] || continue
    url=$(echo "$urls" | grep "_${arch}_" | grep -- "${id}" | head -1)
    [ -n "$url" ] && break
  done
  [ -z "$url" ] && url=$(echo "$urls" | grep "_${arch}_" | head -1)
  [ -z "$url" ] && { echo "    no .deb found for ${arch}" >&2; exit 1; }

  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  echo "    $url"
  curl -fsSL -o "$tmp/ghostty.deb" "$url" || { echo "    download failed" >&2; exit 1; }
  sudo apt-get install -y "$tmp/ghostty.deb" || { echo "    install failed" >&2; exit 1; }
  echo "==> Installed: $(command -v ghostty)"
  exit 0
fi

echo "No supported install path found. See https://ghostty.org/docs/install/binary" >&2
exit 1
