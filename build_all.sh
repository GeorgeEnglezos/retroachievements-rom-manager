#!/usr/bin/env bash
# Local multi-platform build. Builds whatever this machine can actually build,
# reusing the same steps as .github/workflows/build.yml, and skips anything
# that needs a different host OS or missing tooling instead of failing.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

# Bump the build number (the +N in `version: X.Y.Z+N`) on every build. The
# semantic X.Y.Z is left alone; that's a deliberate, human decision. The
# running app reads this back via package_info_plus and shows it bottom-left.
bump_build_number() {
  local cur base build
  cur=$(grep '^version:' pubspec.yaml | awk '{print $2}')
  if [[ "$cur" == *+* ]]; then base=${cur%+*}; build=${cur#*+}; else base=$cur; build=0; fi
  build=$((build + 1))
  sed -i -E "s/^version: .*/version: ${base}+${build}/" pubspec.yaml
  echo "==> Bumped version to ${base}+${build}"
}
bump_build_number

echo "==> flutter pub get"
flutter pub get

# Regenerate launcher icons from assets/thumbnail.png so Windows/Android always
# build with the current icon. The generated files are committed, but stale if
# thumbnail.png changed without a manual regen.
echo "==> Regenerating launcher icons"
dart run flutter_launcher_icons

build_windows() {
  echo "==> Building Windows"
  flutter build windows --release

  echo "==> Bundling VC++ runtime DLLs"
  powershell.exe -NoProfile -Command '
    $vsPath = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath
    $crtDir = Get-ChildItem -Path (Join-Path $vsPath "VC\Redist\MSVC") -Recurse -Directory -Filter "Microsoft.VC*.CRT" |
      Where-Object { $_.FullName -like "*\x64\*" } |
      Sort-Object FullName -Descending |
      Select-Object -First 1
    if (-not $crtDir) { throw "Could not locate the VC++ x64 CRT redist folder under $vsPath" }
    $dest = "build\windows\x64\runner\Release"
    foreach ($dll in "msvcp140.dll", "vcruntime140.dll", "vcruntime140_1.dll") {
      Copy-Item (Join-Path $crtDir.FullName $dll) (Join-Path $dest $dll) -Force
    }
  ' || echo "WARNING: could not bundle VC++ runtime DLLs (is Visual Studio installed?)"

  local iscc=""
  for candidate in \
    "/c/Program Files (x86)/Inno Setup 6/ISCC.exe" \
    "/c/Program Files/Inno Setup 6/ISCC.exe" \
    "$HOME/AppData/Local/Programs/Inno Setup 6/ISCC.exe"; do
    [[ -f "$candidate" ]] && iscc="$candidate" && break
  done
  if [[ -n "$iscc" ]]; then
    echo "==> Building Windows installer"
    local version
    version=$(grep '^version:' pubspec.yaml | awk '{print $2}' | sed -E 's/\+.*$//; s/-.*$//')
    # MSYS2_ARG_CONV_EXCL stops Git Bash from mangling the /D flag into a path.
    MSYS2_ARG_CONV_EXCL="/D" "$iscc" "/DMyAppVersion=$version" installer.iss
  else
    echo "SKIP Windows installer: Inno Setup (ISCC.exe) not found"
  fi
}

build_linux() {
  echo "==> Building Linux"
  flutter build linux --release
  bash package_linux.sh
  bash package_appimage.sh
  # Flatpak needs flatpak-builder plus a multi-GB GNOME runtime download;
  # left to CI. Run package_flatpak.sh by hand if you need a local .flatpak.
}

build_macos() {
  echo "==> Building macOS"
  flutter build macos --release
  local app
  app=$(find build/macos/Build/Products/Release -maxdepth 1 -name '*.app' | head -1)
  [[ -n "$app" ]] && mkdir -p artifacts/macos && cp -r "$app" artifacts/macos/
}

build_android() {
  echo "==> Building Android APK"
  flutter build apk --release
  mkdir -p artifacts/android
  cp build/app/outputs/flutter-apk/app-release.apk artifacts/android/
}

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) build_windows ;;
  Linux) build_linux ;;
  Darwin) build_macos ;;
  *) echo "SKIP desktop build: unrecognized host OS $(uname -s)" ;;
esac

build_android || echo "SKIP Android: build failed (Android SDK/NDK not configured?)"

echo "==> Done. Collected outputs are under artifacts/ (raw builds under build/<platform>/)."
