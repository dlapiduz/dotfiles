#!/usr/bin/env bash
#
# Restart the apps whose preferences [bootstrap.macos.defaults] rewrites, so
# the new values take effect. Run automatically as the `post-defaults` hook.
#
set -uo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  exit 0
fi

for app in "Activity Monitor" \
  "cfprefsd" \
  "Dock" \
  "Finder" \
  "Google Chrome" \
  "SystemUIServer"; do
  killall "${app}" &>/dev/null || true
done

echo "Restarted affected apps. Some changes still need a logout/restart."
