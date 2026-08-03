# Retroachievements Rom Manager (RARM)

[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20Android-blue)]()
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Built with Flutter](https://img.shields.io/badge/built%20with-Flutter-02569B?logo=flutter)](https://flutter.dev)

Point it at your ROM folders and instantly see which of your games are on
[RetroAchievements](https://retroachievements.org/), how many achievements each
has, and how far along you are, all in one place.

<!-- TODO: drop a hero screenshot here. Paste an image into this line on GitHub and it auto-uploads. -->
<!-- <img width="2559" alt="Retroachievements Rom Manager - Library" src="..." /> -->

---

## 🎯 Overview

RARM scans your local ROM library, fingerprints every game the same
way RetroArch does, and matches it against the RetroAchievements database, so
your collection and your achievement progress finally live in the same view.
Built with Flutter, it runs natively on Windows, Linux, and Android. macOS and
iOS builds exist but are untested; see [Platform Support](#-platform-support).

### What is RetroAchievements?

[RetroAchievements](https://retroachievements.org/) adds achievements to retro
games played through supported emulators. Each game is identified by a hash of
its ROM, and the site tracks the achievements you've earned per game.

### What does RARM add?

- **Instant collection overview**: see which of *your* ROMs have achievements, at a glance
- **Progress at a glance**: earned counts, points, and casual/hardcore status per game
- **RA-compatible hashing**: the same scheme RetroArch uses, including compressed formats
- **Library cleanup**: spot duplicates and misfiled ROMs across your whole collection
- **"Play Next" picks**: ranked "what should I play next?" suggestions from your own progress
- **Storage insight**: a treemap of exactly where your disk space is going
- **Local-first & private**: your library and credentials never leave your device (only ROM hashes do)

---

## 🚀 Quick Start

### Prerequisites

- A free [RetroAchievements account](https://retroachievements.org/) and your
  **web API key** (found under *Settings → Keys* on the RA website).
- A local library of ROMs you legally own.

### Installation

**Windows**: the easiest way to get started:

Grab the installer from the [Releases](https://github.com/GeorgeEnglezos/retroachievements-rom-manager/releases)
page and run it:

```
rarm-setup-vX.X.X.exe
```

**Other platforms**: download the latest build for your OS from
[Releases](https://github.com/GeorgeEnglezos/retroachievements-rom-manager/releases):

- **Windows (portable)**: `rarm-windows-vX.X.X.zip`
- **macOS**: `rarm-macos-vX.X.X.zip`
- **Linux (AppImage)**: `rarm-vX.X.X-x86_64.AppImage`
- **Linux (Flatpak)**: `rarm-vX.X.X-x86_64.flatpak`
- **Android**: `rarm-android-vX.X.X.apk`

### First Use

1. Launch RARM
2. Open **Settings** and enter your RA **username** and **API key**
3. Pick the folder that holds your ROMs
4. Hit **Scan**: the app hashes each ROM and matches it against RetroAchievements
5. Browse your library, sorted by system, with achievement counts and progress

That's it. Your collection is now mapped to RetroAchievements.

---

## ✨ Key Features

### 🔍 Scanning & Hashing

- Recursive folder scanning across all your systems
- RA-compatible hashing (matches RetroArch), including `.zip` and `.chd`
- Compressed & disc formats handled via a bundled native plugin
- Incremental rescans that skip what hasn't changed

### 🏆 Achievement Tracking

- Matches each ROM to its RA game and pulls achievement counts
- Your earned progress, casual and hardcore, points, and last-played
- Per-game detail view: box art, screenshots, badge grid, progress bar, and a link to the RA page

### 🗂️ Library Organisation

- Group folders by system, with combined-system views
- Duplicate detection across your whole library
- Wrong-folder detection for ROMs that look misfiled
- Favorites and custom playlists

### 🎮 Play Next

- Ranked "what should I play next?" lists across your whole collection
- Scores each game on your progress, hardcore status, achievement count, and community size
- Surfaces near-mastery games and popular sets you haven't touched yet

### 📊 Scan Health & Reports

- A read-only dashboard that turns your scan into decision-oriented counts
- Export the whole picture as CSV, JSON, or Markdown

### 💾 Storage View

- A treemap of disk usage by folder and system, so you can see where the space went

---

<!--
Screenshots section, restored once real captures exist. To add them: paste the
images into this file in GitHub's editor to upload them, replace each src, then
move this block out of the comment.

## 🖼️ Screenshots

<div align="center">
   <img width="48%" alt="Library overview" src="URL" />
   <img width="48%" alt="Game detail" src="URL" />
</div>

<div align="center">
   <img width="48%" alt="Play Next recommendations" src="URL" />
   <img width="48%" alt="Storage treemap" src="URL" />
</div>
-->

## 💻 Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Windows | ✅ Fully Supported | Windows 10/11 |
| Linux | ✅ Fully Supported | AppImage & Flatpak |
| macOS | ⚠️ Untested | Builds in CI but not verified on a device; the maintainer has no Apple hardware. Contributions welcome. |
| Android | ⚠️ Beta | Builds run; folder-access flow still being verified on device |
| iOS | ⚠️ Untested | Builds in CI but not verified on a device; the maintainer has no Apple hardware. Contributions welcome. |

---

## 🔒 Privacy

RARM is **local-first**. Your ROM library, scan results, playlists,
and RA credentials all stay on your device.

- Only the **MD5 hash** of a ROM is sent to RetroAchievements to look up its game
  ID; the ROM file itself never leaves your machine.
- Your username and API key are used solely to fetch your own progress from the RA API.
- No telemetry, no background sync, no phoning home. Requests are throttled to
  respect RA's rate limits.

---

## 🗺️ Roadmap

Shipped so far: scanning & hashing (incl. GameCube/Wii discs), RA lookup &
progress sync, per-game details, library organisation with duplicate &
wrong-folder detection, bulk actions, incremental rescans, backup & restore,
"Play Next" recommendations, a scan-health dashboard with CSV/JSON/Markdown
export, an emulator "Play" button, storage view, global search, and a
RetroAchievements-inspired theme.

Coming next: reverse-gap detection, hash-fix suggestions, and improved mobile
folder access.

---

## 🤝 Contributing

Contributions are welcome!

1. **Report bugs**: open an issue with clear reproduction steps
2. **Suggest features**: share ideas in the discussions
3. **Improve docs**: help make things clearer
4. **Share**: tell other RetroAchievements players about the project

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/GeorgeEnglezos/retroachievements-rom-manager/issues)
- **RetroAchievements**: [retroachievements.org](https://retroachievements.org/)

---

## 📜 License

Released under the [MIT License](LICENSE).

This project bundles third-party libraries inside `packages/raw_hash/src/vendor/`,
each of which stays under its own permissive license: rcheevos (MIT),
libchdr (BSD-3-Clause), and libchdr's bundled codecs zstd, miniz, lzma, and
dr_flac.
RetroAchievements is a trademark of its respective owners; this is an unofficial
community tool and is not affiliated with RetroAchievements.

---

<div align="center">

**Made with ❤️ for the RetroAchievements community**

[⬆ Back to Top](#retroachievements-rom-manager-rarm)

</div>
