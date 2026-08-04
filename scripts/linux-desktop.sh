#!/usr/bin/env bash
#
# Linux desktop settings — the counterpart to [bootstrap.macos.defaults] and
# scripts/macos-extras.sh. Applies the same key-repeat and energy behaviour to
# COSMIC and/or GNOME, whichever is installed.
#
# Run with: mise run linux-desktop
#
# Values are translated from the macOS settings in mise.toml:
#
#   macOS                              equivalent
#   ---------------------------------  ---------------------------------------
#   InitialKeyRepeat = 10  (x15ms)     150 ms before the first repeat
#   KeyRepeat = 1          (x15ms)     15 ms between repeats -> 66 repeats/sec
#   pmset displaysleep 30              screen off after 30 min
#   pmset -c sleep 0                   never suspend on AC
#   pmset -b sleep 60                  suspend after 60 min on battery
#
# macOS stores key repeat as a count of 15 ms ticks; COSMIC wants a delay in ms
# plus a *rate* in Hz, and GNOME wants a delay plus an *interval* in ms.
#
set -uo pipefail

if [ "$(uname -s)" = "Darwin" ]; then
  echo "==> macOS; use `mise run macos` instead."
  exit 0
fi

REPEAT_DELAY_MS=150
REPEAT_INTERVAL_MS=15
REPEAT_RATE_HZ=66          # 1000 / 15, rounded

SCREEN_OFF_MIN=30
SUSPEND_AC_MIN=0           # 0 = never suspend while on AC
SUSPEND_BATTERY_MIN=60

applied=0

ac_label() { [ "$SUSPEND_AC_MIN" -eq 0 ] && echo "never" || echo "${SUSPEND_AC_MIN}m"; }

###############################################################################
# COSMIC                                                                      #
###############################################################################
# Config is one file per key under ~/.config/cosmic/<component>/v1/<key>,
# each holding a RON value.

COSMIC_COMP="$HOME/.config/cosmic/com.system76.CosmicComp/v1"
COSMIC_IDLE="$HOME/.config/cosmic/com.system76.CosmicIdle/v1"

if command -v cosmic-comp >/dev/null 2>&1 || [ -d "$HOME/.config/cosmic" ]; then
  echo "==> COSMIC: key repeat (${REPEAT_DELAY_MS}ms delay, ${REPEAT_RATE_HZ}Hz)"
  mkdir -p "$COSMIC_COMP"
  xkb="$COSMIC_COMP/xkb_config"
  if [ -f "$xkb" ]; then
    # Rewrite only the two repeat fields, preserving layout/model/variant.
    sed -i -E "s/repeat_delay: *[0-9]+/repeat_delay: ${REPEAT_DELAY_MS}/; \
               s/repeat_rate: *[0-9]+/repeat_rate: ${REPEAT_RATE_HZ}/" "$xkb"
  else
    cat > "$xkb" <<RON
(
    rules: "",
    model: "pc105",
    layout: "us",
    variant: "",
    options: None,
    repeat_delay: ${REPEAT_DELAY_MS},
    repeat_rate: ${REPEAT_RATE_HZ},
)
RON
  fi

  echo "==> COSMIC: energy (screen ${SCREEN_OFF_MIN}m, AC $(ac_label), battery ${SUSPEND_BATTERY_MIN}m)"
  mkdir -p "$COSMIC_IDLE"
  # cosmic-idle stores Option<u32> milliseconds; None means never.
  printf 'Some(%d)' "$((SCREEN_OFF_MIN * 60 * 1000))"      > "$COSMIC_IDLE/screen_off_time"
  printf 'Some(%d)' "$((SUSPEND_BATTERY_MIN * 60 * 1000))" > "$COSMIC_IDLE/suspend_on_battery_time"
  if [ "$SUSPEND_AC_MIN" -eq 0 ]; then
    printf 'None' > "$COSMIC_IDLE/suspend_on_ac_time"
  else
    printf 'Some(%d)' "$((SUSPEND_AC_MIN * 60 * 1000))" > "$COSMIC_IDLE/suspend_on_ac_time"
  fi
  applied=1
fi

###############################################################################
# GNOME                                                                       #
###############################################################################

if command -v gsettings >/dev/null 2>&1 && gsettings list-schemas 2>/dev/null | grep -q "^org.gnome.desktop.peripherals.keyboard$"; then
  echo "==> GNOME: key repeat (${REPEAT_DELAY_MS}ms delay, ${REPEAT_INTERVAL_MS}ms interval)"
  gsettings set org.gnome.desktop.peripherals.keyboard delay "$REPEAT_DELAY_MS"
  gsettings set org.gnome.desktop.peripherals.keyboard repeat-interval "$REPEAT_INTERVAL_MS"

  echo "==> GNOME: energy (screen ${SCREEN_OFF_MIN}m, AC $(ac_label), battery ${SUSPEND_BATTERY_MIN}m)"
  gsettings set org.gnome.desktop.session idle-delay "$((SCREEN_OFF_MIN * 60))"
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout "$((SUSPEND_BATTERY_MIN * 60))"
  gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type suspend
  if [ "$SUSPEND_AC_MIN" -eq 0 ]; then
    # Belt and braces: 'nothing' is the explicit never, timeout 0 also disables.
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type nothing
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
  else
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type suspend
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout "$((SUSPEND_AC_MIN * 60))"
  fi

  # Matches the NSGlobalDomain trackpad settings in mise.toml.
  echo "==> GNOME: tap to click, disable natural scrolling"
  gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true
  gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll false
  applied=1
fi

echo
if [ "$applied" -eq 1 ]; then
  echo "==> Done. Log out and back in for COSMIC changes to take effect."
else
  echo "==> No supported desktop found (looked for COSMIC and GNOME); nothing applied."
fi
