#!/usr/bin/env bash
#
# Install the MesloLGS NF fonts that powerlevel10k expects.
# Run with: mise run fonts
#
set -euo pipefail

BASE="https://github.com/romkatv/powerlevel10k-media/raw/master"

case "$(uname -s)" in
  Darwin) FONT_DIR="$HOME/Library/Fonts" ;;
  *)      FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts" ;;
esac

mkdir -p "$FONT_DIR"

for variant in "Regular" "Bold" "Italic" "Bold Italic"; do
  encoded="MesloLGS%20NF%20${variant// /%20}.ttf"
  target="$FONT_DIR/MesloLGS NF ${variant}.ttf"
  if [ -f "$target" ]; then
    echo "==> MesloLGS NF ${variant} already installed"
  else
    echo "==> Downloading MesloLGS NF ${variant}"
    curl -fsSL -o "$target" "${BASE}/${encoded}"
  fi
done

# Linux needs the font cache rebuilt before apps see the new files.
if command -v fc-cache >/dev/null; then
  echo "==> Rebuilding font cache"
  fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
fi

echo "==> Fonts installed to $FONT_DIR. Set your terminal font to 'MesloLGS NF'."
