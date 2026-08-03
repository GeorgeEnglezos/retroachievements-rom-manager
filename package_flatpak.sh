#!/bin/bash
# Packages the Linux release bundle into a single-file Flatpak at
# artifacts/flatpak/rarm-x86_64.flatpak
#
# This is the "self-distributed" flatpak: it grants broad host filesystem
# access so the app can scan/reveal/trash ROMs anywhere on disk. It will NOT
# be accepted on Flathub because of that permission.
#
# Requires: flatpak, flatpak-builder, and the flathub remote.
# Must be run from the repo root, after `flutter build linux --release`.
set -euo pipefail

APP_ID="com.georgeenglezos.rarm"
APP_NAME="rarm"
DISPLAY_NAME="Retroachievements Rom Manager"
BUILD_PATH="build/linux/x64/release/bundle"
OUT_DIR="artifacts/flatpak"
STAGE="flatpak/_stage"

if [ ! -d "$BUILD_PATH" ]; then
  echo "Error: release bundle not found at $BUILD_PATH" >&2
  echo "Run 'flutter build linux --release' first." >&2
  exit 1
fi

# --- Stage the prebuilt bundle + desktop file next to a copy of the manifest --
# flatpak-builder's `dir` source resolves paths relative to the manifest, so
# everything the manifest references must sit in the same directory.
rm -rf "$STAGE"
mkdir -p "$STAGE/bundle"
cp -r "${BUILD_PATH}/." "$STAGE/bundle/"
cp "flatpak/${APP_ID}.yml" "$STAGE/${APP_ID}.yml"

# flatpak build-export validates an icon against the hicolor directory it lands
# in, and the app asset is 1024x1024, so stage a downscaled copy for the
# manifest to install.
bash resize_icon.sh "${BUILD_PATH}/data/flutter_assets/icon.png" \
  "$STAGE/${APP_ID}.png"

cat > "$STAGE/${APP_ID}.desktop" << DESKTOP_EOF
[Desktop Entry]
Name=${DISPLAY_NAME}
Comment=Validate your ROMs against RetroAchievements hashes
Exec=${APP_NAME}
Icon=${APP_ID}
Terminal=false
Type=Application
Categories=Utility;Game;
DESKTOP_EOF

# --- Build, then export a single-file .flatpak bundle -------------------------
mkdir -p "$OUT_DIR"

flatpak-builder --force-clean --user --install-deps-from=flathub \
  --repo=.flatpak-repo .flatpak-build "$STAGE/${APP_ID}.yml"

flatpak build-bundle .flatpak-repo \
  "${OUT_DIR}/rarm-x86_64.flatpak" "$APP_ID"

echo "Flatpak bundle created:"
ls -lh "${OUT_DIR}/rarm-x86_64.flatpak"
