#!/bin/bash
# Writes $1 to $2, downscaled to fit $3 (default 512x512).
#
# Both Linux packagers reject an oversized icon (appimagetool takes a fixed
# resolution list topping out at 512x512, flatpak validates the icon against the
# hicolor directory it lands in) while the app asset is 1024x1024. Resizing at
# package time keeps one icon in the repo: a second, smaller copy would drift
# from the one the app actually ships.
set -euo pipefail

SRC="$1"
DEST="$2"
SIZE="${3:-512x512}"

if command -v magick > /dev/null; then
  magick "$SRC" -resize "$SIZE" "$DEST"
elif convert -version 2> /dev/null | grep -qi imagemagick; then
  # Ubuntu's ImageMagick 6 ships `convert` and no `magick`. The -version check
  # is what keeps this off Windows' unrelated convert.exe in a Git Bash shell.
  convert "$SRC" -resize "$SIZE" "$DEST"
else
  echo "Warning: ImageMagick not found; copying $SRC unresized." >&2
  echo "         Packaging will fail unless it is already $SIZE or smaller." >&2
  cp "$SRC" "$DEST"
fi
