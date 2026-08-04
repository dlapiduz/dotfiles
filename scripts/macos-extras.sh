#!/usr/bin/env bash
#
# macOS tweaks that [bootstrap.macos.defaults] in mise.toml can't express:
#   - array- and dict-valued defaults
#   - defaults needing sudo or -currentHost
#   - values needing an absolute $HOME (mise expands neither ~ nor {{env.HOME}})
#   - PlistBuddy edits, pmset, chflags, PAM
#
# Run with: mise run macos
#
# Deliberately NOT `set -e`: these are independent best-effort tweaks, and
# macOS removes or restricts them between releases. One dead command must not
# stop the rest — failures are collected and reported at the end instead.
#
set -uo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  echo "==> Not macOS; nothing to do."
  exit 0
fi

FAILED=()

# step "description" cmd args...
step() {
  local desc="$1"; shift
  echo "==> ${desc}"
  if ! "$@" >/dev/null 2>&1; then
    echo "    SKIPPED — command failed"
    FAILED+=("${desc}")
  fi
}

fail() { echo "    SKIPPED — $1"; FAILED+=("$1"); }

echo "==> Requesting sudo up front"
if ! sudo -v; then
  echo "Cannot obtain sudo; run this from an interactive terminal." >&2
  exit 1
fi
# Keep the sudo timestamp alive until this script exits
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

###############################################################################
# General UI/UX                                                               #
###############################################################################

step "Login window: show host info when clicking the clock" \
  sudo defaults write /Library/Preferences/com.apple.loginwindow AdminHostInfo HostName

# NOTE: lsregister's old `-kill` flag (which reset the LaunchServices database
# to de-duplicate the "Open With" menu) was removed by Apple as "dangerous and
# no longer useful". A plain rescan is what remains.
step "Rescanning the LaunchServices database" \
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -r -domain local -domain system -domain user

###############################################################################
# Input (-currentHost scoped)                                                 #
###############################################################################

step "Trackpad: tap to click (per-host)" \
  defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

step "Prevent Photos opening when devices are plugged in" \
  defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

###############################################################################
# Energy saving                                                               #
###############################################################################

step "Display sleep after 30 min"     sudo pmset -a displaysleep 30
step "Sleep after 60 min on battery"  sudo pmset -b sleep 60
step "Sleep after 120 min on AC"      sudo pmset -c sleep 120
step "Standby delay 24h"              sudo pmset -a standbydelay 86400

###############################################################################
# Paths needing an absolute $HOME                                             #
###############################################################################

step "Screenshot directory" mkdir -p "${HOME}/Desktop/Screenshots"
step "Screenshots save to ~/Desktop/Screenshots" \
  defaults write com.apple.screencapture location -string "${HOME}/Desktop/Screenshots"
step "Finder: new windows open at Desktop" \
  defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/Desktop/"

###############################################################################
# Finder (dict values + PlistBuddy)                                           #
###############################################################################

step "Finder: expand File Info panes" \
  defaults write com.apple.finder FXInfoPanesExpanded -dict \
    General -bool true OpenWith -bool true Privileges -bool true

echo "==> Finder: snap-to-grid and icon size in icon views"
for view in DesktopViewSettings FK_StandardViewSettings StandardViewSettings; do
  for setting in "arrangeBy grid" "iconSize 80"; do
    /usr/libexec/PlistBuddy -c "Set :${view}:IconViewSettings:${setting}" \
      ~/Library/Preferences/com.apple.finder.plist >/dev/null 2>&1 || true
  done
done

step "Unhide ~/Library" chflags nohidden "${HOME}/Library"
xattr -d com.apple.FinderInfo "${HOME}/Library" >/dev/null 2>&1 || true
step "Unhide /Volumes"  sudo chflags nohidden /Volumes

###############################################################################
# Touch ID for sudo                                                           #
###############################################################################
# macOS 14+ ships /etc/pam.d/sudo_local for exactly this. Don't edit
# /etc/pam.d/sudo in place — a malformed file there can lock you out of sudo.

echo "==> Enabling Touch ID for sudo"
if [ -e /etc/pam.d/sudo_local.template ] || [ -e /etc/pam.d/sudo_local ]; then
  if sudo grep -qs '^auth.*pam_tid\.so' /etc/pam.d/sudo_local 2>/dev/null; then
    echo "    already enabled"
  elif printf 'auth       sufficient     pam_tid.so\n' | sudo tee /etc/pam.d/sudo_local >/dev/null; then
    echo "    enabled via /etc/pam.d/sudo_local"
  else
    fail "Touch ID for sudo"
  fi
else
  fail "Touch ID for sudo (no sudo_local support on this macOS)"
fi

###############################################################################

echo
if [ ${#FAILED[@]} -eq 0 ]; then
  echo "==> Done. Some changes need a logout/restart to take effect."
else
  echo "==> Done, with ${#FAILED[@]} skipped:"
  printf '      - %s\n' "${FAILED[@]}"
  echo "    Some changes need a logout/restart to take effect."
fi
